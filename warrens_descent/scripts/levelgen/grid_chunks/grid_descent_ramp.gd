class_name GridDescentRamp
extends GridChunkBase


func build_interior() -> void:
	var entry_dir := _get_entry_dir()
	var exit_dir := _get_exit_dir()

	# World-space direction of descent (entry -> exit in XZ)
	var descent_vec := Vector3(exit_dir.x, 0, exit_dir.y).normalized()
	# Entry/exit edge centers in local space
	var entry_edge_center := -descent_vec * (CELL_SIZE * 0.5)
	var exit_edge_center := descent_vec * (CELL_SIZE * 0.5)

	# Perpendicular direction for width
	var perp := Vector3(-descent_vec.z, 0, descent_vec.x)

	# Entry floor patch (5m deep at Y=0)
	var entry_patch_center := entry_edge_center + descent_vec * 2.5
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, 5.0), _orient_size(entry_patch_center, descent_vec, CELL_SIZE, 0.5, 5.0), LevelMaterials.floor_mat())

	# Exit floor patch (5m deep at Y=-DESCENT_STEP)
	var exit_patch_center := exit_edge_center - descent_vec * 2.5 + Vector3(0, -DESCENT_STEP, 0)
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, 5.0), _orient_size(exit_patch_center, descent_vec, CELL_SIZE, 0.5, 5.0), LevelMaterials.floor_mat())

	# Ramp surface between patches
	var ramp_start := entry_edge_center + descent_vec * 5.0
	var ramp_end := exit_edge_center - descent_vec * 5.0 + Vector3(0, -DESCENT_STEP, 0)
	var ramp_center := (ramp_start + ramp_end) * 0.5
	var ramp_horizontal_length := 20.0  # CELL_SIZE - 2 * 5m patches
	var ramp_angle := rad_to_deg(atan2(DESCENT_STEP, ramp_horizontal_length))
	var ramp_surface_length := sqrt(ramp_horizontal_length * ramp_horizontal_length + DESCENT_STEP * DESCENT_STEP)

	var ramp_holder := Node3D.new()
	ramp_holder.position = ramp_center
	add_child(ramp_holder)

	# Orient ramp to face the descent direction
	var yaw := atan2(-descent_vec.x, -descent_vec.z)
	ramp_holder.rotation.y = yaw

	MeshBuilder.add_ramp(ramp_holder, Vector3(CELL_SIZE, 0.5, ramp_surface_length), Vector3.ZERO, ramp_angle, LevelMaterials.floor_mat())

	# Ceiling
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Lights descending with slope
	for i in 3:
		var t := float(i) / 2.0
		var light_pos := entry_edge_center.lerp(exit_edge_center, t * 0.8 + 0.1)
		light_pos.y = CORRIDOR_HEIGHT - 1.0 - t * DESCENT_STEP * 0.5
		MeshBuilder.add_light(self, light_pos, Color(0.85, 0.85, 0.95), 2.5, 20.0)

	# Spawn points
	MeshBuilder.add_spawn_point(self, entry_edge_center + descent_vec * 3.0 + Vector3(0, 0.5, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, exit_edge_center - descent_vec * 3.0 + Vector3(0, -DESCENT_STEP + 0.5, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, exit_edge_center - descent_vec * 8.0 + Vector3(0, -DESCENT_STEP + 0.5, 0), "ground", 0)


func _orient_size(center: Vector3, dir: Vector3, width: float, height: float, depth: float) -> Vector3:
	# Returns center position; size orientation handled by box being axis-aligned
	return center


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
	return "descent_ramp"
