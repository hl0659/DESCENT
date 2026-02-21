extends Node3D

var spawn_position: Vector3 = Vector3(0, 2, 0)
var player: CharacterBody3D = null


func _ready() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		spawn_position = player.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and player and not player.is_dead:
			player.global_position = spawn_position
			player.velocity = Vector3.ZERO
		elif event.keycode == KEY_F5 and player:
			player.gain_pneuma(player.max_pneuma)
		elif event.keycode == KEY_F1:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
