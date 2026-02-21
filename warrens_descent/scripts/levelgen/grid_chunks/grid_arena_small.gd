class_name GridArenaSmall
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
	var min_x := -CELL_SIZE * 0.5       # -15
	var max_x := CELL_SIZE * 1.5        # +45
	var min_z := -CELL_SIZE * 0.5       # -15
	var max_z := CELL_SIZE * 1.5        # +45
	var cx := (min_x + max_x) * 0.5    # +15
	var cz := (min_z + max_z) * 0.5    # +15
	var span := CELL_SIZE * 2.0         # 60

	# Floor
	MeshBuilder.add_box(self, Vector3(span, 0.5, span), Vector3(cx, -0.25, cz), LevelMaterials.arena_floor_mat())
	# Ceiling
	MeshBuilder.add_box(self, Vector3(span, 0.5, span), Vector3(cx, ARENA_SM_HEIGHT + 0.25, cz), LevelMaterials.ceiling_mat())

	# Central platform
	MeshBuilder.add_box(self, Vector3(8, 2, 8), Vector3(cx, 1.0, cz), LevelMaterials.platform_mat())

	# Wall ramps on opposite sides
	var ramp_angle := rad_to_deg(atan2(4.0, 15.0))
	MeshBuilder.add_ramp(self, Vector3(6, 0.5, 15), Vector3(min_x + 4, 2.0, cz), -ramp_angle, LevelMaterials.platform_mat())
	MeshBuilder.add_ramp(self, Vector3(6, 0.5, 15), Vector3(max_x - 4, 2.0, cz), ramp_angle, LevelMaterials.platform_mat())

	# Side platforms at different heights
	MeshBuilder.add_platform(self, 6.0, 4.0, Vector3(cx - 12, 3.5, cz - 12), LevelMaterials.platform_mat())
	MeshBuilder.add_platform(self, 5.0, 5.0, Vector3(cx + 12, 6.0, cz + 12), LevelMaterials.platform_mat())

	# Central column
	MeshBuilder.add_cylinder_column(self, 1.5, 16.0, Vector3(cx + 4, 8.0, cz - 4), LevelMaterials.platform_mat())

	# Lights
	MeshBuilder.add_light(self, Vector3(cx, ARENA_SM_HEIGHT - 1, cz), Color(0.9, 0.85, 0.8), 5.0, 35.0)
	MeshBuilder.add_light(self, Vector3(min_x + 5, ARENA_SM_HEIGHT - 1, min_z + 5), Color(0.9, 0.85, 0.8), 3.0, 25.0)
	MeshBuilder.add_light(self, Vector3(max_x - 5, ARENA_SM_HEIGHT - 1, min_z + 5), Color(0.9, 0.85, 0.8), 3.0, 25.0)
	MeshBuilder.add_light(self, Vector3(min_x + 5, ARENA_SM_HEIGHT - 1, max_z - 5), Color(0.9, 0.85, 0.8), 3.0, 25.0)
	MeshBuilder.add_light(self, Vector3(max_x - 5, ARENA_SM_HEIGHT - 1, max_z - 5), Color(0.9, 0.85, 0.8), 3.0, 25.0)

	# Spawn points - 3 waves
	# Wave 0: 4 ground at radius 10m from center
	var r0 := 10.0
	MeshBuilder.add_spawn_point(self, Vector3(cx + r0, 0, cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r0, 0, cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz + r0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz - r0), "ground", 0)

	# Wave 1: 4 ground at radius 18m
	var r1 := 18.0
	MeshBuilder.add_spawn_point(self, Vector3(cx + r1, 0, cz), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r1, 0, cz), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz + r1), "ground", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz - r1), "ground", 1)

	# Wave 2: 3 ground at radius 12m
	var r2 := 12.0
	MeshBuilder.add_spawn_point(self, Vector3(cx + r2, 0, cz + r2 * 0.5), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx - r2, 0, cz - r2 * 0.5), "ground", 2)
	MeshBuilder.add_spawn_point(self, Vector3(cx, 0, cz + r2), "ground", 2)

	# Flying spawns
	MeshBuilder.add_spawn_point(self, Vector3(cx, 12, cz), "flying", 0)
	MeshBuilder.add_spawn_point(self, Vector3(cx - 8, 11, cz - 6), "flying", 1)
	MeshBuilder.add_spawn_point(self, Vector3(cx + 8, 11, cz + 6), "flying", 1)


func get_wall_height() -> float:
	return ARENA_SM_HEIGHT


func get_wall_material() -> StandardMaterial3D:
	return LevelMaterials.arena_wall_mat()


func is_arena() -> bool:
	return true


func get_chunk_type() -> String:
	return "arena_small"
