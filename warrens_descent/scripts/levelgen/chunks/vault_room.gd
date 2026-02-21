class_name VaultRoom
extends ChunkBase
## Small vault room: 10 x 12 m, 6 m tall.
## Dead end -- entry only, no exit. Gold reward cube at back.
## Floor at y=0.

const ROOM_WIDTH := 10.0
const ROOM_DEPTH := 12.0
const HEIGHT := 6.0
const WALL_THICKNESS := 0.5


func get_chunk_type() -> String:
	return "vault_room"


func build() -> void:
	var half_w := ROOM_WIDTH * 0.5
	var half_d := ROOM_DEPTH * 0.5

	# Floor & Ceiling
	MeshBuilder.add_box(self, Vector3(ROOM_WIDTH, 0.5, ROOM_DEPTH), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(ROOM_WIDTH, 0.5, ROOM_DEPTH), Vector3(0, HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Walls
	# -Z wall (entry) with door
	var entry_pivot := Node3D.new()
	entry_pivot.position = Vector3(0, HEIGHT * 0.5, -half_d)
	add_child(entry_pivot)
	MeshBuilder.add_wall_with_door(entry_pivot, Vector3(ROOM_WIDTH, HEIGHT, WALL_THICKNESS), Vector3.ZERO, LevelMaterials.wall_mat())

	# +Z wall (back, solid)
	MeshBuilder.add_box(self, Vector3(ROOM_WIDTH, HEIGHT, WALL_THICKNESS), Vector3(0, HEIGHT * 0.5, half_d + WALL_THICKNESS * 0.5), LevelMaterials.wall_mat())

	# -X wall
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, ROOM_DEPTH), Vector3(-half_w - WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())

	# +X wall
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, ROOM_DEPTH), Vector3(half_w + WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())

	# Green entrance light
	MeshBuilder.add_light(self, Vector3(0, HEIGHT - 1, -half_d + 1), Color(0.2, 0.7, 0.3), 1.5, 8.0)

	# Interior light
	MeshBuilder.add_light(self, Vector3(0, HEIGHT - 1, 0), Color(0.7, 0.65, 0.5), 1.0, 10.0)

	# Gold reward cube near back wall
	var cube_z := half_d - 1.5
	_add_reward_cube(Vector3(0, 0.4, cube_z))

	# Reward marker
	var reward_marker := Marker3D.new()
	reward_marker.name = "vault_reward"
	reward_marker.position = Vector3(0, 0.4, cube_z)
	reward_marker.set_meta("pickup_type", "vault_reward")
	reward_marker.add_to_group("pickup_spots")
	add_child(reward_marker)

	# Aura light above cube
	MeshBuilder.add_light(self, Vector3(0, 1.9, cube_z), Color.WHITE, 2.0, 5.0)

	# Enemy spawn points
	MeshBuilder.add_spawn_point(self, Vector3(-3, 0, -2), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(3, 0, -2), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-3, 0, 3), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(3, 0, 3), "ground", 0)

	# Doorway (entry only)
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half_d), Vector3.BACK, "entry")


func _add_reward_cube(pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RewardCube"
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mesh_inst.mesh = box
	mesh_inst.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FFD700")
	mat.emission_enabled = true
	mat.emission = Color("FFD700")
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat

	add_child(mesh_inst)
