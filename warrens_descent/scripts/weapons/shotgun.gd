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

var player: CharacterBody3D = null
var camera: Camera3D = null
var fire_sound: AudioStreamPlayer = null
var reload_sound: AudioStreamPlayer = null


func _ready() -> void:
	player = _find_player()
	if player:
		camera = player.get_node("CameraHolder/CameraEffects/Camera3D") as Camera3D

	fire_sound = AudioStreamPlayer.new()
	fire_sound.stream = SfxGenerator.shotgun_fire()
	fire_sound.volume_db = -6.0
	add_child(fire_sound)

	reload_sound = AudioStreamPlayer.new()
	reload_sound.stream = SfxGenerator.shotgun_reload()
	reload_sound.volume_db = -8.0
	add_child(reload_sound)


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
	if not player or not camera:
		return false

	can_fire = false
	fire_timer = fire_rate
	current_ammo -= 1

	if fire_sound:
		fire_sound.play()

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var cam_transform: Transform3D = camera.global_transform

	for i in pellet_count:
		var spread_dir: Vector3 = _get_spread_direction(cam_transform)
		var from: Vector3 = cam_transform.origin
		var to: Vector3 = from + spread_dir * range_distance

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 0b00000101)
		query.exclude = [player.get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)

		var hit: bool = false
		var end_pos: Vector3 = to
		if not result.is_empty():
			end_pos = result.get("position", Vector3.ZERO) as Vector3
			var hit_normal: Vector3 = result.get("normal", Vector3.UP) as Vector3
			var collider = result.get("collider")
			if collider and collider.has_method("take_damage"):
				hit = true
				collider.take_damage(damage_per_pellet)
				_spawn_blood(end_pos, hit_normal)

		get_parent().record_shot(hit)
		_spawn_tracer(from, end_pos)

	return true


func _get_spread_direction(cam_transform: Transform3D) -> Vector3:
	var forward: Vector3 = -cam_transform.basis.z
	var spread_rad: float = deg_to_rad(spread_degrees)
	var random_angle: float = randf() * TAU
	var random_spread: float = randf() * spread_rad
	var right: Vector3 = cam_transform.basis.x
	var up: Vector3 = cam_transform.basis.y
	var spread_offset: Vector3 = (right * cos(random_angle) + up * sin(random_angle)) * sin(random_spread)
	return (forward + spread_offset).normalized()


func reload() -> void:
	if current_ammo >= max_ammo or reserve_ammo <= 0 or is_reloading:
		return
	is_reloading = true
	shells_to_load = mini(max_ammo - current_ammo, reserve_ammo)
	reload_timer = reload_time
	if reload_sound:
		reload_sound.play()


func _load_one_shell() -> void:
	if shells_to_load > 0 and reserve_ammo > 0:
		current_ammo += 1
		reserve_ammo -= 1
		shells_to_load -= 1
		if shells_to_load > 0:
			reload_timer = reload_time
			if reload_sound:
				reload_sound.play()
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
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
	return null


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(Vector3.ZERO)
	imm.surface_add_vertex(to_pos - from_pos)
	imm.surface_end()
	mesh_inst.mesh = imm
	mesh_inst.global_position = from_pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.5)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	get_tree().current_scene.add_child(mesh_inst)
	var tween := get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(mesh_inst.queue_free)


func _spawn_blood(pos: Vector3, normal: Vector3) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.4
	particles.explosiveness = 0.9
	particles.direction = normal
	particles.spread = 35.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0, -12, 0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.05, 0.02)
	var blood_mesh: BoxMesh = BoxMesh.new()
	blood_mesh.size = Vector3(0.04, 0.04, 0.04)
	blood_mesh.material = mat
	particles.mesh = blood_mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
