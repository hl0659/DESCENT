extends Area3D

@export var pneuma_amount: float = 15.0
@export var pickup_base_radius: float = 2.0
@export var pickup_speed_bonus_radius: float = 3.0
@export var magnetize_speed: float = 10.0
@export var bob_speed: float = 3.0
@export var bob_height: float = 0.15
@export var rotate_speed: float = 3.0
@export var despawn_time: float = 0.0  # 0 = never despawn

var is_magnetized: bool = false
var current_magnetize_speed: float = 0.0
var player: Node3D = null
var time: float = 0.0
var base_y: float = 0.0

var pickup_sound: AudioStreamPlayer3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	base_y = global_position.y
	time = randf() * TAU
	body_entered.connect(_on_body_entered)

	pickup_sound = AudioStreamPlayer3D.new()
	pickup_sound.stream = SfxGenerator.pneuma_pickup()
	pickup_sound.max_db = 8.0
	add_child(pickup_sound)

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	if despawn_time > 0.0:
		await get_tree().create_timer(despawn_time).timeout
		if is_inside_tree():
			queue_free()


func _physics_process(delta: float) -> void:
	if not is_magnetized or not player:
		return
	var dir: Vector3 = (player.global_position + Vector3.UP * 0.9 - global_position).normalized()
	global_position += dir * current_magnetize_speed * delta
	current_magnetize_speed = minf(current_magnetize_speed + delta * 40.0, 80.0)


func _process(delta: float) -> void:
	if is_magnetized:
		return

	if not player:
		return

	# Check magnetism radius based on player speed
	var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var max_speed: float = maxf(player.ground_speed, 0.001)
	var effective_radius: float = pickup_base_radius + (player_speed / max_speed) * pickup_speed_bonus_radius
	var dist: float = global_position.distance_to(player.global_position)

	if dist < effective_radius:
		is_magnetized = true
		current_magnetize_speed = magnetize_speed
		return

	# Idle animation: bob and rotate
	time += delta
	if mesh:
		mesh.position.y = sin(time * bob_speed) * bob_height
		mesh.rotate_y(rotate_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("gain_pneuma"):
		body.gain_pneuma(pneuma_amount)
	if pickup_sound:
		# Reparent sound so it plays after orb is freed
		pickup_sound.reparent(get_tree().current_scene)
		pickup_sound.play()
		pickup_sound.finished.connect(pickup_sound.queue_free)
	queue_free()
