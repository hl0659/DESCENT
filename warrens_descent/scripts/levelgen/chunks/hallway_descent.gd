class_name HallwayDescent
extends ChunkBase
## A ramped hallway that descends 5 m over its length.
## 10 m wide, 35 m long total: 5 m flat top, 25 m ramp down, 5 m flat bottom.
## Entry at -Z (top), exit at +Z (bottom). Floor starts at y=RISE.

const TOTAL_LENGTH := 35.0
const WIDTH := 10.0
const BASE_HEIGHT := 8.0
const RISE := 5.0
const WALL_THICKNESS := 0.5

const FLAT_TOP := 5.0
const RAMP_LENGTH := 25.0
const FLAT_BOTTOM := 5.0

const LIGHT_COLOR := Color(0.85, 0.85, 0.95)
const LIGHT_ENERGY := 2.5
const LIGHT_RANGE := 20.0


func get_chunk_type() -> String:
	return "hallway_descent"


func build() -> void:
	var half_wid := WIDTH * 0.5
	var half_len := TOTAL_LENGTH * 0.5

	# Z layout (centered at z=0):
	#   Top flat:    z = -17.5 to z = -12.5  (at y = RISE)
	#   Ramp down:   z = -12.5 to z = +12.5  (from y = RISE to y = 0)
	#   Bottom flat: z = +12.5 to z = +17.5  (at y = 0)

	var top_z_start := -half_len
	var top_z_end := top_z_start + FLAT_TOP
	var ramp_z_start := top_z_end
	var ramp_z_end := ramp_z_start + RAMP_LENGTH
	var bottom_z_start := ramp_z_end
	var bottom_z_end := bottom_z_start + FLAT_BOTTOM

	var ceiling_y := RISE + BASE_HEIGHT  # 13 m

	# ---- Top flat section (entry end) ----
	var top_cz := (top_z_start + top_z_end) * 0.5
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, FLAT_TOP), Vector3(0, RISE - 0.25, top_cz), LevelMaterials.floor_mat())

	# ---- Ramp (descending from -Z to +Z) ----
	var ramp_cz := (ramp_z_start + ramp_z_end) * 0.5
	var ramp_cy := RISE * 0.5
	var ramp_surface_len := sqrt(RAMP_LENGTH * RAMP_LENGTH + RISE * RISE)
	var ramp_angle := rad_to_deg(atan2(RISE, RAMP_LENGTH))
	# Positive X rotation: -Z end goes UP, +Z end goes DOWN (descent)
	MeshBuilder.add_ramp(self, Vector3(WIDTH, 0.5, ramp_surface_len), Vector3(0, ramp_cy, ramp_cz), ramp_angle, LevelMaterials.floor_mat())

	# ---- Bottom flat section (exit end) ----
	var bottom_cz := (bottom_z_start + bottom_z_end) * 0.5
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, FLAT_BOTTOM), Vector3(0, -0.25, bottom_cz), LevelMaterials.floor_mat())

	# ---- Ceiling (single high slab) ----
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, TOTAL_LENGTH), Vector3(0, ceiling_y + 0.25, 0), LevelMaterials.ceiling_mat())

	# ---- Walls (tall enough to cover everything) ----
	var wall_cy := ceiling_y * 0.5
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, ceiling_y, TOTAL_LENGTH), Vector3(-half_wid - WALL_THICKNESS * 0.5, wall_cy, 0), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, ceiling_y, TOTAL_LENGTH), Vector3(half_wid + WALL_THICKNESS * 0.5, wall_cy, 0), LevelMaterials.wall_mat())

	# ---- Lights ----
	MeshBuilder.add_light(self, Vector3(0, ceiling_y - 1, top_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(0, ceiling_y - 1, ramp_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)
	MeshBuilder.add_light(self, Vector3(0, ceiling_y - 1, bottom_cz), LIGHT_COLOR, LIGHT_ENERGY, LIGHT_RANGE)

	# ---- Spawn points ----
	MeshBuilder.add_spawn_point(self, Vector3(0, RISE, top_cz), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, bottom_cz), "ground", 0)

	# ---- Doorways ----
	var top_door_y := RISE + MeshBuilder.DOOR_HEIGHT * 0.5
	var bottom_door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, top_door_y, top_z_start), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, bottom_door_y, bottom_z_end), Vector3.FORWARD, "exit")
