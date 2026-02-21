class_name LevelGrid

const CELL_SIZE := 30.0
const DESCENT_STEP := 7.0

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const ALL_DIRS: Array[Vector2i] = [NORTH, SOUTH, EAST, WEST]

var cells: Dictionary = {}                   # Vector2i -> CellData
var critical_path: Array[Vector2i] = []      # Ordered cells on main path
var grid_min: Vector2i = Vector2i.ZERO
var grid_max: Vector2i = Vector2i.ZERO


class CellData:
	var grid_pos: Vector2i = Vector2i.ZERO
	var chunk_type: String = ""
	var elevation: int = 0
	var exit_elevation: int = 0          # For descent chunks only. equals elevation for flat chunks.
	var connections: Dictionary = {}     # Vector2i direction -> bool
	var is_critical_path: bool = false
	var multi_cell_id: int = -1          # -1 = single cell. Otherwise shared ID for multi-cell chunks.
	var multi_cell_root: Vector2i = Vector2i.ZERO  # Root cell of multi-cell chunk.
	var vault_wall_dir: Vector2i = Vector2i.ZERO   # Direction of destructible wall. ZERO = no vault.
	var path_index: int = -1             # Order along critical path. -1 = not on path.


func is_empty(grid_pos: Vector2i) -> bool:
	return not cells.has(grid_pos)


func are_empty(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if cells.has(pos):
			return false
	return true


## Place a single-cell chunk.
func place_cell(grid_pos: Vector2i, chunk_type: String, elevation: int, is_path: bool = false) -> CellData:
	var cell := CellData.new()
	cell.grid_pos = grid_pos
	cell.chunk_type = chunk_type
	cell.elevation = elevation
	cell.exit_elevation = elevation
	cell.is_critical_path = is_path
	cells[grid_pos] = cell
	_update_bounds(grid_pos)
	return cell


## Place a multi-cell chunk. positions[0] is the root.
func place_multi_cell(positions: Array[Vector2i], chunk_type: String, elevation: int, is_path: bool = false) -> CellData:
	var root := positions[0]
	var mc_id := cells.size()
	var root_cell: CellData = null
	for pos in positions:
		var cell := CellData.new()
		cell.grid_pos = pos
		cell.chunk_type = chunk_type
		cell.elevation = elevation
		cell.exit_elevation = elevation
		cell.is_critical_path = is_path
		cell.multi_cell_id = mc_id
		cell.multi_cell_root = root
		cells[pos] = cell
		_update_bounds(pos)
		if pos == root:
			root_cell = cell
	return root_cell


## Add a bidirectional doorway connection between two adjacent cells.
func connect_cells(pos_a: Vector2i, pos_b: Vector2i) -> void:
	var dir: Vector2i = pos_b - pos_a
	if cells.has(pos_a):
		cells[pos_a].connections[dir] = true
	if cells.has(pos_b):
		cells[pos_b].connections[-dir] = true


func get_connected_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not cells.has(grid_pos):
		return result
	var cell: CellData = cells[grid_pos]
	for dir in cell.connections:
		if cell.connections[dir]:
			result.append(grid_pos + dir)
	return result


## Convert grid position + elevation to world-space Vector3 (center of cell floor).
func grid_to_world(grid_pos: Vector2i, elevation: int = 0) -> Vector3:
	return Vector3(
		grid_pos.x * CELL_SIZE,
		elevation * DESCENT_STEP,
		grid_pos.y * CELL_SIZE
	)


func elevation_to_y(elevation: int) -> float:
	return float(elevation) * DESCENT_STEP


## Get all cells belonging to the same multi-cell chunk.
func get_multi_cell_siblings(grid_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not cells.has(grid_pos):
		return result
	var cell: CellData = cells[grid_pos]
	if cell.multi_cell_id < 0:
		result.append(grid_pos)
		return result
	for pos in cells:
		if cells[pos].multi_cell_id == cell.multi_cell_id:
			result.append(pos)
	return result


## Get the opposite direction.
static func opposite_dir(dir: Vector2i) -> Vector2i:
	return -dir


## Get perpendicular directions (for branching).
static func perpendicular_dirs(dir: Vector2i) -> Array[Vector2i]:
	if dir == NORTH or dir == SOUTH:
		return [EAST, WEST]
	else:
		return [NORTH, SOUTH]


func _update_bounds(pos: Vector2i) -> void:
	grid_min.x = mini(grid_min.x, pos.x)
	grid_min.y = mini(grid_min.y, pos.y)
	grid_max.x = maxi(grid_max.x, pos.x)
	grid_max.y = maxi(grid_max.y, pos.y)
