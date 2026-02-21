extends Node3D

@export var enemy_grunt_scene: PackedScene
@export var pickup_health_scene: PackedScene
@export var pickup_ammo_scene: PackedScene

var enemy_spawn_points: Array[Vector3] = [
	Vector3(-12, 1, -12),
	Vector3(12, 1, -12),
	Vector3(-12, 1, 12),
	Vector3(12, 1, 12),
	Vector3(0, 1, -15),
]

var pickup_health_positions: Array[Vector3] = [
	Vector3(-8, 1, 0),
	Vector3(8, 1, 0),
	Vector3(0, 1, -10),
]

var pickup_ammo_positions: Array[Vector3] = [
	Vector3(-5, 1, -8),
	Vector3(5, 1, 8),
	Vector3(-10, 1, 10),
	Vector3(10, 1, -10),
]

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	enemy_grunt_scene = load("res://scenes/enemy_grunt.tscn")
	pickup_health_scene = load("res://scenes/pickup_health.tscn")
	pickup_ammo_scene = load("res://scenes/pickup_ammo.tscn")

	# Bake navigation mesh at runtime (required since we use CSG)
	nav_region.bake_finished.connect(_on_nav_bake_finished)
	nav_region.bake_navigation_mesh()


func _on_nav_bake_finished() -> void:
	_spawn_enemies()
	_spawn_pickups()


func _spawn_enemies() -> void:
	for pos in enemy_spawn_points:
		_spawn_enemy_at(pos)


func _spawn_enemy_at(pos: Vector3) -> void:
	if not enemy_grunt_scene:
		return
	var enemy := enemy_grunt_scene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.enemy_died.connect(_on_enemy_died.bind(pos))


func _on_enemy_died(enemy: EnemyBase, spawn_pos: Vector3) -> void:
	# Drop a random pickup at death location
	var drop_pos := enemy.global_position
	drop_pos.y = 1.0
	_spawn_pickup_at(drop_pos, [pickup_health_scene, pickup_ammo_scene].pick_random())

	# Respawn enemy after delay
	await get_tree().create_timer(8.0).timeout
	if is_inside_tree():
		_spawn_enemy_at(spawn_pos)


func _spawn_pickups() -> void:
	for pos in pickup_health_positions:
		_spawn_pickup_at(pos, pickup_health_scene)
	for pos in pickup_ammo_positions:
		_spawn_pickup_at(pos, pickup_ammo_scene)


func _spawn_pickup_at(pos: Vector3, scene: PackedScene) -> void:
	if not scene:
		return
	var pickup := scene.instantiate()
	add_child(pickup)
	pickup.global_position = pos
