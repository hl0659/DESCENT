class_name GridTransition
extends GridChunkBase


func build_interior() -> void:
	# Floor & ceiling
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, -0.25, 0), LevelMaterials.floor_mat())
	MeshBuilder.add_box(self, Vector3(CELL_SIZE, 0.5, CELL_SIZE), Vector3(0, CORRIDOR_HEIGHT + 0.25, 0), LevelMaterials.ceiling_mat())

	# Warm amber lights - signals safe zone
	MeshBuilder.add_light(self, Vector3(-5, CORRIDOR_HEIGHT - 1.0, 0), Color(0.9, 0.8, 0.5), 3.0, 16.0)
	MeshBuilder.add_light(self, Vector3(5, CORRIDOR_HEIGHT - 1.0, 0), Color(0.9, 0.8, 0.5), 3.0, 16.0)

	# Pickup spots
	var health_spot := Marker3D.new()
	health_spot.position = Vector3(-4, 0.5, 0)
	health_spot.set_meta("pickup_type", "health")
	health_spot.add_to_group("pickup_spots")
	add_child(health_spot)

	var ammo_spot := Marker3D.new()
	ammo_spot.position = Vector3(4, 0.5, 0)
	ammo_spot.set_meta("pickup_type", "ammo")
	ammo_spot.add_to_group("pickup_spots")
	add_child(ammo_spot)

	var pneuma_spot := Marker3D.new()
	pneuma_spot.position = Vector3(0, 0.5, 2)
	pneuma_spot.set_meta("pickup_type", "pneuma")
	pneuma_spot.add_to_group("pickup_spots")
	add_child(pneuma_spot)


func get_chunk_type() -> String:
	return "transition"
