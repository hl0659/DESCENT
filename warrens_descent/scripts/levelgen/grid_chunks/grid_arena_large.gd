class_name GridArenaLarge
extends GridChunkBase


func _build_perimeter_walls() -> void:
	var height := get_wall_height()
	var wall_mat := get_wall_material()
	var siblings := grid.get_multi_cell_siblings(cell_data.grid_pos)
	var half_cell := CELL_SIZE * 0.5

	for cell_pos in siblings:
		var sibling_cell: LevelGrid.CellData = grid.cells[cell_pos]
		var cell_offset := Vector3(
			(cell_pos.x - cell_data.grid_pos.x) * CELL_SIZE,
			0,
			(cell_pos.y - cell_data.grid_pos.y) * CELL_SIZE
		)

		for dir in LevelGrid.ALL_DIRS:
			var neighbor_pos: Vector2i = cell_pos + dir
			if neighbor_pos in siblings:
				continue

			var has_connection: bool = sibling_cell.connections.get(dir, false)

			var wall_center: Vector3
			var wall_size: Vector3

			match dir:
				LevelGrid.NORTH:
					wall_center = cell_offset + Vector3(0, height * 0.5, -half_cell)
					wall_size = Vector3(CELL_SIZE, height, WALL_THICKNESS)
				LevelGrid.SOUTH:
					wall_center = cell_offset + Vector3(0, height * 0.5, half_cell)
					wall_size = Vector3(CELL_SIZE, height, WALL_THICKNESS)
				LevelGrid.EAST:
					wall_center = cell_offset + Vector3(half_cell, height * 0.5, 0)
					wall_size = Vector3(WALL_THICKNESS, height, CELL_SIZE)
				LevelGrid.WEST:
					wall_center = cell_offset + Vector3(-half_cell, height * 0.5, 0)
					wall_size = Vector3(WALL_THICKNESS, height, CELL_SIZE)

			if has_connection:
				_build_wall_with_doorway(dir, wall_center, wall_size, height, wall_mat, 0.0)
			else:
				MeshBuilder.add_box(self, wall_size, wall_center, wall_mat)


func build_interior() -> void:
	var span := CELL_SIZE * 3.0          # 90
	var min_x := -CELL_SIZE * 0.5        # -15
	var max_x := CELL_SIZE * 2.5         # +75
	var min_z := -CELL_SIZE * 0.5        # -15
	var max_z := CELL_SIZE * 2.5         # +75
	var cx := (min_x + max_x) * 0.5     # +30
	var cz := (min_z + max_z) * 0.5     # +30

	# Floor
	MeshBuilder.add_box(self, Vector3(span, 0.5, span), Vector3(cx, -0.25, cz), LevelMaterials.arena_floor_mat())
	# Ceiling
	MeshBuilder.add_box(self, Vector3(span, 0.5, span), Vector3(cx, ARENA_LG_HEIGHT + 0.25, cz), LevelMaterials.ceiling_mat())

	# Central raised ring (4 boxes forming a square ring)
	var ring_h := 2.5
	MeshBuilder.add_box(self, Vector3(20, ring_h, 5), Vector3(cx, ring_h * 0.5, cz - 10), LevelMaterials.platform_mat())  # North side
	MeshBuilder.add_box(self, Vector3(20, ring_h, 5), Vector3(cx, ring_h * 0.5, cz + 10), LevelMaterials.platform_mat())  # South side
	MeshBuilder.add_box(self, Vector3(5, ring_h, 20), Vector3(cx - 10, ring_h * 0.5, cz), LevelMaterials.platform_mat())  # West side
	MeshBuilder.add_box(self, Vector3(5, ring_h, 20), Vector3(cx + 10, ring_h * 0.5, cz), LevelMaterials.platform_mat())  # East side

	# Elevated platforms at different heights in different quadrants
	MeshBuilder.add_platform(self, 7.0, 7.0, Vector3(cx - 20, 4.0, cz - 20), LevelMaterials.platform_mat())
	MeshBuilder.add_platform(self, 6.0, 6.0, Vector3(cx + 20, 7.0, cz - 20), LevelMaterials.platform_mat())
	MeshBuilder.add_platform(self, 8.0, 6.0, Vector3(cx - 20, 10.0, cz + 20), LevelMaterials.platform_mat())
	MeshBuilder.add_platform(self, 6.0, 7.0, Vector3(cx + 20, 13.0, cz + 20), LevelMaterials.platform_mat())

	# Wall ramps - one on each wall
	var ramp_angle := rad_to_deg(atan2(5.0, 20.0))
	MeshBuilder.add_ramp(self, Vector3(6, 0.5, 20), Vector3(min_x + 5, 2.5, cz), -ramp_angle, LevelMaterials.platform_mat())    # West
	MeshBuilder.add_ramp(self, Vector3(6, 0.5, 20), Vector3(max_x - 5, 2.5, cz), ramp_angle, LevelMaterials.platform_mat())     # East
	MeshBuilder.add_ramp(self, Vector3(20, 0.5, 6), Vector3(cx, 2.5, min_z + 5), ramp_angle, LevelMaterials.platform_mat())      # North
	MeshBuilder.add_ramp(self, Vector3(20, 0.5, 6), Vector3(cx, 2.5, max_z - 5), -ramp_angle, LevelMaterials.platform_mat())     # South

	# Central pillar cluster - 3 columns for cover
	MeshBuilder.add_cylinder_column(self, 2.0, 20.0, Vector3(cx - 3, 10.0, cz), LevelMaterials.platform_mat())
	MeshBuilder.add_cylinder_column(self, 2.0, 20.0, Vector3(cx + 4, 10.0, cz - 3), LevelMaterials.platform_mat())
	MeshBuilder.add_cylinder_column(self, 2.0, 20.0, Vector3(cx + 1, 10.0, cz + 4), LevelMaterials.platform_mat())

	# Lights
	MeshBuilder.add_light(self, Vector3(cx, ARENA_LG_HEIGHT - 1, cz), Color(0.95, 0.9, 0.85), 6.0, 50.0)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			MeshBuilder.add_light(self, Vector3(cx + dx * 25, ARENA_LG_HEIGHT - 1, cz + dz * 25), Color(0.9, 0.85, 0.8), 3.5, 30.0)
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 1.0]:
			if dx == 0.0:
				continue
			MeshBuilder.add_light(self, Vector3(cx + dx * 15, 10.0, cz + dz * 15), Color(0.85, 0.85, 0.9), 2.5, 20.0)

	# Spawn points
	# Wave 0: Boss + 4 ground
	var boss_spawn := MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz), "boss", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx + 12, 0, cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx - 12, 0, cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz + 12), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz - 12), "ground", 0)

	# Wave 1: 6 ground + 2 flying
	var r1 := 20.0
	MeshBuilder.add_spawn_point(self, Vector3(cx + r1, 0, cz), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r1, 0, cz), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz + r1), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz - r1), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx + r1 * 0.7, 0, cz + r1 * 0.7), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r1 * 0.7, 0, cz - r1 * 0.7), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx - 10, 14, cz), "flying", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx + 10, 14, cz), "flying", 1)

	# Wave 2: 4 ground + 3 flying
	var r2 := 15.0
	MeshBuilder.add_spawn_point(self, Vector3(cx + r2, 0, cz + r2 * 0.5), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r2, 0, cz - r2 * 0.5), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx + r2 * 0.5, 0, cz + r2), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r2 * 0.5, 0, cz - r2), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 16, cz), "flying", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx - 15, 13, cz - 10), "flying", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx + 15, 13, cz + 10), "flying", 2)


func get_wall_height() -> float:
	return ARENA_LG_HEIGHT


func get_wall_material() -> StandardMaterial3D:
	return LevelMaterials.arena_wall_mat()


func is_arena() -> bool:
	return true


func is_boss_arena() -> bool:
	return true


func get_chunk_type() -> String:
	return "arena_large"
