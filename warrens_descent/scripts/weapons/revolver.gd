extends Node3D

## Colt Python — Precision hand cannon. Every shot is a commitment.

@export_group("Damage")
@export var damage: int = 85
@export var range_distance: float = 30.0

@export_group("Fire Rate")
@export var fire_rate: float = 1.2

@export_group("Ammo")
@export var max_ammo: int = 6
@export var reload_time: float = 2.5

@export_group("Recoil")
@export var recoil_kick_degrees: float = 4.5
@export var recoil_snap_time: float = 0.15
@export var recoil_recover_time: float = 0.3

@export_group("Screen Shake")
@export var shake_intensity: float = 0.06
@export var shake_duration: float = 0.12

@export_group("FOV Punch")
@export var fov_punch_amount: float = -5.0
@export var fov_punch_recover_time: float = 0.2

@export_group("Muzzle Flash")
@export var flash_duration: float = 0.1
@export var flash_intensity: float = 3.0
@export var flash_range: float = 8.0

@export_group("Recovery Animation")
@export var recovery_tilt_degrees: float = 3.0
@export var recovery_tilt_time: float = 0.15
@export var recovery_return_time: float = 0.25

var current_ammo: int = 6
var reserve_ammo: int = 18
var can_fire: bool = true
var is_reloading: bool = false
var fire_timer: float = 0.0
var reload_timer: float = 0.0

var player: CharacterBody3D = null
var camera: Camera3D = null
var camera_effects: Node3D = null
var fire_sound: AudioStreamPlayer = null
var reload_sound: AudioStreamPlayer = null

# Muzzle flash
var muzzle_flash_light: OmniLight3D = null
var flash_timer: float = 0.0

# Recovery animation state
var recovery_phase: int = 0  # 0=idle, 1=tilting down, 2=returning
var recovery_timer: float = 0.0
var mesh_node: Node3D = null
var mesh_base_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	player = _find_player()
	if player:
		camera = player.get_node("CameraHolder/CameraEffects/Camera3D") as Camera3D
		camera_effects = player.get_node("CameraHolder/CameraEffects") as Node3D

	fire_sound = AudioStreamPlayer.new()
	fire_sound.stream = SfxGenerator.revolver_fire()
	fire_sound.volume_db = -3.0
	add_child(fire_sound)

	reload_sound = AudioStreamPlayer.new()
	reload_sound.stream = SfxGenerator.revolver_reload()
	reload_sound.volume_db = -6.0
	add_child(reload_sound)

	# Create muzzle flash light (starts off)
	muzzle_flash_light = OmniLight3D.new()
	muzzle_flash_light.light_color = Color(1.0, 0.9, 0.7)
	muzzle_flash_light.light_energy = 0.0
	muzzle_flash_light.omni_range = flash_range
	muzzle_flash_light.omni_attenuation = 2.0
	add_child(muzzle_flash_light)

	# Find mesh child for recovery animation (skip light node we created)
	await get_tree().process_frame
	for child in get_children():
		if child is MeshInstance3D:
			mesh_node = child
			mesh_base_rotation = child.rotation
			break
		elif child is Node3D and not (child is OmniLight3D):
			mesh_node = child
			mesh_base_rotation = child.rotation
			break


func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	# Muzzle flash fade
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			muzzle_flash_light.light_energy = 0.0
		else:
			muzzle_flash_light.light_energy = flash_intensity * (flash_timer / flash_duration)

	# Recovery animation
	_process_recovery(delta)


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

	# Hitscan — single perfect-accuracy ray
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var cam_transform: Transform3D = camera.global_transform
	var forward: Vector3 = -cam_transform.basis.z
	var from: Vector3 = cam_transform.origin
	var to: Vector3 = from + forward * range_distance

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
			collider.take_damage(damage)
			_spawn_blood(end_pos, hit_normal)

	get_parent().record_shot(hit)
	_spawn_tracer(from, end_pos)

	# Camera effects — this is what makes it feel like a hand cannon
	if camera_effects:
		if camera_effects.has_method("apply_recoil"):
			camera_effects.apply_recoil(recoil_kick_degrees, recoil_snap_time, recoil_recover_time)
		if camera_effects.has_method("apply_shake"):
			camera_effects.apply_shake(shake_intensity, shake_duration)
		if camera_effects.has_method("apply_fov_punch"):
			camera_effects.apply_fov_punch(fov_punch_amount, fov_punch_recover_time)

	# Muzzle flash
	flash_timer = flash_duration
	muzzle_flash_light.light_energy = flash_intensity

	# Start recovery animation
	recovery_phase = 1
	recovery_timer = 0.0

	return true


func reload() -> void:
	if current_ammo >= max_ammo or reserve_ammo <= 0 or is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time
	if reload_sound:
		reload_sound.play()


func _finish_reload() -> void:
	var needed: int = max_ammo - current_ammo
	var loaded: int = mini(needed, reserve_ammo)
	current_ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false


func _process_recovery(delta: float) -> void:
	if not mesh_node or recovery_phase == 0:
		return

	recovery_timer += delta

	if recovery_phase == 1:
		# Tilt downward
		var t: float = clampf(recovery_timer / recovery_tilt_time, 0.0, 1.0)
		var tilt: float = deg_to_rad(recovery_tilt_degrees) * t
		mesh_node.rotation.x = mesh_base_rotation.x + tilt
		if t >= 1.0:
			recovery_phase = 2
			recovery_timer = 0.0
	elif recovery_phase == 2:
		# Return to ready
		var t: float = clampf(recovery_timer / recovery_return_time, 0.0, 1.0)
		# Ease out
		var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
		var tilt: float = deg_to_rad(recovery_tilt_degrees) * (1.0 - eased)
		mesh_node.rotation.x = mesh_base_rotation.x + tilt
		if t >= 1.0:
			mesh_node.rotation = mesh_base_rotation
			recovery_phase = 0


func is_auto() -> bool:
	return false


func get_weapon_name() -> String:
	return "COLT PYTHON"


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
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 0.95
	particles.direction = normal
	particles.spread = 40.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -12, 0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.05, 0.02)
	var blood_mesh: BoxMesh = BoxMesh.new()
	blood_mesh.size = Vector3(0.05, 0.05, 0.05)
	blood_mesh.material = mat
	particles.mesh = blood_mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
