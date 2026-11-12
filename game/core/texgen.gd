class_name TexGen
## Procedural PBR texture sets generated at load time (no image files): sci-fi wall panels with
## grooves and rivets, floor grating, and ceiling panels. Each set = {albedo, normal, roughness}.
## Built with native Image ops + FastNoiseLite so it takes well under a second.

const SIZE := 512
static var _cache: Dictionary = {}

static func _noise_img(seed_value: int, freq: float, octaves: int = 4) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(SIZE, SIZE)
	img.convert(Image.FORMAT_RGBA8)
	return img

## Height map: noise base + panel grooves + rivets. `cells` panels per side.
static func _panel_height(seed_value: int, cells: int, groove: int, rivets: bool) -> Image:
	var h := _noise_img(seed_value, 0.02, 3)
	# compress noise into a subtle 0.55..0.75 band so grooves read clearly
	h.adjust_bcs(0.7, 0.05, 1.0)
	var step := SIZE / cells
	var dark := Color(0.08, 0.08, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in cells:
		var p := i * step
		h.fill_rect(Rect2i(p, 0, groove, SIZE), dark)
		h.fill_rect(Rect2i(0, p, SIZE, groove), dark)
		# bevel highlight next to each groove
		h.fill_rect(Rect2i(p + groove, 0, 2, SIZE), Color(0.8, 0.8, 0.8))
		h.fill_rect(Rect2i(0, p + groove, SIZE, 2), Color(0.8, 0.8, 0.8))
	# some panels split in half, some get an inset plate
	for y in cells:
		for x in cells:
			var ox := x * step
			var oy := y * step
			var roll := rng.randf()
			if roll < 0.25:
				h.fill_rect(Rect2i(ox + step / 2, oy, groove / 2 + 1, step), dark)
			elif roll < 0.45:
				var m := step / 5
				h.fill_rect(Rect2i(ox + m, oy + m, step - 2 * m, step - 2 * m), Color(0.82, 0.82, 0.82))
				h.fill_rect(Rect2i(ox + m, oy + m, step - 2 * m, 2), Color(0.3, 0.3, 0.3))
				h.fill_rect(Rect2i(ox + m, oy + m, 2, step - 2 * m), Color(0.3, 0.3, 0.3))
			if rivets:
				for c in [Vector2i(8, 8), Vector2i(step - 14, 8), Vector2i(8, step - 14), Vector2i(step - 14, step - 14)]:
					h.fill_rect(Rect2i(ox + c.x, oy + c.y, 6, 6), Color(0.95, 0.95, 0.95))
	return h

static func _grating_height(seed_value: int) -> Image:
	var h := _noise_img(seed_value, 0.03, 2)
	h.adjust_bcs(0.65, 0.05, 1.0)
	var bars := 32
	var step := SIZE / bars
	for i in bars:
		h.fill_rect(Rect2i(i * step, 0, 4, SIZE), Color(0.05, 0.05, 0.05))
	for j in 4:
		h.fill_rect(Rect2i(0, j * (SIZE / 4), SIZE, 10), Color(0.9, 0.9, 0.9))
	return h

static func _make_set(height: Image, albedo_bright: float, rough_bright: float, normal_strength: float, seed_value: int) -> Dictionary:
	var albedo := height.duplicate() as Image
	albedo.adjust_bcs(albedo_bright, 0.7, 1.0)
	var rough := _noise_img(seed_value + 99, 0.01, 3)
	rough.adjust_bcs(rough_bright, 0.25, 1.0)
	var normal := height.duplicate() as Image
	normal.bump_map_to_normal_map(normal_strength)
	for img in [albedo, rough, normal]:
		img.generate_mipmaps()
	return {
		"albedo": ImageTexture.create_from_image(albedo),
		"normal": ImageTexture.create_from_image(normal),
		"roughness": ImageTexture.create_from_image(rough),
	}

static func wall_set() -> Dictionary:
	if not _cache.has("wall"):
		_cache["wall"] = _make_set(_panel_height(11, 4, 4, true), 1.45, 1.25, 5.0, 11)
	return _cache["wall"]

static func floor_set() -> Dictionary:
	if not _cache.has("floor"):
		_cache["floor"] = _make_set(_grating_height(23), 1.4, 1.4, 3.0, 23)
	return _cache["floor"]

static func ceiling_set() -> Dictionary:
	if not _cache.has("ceil"):
		_cache["ceil"] = _make_set(_panel_height(37, 2, 8, false), 1.4, 1.45, 4.0, 37)
	return _cache["ceil"]

## Vertex-coloured, world-triplanar PBR material from a generated set.
static func material(set: Dictionary, uv_scale: float, metallic: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = set.albedo
	m.normal_enabled = true
	m.normal_texture = set.normal
	m.normal_scale = 1.0
	m.roughness_texture = set.roughness
	m.roughness = 1.0
	m.metallic = metallic
	m.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
