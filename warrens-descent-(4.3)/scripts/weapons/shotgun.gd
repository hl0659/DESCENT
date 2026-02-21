extends Node3D

@export var pellet_count: int = 8
@export var spread_degrees: float = 5.0
@export var damage_per_pellet: int = 12
@export var fire_rate: float = 0.8
@export var max_ammo: int = 6
@export var reload_time: float = 0.5
@export var range_distance: float = 50.0

var current_ammo: int = 6
var reserve_ammo: int = 30
var can_fire: bool = true
var is_reloading: bool = false
var fire_timer: float = 0.0
var reload_timer: float = 0.0
var shells_to_load: int = 0

@onready var player: CharacterBody3D = null
@onready var camera: Camera3D = null


func _ready() -> void:
	player = _find_player()
	if player:
		camera = player.get_node("CameraHolder/Camera3D")


func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_load_one_shell()


func fire() -> bool:
	if not can_fire or current_ammo <= 0 or is_reloading:
		return false

	can_fire = false
	fire_timer = fire_rate
	current_ammo -= 1

	# Cast rays for each pellet
	var space_state := player.get_world_3d().direct_space_state
	var cam_transform := camera.global_transform

	for i in pellet_count:
		var spread_dir := _get_spread_direction(cam_transform)
		var from := cam_transform.origin
		var to := from + spread_dir * range_distance

		var query := PhysicsRayQueryParameters3D.create(from, to, 0b00000101)  # layers 1 + 3
		query.exclude = [player.get_rid()]
		var result := space_state.intersect_ray(query)

		if result:
			var collider = result.collider
			if collider.has_method("take_damage"):
				collider.take_damage(damage_per_pellet)

	return true


func _get_spread_direction(cam_transform: Transform3D) -> Vector3:
	var forward := -cam_transform.basis.z
	var spread_rad := deg_to_rad(spread_degrees)
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
	shells_to_load = min(max_ammo - current_ammo, reserve_ammo)
	reload_timer = reload_time


func _load_one_shell() -> void:
	if shells_to_load > 0 and reserve_ammo > 0:
		current_ammo += 1
		reserve_ammo -= 1
		shells_to_load -= 1
		if shells_to_load > 0:
			reload_timer = reload_time
		else:
			is_reloading = false
	else:
		is_reloading = false


func is_auto() -> bool:
	return false


func get_weapon_name() -> String:
	return "SHOTGUN"


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
