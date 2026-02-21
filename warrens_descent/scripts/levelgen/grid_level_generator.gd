class_name GridLevelGenerator
extends Node3D

var enemy_grunt_scene: PackedScene = preload("res://scenes/enemy_grunt.tscn")
var enemy_flying_scene: PackedScene = preload("res://scenes/enemy_flying.tscn")
var enemy_boss_scene: PackedScene = preload("res://scenes/enemy_boss.tscn")
var pickup_health_scene: PackedScene = preload("res://scenes/pickup_health.tscn")
var pickup_ammo_scene: PackedScene = preload("res://scenes/pickup_ammo.tscn")
var pneuma_pickup_scene: PackedScene = preload("res://scenes/pneuma_pickup.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")
var hud_scene: PackedScene = preload("res://scenes/hud.tscn")

@export var level_number: int = 1

var grid: LevelGrid = null
var chunks: Dictionary = {}          # Vector2i -> GridChunkBase (root cells only)
var arena_triggers: Array[ArenaTrigger] = []
var nav_region: NavigationRegion3D = null
var player: Node3D = null
var total_enemies: int = 0
var enemies_killed: int = 0
var level_start_time: float = 0.0
var is_level_complete: bool = false
var _player_last_safe_pos: Vector3 = Vector3.ZERO

signal level_ready()
signal level_cleared()


func _ready() -> void:
	generate_level()


func generate_level() -> void:
	randomize()

	# Clear
	for child in get_children():
		child.queue_free()
	chunks.clear()
	arena_triggers.clear()
	is_level_complete = false
	enemies_killed = 0
	total_enemies = 0

	# --- PHASE 1: Paint the grid ---
	grid = LevelGrid.new()
	_paint_grid()

	# --- PHASE 2: Build geometry from grid ---
	_setup_environment()
	_add_safety_floor()

	nav_region = NavigationRegion3D.new()
	add_child(nav_region)

	_build_all_chunks()
	_bake_navigation()


# ==========================================================================
# PHASE 1: Grid painting
# ==========================================================================

func _paint_grid() -> void:
	var current_pos := Vector2i(0, 0)
	var current_elevation: int = 0
	var current_dir := LevelGrid.SOUTH
	var path_length: int = randi_range(10, 16)
	var chunks_since_arena: int = 0
	var chunks_since_descent: int = 0
	var arena_count: int = 0
	var path_index: int = 0

	# Place starting hallway
	var start_cell := grid.place_cell(current_pos, "hallway_straight", current_elevation, true)
	start_cell.path_index = path_index
	grid.critical_path.append(current_pos)
	path_index += 1

	for step in range(1, path_length):
		var next_dir := _pick_next_direction(current_pos, current_dir)
		var next_pos := current_pos + next_dir

		var chunk_type: String
		var next_elevation: int = current_elevation
		var is_last_step: bool = (step == path_length - 1)

		if is_last_step:
			# Final step: always an arena
			chunk_type = _place_arena(next_pos, current_elevation, next_dir, path_index)
			chunks_since_arena = 0
		elif chunks_since_arena >= 4 and arena_count < 3:
			# Time for an arena — place transition first, then arena
			var trans_cell := grid.place_cell(next_pos, "transition", current_elevation, true)
			trans_cell.path_index = path_index
			grid.connect_cells(current_pos, next_pos)
			grid.critical_path.append(next_pos)
			path_index += 1
			current_pos = next_pos

			next_dir = _pick_next_direction(current_pos, next_dir)
			next_pos = current_pos + next_dir
			chunk_type = _place_arena(next_pos, current_elevation, next_dir, path_index)
			chunks_since_arena = 0
			arena_count += 1
		elif chunks_since_descent >= 3 and randf() < 0.5:
			# Time to descend
			chunk_type = ["descent_ramp", "descent_shaft"].pick_random()
			next_elevation = current_elevation - 1
			var cell := grid.place_cell(next_pos, chunk_type, current_elevation, true)
			cell.exit_elevation = next_elevation
			cell.path_index = path_index
			chunks_since_descent = 0
			chunks_since_arena += 1
		elif randf() < 0.2:
			# Combat room
			chunk_type = "combat_room"
			var cell := grid.place_cell(next_pos, chunk_type, current_elevation, true)
			cell.path_index = path_index
			chunks_since_arena += 1
			chunks_since_descent += 1
		elif randf() < 0.15:
			# Curve
			chunk_type = "hallway_curve"
			var cell := grid.place_cell(next_pos, chunk_type, current_elevation, true)
			cell.path_index = path_index
			var perp := LevelGrid.perpendicular_dirs(next_dir)
			next_dir = perp.pick_random()
			chunks_since_arena += 1
			chunks_since_descent += 1
		else:
			# Standard hallway
			chunk_type = "hallway_straight"
			var cell := grid.place_cell(next_pos, chunk_type, current_elevation, true)
			cell.path_index = path_index
			chunks_since_arena += 1
			chunks_since_descent += 1

		grid.connect_cells(current_pos, next_pos)
		grid.critical_path.append(next_pos)
		path_index += 1

		current_pos = next_pos
		current_elevation = next_elevation
		current_dir = next_dir

	# Side branches: vaults
	_place_vaults()


func _pick_next_direction(from: Vector2i, preferred: Vector2i) -> Vector2i:
	var next := from + preferred
	if grid.is_empty(next):
		if randf() < 0.7:
			return preferred

	var candidates: Array[Vector2i] = []
	for dir in LevelGrid.ALL_DIRS:
		if dir == LevelGrid.opposite_dir(preferred):
			continue
		var test_pos := from + dir
		if grid.is_empty(test_pos):
			candidates.append(dir)

	if candidates.is_empty():
		return preferred

	if preferred in candidates and randf() < 0.6:
		return preferred

	return candidates.pick_random()


func _place_arena(start_pos: Vector2i, elevation: int, entry_dir: Vector2i, path_index: int) -> String:
	var is_boss_level: bool = (level_number % 5 == 0) or (level_number == 1)

	if is_boss_level:
		var positions := _get_3x3_positions(start_pos, entry_dir)
		if grid.are_empty(positions):
			var root_cell := grid.place_multi_cell(positions, "arena_large", elevation, true)
			root_cell.path_index = path_index
			return "arena_large"

	# Fall back to 2x2 small arena
	var positions := _get_2x2_positions(start_pos, entry_dir)
	if grid.are_empty(positions):
		var root_cell := grid.place_multi_cell(positions, "arena_small", elevation, true)
		root_cell.path_index = path_index
		return "arena_small"

	# Can't fit any arena — place a combat room instead
	var cell := grid.place_cell(start_pos, "combat_room", elevation, true)
	cell.path_index = path_index
	return "combat_room"


func _get_2x2_positions(start: Vector2i, entry_dir: Vector2i) -> Array[Vector2i]:
	var forward := entry_dir
	var right: Vector2i
	if entry_dir == LevelGrid.SOUTH or entry_dir == LevelGrid.NORTH:
		right = LevelGrid.EAST
	else:
		right = LevelGrid.SOUTH
	return [start, start + right, start + forward, start + forward + right]


func _get_3x3_positions(start: Vector2i, entry_dir: Vector2i) -> Array[Vector2i]:
	var forward := entry_dir
	var right: Vector2i
	if entry_dir == LevelGrid.SOUTH or entry_dir == LevelGrid.NORTH:
		right = LevelGrid.EAST
	else:
		right = LevelGrid.SOUTH

	var positions: Array[Vector2i] = []
	for fwd_step in 3:
		for right_step in 3:
			positions.append(start + forward * fwd_step + right * right_step)
	return positions


func _place_vaults() -> void:
	for cell_pos in grid.critical_path:
		var cell: LevelGrid.CellData = grid.cells[cell_pos]
		if not cell.chunk_type.begins_with("hallway"):
			continue

		var perp_dirs := LevelGrid.perpendicular_dirs(_get_path_direction(cell_pos))
		perp_dirs.shuffle()

		for dir in perp_dirs:
			var vault_pos := cell_pos + dir
			if grid.is_empty(vault_pos) and randf() < 0.25:
				var vault_cell := grid.place_cell(vault_pos, "vault", cell.elevation, false)
				vault_cell.connections[LevelGrid.opposite_dir(dir)] = true
				cell.vault_wall_dir = dir
				break


func _get_path_direction(cell_pos: Vector2i) -> Vector2i:
	var idx: int = grid.critical_path.find(cell_pos)
	if idx >= 0 and idx < grid.critical_path.size() - 1:
		return grid.critical_path[idx + 1] - cell_pos
	return LevelGrid.SOUTH


# ==========================================================================
# PHASE 2: Geometry construction
# ==========================================================================

func _build_all_chunks() -> void:
	var built_multi_cells: Array[int] = []

	for cell_pos in grid.cells:
		var cell: LevelGrid.CellData = grid.cells[cell_pos]

		# For multi-cell chunks, only build from the root cell
		if cell.multi_cell_id >= 0:
			if cell.grid_pos != cell.multi_cell_root:
				continue
			if cell.multi_cell_id in built_multi_cells:
				continue
			built_multi_cells.append(cell.multi_cell_id)

		var chunk: GridChunkBase = _create_chunk(cell.chunk_type)
		chunk.cell_data = cell
		chunk.grid = grid
		chunk.cell_world_pos = grid.grid_to_world(cell.grid_pos, cell.elevation)

		nav_region.add_child(chunk)
		chunk.build()
		chunks[cell_pos] = chunk

		# Setup arena triggers
		if chunk.is_arena():
			var trigger := ArenaTrigger.new()
			add_child(trigger)
			trigger.setup(chunk, enemy_grunt_scene, enemy_flying_scene, enemy_boss_scene, level_number)
			trigger.arena_cleared.connect(_on_arena_cleared)
			arena_triggers.append(trigger)

	print("[GridLevelGen] Built ", chunks.size(), " chunks, ", arena_triggers.size(), " arenas")
	for pos in grid.critical_path:
		var cell: LevelGrid.CellData = grid.cells[pos]
		print("[GridLevelGen]   Path[", cell.path_index, "]: ", cell.chunk_type, " @ ", pos, " elev=", cell.elevation)


func _create_chunk(chunk_type: String) -> GridChunkBase:
	match chunk_type:
		"hallway_straight":
			return GridHallwayStraight.new()
		"hallway_curve":
			return GridHallwayCurve.new()
		"transition":
			return GridTransition.new()
		"combat_room":
			return GridCombatRoom.new()
		"descent_ramp":
			return GridDescentRamp.new()
		"descent_shaft":
			return GridDescentShaft.new()
		"arena_small":
			return GridArenaSmall.new()
		"arena_large":
			return GridArenaLarge.new()
		"vault":
			return GridVault.new()
		_:
			return GridHallwayStraight.new()


# ==========================================================================
# Navigation + spawning
# ==========================================================================

func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_finished.connect(_on_nav_baked, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh()


func _on_nav_baked() -> void:
	_spawn_player()
	_spawn_non_arena_enemies()
	_spawn_pickups()
	level_start_time = Time.get_ticks_msec() / 1000.0
	level_ready.emit()


func _spawn_player() -> void:
	player = player_scene.instantiate()
	add_child(player)

	if grid.critical_path.size() > 0:
		var start_cell: LevelGrid.CellData = grid.cells[grid.critical_path[0]]
		var world_pos: Vector3 = grid.grid_to_world(start_cell.grid_pos, start_cell.elevation)
		player.global_position = world_pos + Vector3(0, 1.0, 0)

		if grid.critical_path.size() > 1:
			var next_pos: Vector3 = grid.grid_to_world(grid.critical_path[1], start_cell.elevation)
			var look_dir: Vector3 = (next_pos - world_pos).normalized()
			player.rotation.y = atan2(-look_dir.x, -look_dir.z)
	else:
		player.global_position = Vector3(0, 1, 0)

	_player_last_safe_pos = player.global_position

	var hud := hud_scene.instantiate()
	add_child(hud)


func _spawn_non_arena_enemies() -> void:
	for cell_pos in chunks:
		var chunk: GridChunkBase = chunks[cell_pos]
		if chunk.is_arena():
			continue
		for spawn in chunk.get_spawn_points():
			var enemy_type: String = spawn.get_meta("enemy_type", "ground")
			var scene: PackedScene
			match enemy_type:
				"flying":
					scene = enemy_flying_scene
				"boss":
					scene = enemy_boss_scene
				_:
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
	for cell_pos in chunks:
		var chunk: GridChunkBase = chunks[cell_pos]
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


# ==========================================================================
# Level completion
# ==========================================================================

func _on_enemy_died(_enemy: Node3D) -> void:
	enemies_killed += 1


func _on_arena_cleared() -> void:
	var all_cleared: bool = true
	for trigger in arena_triggers:
		if not trigger.is_cleared:
			all_cleared = false
			break
	if all_cleared and arena_triggers.size() > 0:
		_on_level_complete()


func _on_level_complete() -> void:
	if is_level_complete:
		return
	is_level_complete = true
	level_cleared.emit()

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


# ==========================================================================
# Environment + safety
# ==========================================================================

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

	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.8, 0.8, 0.9)
	dir_light.light_energy = 1.0
	dir_light.rotation_degrees = Vector3(-60, 30, 0)
	dir_light.shadow_enabled = false
	add_child(dir_light)


func _add_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, -50, 0)
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1000, 1, 1000)
	col.shape = shape
	body.add_child(col)


func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	if player.is_on_floor():
		_player_last_safe_pos = player.global_position
	if player.global_position.y < -40.0:
		player.global_position = _player_last_safe_pos + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
