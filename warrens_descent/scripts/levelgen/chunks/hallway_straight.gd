class_name HallwayStraight
extends ChunkBase
## A straight hallway: 10 m wide, 8 m tall, 40 m long.
## Runs along Z axis. Entry at -Z, exit at +Z. Floor at y=0.

const LENGTH := 40.0
const WIDTH := 10.0
const HEIGHT := 8.0
const WALL_THICKNESS := 0.5

const LIGHT_COLOR := Color(0.85, 0.85, 0.95)
const LIGHT_ENERGY := 2.5
const LIGHT_RANGE := 20.0


func get_chunk_type() -> String:
	return "hallway_straight"


func build() -> void:
	var half_len := LENGTH * 0.5
	var half_wid := WIDTH * 0.5

	# Floor
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LENGTH), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())

	# Ceiling
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LENGTH), Vector3(0, HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Left wall
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LENGTH), Vector3(-half_wid - WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())

	# Right wall
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LENGTH), Vector3(half_wid + WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())

	# Lights (4 evenly spaced)
	var light_y := HEIGHT - 1.0
	MeshBuilder.add_light(self, Vector3(0, light_y, -half_len * 0.6), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(0, light_y, -half_len * 0.2), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(0, light_y, half_len * 0.2), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(0, light_y, half_len * 0.6), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)

	# Spawn points (5 scattered)
	MeshBuilder.add_spawn_point(self, Vector3(-2, 0, -half_len * 0.5), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(2, 0, -half_len * 0.25), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-2, 0, half_len * 0.25), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(2, 0, half_len * 0.5), "ground", 0)

	# Doorways
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half_len), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, door_y, half_len), Vector3.FORWARD, "exit")
