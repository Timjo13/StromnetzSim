extends Node

const NOMINAL_FREQ       = 50.0
const FREQ_RATE          = 0.005
const FREQ_DANGER        = 1.5
const EVENT_INTERVAL_MIN = 8.0
const EVENT_INTERVAL_MAX = 18.0

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
	for n in grid_nodes:
		if n.state_changed.is_connected(_on_node_changed):
			n.state_changed.disconnect(_on_node_changed)
		n.state_changed.connect(_on_node_changed)
	print("GridManager: %d Knoten, %d Leitungen" % [grid_nodes.size(), grid_lines.size()])

func _process(delta: float):
	if not game_active:
		return

	elapsed_time += delta
	_update_score(delta)
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
	for line in grid_lines:
		if line.tripped or not line.node_a or not line.node_b:
			continue
		var power_a = line.node_a.get_power()
		var power_b = line.node_b.get_power()
		var flow = 0.0
		var direction = 1.0
		if power_a > 0 and power_b <= 0:
			flow = min(power_a, abs(power_b))
			direction = 1.0
		elif power_b > 0 and power_a <= 0:
			flow = min(power_b, abs(power_a))
			direction = -1.0
		line.set_flow(flow, direction)

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
