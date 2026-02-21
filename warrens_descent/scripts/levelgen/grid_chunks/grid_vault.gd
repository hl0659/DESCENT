class_name GridVault
extends GridChunkBase


func build_interior() -> void:
	# Floor & ceiling - lower ceiling for claustrophobic feel
	var vault_height := 8.0
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, vault_height + 0.25, 0), LevelMaterials.ceiling_mat())

	# Find the entry direction (the one connection this vault has)
	var entry_dir := Vector2i.ZERO
	for dir in cell_data.connections:
		if cell_data.connections[dir]:
			entry_dir = dir
			break

	var entry_vec := Vector3(entry_dir.x, 0, entry_dir.y).normalized()

	# Green entrance light near the entry side
	MeshBuilder.add_light(self, -entry_vec * 10.0 + Vector3(0, vault_height - 1.0, 0), Color(0.2, 0.7, 0.3), 3.0, 15.0)

	# Warm gold interior light
	MeshBuilder.add_light(self, Vector3(0, vault_height - 1.0, 0), Color(0.7, 0.65, 0.5), 2.5, 12.0)

	# Gold reward cube near the back wall (opposite entry)
	var reward_pos := entry_vec * 10.0 + Vector3(0, 0.4, 0)
	var reward_mat := StandardMaterial3D.new()
	reward_mat.albedo_color = Color(0.85, 0.7, 0.2)
	reward_mat.emission_enabled = true
	reward_mat.emission = Color(0.85, 0.7, 0.2)
	reward_mat.emission_energy_multiplier = 2.0
	MeshBuilder.add_box(self, Vector3(0.8, 0.8, 0.8), reward_pos, reward_mat)
	# Aura light on the reward
	MeshBuilder.add_light(self, reward_pos + Vector3(0, 1.0, 0), Color(0.85, 0.7, 0.2), 2.0, 8.0)

	# Pickup spot marker for the reward
	var reward_spot := Marker3D.new()
	reward_spot.position = reward_pos
	reward_spot.set_meta("pickup_type", "vault_reward")
	reward_spot.add_to_group("pickup_spots")
	add_child(reward_spot)

	# Spawn points - 4 ground enemies guarding the vault
	MeshBuilder.add_spawn_point(self, Vector3(-5, 0, -3), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(5, 0, -3), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(-5, 0, 5), "ground", 0)
	MeshBuilder.add_spawn_point(self, Vector3(5, 0, 5), "ground", 0)


func get_wall_height() -> float:
	return 8.0


func get_chunk_type() -> String:
	return "vault"
