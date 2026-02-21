extends EnemyBase

enum State { IDLE, ATTACK, STAGGER, DEAD }

@export var detection_range: float = 30.0
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 16.0
@export var projectile_damage: int = 8
@export var bob_amplitude: float = 0.15
@export var bob_frequency: float = 2.0

var state: State = State.IDLE
var attack_timer: float = 0.0
var stagger_timer: float = 0.0
var bob_time: float = 0.0
var base_y: float = 0.0

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
var pneuma_pickup_scene: PackedScene = preload("res://scenes/pneuma_pickup.tscn")


func _ready() -> void:
	super._ready()
	max_health = 35
	health = max_health
	base_y = global_position.y


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)

	# Hover bob animation
	bob_time += delta
	global_position.y = base_y + sin(bob_time * bob_frequency * TAU) * bob_amplitude

	match state:
		State.IDLE:
			_state_idle()
		State.ATTACK:
			_state_attack()
		State.STAGGER:
			_state_stagger(delta)
		State.DEAD:
			return


func _state_idle() -> void:
	if player and _distance_to_player() < detection_range:
		if attack_timer <= 0.0 and _distance_to_player() < attack_range and _can_see_player():
			state = State.ATTACK


func _state_attack() -> void:
	if not player:
		state = State.IDLE
		return

	# Face the player
	var look_pos: Vector3 = player.global_position
	look_pos.y = global_position.y
	look_at(look_pos, Vector3.UP)

	# Fire projectile
	_fire_projectile()
	attack_timer = attack_cooldown
	state = State.IDLE


func _state_stagger(delta: float) -> void:
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
		_spawn_pneuma_orb()
	super._die()
	state = State.DEAD

	# Fade out and free
	var tween: Tween = create_tween()
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var original_mat: Material = mesh.get_surface_override_material(0)
		if original_mat:
			var mat: StandardMaterial3D = original_mat.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, mat)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _spawn_pneuma_orb() -> void:
	if not pneuma_pickup_scene:
		return
	var orb: Node3D = pneuma_pickup_scene.instantiate()
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector3.UP * 0.3
	orb.pneuma_amount = pneuma_drop_amount


func _fire_projectile() -> void:
	if not projectile_scene or not player:
		return
	var proj: Node3D = projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(proj)
	var spawn_pos: Vector3 = get_center_position() + (-transform.basis.z * 0.8)
	proj.global_position = spawn_pos
	var target: Vector3 = player.global_position + Vector3.UP * 0.9
	var direction: Vector3 = (target - spawn_pos).normalized()
	proj.call("setup", direction, projectile_speed, projectile_damage)


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
	return global_position
