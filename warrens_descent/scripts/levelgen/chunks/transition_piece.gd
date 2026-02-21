class_name TransitionPiece
extends ChunkBase
## Short transition corridor: 10 m wide, 8 m tall, 8 m long.
## No enemies. Pickup spots for health/ammo/pneuma. Floor at y=0.

const LENGTH := 8.0
const WIDTH := 10.0
const HEIGHT := 8.0
const WALL_THICKNESS := 0.5


func get_chunk_type() -> String:
	return "transition"


func build() -> void:
	var half_len := LENGTH * 0.5
	var half_wid := WIDTH * 0.5

	# Floor
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LENGTH), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())

	# Ceiling
	MeshBuilder.add_box(self, Vector3(WIDTH, 0.5, LENGTH), Vector3(0, HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Walls
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LENGTH), Vector3(-half_wid - WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())
	MeshBuilder.add_box(self, Vector3(WALL_THICKNESS, HEIGHT, LENGTH), Vector3(half_wid + WALL_THICKNESS * 0.5, HEIGHT * 0.5, 0), LevelMaterials.wall_mat())

	# Accent lights at both ends
	var light_y := HEIGHT - 1.0
	MeshBuilder.add_light(self, Vector3(0, light_y, -half_len + 1), Color(0.9, 0.8, 0.5), 3.0, 16.0)
	MeshBuilder.add_light(self, Vector3(0, light_y, half_len - 1), Color(0.9, 0.8, 0.5), 3.0, 16.0)

	# Pickup spots
	_add_pickup_spot("pickup_01", Vector3(-2, 0.5, 0), "health")
	_add_pickup_spot("pickup_02", Vector3(2, 0.5, 0), "ammo")
	_add_pickup_spot("pickup_03", Vector3(0, 0.5, 1), "pneuma")

	# Doorways
	var door_y := MeshBuilder.DOOR_HEIGHT * 0.5
	MeshBuilder.add_doorway(self, Vector3(0, door_y, -half_len), Vector3.BACK, "entry")
	MeshBuilder.add_doorway(self, Vector3(0, door_y, half_len), Vector3.FORWARD, "exit")


func _add_pickup_spot(spot_name: String, pos: Vector3, pickup_type: String) -> void:
	var marker := Marker3D.new()
	marker.name = spot_name
	marker.position = pos
	marker.set_meta("pickup_type", pickup_type)
	marker.add_to_group("pickup_spots")
	add_child(marker)
