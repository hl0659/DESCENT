extends Control

signal continue_pressed()

@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var kills_label: Label = $VBoxContainer/KillsLabel
@onready var accuracy_label: Label = $VBoxContainer/AccuracyLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var continue_label: Label = $VBoxContainer/ContinueLabel


func show_score(time_seconds: float, kills: int, total_enemies: int, accuracy: float) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var minutes := int(time_seconds) / 60
	var seconds := int(time_seconds) % 60
	time_label.text = "TIME: %d:%02d" % [minutes, seconds]
	kills_label.text = "KILLS: %d / %d" % [kills, total_enemies]
	accuracy_label.text = "ACCURACY: %.1f%%" % accuracy

	# Score formula: weight speed and kills heavily
	var time_bonus: float = maxf(0.0, 300.0 - time_seconds) * 10.0
	var kill_score: float = kills * 100.0
	var accuracy_bonus: float = accuracy * 20.0
	var total_score: int = int(time_bonus + kill_score + accuracy_bonus)
	score_label.text = "SCORE: %d" % total_score

	continue_label.text = "PRESS ANY KEY TO CONTINUE"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		continue_pressed.emit()
	elif event is InputEventMouseButton and event.pressed:
		continue_pressed.emit()
