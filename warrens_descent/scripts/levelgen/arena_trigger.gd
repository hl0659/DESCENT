class_name ArenaTrigger
extends Node3D

signal arena_cleared()

@export var enemy_grunt_scene: PackedScene
@export var enemy_flying_scene: PackedScene

var chunk: ChunkBase = null
var is_active: bool = false
var is_cleared: bool = false
var waves: Dictionary = {}  # wave_number -> Array[Marker3D]
var active_enemies: Array[Node3D] = []
var current_wave: int = 0
var max_wave: int = 0
var door_blockers: Array[Node3D] = []
var trigger_area: Area3D = null
var wave_horn_sound: AudioStreamPlayer = null
var level_number: int = 1
var enemy_ground_multiplier: float = 1.0
var enemy_flying_multiplier: float = 1.0


func setup(arena_chunk: ChunkBase, grunt_scene: PackedScene, flying_scene: PackedScene, level: int = 1) -> void:
	chunk = arena_chunk
	enemy_grunt_scene = grunt_scene
	enemy_flying_scene = flying_scene
	level_number = level
	_calculate_multipliers()
	_organize_waves()
	_create_trigger_area()
	_create_wave_horn()


func _calculate_multipliers() -> void:
	if level_number <= 5:
		enemy_ground_multiplier = 1.0
		enemy_flying_multiplier = 0.5
	elif level_number <= 10:
		enemy_ground_multiplier = 1.3
		enemy_flying_multiplier = 1.0
	elif level_number <= 15:
		enemy_ground_multiplier = 1.5
		enemy_flying_multiplier = 1.3
	elif level_number <= 20:
		enemy_ground_multiplier = 1.8
		enemy_flying_multiplier = 1.5
	else:
		enemy_ground_multiplier = 2.0
		enemy_flying_multiplier = 2.0


func _organize_waves() -> void:
	if not chunk:
		return
	for spawn in chunk.get_spawn_points():
		var group: int = spawn.get_meta("spawn_group", 0)
		if not waves.has(group):
			waves[group] = []
		waves[group].append(spawn)
		max_wave = maxi(max_wave, group)


func _create_trigger_area() -> void:
	trigger_area = Area3D.new()
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 2  # Player layer
	chunk.add_child(trigger_area)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()

	# Size trigger from doorway markers, inset 2m from entry so the player
	# must cross the threshold before the arena activates.
	var entry_marker := chunk.get_entry()
	var exit_marker := chunk.get_exit()
	if entry_marker and exit_marker:
		var trigger_z_min := entry_marker.position.z + 2.0
		var trigger_z_max := exit_marker.position.z
		var depth := trigger_z_max - trigger_z_min
		var center_z := (trigger_z_min + trigger_z_max) * 0.5
		shape.size = Vector3(40.0, 6.0, depth)
		col.position = Vector3(0, 3.0, center_z)
	else:
		shape.size = Vector3(40.0, 6.0, 40.0)
		col.position = Vector3(0, 3.0, 0)

	col.shape = shape
	trigger_area.add_child(col)

	trigger_area.body_entered.connect(_on_body_entered)


func _create_wave_horn() -> void:
	wave_horn_sound = AudioStreamPlayer.new()
	wave_horn_sound.stream = SfxGenerator.wave_spawn_horn()
	wave_horn_sound.volume_db = -2.0
	add_child(wave_horn_sound)


func _on_body_entered(body: Node3D) -> void:
	if is_active or is_cleared:
		return
	if not body.is_in_group("player"):
		return
	_activate()


func _activate() -> void:
	is_active = true
	_lock_doors()
	_spawn_wave(0)


func _lock_doors() -> void:
	# Create physical blockers at each doorway
	for doorway_name in ["entry", "exit"]:
		var marker: Marker3D = chunk.get_node_or_null(doorway_name) as Marker3D
		if not marker:
			continue
		var blocker := MeshBuilder.add_box(
			chunk,
			Vector3(MeshBuilder.DOOR_WIDTH, MeshBuilder.DOOR_HEIGHT, 0.5),
			marker.position,
			LevelMaterials.door_mat()
		)
		door_blockers.append(blocker)


func _unlock_doors() -> void:
	for blocker in door_blockers:
		blocker.queue_free()
	door_blockers.clear()


func _spawn_wave(wave_num: int) -> void:
	current_wave = wave_num
	if not waves.has(wave_num):
		return

	if wave_num > 0 and wave_horn_sound:
		wave_horn_sound.play()

	for spawn_point in waves[wave_num]:
		var enemy_type: String = spawn_point.get_meta("enemy_type", "ground")
		var multiplier: float = enemy_ground_multiplier if enemy_type == "ground" else enemy_flying_multiplier

		# Apply scaling: spawn extra enemies based on multiplier
		var count: int = maxi(1, roundi(multiplier))
		for i in count:
			var offset := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * float(i)
			_spawn_enemy_at(spawn_point.global_position + offset, enemy_type)


func _spawn_enemy_at(pos: Vector3, enemy_type: String) -> void:
	var scene: PackedScene = enemy_grunt_scene if enemy_type == "ground" else enemy_flying_scene
	if not scene:
		scene = enemy_grunt_scene  # Fallback
	if not scene:
		return

	var enemy: Node3D = scene.instantiate()
	enemy.position = pos
	get_tree().current_scene.add_child(enemy)
	active_enemies.append(enemy)

	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))


func _on_enemy_died(_dead_enemy: Node3D, tracked_ref: Node3D) -> void:
	active_enemies.erase(tracked_ref)

	# Check if we should spawn next wave (current wave ~50% cleared)
	var current_wave_total: int = waves[current_wave].size() if waves.has(current_wave) else 1
	var remaining_from_wave: int = 0
	for e in active_enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			remaining_from_wave += 1

	var cleared_ratio := 1.0 - (float(remaining_from_wave) / maxf(current_wave_total, 1))
	if cleared_ratio >= 0.5 and current_wave < max_wave:
		_spawn_wave(current_wave + 1)

	# Check if all enemies are dead
	var all_dead := true
	for e in active_enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			all_dead = false
			break

	if all_dead and current_wave >= max_wave:
		_on_arena_cleared()


func _on_arena_cleared() -> void:
	is_cleared = true
	is_active = false
	_unlock_doors()
	arena_cleared.emit()
