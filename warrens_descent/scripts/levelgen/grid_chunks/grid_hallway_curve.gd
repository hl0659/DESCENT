class_name GridHallwayCurve
extends GridChunkBase


func build_interior() -> void:
	# Floor & ceiling
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Determine connected edges
	var connected_dirs: Array[Vector2i] = []
	for dir in LevelGrid.ALL_DIRS:
		if cell_data.connections.get(dir, false):
			connected_dirs.append(dir)

	# Find the inner corner based on which two edges are connected
	var corner_x := 0.0
	var corner_z := 0.0

	if connected_dirs.size() >= 2:
		var d0 := connected_dirs[0]
		var d1 := connected_dirs[1]
		# Inner corner is the corner shared by the two NON-connected edges
		# For NORTH+EAST: inner corner at (+X, -Z) = NE corner
		if _has_dirs(connected_dirs, LevelGrid.NORTH, LevelGrid.EAST):
			corner_x = 1.0; corner_z = -1.0
		elif _has_dirs(connected_dirs, LevelGrid.NORTH, LevelGrid.WEST):
			corner_x = -1.0; corner_z = -1.0
		elif _has_dirs(connected_dirs, LevelGrid.SOUTH, LevelGrid.EAST):
			corner_x = 1.0; corner_z = 1.0
		elif _has_dirs(connected_dirs, LevelGrid.SOUTH, LevelGrid.WEST):
			corner_x = -1.0; corner_z = 1.0
		else:
			# Fallback: NORTH+EAST
			corner_x = 1.0; corner_z = -1.0
	else:
		corner_x = 1.0; corner_z = -1.0

	# Inner corner wall pieces - create a 45-degree cut ~8m from the corner
	var cx := corner_x * 10.0
	var cz := corner_z * 10.0
	# Two angled box pieces forming a diagonal wall
	MeshBuilder.add_box(self, Vector3(8.0, CORRIDOR_HEIGHT, 1.0), Vector3(cx, CORRIDOR_HEIGHT * 0.5, cz * 0.6), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(1.0, CORRIDOR_HEIGHT, 8.0), Vector3(cx * 0.6, CORRIDOR_HEIGHT * 0.5, cz), LevelMaterials.wall_mat())

	# Lights
	MeshBuilder.add_light(self, Vector3(-corner_x * 4.0, CORRIDOR_HEIGHT - 1.0, -corner_z * 4.0), Color(0.85, 0.85, 0.95), 2.5, 20.0)
	MeshBuilder.add_light(self, Vector3(corner_x * 2.0, CORRIDOR_HEIGHT - 1.0, corner_z * 2.0), Color(0.85, 0.85, 0.95), 2.0, 15.0)

	# Spawn points - 2-3 ground enemies in the outer half
	MeshBuilder.add_spawn_point(self, Vector3(-corner_x * 6.0, 0, -corner_z * 6.0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-corner_x * 8.0, 0, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, -corner_z * 8.0), "ground", 0)


func _has_dirs(dirs: Array[Vector2i], a: Vector2i, b: Vector2i) -> bool:
	return a in dirs and b in dirs


func get_chunk_type() -> String:
	return "hallway_curve"
