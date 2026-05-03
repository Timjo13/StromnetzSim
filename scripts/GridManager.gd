extends Node

const NOMINAL_FREQ       = 50.0
const FREQ_RATE          = 0.005
const FREQ_DANGER        = 1.5
const EVENT_INTERVAL_MIN = 8.0
const EVENT_INTERVAL_MAX = 18.0
const FLUCT_AMP          = 0.15   # ±15 % Verbrauchsschwankung
const FLUCT_PERIOD       = 60.0   # Sekunden pro vollständigem Zyklus

var frequency:         float = NOMINAL_FREQ
var game_active:       bool  = true
var grid_nodes:        Array = []
var grid_lines:        Array = []
var elapsed_time:      float = 0.0
var score:             int   = 0
var _score_acc:        float = 0.0
var _next_event_timer: float = 0.0
var _active_events:    Array = []
var _rng:              RandomNumberGenerator = RandomNumberGenerator.new()
var _fluct_phase:      Dictionary = {}   # consumer node → float phase offset

signal frequency_updated(freq: float)
signal game_over(reason: String)
signal stats_updated(time: float, score: int)
signal event_triggered(msg: String)

func _ready():
	_rng.randomize()
	_schedule_next_event()

func setup(nodes: Array, lines: Array):
	grid_nodes = nodes
	grid_lines = lines
	_fluct_phase.clear()
	for n in grid_nodes:
		if n.state_changed.is_connected(_on_node_changed):
			n.state_changed.disconnect(_on_node_changed)
		n.state_changed.connect(_on_node_changed)
		if n.node_type == 1:   # consumer: assign random phase so peaks don't align
			_fluct_phase[n] = _rng.randf() * TAU
	print("GridManager: %d Knoten, %d Leitungen" % [grid_nodes.size(), grid_lines.size()])

func _process(delta: float):
	if not game_active:
		return

	elapsed_time += delta
	_update_score(delta)
	_fluctuate_consumers()
	_tick_events(delta)
	stats_updated.emit(elapsed_time, score)

	_update_line_flows()

	for line in grid_lines:
		if not line.tripped and line.is_overloaded():
			line.trip()
			var reason = "Schutzschalter ausgelöst!\nLeitung %s überlastet\n(%.0f MW > %.0f MW Limit)" % [line.name, line.current_load, line.max_capacity]
			_trigger_game_over(reason)
			return

	var net_power = _calc_net_power()
	frequency += net_power * FREQ_RATE * delta
	frequency = clamp(frequency, 44.0, 56.0)
	frequency_updated.emit(frequency)

	if abs(frequency - NOMINAL_FREQ) >= FREQ_DANGER:
		var reason = "Frequenz kollabiert\n(%.2f Hz)" % frequency
		_trigger_game_over(reason)

func _calc_net_power() -> float:
	var total = 0.0
	for n in grid_nodes:
		total += n.get_power()
	return total

func _update_score(delta: float):
	var dev = abs(frequency - NOMINAL_FREQ)
	var stability = clamp(1.0 - dev / FREQ_DANGER, 0.0, 1.0)
	_score_acc += delta * 10.0 * stability
	score = int(_score_acc)

func _update_line_flows():
	# Reset
	for line in grid_lines:
		if not line.tripped:
			line.set_flow(0.0, 1.0)

	# Undirected adjacency (active lines only)
	var adj: Dictionary = {}
	for n in grid_nodes:
		adj[n] = []
	for line in grid_lines:
		if line.tripped or not line.node_a or not line.node_b:
			continue
		adj[line.node_a].append({"node": line.node_b, "line": line})
		adj[line.node_b].append({"node": line.node_a, "line": line})

	# Total generation / consumption
	var total_gen := 0.0
	var total_con := 0.0
	for n in grid_nodes:
		var p = n.get_power()
		if p > 0.0: total_gen += p
		else:       total_con -= p
	if total_gen < 0.01 or total_con < 0.01:
		return

	# Generators can only supply what they produce; scale demand accordingly
	var supply_ratio := minf(total_gen / total_con, 1.0)

	# Signed flow accumulator (positive = node_a → node_b)
	var flow_acc: Dictionary = {}
	for line in grid_lines:
		flow_acc[line] = 0.0

	# For each consumer: BFS to all reachable generators, distribute
	# scaled demand proportionally, route along shortest-path tree.
	for consumer in grid_nodes:
		var demand: float = -consumer.get_power()
		if demand <= 0.0:
			continue
		var served: float = demand * supply_ratio

		# BFS from consumer outward
		var parent: Dictionary = {consumer: null}
		var queue  := [consumer]
		var qi     := 0
		var gens   := []
		var gen_sum := 0.0
		while qi < queue.size():
			var curr = queue[qi]; qi += 1
			var p = curr.get_power()
			if p > 0.0:
				gens.append(curr)
				gen_sum += p
			for nb in adj.get(curr, []):
				if not (nb.node in parent):
					parent[nb.node] = {"node": curr, "line": nb.line}
					queue.append(nb.node)

		if gens.is_empty() or gen_sum < 0.01:
			continue  # isolated consumer – no supply reachable

		# Route each generator's proportional share back toward consumer
		for gen in gens:
			var power: float = served * gen.get_power() / gen_sum
			var curr  = gen
			while parent.get(curr) != null:
				var hop = parent[curr]
				var ln  = hop.line
				flow_acc[ln] += power if ln.node_a == curr else -power
				curr = hop.node

	# Push results to lines
	for line in grid_lines:
		if line.tripped:
			continue
		var f: float = flow_acc.get(line, 0.0)
		line.set_flow(abs(f), sign(f) if abs(f) > 0.01 else 1.0)

func _fluctuate_consumers():
	for n in grid_nodes:
		if n.node_type != 1:
			continue
		var phase: float = _fluct_phase.get(n, 0.0)
		n.demand_mult = 1.0 + FLUCT_AMP * sin(TAU * elapsed_time / FLUCT_PERIOD + phase)
		n.queue_redraw()

func _schedule_next_event():
	_next_event_timer = _rng.randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)

func _tick_events(delta: float):
	_next_event_timer -= delta
	if _next_event_timer <= 0.0:
		_fire_event()
		_schedule_next_event()
	for i in range(_active_events.size() - 1, -1, -1):
		var ev = _active_events[i]
		ev.timer -= delta
		if ev.timer <= 0.0:
			_revert_event(ev)
			_active_events.remove_at(i)

func _fire_event():
	if _rng.randi() % 2 == 0:
		_fire_load_spike()
	else:
		_fire_gen_failure()

func _fire_load_spike():
	var already_spiked = []
	for ev in _active_events:
		if ev.type == "load_spike":
			already_spiked.append(ev.node)
	var candidates = []
	for n in grid_nodes:
		if n.node_type == 1 and n.is_active and not n in already_spiked:
			candidates.append(n)
	if candidates.is_empty():
		return
	var target = candidates[_rng.randi() % candidates.size()]
	var orig = target.power_value
	target.power_value = orig * 1.8
	target.queue_redraw()
	_active_events.append({"type": "load_spike", "node": target, "original": orig, "timer": 10.0})
	event_triggered.emit("Lastspitze: %s (+80%%, 10s)" % target.name)

func _fire_gen_failure():
	var already_failed = []
	for ev in _active_events:
		if ev.type == "gen_failure":
			already_failed.append(ev.node)
	var candidates = []
	for n in grid_nodes:
		if n.node_type == 0 and n.is_active and not n in already_failed:
			candidates.append(n)
	if candidates.is_empty():
		return
	var target     = candidates[_rng.randi() % candidates.size()]
	var saved_step = target.throttle_step
	target.force_off()
	_active_events.append({"type": "gen_failure", "node": target, "saved_step": saved_step, "timer": 12.0})
	event_triggered.emit("Generatorausfall: %s (12s)" % target.name)

func _revert_event(ev: Dictionary):
	if not is_instance_valid(ev.node):
		return
	if ev.type == "load_spike":
		ev.node.power_value = ev.original
		ev.node.queue_redraw()
	elif ev.type == "gen_failure" and not ev.node.is_active:
		ev.node.force_restore(ev.get("saved_step", 5))

func _on_node_changed():
	pass

func _trigger_game_over(reason: String):
	game_active = false
	print("GAME OVER – %s" % reason)
	game_over.emit(reason)
