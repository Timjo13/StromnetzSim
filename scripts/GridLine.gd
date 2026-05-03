extends Line2D

func _ready():
	width = 3.0
	default_color = Color(0.4, 0.65, 1.0, 0.75)

## Verbindet zwei Positionen (globale Koordinaten des Parent-Node)
func connect_nodes(from_pos: Vector2, to_pos: Vector2):
	clear_points()
	add_point(from_pos)
	add_point(to_pos)
