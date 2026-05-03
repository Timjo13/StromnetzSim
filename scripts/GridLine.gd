extends Line2D

@export var node_a_path: NodePath
@export var node_b_path: NodePath
@export var max_capacity: float = 20.0  # MW

var node_a: Node = null
var node_b: Node = null
var current_load: float = 0.0  # MW
var flow_direction: float = 1.0  # +1 = A→B, -1 = B→A

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

func _process(_delta):
	if not node_a or not node_b:
		return
	set_point_position(0, node_a.position)
	set_point_position(1, node_b.position)
	_update_visuals()

func set_flow(load_mw: float, direction: float):
	current_load = abs(load_mw)
	flow_direction = direction

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
		default_color = Color(1.0, 0.2, 0.1, 1.0)
		width = 8.0

func is_overloaded() -> bool:
	return current_load > max_capacity
