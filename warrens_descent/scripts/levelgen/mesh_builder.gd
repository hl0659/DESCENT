class_name MeshBuilder
## Static utility for building level geometry. Every function adds a
## MeshInstance3D for visuals and a StaticBody3D + CollisionShape3D for
## physics (collision_layer = 1 = environment).
##
## add_box and add_ramp return a Node3D wrapper so callers can rotate
## the visual + collision together with a single transform.

# Door opening dimensions (meters)
const DOOR_WIDTH := 4.0
const DOOR_HEIGHT := 5.0


## Creates a box with mesh + static body under a single Node3D wrapper.
## Returns the wrapper Node3D so rotation is trivial.
static func add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	holder.add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	return holder


## Creates a wall with a doorway opening cut into it.
## The wall runs along the X axis. door_x_offset is the local X position
## of the door center relative to the wall center. The opening is
## DOOR_WIDTH x DOOR_HEIGHT. This builds three box segments:
##   - left section (left of the door)
##   - right section (right of the door)
##   - top section (lintel above the door)
## Returns the parent Node3D holding all three segments.
static func add_wall_with_door(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, door_x_offset: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)

	var wall_width: float = size.x
	var wall_height: float = size.y
	var wall_depth: float = size.z

	# Door edges in local X space (centered on wall)
	var door_left: float = door_x_offset - DOOR_WIDTH * 0.5
	var door_right: float = door_x_offset + DOOR_WIDTH * 0.5

	var half_wall: float = wall_width * 0.5

	# Left section: from -half_wall to door_left
	var left_width: float = door_left + half_wall
	if left_width > 0.01:
		var left_size := Vector3(left_width, wall_height, wall_depth)
		var left_x: float = -half_wall + left_width * 0.5
		_add_box_local(holder, left_size, Vector3(left_x, 0.0, 0.0), mat)

	# Right section: from door_right to +half_wall
	var right_width: float = half_wall - door_right
	if right_width > 0.01:
		var right_size := Vector3(right_width, wall_height, wall_depth)
		var right_x: float = door_right + right_width * 0.5
		_add_box_local(holder, right_size, Vector3(right_x, 0.0, 0.0), mat)

	# Lintel above the door
	var lintel_height: float = wall_height - DOOR_HEIGHT
	if lintel_height > 0.01:
		var lintel_size := Vector3(DOOR_WIDTH, lintel_height, wall_depth)
		# Wall center Y is 0. Door spans from bottom (-wall_height/2) up to
		# (-wall_height/2 + DOOR_HEIGHT). Lintel fills the remainder above.
		var door_top: float = -wall_height * 0.5 + DOOR_HEIGHT
		var lintel_y: float = (door_top + wall_height * 0.5) * 0.5
		_add_box_local(holder, lintel_size, Vector3(door_x_offset, lintel_y, 0.0), mat)

	return holder


## Creates a thin accent trim strip. If vertical is true, the strip runs
## along Y; otherwise it runs along X.
static func add_trim(parent: Node3D, length: float, pos: Vector3, mat: StandardMaterial3D, vertical: bool = false) -> Node3D:
	var size: Vector3
	if vertical:
		size = Vector3(0.05, length, 0.05)
	else:
		size = Vector3(length, 0.05, 0.05)
	return add_box(parent, size, pos, mat)


## Creates an angled ramp. The box is rotated by angle_deg around the
## local X axis (pitch). Uses the Node3D wrapper so callers can apply
## additional rotation (e.g. yaw) after the fact.
static func add_ramp(parent: Node3D, size: Vector3, pos: Vector3, angle_deg: float, mat: StandardMaterial3D) -> Node3D:
	var holder := add_box(parent, size, pos, mat)
	holder.rotation_degrees.x = angle_deg
	return holder


## Adds an OmniLight3D to the scene.
static func add_light(parent: Node3D, pos: Vector3, color: Color = Color.WHITE, energy: float = 1.0, light_range: float = 10.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	return light


## Adds a Marker3D used as an enemy spawn point with metadata.
static func add_spawn_point(parent: Node3D, pos: Vector3, enemy_type: String = "ground", spawn_group: int = 0) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "SpawnPoint"
	marker.position = pos
	marker.set_meta("enemy_type", enemy_type)
	marker.set_meta("spawn_group", spawn_group)
	marker.add_to_group("spawn_points")
	parent.add_child(marker)
	return marker


## Adds a Marker3D used as a doorway connection point for chunk stitching.
## facing is a Vector3 indicating the direction the doorway opens toward.
static func add_doorway(parent: Node3D, pos: Vector3, facing: Vector3, doorway_name: String = "doorway") -> Marker3D:
	var marker := Marker3D.new()
	marker.name = doorway_name
	marker.position = pos
	marker.set_meta("facing", facing)
	marker.set_meta("is_doorway", true)
	parent.add_child(marker)
	return marker


## Creates a platform (floor slab with collision). The platform is a box
## centered at pos, with given width/depth and a fixed 0.5m thickness.
static func add_platform(parent: Node3D, width: float, depth: float, pos: Vector3, mat: StandardMaterial3D) -> Node3D:
	return add_box(parent, Vector3(width, 0.5, depth), pos, mat)


## Creates a cylindrical column with mesh + static body collision.
static func add_cylinder_column(parent: Node3D, radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh_inst.mesh = cyl
	mesh_inst.material_override = mat
	holder.add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)

	return holder


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Same as add_box but for building sub-parts inside an existing holder.
## Positions are local to the holder.
static func _add_box_local(holder: Node3D, size: Vector3, local_pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = local_pos
	holder.add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = local_pos
	holder.add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
