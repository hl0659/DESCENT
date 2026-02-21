class_name HallwayCurve
extends ChunkBase
## An L-shaped 90-degree turn hallway.
## Leg 1 runs along Z (entry at -Z). Leg 2 runs along +X (exit at +X).
## 10 m wide, 8 m tall, 20 m per leg. Floor at y=0.

const LEG_LENGTH := 20.0
const WIDTH := 10.0
const HEIGHT := 8.0
const WALL_THICKNESS := 0.5

const LIGHT_COLOR := Color(0.85, 0.85, 0.95)
const LIGHT_ENERGY := 2.5
const LIGHT_RANGE := 20.0


func get_chunk_type() -> String:
	return "hallway_curve"


func build() -> void:
	var half_wid := WIDTH * 0.5

	# Leg 1: z = -LEG_LENGTH to z = 0, centered on x = 0
	# Corner: square from (0, 0, 0) to (WIDTH, 0, WIDTH), center at (half_wid, 0, half_wid)
	# Leg 2: along X from half_wid to half_wid + LEG_LENGTH, at z = half_wid

	var leg1_cz := -LEG_LENGTH * 0.5
	var corner_cx := half_wid
	var corner_cz := half_wid
	var leg2_cx := half_wid + LEG_LENGTH * 0.5
	var leg2_cz := half_wid

	# ---- LEG 1 (along Z) ----
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LEG_LENGTH), Vector3(0, -0.25, leg1_cz), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LEG_LENGTH), Vector3(0, HEIGHT + 0.25, leg1_cz), LevelMaterials.ceiling_mat())
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LEG_LENGTH), Vector3(-half_wid - WALL_THICKNESS * 0.5, HEIGHT * 0.5, leg1_cz), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LEG_LENGTH), Vector3(half_wid + WALL_THICKNESS * 0.5, HEIGHT * 0.5, leg1_cz), LevelMaterials.wall_mat())

	# ---- CORNER ----
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, WIDTH), Vector3(corner_cx, -0.25, corner_cz), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, WIDTH), Vector3(corner_cx, HEIGHT + 0.25, corner_cz), LevelMaterials.ceiling_mat())
	# Outer wall continuation (-X side at corner)
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, WIDTH), Vector3(-half_wid - WALL_THICKNESS * 0.5, HEIGHT * 0.5, corner_cz), LevelMaterials.wall_mat())
	# Back wall (+Z side of corner)
	MeshBuilder.add_box(self, Vector3(WIDTH, HEIGHT, WALL_THICKNESS), Vector3(corner_cx, HEIGHT * 0.5, half_wid + WIDTH * 0.5 + WALL_THICKNESS * 0.5), LevelMaterials.wall_mat())

	# ---- LEG 2 (along X) ----
	MeshBuilder.add_box(self, Vector3(LEG_LENGTH, 0.5, WIDTH), Vector3(leg2_cx, -0.25, leg2_cz), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(LEG_LENGTH, 0.5, WIDTH), Vector3(leg2_cx, HEIGHT + 0.25, leg2_cz), LevelMaterials.ceiling_mat())
	MeshBuilder.add_box(self, Vector3(LEG_LENGTH, HEIGHT, WALL_THICKNESS), Vector3(leg2_cx, HEIGHT * 0.5, leg2_cz - half_wid - WALL_THICKNESS * 0.5), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(LEG_LENGTH, HEIGHT, WALL_THICKNESS), Vector3(leg2_cx, HEIGHT * 0.5, leg2_cz + half_wid + WALL_THICKNESS * 0.5), LevelMaterials.wall_mat())

	# ---- Lights ----
	var light_y := HEIGHT - 1.0
	MeshBuilder.add_light(self, Vector3(0, light_y, leg1_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(corner_cx, light_y, corner_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(leg2_cx, light_y, leg2_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)

	# ---- Spawn points ----
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, leg1_cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(corner_cx, 0, corner_cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(leg2_cx, 0, leg2_cz), "ground", 0)

	# ---- Doorways ----
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -LEG_LENGTH), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(half_wid + LEG_LENGTH, door_y, leg2_cz), Vector3.LEFT, "exit")
