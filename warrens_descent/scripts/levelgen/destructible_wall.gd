class_name DestructibleWall
extends StaticBody3D

@export var wall_health: int = 50
var current_health: int = 50


func _ready() -> void:
	current_health = wall_health
	collision_layer = 1
	collision_mask = 0


func take_damage(amount: int) -> void:
	current_health -= amount
	_flash_hit()
	if current_health <= 0:
		_shatter()


func _flash_hit() -> void:
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if not mesh:
		return
	var mat: StandardMaterial3D = mesh.material_override
	if mat:
		var original_color: Color = mat.albedo_color
		mat.albedo_color = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if is_inside_tree():
			mat.albedo_color = original_color


func _shatter() -> void:
	# Spawn particle burst
	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 8.0
	particles.gravity = Vector3(0, -15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.3)
	var debris_mesh := BoxMesh.new()
	debris_mesh.size = Vector3(0.15, 0.15, 0.15)
	debris_mesh.material = mat
	particles.mesh = debris_mesh
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)

	# Play destruction sound
	var sound := AudioStreamPlayer3D.new()
	sound.stream = SfxGenerator.wall_break()
	sound.max_db = 12.0
	get_tree().current_scene.add_child(sound)
	sound.global_position = global_position
	sound.play()
	sound.finished.connect(sound.queue_free)

	queue_free()
