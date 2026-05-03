extends CanvasLayer

const NOMINAL  = 50.0
const MAX_DEV  = 1.5

@onready var freq_bar:        ProgressBar = $FreqContainer/FreqBar
@onready var freq_label:      Label       = $FreqContainer/FreqLabel
@onready var status_label:    Label       = $StatusLabel
@onready var score_label:     Label       = $ScoreLabel
@onready var event_label:     Label       = $EventLabel
@onready var game_over_panel: Panel       = $GameOverPanel
@onready var reason_label:    Label       = $GameOverPanel/ReasonLabel

var _last_score: int   = 0
var _last_time:  float = 0.0
var _event_timer: float = 0.0

func _ready():
	game_over_panel.visible = false
	event_label.visible = false
	status_label.text = "Stabil"

func _process(delta: float):
	if _event_timer > 0.0:
		_event_timer -= delta
		if _event_timer <= 0.0:
			event_label.visible = false

func on_frequency_updated(freq: float):
	var deviation = freq - NOMINAL
	var ratio     = clamp(abs(deviation) / MAX_DEV, 0.0, 1.0)
	freq_label.text = "%.2f Hz" % freq
	freq_bar.value  = 50.0 + (deviation / MAX_DEV) * 50.0
	if ratio < 0.4:
		freq_bar.modulate     = Color(0.2, 0.9, 0.3)
		status_label.text     = "● Stabil"
		status_label.modulate = Color.WHITE
	elif ratio < 0.8:
		freq_bar.modulate     = Color(1.0, 0.8, 0.0)
		status_label.text     = "⚠ Instabil"
		status_label.modulate = Color.YELLOW
	else:
		freq_bar.modulate     = Color(1.0, 0.2, 0.2)
		status_label.text     = "⛔ Kritisch!"
		status_label.modulate = Color.RED

func on_stats_updated(time: float, score: int):
	_last_score = score
	_last_time  = time
	score_label.text = "Zeit: %ds  |  Punkte: %d" % [int(time), score]

func on_event_triggered(msg: String):
	event_label.text    = "! " + msg
	event_label.visible = true
	_event_timer        = 4.0

func on_game_over(reason: String):
	game_over_panel.visible = true
	reason_label.text = "%s\n\nPunkte: %d  |  Zeit: %ds" % [reason, _last_score, int(_last_time)]

func _on_restart_pressed():
	get_tree().reload_current_scene()
