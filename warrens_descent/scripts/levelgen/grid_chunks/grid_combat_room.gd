class_name GridCombatRoom
extends GridChunkBase


func build_interior() -> void:
	# Floor - arena floor mat signals combat zone
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, -0.25, 0), LevelMaterials.arena_floor_mat())
	# Ceiling
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Cover blocks - asymmetric placement
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(-7, 0.6, -5), LevelMaterials.platform_mat())
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(7, 0.6, 4), LevelMaterials.platform_mat())
	MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(-2, 0.6, 8), LevelMaterials.platform_mat())
	if randf() < 0.5:
		MeshBuilder.add_box(self, Vector3(2.5, 1.2, 2.5), Vector3(5, 0.6, -8), LevelMaterials.platform_mat())

	# Elevated walkway along one wall with ramp
	MeshBuilder.add_box(self, Vector3(3.0, 2.5, 12.0), Vector3(-10, 1.25, 0), LevelMaterials.platform_mat())
	MeshBuilder.add_ramp(self, Vector3(3.0, 0.5, 6.0), Vector3(-10, 0.6, 9.0), -rad_to_deg(atan2(2.5, 6.0)), LevelMaterials.platform_mat())

	# Lights
	MeshBuilder.add_light(self, Vector3(0, CORRIDOR_HEIGHT - 1.0, 0), Color(0.9, 0.85, 0.8), 3.0, 20.0)
	MeshBuilder.add_light(self, Vector3(-8, CORRIDOR_HEIGHT - 1.0, -8), Color(0.9, 0.85, 0.8), 3.0, 15.0)
	MeshBuilder.add_light(self, Vector3(8, CORRIDOR_HEIGHT - 1.0, 8), Color(0.9, 0.85, 0.8), 3.0, 15.0)

	# Spawn points - 5 ground + 2 flying
	MeshBuilder.add_spawn_point(self, Vector3(-6, 0, -6), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(6, 0, -4), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-3, 0, 5), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(8, 0, 7), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(0, 0, 0), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-4, 7.0, -3), "flying", 0)
	MeshBuilder.add_spawn_point(self, Vector3(5, 8.0, 4), "flying", 0)


func get_wall_material() -> StandardMaterial3D:
	return LevelMaterials.arena_wall_mat()


func get_chunk_type() -> String:
	return "combat_room"
