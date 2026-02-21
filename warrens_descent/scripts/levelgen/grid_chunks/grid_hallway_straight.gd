class_name GridHallwayStraight
extends GridChunkBase


func build_interior() -> void:
	# Floor
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())

	# Ceiling
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Movement geometry variants
	var roll := randf()
	if roll < 0.4:
		# Variant A: Small raised platform
		MeshBuilder.add_platform(self, 4.0, 4.0, Vector3(randf_range(-6, 6), 0.4, randf_range(-6, 6)), LevelMaterials.platform_mat())
	elif roll < 0.7:
		# Variant B: Low ramp along one wall
		MeshBuilder.add_ramp(self, Vector3(6.0, 0.5, 8.0), Vector3(-10, 0.75, 0), -rad_to_deg(atan2(1.5, 8.0)), LevelMaterials.platform_mat())

	# Lights
	for i in 3:
		var z_pos := -10.0 + float(i) * 10.0
		MeshBuilder.add_light(self, Vector3(0, CORRIDOR_HEIGHT - 1.0, z_pos), Color(0.85, 0.85, 0.95), 2.5, 20.0)

	# Spawn points - 4 ground enemies
	MeshBuilder.add_spawn_point(self, Vector3(-6, 0, -6), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(6, 0, -6), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-6, 0, 6), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(6, 0, 6), "ground", 0)


func get_chunk_type() -> String:
	return "hallway_straight"
