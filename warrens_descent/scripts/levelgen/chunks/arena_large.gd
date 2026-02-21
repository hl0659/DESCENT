class_name ArenaLarge
extends ChunkBase
## Large box arena: 40 x 35 m, 15 m tall.
## Center raised platform for height variety.
## Entry on -Z wall, exit on +Z wall. Floor at y=0.

const WIDTH := 40.0
const DEPTH := 35.0
const HEIGHT := 15.0
const WALL_THICKNESS := 0.5


func get_chunk_type() -> String:
	return "arena_large"


func is_arena() -> bool:
	return true


func build() -> void:
	var half_w := WIDTH * 0.5
	var half_d := DEPTH * 0.5
	var wall_mat := LevelMaterials.arena_wall_mat()

	# Floor & Ceiling
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, DEPTH), Vector3(0, -0.25, 0), LevelMaterials.arena_floor_mat())
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, DEPTH), Vector3(0, HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# -Z wall (entry) with door
	var entry_pivot := Node3D.new()
	entry_pivot.position = Vector3(0, HEIGHT * 0.5, -half_d)
	add_child(entry_pivot)
	MeshBuilder.add_wall_with_door(entry_pivot, Vector3(WIDTH, HEIGHT, WALL_THICKNESS), Vector3.ZERO, wall_mat)

	# +Z wall (exit) with door
	var exit_pivot := Node3D.new()
	exit_pivot.position = Vector3(0, HEIGHT * 0.5, half_d)
	add_child(exit_pivot)
	MeshBuilder.add_wall_with_door(exit_pivot, Vector3(WIDTH, HEIGHT, WALL_THICKNESS), Vector3.ZERO, wall_mat)

	# -X wall (solid)
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, DEPTH), Vector3(-half_w - WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), wall_mat)

	# +X wall (solid)
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, DEPTH), Vector3(half_w + WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), wall_mat)

	# Center raised platform
	MeshBuilder.add_box(self, Vector3(8, 1.5, 8), Vector3(0, 0.75, 0), LevelMaterials.platform_mat())

	# Lights
	var light_color := Color(0.9, 0.85, 0.8)
	MeshBuilder.add_light(self, Vector3(0, HEIGHT - 1, 0), light_color, 5.0, 35.0)
	for i in 4:
		var angle := float(i) / 4.0 * TAU
		MeshBuilder.add_light(self, Vector3(cos(angle) * 12, HEIGHT - 2, sin(angle) * 12), light_color, 3.0, 25.0)

	# Spawn points: 3 waves of ground + flying
	var inner_r := 8.0
	var outer_r := 14.0

	# Wave 0: 5 ground
	for i in 5:
		var angle := float(i) / 5.0 * TAU
		MeshBuilder.add_spawn_point(self, Vector3(cos(angle) * inner_r, 0, sin(angle) * inner_r), "ground", 0)

	# Wave 1: 4 ground
	for i in 4:
		var angle := float(i) / 4.0 * TAU + PI / 4.0
		MeshBuilder.add_spawn_point(self, Vector3(cos(angle) * outer_r, 0, sin(angle) * outer_r), "ground", 1)

	# Wave 2: 4 ground
	for i in 4:
		var angle := float(i) / 4.0 * TAU + PI / 8.0
		MeshBuilder.add_spawn_point(self, Vector3(cos(angle) * inner_r, 0, sin(angle) * inner_r), "ground", 2)

	# Flying spawns
	MeshBuilder.add_spawn_point(self, Vector3(0, 9, 0), "flying", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-8, 8, 6), "flying", 1)
	MeshBuilder.add_spawn_point(self, Vector3(8, 8.5, -6), "flying", 1)
	MeshBuilder.add_spawn_point(self, Vector3(-6, 11, -8), "flying", 2)
	MeshBuilder.add_spawn_point(self, Vector3(6, 10.5, 8), "flying", 2)

	# Doorways
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half_d), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, door_y, half_d), Vector3.FORWARD, "exit")
