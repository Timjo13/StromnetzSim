extends CanvasLayer

const NOMINAL  = 50.0
const MAX_DEV  = 1.5   # muss gleich FREQ_DANGER in GridManager sein

@onready var freq_bar:       ProgressBar = $FreqContainer/FreqBar
@onready var freq_label:     Label       = $FreqContainer/FreqLabel
@onready var status_label:   Label       = $StatusLabel
@onready var game_over_panel: Panel      = $GameOverPanel

func _ready():
	game_over_panel.visible = false
	status_label.text = "Stabil"

func on_frequency_updated(freq: float):
	var deviation = freq - NOMINAL
	var ratio     = clamp(abs(deviation) / MAX_DEV, 0.0, 1.0)

	freq_label.text  = "%.2f Hz" % freq
	# ProgressBar: 0 = 50Hz, -1 = zu wenig, +1 = zu viel  →  in 0–100 umrechnen
	freq_bar.value   = 50.0 + (deviation / MAX_DEV) * 50.0

	if ratio < 0.4:
		freq_bar.modulate    = Color(0.2, 0.9, 0.3)
		status_label.text    = "● Stabil"
		status_label.modulate = Color.WHITE
	elif ratio < 0.8:
		freq_bar.modulate    = Color(1.0, 0.8, 0.0)
		status_label.text    = "⚠ Instabil"
		status_label.modulate = Color.YELLOW
	else:
		freq_bar.modulate    = Color(1.0, 0.2, 0.2)
		status_label.text    = "⛔ Kritisch!"
		status_label.modulate = Color.RED

func on_game_over():
	game_over_panel.visible = true
