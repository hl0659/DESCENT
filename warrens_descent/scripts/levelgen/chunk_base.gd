class_name ChunkBase
extends Node3D
## Base class all level chunks extend. Provides entry/exit marker lookup
## and spawn-point querying so the level generator can stitch chunks
## together and populate enemies without knowing concrete geometry.

func build() -> void:
	pass


func get_entry() -> Marker3D:
	return get_node_or_null("entry") as Marker3D


func get_exit() -> Marker3D:
	return get_node_or_null("exit") as Marker3D


func get_doorways() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and child.get_meta("is_doorway", false):
			result.append(child)
	return result


func get_spawn_points(group_filter: int = -1) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and child.is_in_group("spawn_points"):
			if group_filter < 0 or child.get_meta("spawn_group", 0) == group_filter:
				result.append(child)
	return result


func is_arena() -> bool:
	return false


func get_chunk_type() -> String:
	return "base"
