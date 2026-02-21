extends Node3D

@export var damage: int = 8
@export var fire_interval: float = 0.083
@export var max_ammo: int = 30
@export var reload_time: float = 1.5
@export var range_distance: float = 80.0
@export var base_spread: float = 0.5
@export var max_spread: float = 4.0
@export var spread_increase: float = 0.3
@export var spread_recovery: float = 5.0

var current_ammo: int = 30
var reserve_ammo: int = 120
var can_fire: bool = true
var is_reloading: bool = false
var fire_timer: float = 0.0
var reload_timer: float = 0.0
var current_spread: float = 0.5

@onready var player: CharacterBody3D = null
@onready var camera: Camera3D = null


func _ready() -> void:
	player = _find_player()
	if player:
		camera = player.get_node("CameraHolder/Camera3D")
	current_spread = base_spread


func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	# Spread recovery
	if not Input.is_action_pressed("fire"):
		current_spread = move_toward(current_spread, base_spread, spread_recovery * delta)


func fire() -> bool:
	if not can_fire or current_ammo <= 0 or is_reloading:
		return false

	can_fire = false
	fire_timer = fire_interval
	current_ammo -= 1

	var space_state := player.get_world_3d().direct_space_state
	var cam_transform := camera.global_transform
	var spread_dir := _get_spread_direction(cam_transform)
	var from := cam_transform.origin
	var to := from + spread_dir * range_distance

	var query := PhysicsRayQueryParameters3D.create(from, to, 0b00000101)  # layers 1 + 3
	query.exclude = [player.get_rid()]
	var result := space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage)

	# Increase spread bloom
	current_spread = min(current_spread + spread_increase, max_spread)

	return true


func _get_spread_direction(cam_transform: Transform3D) -> Vector3:
	var forward := -cam_transform.basis.z
	var spread_rad := deg_to_rad(current_spread)
	var random_angle := randf() * TAU
	var random_spread := randf() * spread_rad
	var right := cam_transform.basis.x
	var up := cam_transform.basis.y
	var spread_offset := (right * cos(random_angle) + up * sin(random_angle)) * sin(random_spread)
	return (forward + spread_offset).normalized()


func reload() -> void:
	if current_ammo >= max_ammo or reserve_ammo <= 0 or is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time


func _finish_reload() -> void:
	var needed := max_ammo - current_ammo
	var loaded := min(needed, reserve_ammo)
	current_ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false


func is_auto() -> bool:
	return true


func get_weapon_name() -> String:
	return "SMG"


func get_ammo_info() -> Vector2i:
	return Vector2i(current_ammo, reserve_ammo)


func add_ammo(amount: int) -> void:
	reserve_ammo += amount


func _find_player() -> CharacterBody3D:
	var node := self
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
