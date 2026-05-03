extends Node

const NOMINAL_FREQ  = 50.0   # Ziel-Frequenz in Hz
const FREQ_RATE     = 0.05   # Hz-Änderung pro MW Ungleichgewicht pro Sekunde
const FREQ_DANGER   = 1.5    # Abweichung in Hz → Game Over
const FREQ_WARN     = 0.8    # Abweichung in Hz → Warnung

var frequency: float = NOMINAL_FREQ
var game_active: bool = true
var grid_nodes: Array = []

signal frequency_updated(freq: float)
signal game_over

func _ready():
	# Nodes erst nach _ready aller Kinder einsammeln
	call_deferred("_collect_nodes")

func _collect_nodes():
	grid_nodes = get_tree().get_nodes_in_group("grid_nodes")
	for n in grid_nodes:
		n.state_changed.connect(_on_node_changed)
	print("GridManager: %d Knoten gefunden" % grid_nodes.size())

func _process(delta: float):
	if not game_active:
		return

	var net_power = _calc_net_power()
	# Frequenz steigt bei Überschuss, fällt bei Defizit
	frequency += net_power * FREQ_RATE * delta
	frequency = clamp(frequency, 44.0, 56.0)

	frequency_updated.emit(frequency)

	if abs(frequency - NOMINAL_FREQ) >= FREQ_DANGER:
		_trigger_game_over()

func _calc_net_power() -> float:
	var total = 0.0
	for n in grid_nodes:
		total += n.get_power()
	return total

func _on_node_changed():
	pass  # Frequenzupdate läuft kontinuierlich in _process

func _trigger_game_over():
	game_active = false
	print("GAME OVER – Frequenz: %.2f Hz" % frequency)
	game_over.emit()
