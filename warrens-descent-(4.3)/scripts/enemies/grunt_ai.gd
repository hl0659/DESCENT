extends EnemyBase

enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD }

@export var move_speed: float = 5.0
@export var detection_range: float = 25.0
@export var attack_range: float = 15.0
@export var attack_cooldown: float = 1.5
@export var projectile_speed: float = 18.0
@export var projectile_damage: int = 10
@export var gravity_force: float = 20.0

var state: State = State.IDLE
var attack_timer: float = 0.0
var stagger_timer: float = 0.0
var nav_ready: bool = false

var projectile_scene: PackedScene = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	super._ready()
	projectile_scene = load("res://scenes/projectile.tscn")
	nav_agent.path_desired_distance = 1.5
	nav_agent.target_desired_distance = 1.5
	nav_agent.max_speed = move_speed

	# Wait for navigation to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_ready = true


func _physics_process(delta: float) -> void:
	if not nav_ready or is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity_force * delta

	attack_timer = max(0.0, attack_timer - delta)

	match state:
		State.IDLE:
			_state_idle()
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.STAGGER:
			_state_stagger(delta)
		State.DEAD:
			return

	move_and_slide()


func _state_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if player and _distance_to_player() < detection_range:
		state = State.CHASE


func _state_chase(delta: float) -> void:
	if not player:
		state = State.IDLE
		return

	var dist := _distance_to_player()

	if dist > detection_range * 1.2:
		state = State.IDLE
		return

	if dist < attack_range and attack_timer <= 0.0 and _can_see_player():
		state = State.ATTACK
		return

	# Navigate toward player
	nav_agent.target_position = player.global_position
	if not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var direction := (next_pos - global_position).normalized()
		direction.y = 0.0
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		# Face movement direction
		if direction.length() > 0.1:
			var look_target := global_position + direction
			look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _state_attack(_delta: float) -> void:
	if not player:
		state = State.IDLE
		return

	# Face player
	var look_pos := player.global_position
	look_pos.y = global_position.y
	look_at(look_pos, Vector3.UP)

	# Fire projectile
	_fire_projectile()
	attack_timer = attack_cooldown
	state = State.CHASE


func _state_stagger(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	stagger_timer -= delta
	if stagger_timer <= 0.0:
		state = State.CHASE


func _on_stagger() -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	stagger_timer = stagger_duration


func _die() -> void:
	super._die()
	state = State.DEAD
	velocity = Vector3.ZERO

	# Fade out and free
	var tween := create_tween()
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh and mesh.get_surface_override_material(0):
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _fire_projectile() -> void:
	if not projectile_scene or not player:
		return
	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var spawn_pos := get_center_position() + (-transform.basis.z * 1.0)
	proj.global_position = spawn_pos
	var target := player.global_position + Vector3.UP * 0.9
	var direction := (target - spawn_pos).normalized()
	proj.setup(direction, projectile_speed, projectile_damage)


func _distance_to_player() -> float:
	if not player:
		return 9999.0
	return global_position.distance_to(player.global_position)


func _can_see_player() -> bool:
	if not player:
		return false
	var space_state := get_world_3d().direct_space_state
	var from := get_center_position()
	var to := player.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # Only check environment
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return result.is_empty()  # No obstacle means we can see the player
