extends Node3D

@export_group("Head Bob")
@export var bob_frequency: float = 12.0
@export var bob_amplitude: float = 0.04

@export_group("Tilt")
@export var strafe_tilt_amount: float = 2.0
@export var tilt_speed: float = 8.0

@export_group("Landing")
@export var landing_dip_amount: float = 0.15
@export var landing_dip_recovery: float = 8.0

@export_group("Slide")
@export var slide_camera_offset: float = -0.6
@export var slide_camera_speed: float = 12.0

@export_group("FOV")
@export var base_fov: float = 90.0
@export var speed_fov_add: float = 10.0
@export var dash_fov_add: float = 20.0
@export var fov_lerp_speed: float = 6.0
@export var speed_fov_threshold: float = 12.0

var bob_time: float = 0.0
var current_tilt: float = 0.0
var landing_offset: float = 0.0
var was_on_floor: bool = true
var previous_y_velocity: float = 0.0
var slide_offset: float = 0.0

var player: CharacterBody3D = null
var camera: Camera3D = null

# Recoil state
var recoil_pitch: float = 0.0
var recoil_target: float = 0.0
var recoil_snap_speed: float = 0.0
var recoil_recover_speed: float = 0.0
var recoil_phase: int = 0  # 0=idle, 1=kicking up, 2=settling back

# Screen shake state
var shake_intensity: float = 0.0
var shake_decay: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO

# FOV punch state
var fov_punch_amount: float = 0.0
var fov_punch_recover_speed: float = 0.0


func _ready() -> void:
	player = get_parent().get_parent() as CharacterBody3D
	camera = get_node("Camera3D") as Camera3D
	if camera:
		camera.fov = base_fov


func _process(delta: float) -> void:
	if not player or not camera:
		return
	var dead = player.get("is_dead")
	if dead:
		return

	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()

	_process_head_bob(delta, speed)
	_process_strafe_tilt(delta)
	_process_landing(delta)
	_process_slide_camera(delta)
	_process_recoil(delta)
	_process_shake(delta)
	_process_fov(delta, speed)


func _process_head_bob(delta: float, speed: float) -> void:
	if player.is_on_floor() and speed > 1.0:
		bob_time += delta * bob_frequency * (speed / 10.0)
		position.y = sin(bob_time) * bob_amplitude
		position.x = cos(bob_time * 0.5) * bob_amplitude * 0.5
	else:
		bob_time = 0.0
		position.y = move_toward(position.y, 0.0, delta * 2.0)
		position.x = move_toward(position.x, 0.0, delta * 2.0)


func _process_strafe_tilt(delta: float) -> void:
	var input_x: float = Input.get_axis("move_left", "move_right")
	var target_tilt: float = -input_x * deg_to_rad(strafe_tilt_amount)
	current_tilt = lerpf(current_tilt, target_tilt, tilt_speed * delta)
	rotation.z = current_tilt


func _process_landing(delta: float) -> void:
	if player.is_on_floor() and not was_on_floor:
		var impact: float = absf(previous_y_velocity)
		if impact > 4.0:
			landing_offset = -landing_dip_amount * clampf(impact / 15.0, 0.3, 1.0)

	was_on_floor = player.is_on_floor()
	previous_y_velocity = player.velocity.y

	if absf(landing_offset) > 0.001:
		landing_offset = move_toward(landing_offset, 0.0, landing_dip_recovery * delta)
		position.y += landing_offset


func _process_slide_camera(delta: float) -> void:
	var target: float = 0.0
	if player.get("is_sliding"):
		target = slide_camera_offset
	slide_offset = move_toward(slide_offset, target, slide_camera_speed * delta)
	position.y += slide_offset


func _process_fov(delta: float, speed: float) -> void:
	var target_fov: float = base_fov

	if player.has_method("get_dash_cooldown_percent") and player.get("is_dashing"):
		target_fov = base_fov + dash_fov_add
	elif speed > speed_fov_threshold:
		var speed_factor: float = clampf((speed - speed_fov_threshold) / 8.0, 0.0, 1.0)
		target_fov = base_fov + speed_fov_add * speed_factor

	# Apply FOV punch (subtracts from FOV for zoom-in effect)
	if absf(fov_punch_amount) > 0.01:
		fov_punch_amount = move_toward(fov_punch_amount, 0.0, fov_punch_recover_speed * delta)
		target_fov += fov_punch_amount

	camera.fov = lerpf(camera.fov, target_fov, fov_lerp_speed * delta)


func _process_recoil(delta: float) -> void:
	if recoil_phase == 1:
		# Kicking up
		recoil_pitch = move_toward(recoil_pitch, recoil_target, recoil_snap_speed * delta)
		if absf(recoil_pitch - recoil_target) < 0.001:
			recoil_phase = 2
	elif recoil_phase == 2:
		# Settling back
		recoil_pitch = move_toward(recoil_pitch, 0.0, recoil_recover_speed * delta)
		if absf(recoil_pitch) < 0.001:
			recoil_pitch = 0.0
			recoil_phase = 0

	rotation.x = recoil_pitch


func _process_shake(delta: float) -> void:
	if shake_intensity > 0.01:
		shake_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0.0
		)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		position += shake_offset
	else:
		shake_intensity = 0.0
		shake_offset = Vector3.ZERO


## Public API for weapons to call

func apply_recoil(kick_degrees: float, snap_time: float, recover_time: float) -> void:
	recoil_target = deg_to_rad(-kick_degrees)  # Negative = upward pitch
	recoil_snap_speed = absf(recoil_target) / maxf(snap_time, 0.01)
	recoil_recover_speed = absf(recoil_target) / maxf(recover_time, 0.01)
	recoil_pitch = 0.0
	recoil_phase = 1


func apply_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_decay = intensity / maxf(duration, 0.01)


func apply_fov_punch(amount: float, recover_time: float) -> void:
	fov_punch_amount = amount
	fov_punch_recover_speed = absf(amount) / maxf(recover_time, 0.01)
