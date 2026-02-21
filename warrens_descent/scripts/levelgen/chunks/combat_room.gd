class_name CombatRoom
extends ChunkBase
## Rectangular combat room: 20 x 18 m, 8 m tall.
## A few big cover blocks. Not an arena (doors stay open).
## Entry on -Z, exit on +Z. Floor at y=0.

const WIDTH := 20.0
const DEPTH := 18.0
const HEIGHT := 8.0
const WALL_THICKNESS := 0.5


func get_chunk_type() -> String:
	return "combat_room"


func is_arena() -> bool:
	return false


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

	# 3 cover blocks (waist-height)
	var cover_mat := LevelMaterials.platform_mat()
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(-5, 0.6, -4), cover_mat)
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(5, 0.6, 3), cover_mat)
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(0, 0.6, 6), cover_mat)

	# Lights
	var light_color := Color(0.9, 0.85, 0.8)
	MeshBuilder.add_light(self, Vector3(0, HEIGHT - 1, 0), light_color, 4.0, 24.0)
	MeshBuilder.add_light(self, Vector3(-6, HEIGHT - 1.5, -4), light_color, 2.5, 18.0)
	MeshBuilder.add_light(self, Vector3(6, HEIGHT - 1.5, 4), light_color, 2.5, 18.0)

	# Spawn points
	MeshBuilder.add_spawn_point(self, Vector3(-5, 0, -4), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(5, 0, -4), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-3, 0, 4), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(5, 0, 5), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-3, 6, 0), "flying", 0)
	MeshBuilder.add_spawn_point(self, Vector3(4, 6.5, -2), "flying", 0)

	# Doorways
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half_d), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, door_y, half_d), Vector3.FORWARD, "exit")
