extends Area2D

enum NodeType { GENERATOR, CONSUMER }

@export var node_type: NodeType = NodeType.GENERATOR
@export var power_value: float = 10.0

var is_active: bool = true
var _color_on: Color
var _color_off: Color
const RADIUS = 28.0

signal state_changed

func _ready():
	add_to_group("grid_nodes")
	if node_type == NodeType.GENERATOR:
		_color_on  = Color(0.2, 0.85, 0.3)
		_color_off = Color(0.08, 0.32, 0.12)
	else:
		_color_on  = Color(0.9, 0.4, 0.2)
		_color_off = Color(0.4, 0.18, 0.08)
	queue_redraw()

func _draw():
	var col = _color_on if is_active else _color_off
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)

	var font = ThemeDB.fallback_font
	var prefix = "G" if node_type == NodeType.GENERATOR else "V"
	draw_string(font, Vector2(-18, -6),  prefix,           HORIZONTAL_ALIGNMENT_CENTER, 36, 14, Color.WHITE)
	draw_string(font, Vector2(-18,  10), "%.0fMW" % power_value, HORIZONTAL_ALIGNMENT_CENTER, 36, 11, Color(1,1,1,0.75))

func _unhandled_input(event):
	if node_type != NodeType.GENERATOR:
		return
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		var local = to_local(event.position)
		if local.length() <= RADIUS:
			toggle()
			get_viewport().set_input_as_handled()

func toggle():
	is_active = !is_active
	queue_redraw()
	state_changed.emit()

## Gibt positive Zahl für Erzeugung, negative für Verbrauch zurück
func get_power() -> float:
	if not is_active:
		return 0.0
	return power_value if node_type == NodeType.GENERATOR else -power_value
