class_name GridDescentShaft
extends GridChunkBase


func build_interior() -> void:
	var entry_dir := _get_entry_dir()
	var exit_dir := _get_exit_dir()

	var entry_vec := Vector3(entry_dir.x, 0, entry_dir.y).normalized()
	var exit_vec := Vector3(exit_dir.x, 0, exit_dir.y).normalized()

	# Entry platform at Y=0, near entry edge
	var entry_center := -entry_vec * (CELL_SIZE * 0.5) + entry_vec * 5.0
	MeshBuilder.add_platform(self, 10.0, 10.0, entry_center + Vector3(0, -0.25, 0), LevelMaterials.floor_mat())

	# Exit platform at Y=-DESCENT_STEP, near exit edge
	var exit_center := -exit_vec * (CELL_SIZE * 0.5) + exit_vec * 5.0
	MeshBuilder.add_platform(self, 10.0, 10.0, exit_center + Vector3(0, -DESCENT_STEP - 0.25, 0), LevelMaterials.floor_mat())

	# Intermediate zigzag platforms
	var plat_positions := [
		Vector3(-8, -1.75, 0),
		Vector3(8, -3.5, 0),
		Vector3(-8, -5.25, 0),
	]
	for pos in plat_positions:
		MeshBuilder.add_platform(self, 6.0, 6.0, pos, LevelMaterials.platform_mat())

	# Ceiling only above entry platform
	MeshBuilder.add_box(self, Vector3(12.0, 0.5, 12.0), entry_center + Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Lights at each platform level - dim blue
	MeshBuilder.add_light(self, entry_center + Vector3(0, CORRIDOR_HEIGHT - 1.0, 0), Color(0.7, 0.7, 0.85), 1.5, 15.0)
	for pos in plat_positions:
		MeshBuilder.add_light(self, pos + Vector3(0, 3.0, 0), Color(0.7, 0.7, 0.85), 1.5, 12.0)
	MeshBuilder.add_light(self, exit_center + Vector3(0, -DESCENT_STEP + 3.0, 0), Color(0.7, 0.7, 0.85), 1.5, 12.0)

	# Spawn points
	MeshBuilder.add_spawn_point(self, Vector3(-8, -1.75 + 0.5, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(8, -3.5 + 0.5, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, -3.5, 0), "flying", 0)


func get_wall_height() -> float:
	return CORRIDOR_HEIGHT + DESCENT_STEP


func _get_wall_center_y(height: float) -> float:
	return (CORRIDOR_HEIGHT - DESCENT_STEP) * 0.5


func _get_door_y_offset(dir: Vector2i) -> float:
	if _is_exit_direction(dir):
		return -DESCENT_STEP
	return 0.0


func _get_entry_dir() -> Vector2i:
	for dir in cell_data.connections:
		if cell_data.connections[dir]:
			var neighbor_pos: Vector2i = cell_data.grid_pos + dir
			if grid.cells.has(neighbor_pos):
				var neighbor: LevelGrid.CellData = grid.cells[neighbor_pos]
				if neighbor.exit_elevation >= cell_data.elevation:
					return dir
	for dir in cell_data.connections:
		if cell_data.connections[dir]:
			return dir
	return LevelGrid.NORTH


func _get_exit_dir() -> Vector2i:
	var entry := _get_entry_dir()
	for dir in cell_data.connections:
		if cell_data.connections[dir] and dir != entry:
			return dir
	return LevelGrid.opposite_dir(entry)


func _is_exit_direction(dir: Vector2i) -> bool:
	return dir == _get_exit_dir()


func get_chunk_type() -> String:
	return "descent_shaft"
