extends CharacterBody3D
class_name EnemyBase

signal enemy_died(enemy: EnemyBase)

@export var max_health: int = 60
@export var stagger_threshold: int = 20
@export var stagger_duration: float = 0.4

var health: int = 60
var accumulated_damage: int = 0
var is_dead: bool = false
var player: CharacterBody3D = null


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_find_player()


func _find_player() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	accumulated_damage += amount

	if accumulated_damage >= stagger_threshold:
		accumulated_damage = 0
		_on_stagger()

	if health <= 0:
		_die()


func _on_stagger() -> void:
	pass  # Override in subclass


func _die() -> void:
	is_dead = true
	enemy_died.emit(self)
	# Subclass handles actual removal


func get_center_position() -> Vector3:
	return global_position + Vector3.UP * 0.9
