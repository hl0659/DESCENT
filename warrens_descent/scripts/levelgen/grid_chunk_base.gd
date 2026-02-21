class_name GridChunkBase
extends Node3D

const CELL_SIZE := 30.0
const DESCENT_STEP := 7.0
const CORRIDOR_HEIGHT := 12.0
const ARENA_SM_HEIGHT := 20.0
const ARENA_LG_HEIGHT := 25.0
const WALL_THICKNESS := 0.5
const DOOR_WIDTH := 4.0
const DOOR_HEIGHT := 5.0

var cell_data: LevelGrid.CellData = null
var grid: LevelGrid = null
var cell_world_pos: Vector3 = Vector3.ZERO


func build() -> void:
	position = cell_world_pos
	_build_perimeter_walls()
	build_interior()


func _build_perimeter_walls() -> void:
	var height := get_wall_height()
	var half_cell := CELL_SIZE * 0.5
	var wall_mat := get_wall_material()
	var siblings := grid.get_multi_cell_siblings(cell_data.grid_pos)

	for dir in LevelGrid.ALL_DIRS:
		var neighbor_pos: Vector2i = cell_data.grid_pos + dir

		# Skip internal edges of multi-cell chunks (no wall between siblings)
		if neighbor_pos in siblings and neighbor_pos != cell_data.grid_pos:
			continue

		var has_connection: bool = cell_data.connections.get(dir, false)
		var is_vault_wall: bool = (cell_data.vault_wall_dir == dir and cell_data.vault_wall_dir != Vector2i.ZERO)

		var wall_center: Vector3
		var wall_size: Vector3
		var wall_y: float = _get_wall_center_y(height)

		match dir:
			LevelGrid.NORTH:
				wall_center = Vector3(0, wall_y, -half_cell)
				wall_size = Vector3(CELL_SIZE, height, WALL_THICKNESS)
			LevelGrid.SOUTH:
				wall_center = Vector3(0, wall_y, half_cell)
				wall_size = Vector3(CELL_SIZE, height, WALL_THICKNESS)
			LevelGrid.EAST:
				wall_center = Vector3(half_cell, wall_y, 0)
				wall_size = Vector3(WALL_THICKNESS, height, CELL_SIZE)
			LevelGrid.WEST:
				wall_center = Vector3(-half_cell, wall_y, 0)
				wall_size = Vector3(WALL_THICKNESS, height, CELL_SIZE)

		if has_connection:
			var door_y_offset: float = _get_door_y_offset(dir)
			_build_wall_with_doorway(dir, wall_center, wall_size, height, wall_mat, door_y_offset)
		elif is_vault_wall:
			_build_vault_wall(dir, wall_center, wall_size, height, wall_mat)
		else:
			MeshBuilder.add_box(self, wall_size, wall_center, wall_mat)


## Wall center Y. Override in descent chunks to extend walls below Y=0.
func _get_wall_center_y(height: float) -> float:
	return height * 0.5


## Doorway Y offset per edge. 0 for flat chunks. Descent chunks override for exit edge.
func _get_door_y_offset(_dir: Vector2i) -> float:
	return 0.0


func _build_wall_with_doorway(dir: Vector2i, center: Vector3, size: Vector3, height: float, mat: StandardMaterial3D, door_y_offset: float = 0.0) -> void:
	# add_wall_with_door cuts along its local X axis.
	# N/S walls already run along X. E/W walls need 90 rotation.
	if dir == LevelGrid.NORTH or dir == LevelGrid.SOUTH:
		var pivot := Node3D.new()
		pivot.position = center + Vector3(0, door_y_offset, 0)
		add_child(pivot)
		MeshBuilder.add_wall_with_door(pivot, Vector3(CELL_SIZE, height, WALL_THICKNESS), Vector3.ZERO, mat, 0.0)
	else:
		var pivot := Node3D.new()
		pivot.position = center + Vector3(0, door_y_offset, 0)
		pivot.rotation_degrees.y = 90.0
		add_child(pivot)
		MeshBuilder.add_wall_with_door(pivot, Vector3(CELL_SIZE, height, WALL_THICKNESS), Vector3.ZERO, mat, 0.0)


## Builds a wall with a doorway shape, but fills the doorway with a DestructibleWall.
func _build_vault_wall(dir: Vector2i, center: Vector3, size: Vector3, height: float, mat: StandardMaterial3D) -> void:
	# Build the surrounding wall with doorway cutout (same as a normal doorway)
	if dir == LevelGrid.NORTH or dir == LevelGrid.SOUTH:
		var pivot := Node3D.new()
		pivot.position = center
		add_child(pivot)
		MeshBuilder.add_wall_with_door(pivot, Vector3(CELL_SIZE, height, WALL_THICKNESS), Vector3.ZERO, mat, 0.0)
	else:
		var pivot := Node3D.new()
		pivot.position = center
		pivot.rotation_degrees.y = 90.0
		add_child(pivot)
		MeshBuilder.add_wall_with_door(pivot, Vector3(CELL_SIZE, height, WALL_THICKNESS), Vector3.ZERO, mat, 0.0)

	# Place a DestructibleWall filling the doorway opening
	var dest_wall := DestructibleWall.new()
	dest_wall.name = "DestructibleWall"

	var dest_size := Vector3(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS)

	# Mesh - distinct cracked appearance
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dest_size
	mesh_inst.mesh = box
	mesh_inst.name = "MeshInstance3D"
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color(0.35, 0.3, 0.25)
	mesh_inst.material_override = crack_mat
	dest_wall.add_child(mesh_inst)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dest_size
	col.shape = shape
	dest_wall.add_child(col)

	# Position at the doorway opening (bottom of wall + half door height)
	var door_center_y: float = DOOR_HEIGHT * 0.5
	dest_wall.position = center + Vector3(0, door_center_y - height * 0.5, 0)
	if dir == LevelGrid.EAST or dir == LevelGrid.WEST:
		dest_wall.rotation_degrees.y = 90.0

	add_child(dest_wall)


# --- Virtual methods for subclasses ---

func build_interior() -> void:
	pass


func get_wall_height() -> float:
	return CORRIDOR_HEIGHT


func get_wall_material() -> StandardMaterial3D:
	return LevelMaterials.wall_mat()


func is_arena() -> bool:
	return false


func is_boss_arena() -> bool:
	return false


func get_spawn_points(group_filter: int = -1) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and child.is_in_group("spawn_points"):
			if group_filter < 0 or child.get_meta("spawn_group", 0) == group_filter:
				result.append(child)
	return result


func get_chunk_type() -> String:
	return "base"
