extends CharacterBody3D
class_name EnemyBase

signal enemy_died(enemy: Node3D)

@export var max_health: int = 60
@export var stagger_threshold: int = 20
@export var stagger_duration: float = 0.4

@export_group("Pneuma")
@export var drops_pneuma: bool = true
@export var pneuma_drop_amount: float = 15.0

var health: int = 60
var accumulated_damage: int = 0
var is_dead: bool = false
var player: Node3D = null
var hit_sound: AudioStreamPlayer3D = null
var death_sound: AudioStreamPlayer3D = null


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_find_player()

	hit_sound = AudioStreamPlayer3D.new()
	hit_sound.stream = SfxGenerator.enemy_hit()
	hit_sound.max_db = 10.0
	add_child(hit_sound)

	death_sound = AudioStreamPlayer3D.new()
	death_sound.stream = SfxGenerator.enemy_death()
	death_sound.max_db = 12.0
	add_child(death_sound)


func _find_player() -> void:
	await get_tree().process_frame
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node3D


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	accumulated_damage += amount

	if hit_sound:
		hit_sound.play()

	if accumulated_damage >= stagger_threshold:
		accumulated_damage = 0
		_on_stagger()

	if health <= 0:
		_die()


func _on_stagger() -> void:
	pass


func _die() -> void:
	is_dead = true
	if death_sound:
		death_sound.play()
	enemy_died.emit(self)


func get_center_position() -> Vector3:
	return global_position + Vector3.UP * 0.9
