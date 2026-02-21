class_name ArenaSmall
extends ChunkBase
## Simple box arena: 25 x 25 m, 12 m tall.
## Entry on -Z wall, exit on +Z wall. Floor at y=0.

const SIZE := 25.0
const HEIGHT := 12.0
const WALL_THICKNESS := 0.5


func get_chunk_type() -> String:
	return "arena_small"


func is_arena() -> bool:
	return true


func build() -> void:
	var half := SIZE * 0.5
	var wall_mat := LevelMaterials.arena_wall_mat()

	# Floor & Ceiling
	MeshBuilder.add_box(self, Vector3(SIZE, 0.5, SIZE), Vector3(0, -0.25, 0), LevelMaterials.arena_floor_mat())
	MeshBuilder.add_box(self, Vector3(SIZE, 0.5, SIZE), Vector3(0, HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# -Z wall (entry) with door
	var entry_pivot := Node3D.new()
	entry_pivot.position = Vector3(0, HEIGHT * 0.5, -half)
	add_child(entry_pivot)
	MeshBuilder.add_wall_with_door(entry_pivot, Vector3(SIZE, HEIGHT, WALL_THICKNESS), Vector3.ZERO, wall_mat)

	# +Z wall (exit) with door
	var exit_pivot := Node3D.new()
	exit_pivot.position = Vector3(0, HEIGHT * 0.5, half)
	add_child(exit_pivot)
	MeshBuilder.add_wall_with_door(exit_pivot, Vector3(SIZE, HEIGHT, WALL_THICKNESS), Vector3.ZERO, wall_mat)

	# -X wall (solid)
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, SIZE), Vector3(-half - WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), wall_mat)

	# +X wall (solid)
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, SIZE), Vector3(half + WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), wall_mat)

	# Lights
	var light_color := Color(0.9, 0.85, 0.8)
	MeshBuilder.add_light(self, Vector3(0, HEIGHT - 1, 0), light_color, 4.0, 30.0)
	MeshBuilder.add_light(self, Vector3(-8, HEIGHT - 1.5, -8), light_color, 3.0, 20.0)
	MeshBuilder.add_light(self, Vector3(8, HEIGHT - 1.5, 8), light_color, 3.0, 20.0)

	# Spawn points: 8 ground in a ring (2 waves) + 3 flying
	var spawn_r := SIZE * 0.3
	for i in 8:
		var angle := float(i) / 8.0 * TAU
		var pos := Vector3(cos(angle) * spawn_r, 0, sin(angle) * spawn_r)
		MeshBuilder.add_spawn_point(self, pos, "ground", 0 if i < 4 else 1)

	MeshBuilder.add_spawn_point(self, Vector3(0, 8, 0), "flying", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-5, 7, 4), "flying", 1)
	MeshBuilder.add_spawn_point(self, Vector3(5, 7, -4), "flying", 1)

	# Doorways
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, door_y, half), Vector3.FORWARD, "exit")
