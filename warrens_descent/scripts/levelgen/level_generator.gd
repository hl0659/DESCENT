class_name LevelGenerator
extends Node3D

signal level_ready()
signal level_cleared()

@export var level_number: int = 1
@export_group("Light Tuning")
@export var hallway_light_energy: float = 0.8
@export var arena_light_energy: float = 2.0

var enemy_grunt_scene: PackedScene = preload("res://scenes/enemy_grunt.tscn")
var enemy_flying_scene: PackedScene = preload("res://scenes/enemy_flying.tscn")
var enemy_boss_scene: PackedScene = preload("res://scenes/enemy_boss.tscn")
var pickup_health_scene: PackedScene = preload("res://scenes/pickup_health.tscn")
var pickup_ammo_scene: PackedScene = preload("res://scenes/pickup_ammo.tscn")
var pneuma_pickup_scene: PackedScene = preload("res://scenes/pneuma_pickup.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")
var hud_scene: PackedScene = preload("res://scenes/hud.tscn")

var chunks: Array[ChunkBase] = []
var arena_triggers: Array[ArenaTrigger] = []
var nav_region: NavigationRegion3D = null
var player: Node3D = null
var total_enemies: int = 0
var enemies_killed: int = 0
var level_start_time: float = 0.0
var is_level_complete: bool = false
var _player_last_safe_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	generate_level()


func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	# Track last safe position (on solid ground, not falling)
	if player.is_on_floor():
		_player_last_safe_pos = player.global_position
	# Respawn if fallen too far
	if player.global_position.y < -20.0:
		player.global_position = _player_last_safe_pos + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO


func generate_level() -> void:
	randomize()

	# Clear old level
	for child in get_children():
		child.queue_free()
	chunks.clear()
	arena_triggers.clear()
	is_level_complete = false
	enemies_killed = 0
	total_enemies = 0

	# Setup environment
	_setup_environment()

	# Safety catch floor far below the level
	_add_safety_floor()

	# Create navigation region
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)

	# Generate chunk sequence
	var sequence := _generate_sequence()

	# Build and connect chunks
	print("[LevelGen] Sequence: ", sequence)
	for i in sequence.size():
		var chunk: ChunkBase = _create_chunk(sequence[i])
		chunk.build()
		nav_region.add_child(chunk)
		chunks.append(chunk)

		if i == 0:
			chunk.position = Vector3.ZERO
		else:
			_connect_chunks(chunks[i - 1], chunk)

		print("[LevelGen] Chunk ", i, " (", sequence[i], ") pos=", chunk.position, " rot=", chunk.rotation)

		# Setup arena trigger if needed
		if chunk.is_arena():
			var trigger := ArenaTrigger.new()
			add_child(trigger)
			trigger.setup(chunk, enemy_grunt_scene, enemy_flying_scene, level_number)
			trigger.arena_cleared.connect(_on_arena_cleared)
			arena_triggers.append(trigger)

	# Seal the entry of the first chunk with a solid wall
	_seal_first_entry()

	# Bake navigation
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_finished.connect(_on_nav_baked, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh()


func _generate_sequence() -> Array[String]:
	var seq: Array[String] = []
	var total_chunks := randi_range(8, 14)
	var arena_count := 0
	var large_arena_count := 0
	var last_was_arena := false
	var vertical_count := 0

	# Must start with hallway
	seq.append(_random_hallway_type())

	for i in range(1, total_chunks - 1):
		# Always add transition after arenas
		if last_was_arena:
			seq.append("transition")
			last_was_arena = false
			continue

		# Decide what to place
		var roll := randf()
		if roll < 0.25 and not last_was_arena and arena_count < 3:
			seq.append("transition")
			if large_arena_count < 1 and arena_count >= 1 and randf() < 0.4:
				seq.append("arena_large")
				large_arena_count += 1
			else:
				seq.append("arena_small")
			arena_count += 1
			last_was_arena = true
		elif roll < 0.40 and not last_was_arena:
			seq.append("combat_room")
			last_was_arena = false
		else:
			if vertical_count < 3 and randf() < 0.25:
				if randf() < 0.5:
					seq.append("hallway_vertical")
				else:
					seq.append("hallway_descent")
				vertical_count += 1
			else:
				seq.append(_random_hallway_type())
			last_was_arena = false

	# Must end with arena
	if not seq[seq.size() - 1].begins_with("arena"):
		seq.append("transition")
		if level_number % 5 == 0:
			seq.append("arena_large")
		else:
			seq.append("arena_small")

	return seq


func _random_hallway_type() -> String:
	var types := ["hallway_straight", "hallway_straight", "hallway_curve"]
	return types[randi() % types.size()]


func _create_chunk(type: String) -> ChunkBase:
	match type:
		"hallway_straight":
			return HallwayStraight.new()
		"hallway_curve":
			return HallwayCurve.new()
		"hallway_vertical":
			return HallwayVertical.new()
		"hallway_descent":
			return HallwayDescent.new()
		"arena_small":
			return ArenaSmall.new()
		"arena_large":
			return ArenaLarge.new()
		"combat_room":
			return CombatRoom.new()
		"transition":
			return TransitionPiece.new()
		_:
			return HallwayStraight.new()


func _connect_chunks(prev_chunk: ChunkBase, next_chunk: ChunkBase) -> void:
	var prev_exit: Marker3D = prev_chunk.get_exit()
	var next_entry: Marker3D = next_chunk.get_entry()
	if not prev_exit or not next_entry:
		next_chunk.position = prev_chunk.position + Vector3(0, 0, 40)
		return

	var exit_global: Vector3 = prev_exit.global_position
	var entry_local: Vector3 = next_entry.position

	# Use facing metadata for correct rotation (marker basis is always identity)
	var exit_facing: Vector3 = prev_exit.get_meta("facing", Vector3.FORWARD)
	var entry_facing: Vector3 = next_entry.get_meta("facing", Vector3.BACK)

	# Transform exit facing to global space using the prev chunk's rotation
	var exit_facing_global := prev_chunk.global_transform.basis * exit_facing
	exit_facing_global.y = 0.0
	exit_facing_global = exit_facing_global.normalized()

	# Entry must face opposite to exit (they meet face-to-face)
	var target_entry := -exit_facing_global
	var angle_target := atan2(target_entry.x, target_entry.z)
	var angle_entry := atan2(entry_facing.x, entry_facing.z)
	var rotation_needed := angle_target - angle_entry

	next_chunk.rotation.y = rotation_needed

	# Position: rotate entry offset and subtract from exit position
	var rotated_entry := entry_local.rotated(Vector3.UP, rotation_needed)
	next_chunk.position = exit_global - rotated_entry

	print("[LevelGen] Connect: exit_global=", exit_global, " entry_local=", entry_local, " rot=", rad_to_deg(rotation_needed), "deg -> next_pos=", next_chunk.position)

	# Bridge floor patch to cover any seam
	_add_bridge_floor(prev_exit, next_entry, next_chunk, rotation_needed)


func _maybe_spawn_vault() -> void:
	if randf() > 0.3:  # 30% chance
		return
	var hallway_chunks: Array[ChunkBase] = []
	for chunk in chunks:
		if chunk.get_chunk_type().begins_with("hallway"):
			hallway_chunks.append(chunk)
	if hallway_chunks.is_empty():
		return
	var target_chunk: ChunkBase = hallway_chunks[randi() % hallway_chunks.size()]
	var vault := VaultRoom.new()
	vault.build()
	nav_region.add_child(vault)
	# Place vault perpendicular to the hallway, far enough to not clip
	var local_offset := Vector3(15.0, 0, 0)
	var rotated_offset := local_offset.rotated(Vector3.UP, target_chunk.rotation.y)
	vault.position = target_chunk.position + rotated_offset
	vault.rotation.y = target_chunk.rotation.y + deg_to_rad(90)
	chunks.append(vault)


func _on_nav_baked() -> void:
	_spawn_player()
	_spawn_non_arena_enemies()
	_spawn_pickups()
	level_start_time = Time.get_ticks_msec() / 1000.0
	level_ready.emit()


func _spawn_player() -> void:
	player = player_scene.instantiate()
	add_child(player)
	if chunks.size() > 0:
		var entry: Marker3D = chunks[0].get_entry()
		if entry:
			# Entry facing points INTO the chunk — use it directly as inward direction
			var facing: Vector3 = entry.get_meta("facing", Vector3.BACK)
			var inward: Vector3 = chunks[0].global_transform.basis * facing
			# Place player on the floor, 5m inside the chunk, facing inward
			player.global_position = entry.global_position + Vector3(0, -MeshBuilder.DOOR_HEIGHT * 0.5 + 1.0, 0) + inward * 5.0
			player.rotation.y = atan2(-inward.x, -inward.z)
			print("[LevelGen] Player spawn: ", player.global_position, " | Entry: ", entry.global_position, " | Facing: ", facing, " | Inward: ", inward)
			print("[LevelGen] Chunk0 type: ", chunks[0].get_chunk_type(), " | Chunk0 pos: ", chunks[0].global_position, " | Chunk0 rot: ", chunks[0].rotation)
		else:
			player.global_position = Vector3(0, 1.0, 0)
	_player_last_safe_pos = player.global_position

	# Add HUD
	var hud := hud_scene.instantiate()
	add_child(hud)


func _spawn_non_arena_enemies() -> void:
	for chunk in chunks:
		if chunk.is_arena():
			continue  # Arena trigger handles these
		for spawn in chunk.get_spawn_points():
			var enemy_type: String = spawn.get_meta("enemy_type", "ground")
			var scene: PackedScene
			if enemy_type == "flying":
				scene = enemy_flying_scene
			else:
				scene = enemy_grunt_scene
			if not scene:
				continue
			var enemy := scene.instantiate()
			add_child(enemy)
			enemy.global_position = spawn.global_position
			total_enemies += 1
			if enemy.has_signal("enemy_died"):
				enemy.enemy_died.connect(_on_enemy_died)


func _spawn_pickups() -> void:
	for chunk in chunks:
		for child in chunk.get_children():
			if child is Marker3D and child.is_in_group("pickup_spots"):
				var ptype: String = child.get_meta("pickup_type", "health")
				var scene: PackedScene
				match ptype:
					"health":
						scene = pickup_health_scene
					"ammo":
						scene = pickup_ammo_scene
					"pneuma":
						scene = pneuma_pickup_scene
					_:
						continue
				if not scene:
					continue
				var pickup := scene.instantiate()
				add_child(pickup)
				pickup.global_position = child.global_position


func _on_enemy_died(_enemy: Node3D) -> void:
	enemies_killed += 1


func _on_arena_cleared() -> void:
	# Check if the last arena is cleared
	var last_arena_cleared := true
	for trigger in arena_triggers:
		if not trigger.is_cleared:
			last_arena_cleared = false
			break
	if last_arena_cleared and arena_triggers.size() > 0:
		var last_chunk := chunks[chunks.size() - 1]
		if last_chunk.is_arena():
			for trigger in arena_triggers:
				if trigger.chunk == last_chunk and trigger.is_cleared:
					_on_level_complete()


func _on_level_complete() -> void:
	if is_level_complete:
		return
	is_level_complete = true
	level_cleared.emit()

	# Show score screen
	var score_scene: PackedScene = load("res://scenes/score_screen.tscn")
	var score_screen = score_scene.instantiate()
	add_child(score_screen)

	var accuracy := 0.0
	if player:
		var wm = player.get_node_or_null("WeaponHolder/WeaponManager")
		if wm and wm.has_method("get_accuracy"):
			accuracy = wm.get_accuracy()

	score_screen.show_score(get_level_time(), enemies_killed, total_enemies, accuracy)
	score_screen.continue_pressed.connect(_on_score_continue)


func _on_score_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func get_level_time() -> float:
	return Time.get_ticks_msec() / 1000.0 - level_start_time


func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	environment.ambient_light_energy = 1.5
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.1, 0.1, 0.15)
	environment.fog_density = 0.001
	env.environment = environment
	add_child(env)

	# Directional light for baseline visibility everywhere
	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.8, 0.8, 0.9)
	dir_light.light_energy = 1.0
	dir_light.rotation_degrees = Vector3(-60, 30, 0)
	dir_light.shadow_enabled = false
	add_child(dir_light)


func _seal_first_entry() -> void:
	# Place a solid wall at the first chunk's entry (in chunk-local space)
	if chunks.is_empty():
		return
	var entry: Marker3D = chunks[0].get_entry()
	if not entry:
		return
	# Use entry's LOCAL position within the chunk, shifted outward by the facing direction
	var facing: Vector3 = entry.get_meta("facing", Vector3.BACK)
	var wall_local_pos: Vector3 = entry.position - facing * 0.25
	# Center the wall vertically at mid-height of the chunk
	wall_local_pos.y = 4.0
	MeshBuilder.add_box(chunks[0], Vector3(12.0, 10.0, 0.5), wall_local_pos, LevelMaterials.wall_mat())


func _add_safety_floor() -> void:
	# Huge invisible collision floor to catch the player if they fall through gaps
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, -25, 0)
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 1, 500)
	col.shape = shape
	body.add_child(col)


func _add_bridge_floor(prev_exit: Marker3D, next_entry: Marker3D, next_chunk: ChunkBase, _rot: float) -> void:
	# Place a floor patch at every connection seam to cover gaps
	var exit_pos := prev_exit.global_position
	var entry_pos := next_entry.global_position
	var mid := (exit_pos + entry_pos) * 0.5
	var dist := maxf(exit_pos.distance_to(entry_pos), 2.0)
	var floor_y := minf(exit_pos.y, entry_pos.y) - MeshBuilder.DOOR_HEIGHT * 0.5
	var bridge_pos := Vector3(mid.x, floor_y, mid.z)
	# Orient toward connection direction (fallback to prev chunk exit facing)
	var dir := entry_pos - exit_pos
	var angle: float
	if dir.length_squared() > 0.01:
		angle = atan2(dir.x, dir.z)
	else:
		var exit_facing: Vector3 = prev_exit.get_meta("facing", Vector3.FORWARD)
		var facing_global: Vector3 = prev_exit.get_parent().global_transform.basis * exit_facing
		angle = atan2(-facing_global.x, -facing_global.z)
	var bridge := MeshBuilder.add_box(
		nav_region,
		Vector3(10.0, 0.5, dist + 2.0),
		bridge_pos,
		LevelMaterials.floor_mat()
	)
	bridge.rotation.y = angle
