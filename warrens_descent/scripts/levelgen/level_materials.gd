class_name LevelMaterials
## Static class providing all materials from the spec's color palette.
## Each material is created once and cached. Floor materials get a procedural
## grid texture for spatial readability. Wall materials get vertical line texture.

# Palette from spec
const FLOOR_COLOR := Color("2A2A3A")
const WALL_COLOR := Color("3D3D50")
const CEILING_COLOR := Color("1E1E2E")
const TRIM_COLOR := Color("6A5ACD")
const ARENA_FLOOR_COLOR := Color("332233")
const ARENA_WALL_COLOR := Color("443355")
const PLATFORM_COLOR := Color("4A4A5A")
const DOOR_COLOR := Color("8B7500")
const VAULT_DOOR_COLOR := Color("2E8B57")

static var _cache: Dictionary = {}


static func floor_mat() -> StandardMaterial3D:
	return _get_or_create("floor", FLOOR_COLOR, true)


static func wall_mat() -> StandardMaterial3D:
	return _get_or_create("wall", WALL_COLOR, false, true)


static func ceiling_mat() -> StandardMaterial3D:
	return _get_or_create("ceiling", CEILING_COLOR)


static func trim_mat() -> StandardMaterial3D:
	return _get_or_create("trim", TRIM_COLOR)


static func arena_floor_mat() -> StandardMaterial3D:
	return _get_or_create("arena_floor", ARENA_FLOOR_COLOR, true)


static func arena_wall_mat() -> StandardMaterial3D:
	return _get_or_create("arena_wall", ARENA_WALL_COLOR, false, true)


static func platform_mat() -> StandardMaterial3D:
	return _get_or_create("platform", PLATFORM_COLOR)


static func door_mat() -> StandardMaterial3D:
	return _get_or_create("door", DOOR_COLOR)


static func vault_door_mat() -> StandardMaterial3D:
	return _get_or_create("vault_door", VAULT_DOOR_COLOR)


static func _get_or_create(key: String, color: Color, grid: bool = false, vertical_lines: bool = false) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if grid:
		mat.albedo_texture = _make_grid_texture(color)
		mat.uv1_scale = Vector3(0.5, 0.5, 1.0)  # 2m grid squares
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	elif vertical_lines:
		mat.albedo_texture = _make_vline_texture(color)
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)  # 1m vertical lines
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = mat
	return mat


static func _make_grid_texture(base_color: Color) -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Fill with a slightly adjusted base color so the texture blends with albedo
	var fill := Color(base_color.r * 0.9, base_color.g * 0.9, base_color.b * 0.9, 1.0)
	var line_color := Color(base_color.r * 1.4, base_color.g * 1.4, base_color.b * 1.4, 1.0)
	img.fill(fill)
	for i in size:
		if i < 2 or i >= size - 2:
			for j in size:
				img.set_pixel(i, j, line_color)
				img.set_pixel(j, i, line_color)
	return ImageTexture.create_from_image(img)


static func _make_vline_texture(base_color: Color) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var fill := Color(base_color.r * 0.9, base_color.g * 0.9, base_color.b * 0.9, 1.0)
	var line_color := Color(base_color.r * 1.4, base_color.g * 1.4, base_color.b * 1.4, 1.0)
	img.fill(fill)
	for y in size:
		for x in 2:
			img.set_pixel(x, y, line_color)
			img.set_pixel(size - 1 - x, y, line_color)
	return ImageTexture.create_from_image(img)
