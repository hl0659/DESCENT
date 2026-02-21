extends CharacterBody3D

signal health_changed(new_health: int)
signal player_died()
signal dash_started()
signal dash_cooldown_finished()
signal speed_changed(speed: float)
signal pneuma_changed(current: float, maximum: float)
signal pneuma_denied()

@export_group("Movement")
@export var ground_speed: float = 10.0
@export var ground_accel: float = 50.0
@export var ground_friction: float = 12.0
@export var air_speed_cap: float = 3.5
@export var air_accel: float = 80.0
@export var gravity_force: float = 12.0
@export var jump_velocity: float = 6.8
@export var mouse_sensitivity: float = 0.002

@export_group("Advanced Movement")
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var slide_speed: float = 14.0
@export var slide_friction: float = 8.0
@export var slide_maintain_time: float = 1.0
@export var coyote_time: float = 0.18
@export var wall_jump_force: float = 6.0
@export var wall_jump_up: float = 6.5
@export var bhop_friction_scale: float = 0.02
@export var double_jump_force: float = 8.0

@export_group("Health")
@export var max_health: int = 100
@export var iframe_duration: float = 0.1

@export_group("Pneuma")
@export var max_pneuma: float = 100.0
@export var pneuma_per_dash: float = 10.0
@export var pneuma_per_double_jump: float = 7.5
@export var pneuma_per_wall_jump: float = 5.0

var health: int = 100
var current_pneuma: float = 100.0
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
var has_double_jumped: bool = false
var slide_buffered: bool = false

var camera_holder: Node3D = null
var camera: Camera3D = null
var camera_effects: Node3D = null
var weapon_manager: Node3D = null
var collision_shape: CollisionShape3D = null
var damage_sound: AudioStreamPlayer = null
var jump_sound: AudioStreamPlayer = null
var land_sound: AudioStreamPlayer = null
var dash_sound: AudioStreamPlayer = null
var double_jump_sound: AudioStreamPlayer = null
var pneuma_denied_sound: AudioStreamPlayer = null
var pneuma_low_sound: AudioStreamPlayer = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health = max_health
	current_pneuma = max_pneuma

	camera_holder = get_node("CameraHolder") as Node3D
	camera = get_node("CameraHolder/CameraEffects/Camera3D") as Camera3D
	collision_shape = get_node("CollisionShape3D") as CollisionShape3D
	camera_effects = get_node("CameraHolder/CameraEffects") as Node3D
	weapon_manager = get_node_or_null("WeaponHolder/WeaponManager")

	damage_sound = AudioStreamPlayer.new()
	damage_sound.stream = SfxGenerator.damage_taken()
	damage_sound.volume_db = -4.0
	add_child(damage_sound)

	jump_sound = AudioStreamPlayer.new()
	jump_sound.stream = SfxGenerator.jump()
	jump_sound.volume_db = -6.0
	add_child(jump_sound)

	land_sound = AudioStreamPlayer.new()
	land_sound.stream = SfxGenerator.land()
	land_sound.volume_db = -4.0
	add_child(land_sound)

	dash_sound = AudioStreamPlayer.new()
	dash_sound.stream = SfxGenerator.dash_whoosh()
	dash_sound.volume_db = -4.0
	add_child(dash_sound)

	double_jump_sound = AudioStreamPlayer.new()
	double_jump_sound.stream = SfxGenerator.double_jump_burst()
	double_jump_sound.volume_db = -4.0
	add_child(double_jump_sound)

	pneuma_denied_sound = AudioStreamPlayer.new()
	pneuma_denied_sound.stream = SfxGenerator.pneuma_denied()
	pneuma_denied_sound.volume_db = -2.0
	add_child(pneuma_denied_sound)

	pneuma_low_sound = AudioStreamPlayer.new()
	pneuma_low_sound.stream = SfxGenerator.pneuma_low_loop()
	pneuma_low_sound.volume_db = -10.0
	add_child(pneuma_low_sound)

	add_to_group("player")

	pneuma_denied.connect(_on_pneuma_denied)


func _input(event: InputEvent) -> void:
	if is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_holder.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_holder.rotation.x = clampf(camera_holder.rotation.x, -1.4, 1.4)

	if event.is_action_pressed("quit"):
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)

	# Gravity
	if not is_on_floor() and not is_dashing:
		velocity.y -= gravity_force * delta

	# Landing detection
	if is_on_floor() and not was_on_floor:
		has_double_jumped = false
		if land_sound:
			land_sound.play()

	# Coyote time tracking
	if is_on_floor():
		coyote_timer = coyote_time
	elif was_on_floor and coyote_timer > 0.0:
		pass  # Still in coyote time
	was_on_floor = is_on_floor()

	# Get input direction
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

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
	if not is_sliding:
		if Input.is_action_just_pressed("jump"):
			if is_on_floor() or coyote_timer > 0.0:
				velocity.y = jump_velocity
				coyote_timer = 0.0
				has_double_jumped = false
				if jump_sound:
					jump_sound.play()
			elif is_on_wall():
				if spend_pneuma(pneuma_per_wall_jump):
					_wall_jump()
					has_double_jumped = false
			elif not has_double_jumped:
				if spend_pneuma(pneuma_per_double_jump):
					velocity.y = double_jump_force
					has_double_jumped = true
					if double_jump_sound:
						double_jump_sound.play()
		elif Input.is_action_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
			has_double_jumped = false
			if jump_sound:
				jump_sound.play()

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		if spend_pneuma(pneuma_per_dash):
			_start_dash(wish_dir)

	# Slide — buffer input while airborne, engage on landing
	if Input.is_action_just_pressed("slide") and not is_sliding and not is_dashing:
		if is_on_floor():
			var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
			if horiz_speed > 3.0:
				_start_slide()
		else:
			slide_buffered = true

	if slide_buffered and is_on_floor() and not is_sliding and not is_dashing:
		var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
		if horiz_speed > 3.0:
			_start_slide()
		slide_buffered = false

	if not Input.is_action_pressed("slide"):
		slide_buffered = false

	if is_sliding and (not Input.is_action_pressed("slide") or not is_on_floor()):
		is_sliding = false

	move_and_slide()

	var current_speed: float = Vector2(velocity.x, velocity.z).length()
	speed_changed.emit(current_speed)

	# Low pneuma audio loop
	var pneuma_percent: float = current_pneuma / maxf(max_pneuma, 0.001)
	if pneuma_percent <= 0.2 and pneuma_percent > 0.0:
		if pneuma_low_sound and not pneuma_low_sound.playing:
			pneuma_low_sound.play()
	elif pneuma_low_sound and pneuma_low_sound.playing:
		pneuma_low_sound.stop()


func _process_ground_movement(wish_dir: Vector3, delta: float) -> void:
	var current_horiz_speed: float = Vector2(velocity.x, velocity.z).length()

	if wish_dir.length() > 0.0:
		if current_horiz_speed > ground_speed * 1.05:
			# Moving faster than normal (from bhop/dash) — gentle friction, preserve momentum
			var gentle_friction: float = ground_friction * bhop_friction_scale * delta
			var current_dir: Vector3 = Vector3(velocity.x, 0, velocity.z).normalized()
			# Steer toward wish direction without killing speed
			var target_vel: Vector3 = wish_dir * current_horiz_speed
			velocity.x = move_toward(velocity.x, target_vel.x, gentle_friction + ground_accel * 0.3 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, gentle_friction + ground_accel * 0.3 * delta)
		else:
			var target_vel: Vector3 = wish_dir * ground_speed
			velocity.x = move_toward(velocity.x, target_vel.x, ground_accel * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, ground_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)


func _process_air_movement(wish_dir: Vector3, delta: float) -> void:
	if wish_dir.length() > 0.0:
		# Quake-style air strafing
		var current_speed: float = velocity.dot(wish_dir)
		var add_speed: float = clampf(air_speed_cap - current_speed, 0.0, air_accel * delta)
		velocity += wish_dir * add_speed


func _process_slide(delta: float) -> void:
	slide_timer += delta
	if slide_timer > slide_maintain_time:
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
	if dash_sound:
		dash_sound.play()


func _start_slide() -> void:
	is_sliding = true
	slide_timer = 0.0
	var horiz: Vector3 = Vector3(velocity.x, 0, velocity.z).normalized()
	velocity.x = horiz.x * slide_speed
	velocity.z = horiz.z * slide_speed


func _wall_jump() -> void:
	var wall_normal: Vector3 = get_wall_normal()
	# Full momentum preservation + wall push adds speed like a bhop
	var current_horiz: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var push: Vector3 = wall_normal * wall_jump_force
	velocity.x = current_horiz.x + push.x
	velocity.z = current_horiz.z + push.z
	velocity.y = wall_jump_up
	if jump_sound:
		jump_sound.play()


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

	if iframe_timer > 0.0:
		iframe_timer -= delta


func take_damage(amount: int) -> void:
	if is_dead or iframe_timer > 0.0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	iframe_timer = iframe_duration
	if damage_sound:
		damage_sound.play()
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	player_died.emit()


func get_dash_cooldown_percent() -> float:
	if can_dash:
		return 1.0
	return 1.0 - (dash_cd_timer / dash_cooldown)


func can_spend_pneuma(amount: float) -> bool:
	return current_pneuma >= amount


func spend_pneuma(amount: float) -> bool:
	if current_pneuma < amount:
		pneuma_denied.emit()
		return false
	current_pneuma -= amount
	pneuma_changed.emit(current_pneuma, max_pneuma)
	return true


func gain_pneuma(amount: float) -> void:
	current_pneuma = minf(current_pneuma + amount, max_pneuma)
	pneuma_changed.emit(current_pneuma, max_pneuma)


func _on_pneuma_denied() -> void:
	if pneuma_denied_sound:
		pneuma_denied_sound.play()
