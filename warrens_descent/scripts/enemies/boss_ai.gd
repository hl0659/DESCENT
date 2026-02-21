extends EnemyBase

enum State { IDLE, ATTACK, STAGGER, DEAD }

@export var detection_range: float = 40.0
@export var attack_range: float = 35.0
@export var attack_cooldown: float = 2.5
@export var projectile_speed: float = 14.0
@export var projectile_damage: int = 15
@export var projectiles_per_burst: int = 5
@export var cone_spread_degrees: float = 30.0
@export var gravity_force: float = 20.0

var state: State = State.IDLE
var attack_timer: float = 0.0
var stagger_timer: float = 0.0

var projectile_scene: PackedScene = null
var pneuma_pickup_scene: PackedScene = preload("res://scenes/pneuma_pickup.tscn")


func _ready() -> void:
	max_health = 300
	health = 300
	stagger_threshold = 80
	drops_pneuma = true
	pneuma_drop_amount = 50.0
	super._ready()
	projectile_scene = load("res://scenes/projectile.tscn")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity_force * delta

	attack_timer = maxf(0.0, attack_timer - delta)

	match state:
		State.IDLE:
			_state_idle()
		State.ATTACK:
			_state_attack()
		State.STAGGER:
			_state_stagger(delta)
		State.DEAD:
			return

	move_and_slide()


func _state_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if not player:
		return

	if _distance_to_player() < detection_range:
		# Face player while idle in range
		_face_player()

		if _distance_to_player() < attack_range and attack_timer <= 0.0 and _can_see_player():
			state = State.ATTACK


func _state_attack() -> void:
	if not player:
		state = State.IDLE
		return

	# Face player
	_face_player()

	# Fire cone burst
	_fire_cone_burst()
	attack_timer = attack_cooldown
	state = State.IDLE


func _state_stagger(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	stagger_timer -= delta
	if stagger_timer <= 0.0:
		state = State.IDLE


func _on_stagger() -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	stagger_timer = stagger_duration


func _die() -> void:
	if drops_pneuma:
		_spawn_pneuma_orbs()
	super._die()
	state = State.DEAD
	velocity = Vector3.ZERO

	# Slow fade out (1.0s for boss)
	var tween: Tween = create_tween()
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var original_mat: Material = mesh.get_surface_override_material(0)
		if original_mat:
			var mat: StandardMaterial3D = original_mat.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, mat)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_callback(queue_free)


func _spawn_pneuma_orbs() -> void:
	if not pneuma_pickup_scene:
		return
	for i in 3:
		var orb: Node3D = pneuma_pickup_scene.instantiate()
		get_tree().current_scene.add_child(orb)
		var offset: Vector3 = Vector3(
			randf_range(-2.0, 2.0),
			0.3,
			randf_range(-2.0, 2.0)
		)
		orb.global_position = global_position + offset
		orb.pneuma_amount = pneuma_drop_amount


func _fire_cone_burst() -> void:
	if not projectile_scene or not player:
		return

	var spawn_pos: Vector3 = get_center_position() + (-transform.basis.z * 2.0)
	var target: Vector3 = player.global_position + Vector3.UP * 0.9
	var base_dir: Vector3 = (target - spawn_pos).normalized()

	for i in projectiles_per_burst:
		var t: float = float(i) / float(projectiles_per_burst - 1) - 0.5
		var right: Vector3 = transform.basis.x
		var spread_offset: Vector3 = right * t * deg_to_rad(cone_spread_degrees) * 2.0
		var direction: Vector3 = (base_dir + spread_offset).normalized()

		var proj: Node3D = projectile_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(proj)
		proj.global_position = spawn_pos
		proj.call("setup", direction, projectile_speed, projectile_damage)


func _face_player() -> void:
	var look_pos: Vector3 = player.global_position
	look_pos.y = global_position.y
	look_at(look_pos, Vector3.UP)


func _distance_to_player() -> float:
	if not player:
		return 9999.0
	return global_position.distance_to(player.global_position)


func _can_see_player() -> bool:
	if not player:
		return false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = get_center_position()
	var to: Vector3 = player.global_position + Vector3.UP * 0.9
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()


func get_center_position() -> Vector3:
	return global_position + Vector3.UP * 4.0
