extends Node

const NOMINAL_FREQ  = 50.0
const FREQ_RATE     = 0.05
const FREQ_DANGER   = 1.5

var frequency: float = NOMINAL_FREQ
var game_active: bool = true
var grid_nodes: Array = []
var grid_lines: Array = []

signal frequency_updated(freq: float)
signal game_over(reason: String)

func _ready():
	call_deferred("_collect_nodes")

func _collect_nodes():
	grid_nodes = get_tree().get_nodes_in_group("grid_nodes")
	grid_lines = get_tree().get_nodes_in_group("grid_lines")
	for n in grid_nodes:
		n.state_changed.connect(_on_node_changed)
	print("GridManager: %d Knoten, %d Leitungen" % [grid_nodes.size(), grid_lines.size()])

func _process(delta: float):
	if not game_active:
		return

	_update_line_flows()

	# Überlastung zuerst prüfen – Schutzschalter löst sofort aus
	for line in grid_lines:
		if not line.tripped and line.is_overloaded():
			line.trip()  # Leitung abschalten
			var reason = "Schutzschalter ausgelöst!\nLeitung %s überlastet\n(%.0f MW > %.0f MW Limit)" % [line.name, line.current_load, line.max_capacity]
			_trigger_game_over(reason)
			return

	# Frequenz berechnen
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

func _on_node_changed():
	pass

func _trigger_game_over(reason: String):
	game_active = false
	print("GAME OVER – %s" % reason)
	game_over.emit(reason)
