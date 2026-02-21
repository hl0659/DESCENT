extends Node3D

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
var pickup_health_scene: PackedScene = preload("res://scenes/pickup_health.tscn")
var pickup_ammo_scene: PackedScene = preload("res://scenes/pickup_ammo.tscn")
var pneuma_pickup_scene: PackedScene = preload("res://scenes/pneuma_pickup.tscn")


func _ready() -> void:
	_build_hub()
	_spawn_player()
	_spawn_pickups()

	var hud := hud_scene.instantiate()
	add_child(hud)


func _build_hub() -> void:
	# Environment
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.15, 0.15, 0.2)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	# Floor
	MeshBuilder.add_box(self, Vector3(30, 0.5, 30), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())

	# Low walls around the edge
	MeshBuilder.add_box(self, Vector3(30, 2, 0.5), Vector3(0, 1, -15.25), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(30, 2, 0.5), Vector3(0, 1, 15.25), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(0.5, 2, 30), Vector3(-15.25, 1, 0), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(0.5, 2, 30), Vector3(15.25, 1, 0), LevelMaterials.wall_mat())

	# Lighting
	MeshBuilder.add_light(self, Vector3(0, 8, 0), Color(0.8, 0.8, 0.9), 2.0, 20.0)

	# Portal — glowing area that starts the run
	var portal_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.5
	cylinder.bottom_radius = 1.5
	cylinder.height = 4.0
	portal_mesh.mesh = cylinder
	var portal_mat := StandardMaterial3D.new()
	portal_mat.albedo_color = Color("8B7500")
	portal_mat.emission_enabled = true
	portal_mat.emission = Color("FFD700")
	portal_mat.emission_energy_multiplier = 2.0
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mat.albedo_color.a = 0.4
	portal_mesh.material_override = portal_mat
	portal_mesh.position = Vector3(0, 2.0, -10)
	add_child(portal_mesh)

	# Portal trigger
	var portal_area := Area3D.new()
	portal_area.collision_layer = 0
	portal_area.collision_mask = 2  # Player
	portal_area.position = Vector3(0, 2.0, -10)
	add_child(portal_area)
	var portal_col := CollisionShape3D.new()
	var portal_shape := CylinderShape3D.new()
	portal_shape.radius = 1.5
	portal_shape.height = 4.0
	portal_col.shape = portal_shape
	portal_area.add_child(portal_col)
	portal_area.body_entered.connect(_on_portal_entered)

	# Portal light
	MeshBuilder.add_light(self, Vector3(0, 4, -10), Color(0.85, 0.7, 0.3), 3.0, 8.0)


func _spawn_player() -> void:
	var player := player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1, 5)


func _spawn_pickups() -> void:
	var health := pickup_health_scene.instantiate()
	add_child(health)
	health.global_position = Vector3(-4, 0.5, 0)

	var ammo := pickup_ammo_scene.instantiate()
	add_child(ammo)
	ammo.global_position = Vector3(4, 0.5, 0)

	var pneuma := pneuma_pickup_scene.instantiate()
	add_child(pneuma)
	pneuma.global_position = Vector3(0, 0.5, 2)


func _on_portal_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_start_run()


func _start_run() -> void:
	get_tree().change_scene_to_file("res://scenes/generated_level.tscn")
