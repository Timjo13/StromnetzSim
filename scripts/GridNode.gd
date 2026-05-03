extends Area2D

enum NodeType { GENERATOR, CONSUMER }

@export var node_type:   NodeType = NodeType.GENERATOR
@export var power_value: float    = 10.0   # current output / demand (MW)

var base_power:    float = 0.0   # nominal max (set once in _ready)
var throttle_step: int   = 5     # 1..STEPS when active
var demand_mult:   float = 1.0   # fluctuation multiplier, set each frame by GridManager
var is_active:     bool  = true
var _color_on:  Color
var _color_off: Color

const RADIUS    = 28.0
const STEPS     = 5
# Buttons sit below the circle; y-origin = RADIUS + padding
const BTN_MINUS = Rect2(-28.0, 38.0, 13.0, 12.0)
const BTN_PLUS  = Rect2( 15.0, 38.0, 13.0, 12.0)

signal state_changed

func _ready():
	add_to_group("grid_nodes")
	base_power = power_value
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

	if node_type == NodeType.GENERATOR:
		draw_string(font, Vector2(-18, -6), "G",
				HORIZONTAL_ALIGNMENT_CENTER, 36, 13, Color.WHITE)
		draw_string(font, Vector2(-27, 10),
				"%.0f/%.0fMW" % [abs(get_power()), base_power],
				HORIZONTAL_ALIGNMENT_CENTER, 54, 10, Color(1, 1, 1, 0.85))

		# Throttle bar – 5 segments
		for i in range(STEPS):
			var filled = is_active and i < throttle_step
			var sc = Color(0.2, 0.85, 0.4, 0.9) if filled else Color(0.25, 0.25, 0.25, 0.8)
			draw_rect(Rect2(-22.0 + i * 10.0, RADIUS + 3.0, 8.0, 5.0), sc, true)

		# − button (dimmed when off)
		var mc = Color(0.75, 0.28, 0.28, 0.9) if is_active else Color(0.35, 0.35, 0.35, 0.65)
		draw_rect(BTN_MINUS, mc, true)
		draw_string(font, Vector2(BTN_MINUS.position.x, BTN_MINUS.end.y - 1.0), "−",
				HORIZONTAL_ALIGNMENT_CENTER, int(BTN_MINUS.size.x), 12, Color.WHITE)

		# + button (dimmed when at max)
		var pc = Color(0.28, 0.70, 0.28, 0.9) \
				if (not is_active or throttle_step < STEPS) \
				else Color(0.35, 0.35, 0.35, 0.65)
		draw_rect(BTN_PLUS, pc, true)
		draw_string(font, Vector2(BTN_PLUS.position.x, BTN_PLUS.end.y - 1.0), "+",
				HORIZONTAL_ALIGNMENT_CENTER, int(BTN_PLUS.size.x), 12, Color.WHITE)
	else:
		# Consumer: show actual / nominal; orange when above nominal (Lastspitze)
		draw_string(font, Vector2(-18, -6), "V",
				HORIZONTAL_ALIGNMENT_CENTER, 36, 13, Color.WHITE)
		var actual_con := power_value * demand_mult
		var oc = Color(1.0, 0.55, 0.2, 1.0) if actual_con > base_power * 1.02 \
				else Color(1, 1, 1, 0.85)
		draw_string(font, Vector2(-27, 10),
				"%.0f/%.0fMW" % [actual_con, base_power],
				HORIZONTAL_ALIGNMENT_CENTER, 54, 10, oc)

func _unhandled_input(event):
	if node_type != NodeType.GENERATOR:
		return
	if not (event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var local = to_local(event.position)
	if BTN_MINUS.has_point(local):
		step_down()
		get_viewport().set_input_as_handled()
	elif BTN_PLUS.has_point(local):
		step_up()
		get_viewport().set_input_as_handled()
	elif local.length() <= RADIUS:
		toggle()
		get_viewport().set_input_as_handled()

# ── Power control ──────────────────────────────────────────────────────────────

func step_up():
	if not is_active:
		# Turn on at current throttle_step (or STEPS if never changed)
		is_active = true
		power_value = base_power * throttle_step / float(STEPS)
		queue_redraw()
		state_changed.emit()
	elif throttle_step < STEPS:
		throttle_step += 1
		power_value = base_power * throttle_step / float(STEPS)
		queue_redraw()
		state_changed.emit()

func step_down():
	if not is_active:
		return
	if throttle_step > 1:
		throttle_step -= 1
		power_value = base_power * throttle_step / float(STEPS)
		queue_redraw()
		state_changed.emit()
	else:
		# Already at minimum step – treat as toggle off
		is_active = false
		queue_redraw()
		state_changed.emit()

func toggle():
	# Circle click: fast full-on / off
	if is_active:
		is_active = false
	else:
		is_active = true
		throttle_step = STEPS
		power_value = base_power
	queue_redraw()
	state_changed.emit()

# Used by event system to disable without disturbing throttle_step
func force_off():
	is_active = false
	queue_redraw()
	state_changed.emit()

# Used by event system to restore to the pre-failure throttle level
func force_restore(step: int):
	throttle_step = clampi(step, 1, STEPS)
	is_active = true
	power_value = base_power * throttle_step / float(STEPS)
	queue_redraw()
	state_changed.emit()

func get_power() -> float:
	if not is_active:
		return 0.0
	return power_value if node_type == NodeType.GENERATOR else -power_value * demand_mult
