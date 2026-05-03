extends Line2D

@export var node_a_path: NodePath
@export var node_b_path: NodePath
@export var max_capacity: float = 20.0  # MW

var node_a: Node = null
var node_b: Node = null
var current_load: float = 0.0
var flow_direction: float = 1.0
var tripped: bool = false
var _blink_timer: float = 0.0
var _blink_visible: bool = true

func _ready():
	width = 4.0
	default_color = Color(0.3, 0.4, 0.6, 0.4)
	if node_a_path:
		node_a = get_node(node_a_path)
	if node_b_path:
		node_b = get_node(node_b_path)
	if node_a and node_b:
		clear_points()
		add_point(node_a.position)
		add_point(node_b.position)

func _draw():
	if get_point_count() < 2 or tripped or current_load < 0.5:
		return
	var mid  = (get_point_position(0) + get_point_position(1)) / 2.0
	var font = ThemeDB.fallback_font
	var lbl  = "%.0f/%.0fMW" % [current_load, max_capacity]
	draw_rect(Rect2(mid + Vector2(-23, -10), Vector2(46, 13)), Color(0, 0, 0, 0.60), true)
	draw_string(font, mid + Vector2(-22, 1), lbl, HORIZONTAL_ALIGNMENT_CENTER, 44, 10, Color.WHITE)

func _process(delta):
	if not node_a or not node_b:
		return
	set_point_position(0, node_a.position)
	set_point_position(1, node_b.position)
	queue_redraw()

	if tripped:
		_blink_timer += delta
		if _blink_timer >= 0.15:
			_blink_timer = 0.0
			_blink_visible = !_blink_visible
		visible = _blink_visible
		default_color = Color(1.0, 0.1, 0.1, 1.0)
		width = 9.0
	else:
		visible = true
		_update_visuals()

func set_flow(load_mw: float, direction: float):
	current_load = abs(load_mw)
	flow_direction = direction

func trip():
	tripped = true
	current_load = 0.0

func _update_visuals():
	var ratio = clamp(current_load / max_capacity, 0.0, 1.0)
	if ratio < 0.01:
		default_color = Color(0.3, 0.4, 0.6, 0.4)
		width = 2.0
	elif ratio < 0.5:
		default_color = Color(0.2, 0.8, 0.4, 0.9)
		width = 3.0 + ratio * 4.0
	elif ratio < 0.85:
		default_color = Color(1.0, 0.75, 0.0, 0.9)
		width = 5.0 + ratio * 4.0
	else:
		default_color = Color(1.0, 0.3, 0.1, 1.0)
		width = 8.0

func is_overloaded() -> bool:
	return current_load > max_capacity
