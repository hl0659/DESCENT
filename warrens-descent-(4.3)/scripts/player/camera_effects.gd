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

@onready var player: CharacterBody3D = get_parent().get_parent()
@onready var camera: Camera3D = get_parent().get_node("Camera3D")


func _ready() -> void:
	if camera:
		camera.fov = base_fov


func _process(delta: float) -> void:
	if not player or not camera:
		return
	if player.is_dead:
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()

	_process_head_bob(delta, speed)
	_process_strafe_tilt(delta)
	_process_landing(delta)
	_process_fov(delta, speed)


func _process_head_bob(delta: float, speed: float) -> void:
	if player.is_on_floor() and speed > 1.0:
		bob_time += delta * bob_frequency * (speed / player.ground_speed)
		position.y = sin(bob_time) * bob_amplitude
		position.x = cos(bob_time * 0.5) * bob_amplitude * 0.5
	else:
		bob_time = 0.0
		position.y = move_toward(position.y, 0.0, delta * 2.0)
		position.x = move_toward(position.x, 0.0, delta * 2.0)


func _process_strafe_tilt(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	var target_tilt := -input_x * deg_to_rad(strafe_tilt_amount)
	current_tilt = lerp(current_tilt, target_tilt, tilt_speed * delta)
	rotation.z = current_tilt


func _process_landing(delta: float) -> void:
	if player.is_on_floor() and not was_on_floor:
		var impact := abs(previous_y_velocity)
		if impact > 4.0:
			landing_offset = -landing_dip_amount * clamp(impact / 15.0, 0.3, 1.0)

	was_on_floor = player.is_on_floor()
	previous_y_velocity = player.velocity.y

	if abs(landing_offset) > 0.001:
		landing_offset = move_toward(landing_offset, 0.0, landing_dip_recovery * delta)
		position.y += landing_offset


func _process_fov(delta: float, speed: float) -> void:
	var target_fov := base_fov

	if player.is_dashing:
		target_fov = base_fov + dash_fov_add
	elif speed > speed_fov_threshold:
		var speed_factor := clamp((speed - speed_fov_threshold) / 8.0, 0.0, 1.0)
		target_fov = base_fov + speed_fov_add * speed_factor

	camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)
