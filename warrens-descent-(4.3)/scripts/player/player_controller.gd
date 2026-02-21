extends CharacterBody3D

signal health_changed(new_health: int)
signal player_died()
signal dash_started()
signal dash_cooldown_finished()
signal speed_changed(speed: float)

@export_group("Movement")
@export var ground_speed: float = 10.0
@export var ground_accel: float = 50.0
@export var ground_friction: float = 12.0
@export var air_speed_cap: float = 1.5
@export var air_accel: float = 40.0
@export var gravity_force: float = 20.0
@export var jump_velocity: float = 7.5
@export var mouse_sensitivity: float = 0.002

@export_group("Advanced Movement")
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.0
@export var slide_speed: float = 14.0
@export var slide_friction: float = 4.0
@export var slide_duration: float = 0.6
@export var coyote_time: float = 0.12
@export var wall_jump_force: float = 7.0
@export var wall_jump_up: float = 6.0

@export_group("Health")
@export var max_health: int = 100
@export var iframe_duration: float = 0.1

var health: int = 100
var is_dashing: bool = false
var is_sliding: bool = false
var can_dash: bool = true
var was_on_floor: bool = false
var coyote_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var slide_timer: float = 0.0
var iframe_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_dead: bool = false

@onready var camera_holder: Node3D = $CameraHolder
@onready var camera: Camera3D = $CameraHolder/Camera3D
@onready var camera_effects: Node = null
@onready var weapon_manager: Node = null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health = max_health

	# Find optional components
	camera_effects = camera_holder.get_node_or_null("CameraEffects")
	weapon_manager = get_node_or_null("WeaponHolder/WeaponManager")

	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_holder.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_holder.rotation.x = clamp(camera_holder.rotation.x, -1.4, 1.4)

	if event.is_action_pressed("quit"):
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)

	# Gravity
	if not is_on_floor() and not is_dashing:
		velocity.y -= gravity_force * delta

	# Coyote time tracking
	if is_on_floor():
		coyote_timer = coyote_time
	elif was_on_floor and coyote_timer > 0.0:
		pass  # Still in coyote time
	was_on_floor = is_on_floor()

	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Handle states
	if is_dashing:
		velocity = dash_direction * dash_speed
		velocity.y = 0.0
	elif is_sliding:
		_process_slide(delta)
	elif is_on_floor() or coyote_timer > 0.0:
		_process_ground_movement(wish_dir, delta)
	else:
		_process_air_movement(wish_dir, delta)

	# Jump
	if Input.is_action_just_pressed("jump") and not is_sliding:
		if is_on_floor() or coyote_timer > 0.0:
			velocity.y = jump_velocity
			coyote_timer = 0.0
		elif is_on_wall():
			_wall_jump()

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_start_dash(wish_dir)

	# Slide
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not is_dashing:
		var horiz_speed := Vector2(velocity.x, velocity.z).length()
		if horiz_speed > 3.0:
			_start_slide()

	move_and_slide()

	var current_speed := Vector2(velocity.x, velocity.z).length()
	speed_changed.emit(current_speed)


func _process_ground_movement(wish_dir: Vector3, delta: float) -> void:
	if wish_dir.length() > 0.0:
		var target_vel := wish_dir * ground_speed
		velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)


func _process_air_movement(wish_dir: Vector3, delta: float) -> void:
	if wish_dir.length() > 0.0:
		# Quake-style air strafing
		var current_speed := velocity.dot(wish_dir)
		var add_speed := clamp(air_speed_cap - current_speed, 0.0, air_accel * delta)
		velocity += wish_dir * add_speed


func _process_slide(delta: float) -> void:
	var slide_dir := Vector2(velocity.x, velocity.z).normalized()
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, slide_friction * delta)


func _start_dash(wish_dir: Vector3) -> void:
	if wish_dir.length() < 0.1:
		dash_direction = -transform.basis.z
	else:
		dash_direction = wish_dir
	dash_direction = dash_direction.normalized()
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	iframe_timer = dash_duration
	dash_started.emit()


func _start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	var horiz := Vector3(velocity.x, 0, velocity.z).normalized()
	velocity.x = horiz.x * slide_speed
	velocity.z = horiz.z * slide_speed


func _wall_jump() -> void:
	var wall_normal := get_wall_normal()
	velocity = wall_normal * wall_jump_force
	velocity.y = wall_jump_up


func _update_timers(delta: float) -> void:
	if coyote_timer > 0.0:
		coyote_timer -= delta

	if dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	if dash_cd_timer > 0.0:
		dash_cd_timer -= delta
		if dash_cd_timer <= 0.0:
			can_dash = true
			dash_cooldown_finished.emit()

	if slide_timer > 0.0:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false

	if iframe_timer > 0.0:
		iframe_timer -= delta


func take_damage(amount: int) -> void:
	if is_dead or iframe_timer > 0.0:
		return
	health = max(0, health - amount)
	health_changed.emit(health)
	iframe_timer = iframe_duration
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	player_died.emit()


func get_dash_cooldown_percent() -> float:
	if can_dash:
		return 1.0
	return 1.0 - (dash_cd_timer / dash_cooldown)
