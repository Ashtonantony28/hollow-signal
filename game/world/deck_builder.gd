class_name DeckBuilder
## Turns a DeckGen layout into scene nodes: chunked flat-shaded meshes, trimesh colliders,
## props, lights and the environment (DESIGN.md §6.2 steps 6–8).

const CHUNK := 8
const C := DeckGen.CELL
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func build(layout: Dictionary, quality: int = 1) -> Node3D:
	var root := Node3D.new()
	root.name = "Deck"
	var theme: Dictionary = ThemeData.deck(layout.deck)
	var w: int = layout.w
	var h: int = layout.h
	var cells: PackedByteArray = layout.cells
	var ceil_h: PackedFloat32Array = layout.ceil
	var room_id: PackedInt32Array = layout.room_id
	var noise := RandomNumberGenerator.new()
	noise.seed = int(layout.seed) * 31 + 7

	var tools := {}   # chunk key -> SurfaceTool (geometry)
	var trims := {}   # chunk key -> SurfaceTool (emissive strips)

	for y in h:
		for x in w:
			var k := y * w + x
			if cells[k] != DeckGen.FLOOR:
				continue
			var ck := Vector2i(x / CHUNK, y / CHUNK)
			if not tools.has(ck):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[ck] = st
			var st: SurfaceTool = tools[ck]
			var x0 := x * C
			var x1 := x0 + C
			var z0 := y * C
			var z1 := z0 + C
			var ch := ceil_h[k]
			var is_corr := room_id[k] < 0
			var shade := 0.92 + noise.randf() * 0.12
			var fcol: Color = theme.floor * (0.8 if is_corr else 1.0) * shade
			if (x + y) % 2 == 0:
				fcol = fcol.lightened(0.04)
			fcol.a = 1.0
			Meshes.quad(st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), fcol)
			var ccol: Color = (theme.wall as Color).darkened(0.3)
			Meshes.quad(st, Vector3(x0, ch, z0), Vector3(x0, ch, z1), Vector3(x1, ch, z1), Vector3(x1, ch, z0), ccol)
			if is_corr and (x + y) % 3 == 0:
				if not trims.has(ck):
					var tsc := SurfaceTool.new()
					tsc.begin(Mesh.PRIMITIVE_TRIANGLES)
					trims[ck] = tsc
				var lc: Color = theme.light
				var y2 := ch - 0.02
				Meshes.quad(trims[ck], Vector3(x0 + 1.4, y2, z0 + 1.4), Vector3(x0 + 1.4, y2, z1 - 1.4), Vector3(x1 - 1.4, y2, z1 - 1.4), Vector3(x1 - 1.4, y2, z0 + 1.4), lc)
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				var nsolid := nx < 0 or ny < 0 or nx >= w or ny >= h or cells[ny * w + nx] != DeckGen.FLOOR
				var lo := 0.0
				if not nsolid:
					var nh := ceil_h[ny * w + nx]
					if nh >= ch:
						continue
					lo = nh
				var wcol: Color = (theme.wall as Color) * (0.9 + noise.randf() * 0.15)
				wcol.a = 1.0
				_wall(st, x0, x1, z0, z1, d, lo, ch, wcol, theme)
				# emissive trim strips on solid walls inside rooms
				if nsolid and not is_corr and noise.randf() < 0.35:
					if not trims.has(ck):
						var ts := SurfaceTool.new()
						ts.begin(Mesh.PRIMITIVE_TRIANGLES)
						trims[ck] = ts
					_strip(trims[ck], x0, x1, z0, z1, d, 3.0, theme.trim)
				elif nsolid and is_corr and noise.randf() < 0.2:
					if not trims.has(ck):
						var ts2 := SurfaceTool.new()
						ts2.begin(Mesh.PRIMITIVE_TRIANGLES)
						trims[ck] = ts2
					_strip(trims[ck], x0, x1, z0, z1, d, 0.25, theme.trim)

	var geo_mat := Meshes.vertex_color_mat()
	var body := StaticBody3D.new()
	body.name = "WorldBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for ck in tools:
		var st: SurfaceTool = tools[ck]
		var arrays := st.commit_to_arrays()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = geo_mat
		mi.name = "Chunk_%d_%d" % [ck.x, ck.y]
		root.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(arrays[Mesh.ARRAY_VERTEX])
		cs.shape = shape
		body.add_child(cs)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim_mat.vertex_color_use_as_albedo = true
	for ck in trims:
		var tm := MeshInstance3D.new()
		tm.mesh = (trims[ck] as SurfaceTool).commit()
		tm.material_override = trim_mat
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tm)

	_build_props(root, layout, theme)
	_build_lights(root, layout, theme, quality)
	root.add_child(make_environment(theme, quality))
	return root

static func _wall(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, d: Vector2i,
		lo: float, hi: float, col: Color, theme: Dictionary) -> void:
	# split into a darker skirting band + main wall
	var skirt := minf(lo + 0.5, hi) if lo == 0.0 else lo
	if lo == 0.0:
		_wall_quad(st, x0, x1, z0, z1, d, 0.0, skirt, (theme.wall as Color).darkened(0.5))
	_wall_quad(st, x0, x1, z0, z1, d, skirt, hi, col)

static func _wall_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, d: Vector2i,
		lo: float, hi: float, col: Color) -> void:
	if hi <= lo:
		return
	var a: Vector3; var b: Vector3; var c: Vector3; var e: Vector3
	var inward := Vector3(-d.x, 0, -d.y)
	match d:
		Vector2i(1, 0):
			a = Vector3(x1, lo, z0); b = Vector3(x1, hi, z0); c = Vector3(x1, hi, z1); e = Vector3(x1, lo, z1)
		Vector2i(-1, 0):
			a = Vector3(x0, lo, z0); b = Vector3(x0, hi, z0); c = Vector3(x0, hi, z1); e = Vector3(x0, lo, z1)
		Vector2i(0, 1):
			a = Vector3(x0, lo, z1); b = Vector3(x0, hi, z1); c = Vector3(x1, hi, z1); e = Vector3(x1, lo, z1)
		_:
			a = Vector3(x0, lo, z0); b = Vector3(x0, hi, z0); c = Vector3(x1, hi, z0); e = Vector3(x1, lo, z0)
	var n := (c - a).cross(b - a)
	if n.dot(inward) < 0.0:
		Meshes.quad(st, a, e, c, b, col)
	else:
		Meshes.quad(st, a, b, c, e, col)

static func _strip(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, d: Vector2i, y: float, col: Color) -> void:
	var inset := 0.03
	var xa := x0 + 0.6; var xb := x1 - 0.6; var za := z0 + 0.6; var zb := z1 - 0.6
	match d:
		Vector2i(1, 0): xa = x1 - inset; xb = x1 - inset
		Vector2i(-1, 0): xa = x0 + inset; xb = x0 + inset
		Vector2i(0, 1): za = z1 - inset; zb = z1 - inset
		_: za = z0 + inset; zb = z0 + inset
	_wall_quad(st, minf(xa, xb), maxf(xa, xb), minf(za, zb), maxf(za, zb), d, y, y + 0.12, col)

static func _build_props(root: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	var props_node := Node3D.new()
	props_node.name = "Props"
	root.add_child(props_node)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	props_node.add_child(body)
	var crate_col: Color = (theme.wall as Color).lightened(0.12)
	for p in layout.props:
		var c: Vector2i = p.cell
		var base := DeckGen.cell_to_world(c)
		var size := Vector3(1.8, 1.3, 1.8)
		var col := crate_col
		match p.kind:
			&"barrier":
				size = Vector3(3.2, 1.15, 0.6) if p.rot % 2 == 0 else Vector3(0.6, 1.15, 3.2)
				col = (theme.floor as Color).lightened(0.2)
			&"pillar":
				var ch: float = layout.ceil[c.y * layout.w + c.x]
				size = Vector3(1.6, ch, 1.6)
				col = (theme.wall as Color).darkened(0.1)
		var mi := Meshes.box(size, col)
		mi.position = base + Vector3(0, size.y / 2.0, 0)
		props_node.add_child(mi)
		if p.kind == &"crate":
			var band := Meshes.box(Vector3(size.x + 0.02, 0.12, size.z + 0.02), theme.trim, 1.5)
			band.position = mi.position + Vector3(0, 0.25, 0)
			props_node.add_child(band)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = mi.position
		body.add_child(cs)

static func _build_lights(root: Node3D, layout: Dictionary, theme: Dictionary, quality: int) -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	for room in layout.rooms:
		var r: Rect2i = room.rect
		var ch: float = room.ceil
		var span := maxf(r.size.x, r.size.y) * C
		var positions: Array[Vector3] = []
		if r.size.x >= 7 or r.size.y >= 7:
			var off := Vector3((r.size.x / 4.0) * C, 0, (r.size.y / 4.0) * C)
			var cpos := DeckGen.cell_to_world(room.center, ch - 1.2)
			positions.append(cpos - off * Vector3(1, 0, 1))
			positions.append(cpos + off * Vector3(1, 0, 1))
		else:
			positions.append(DeckGen.cell_to_world(room.center, ch - 1.2))
		for pos in positions:
			var l := OmniLight3D.new()
			l.position = pos
			l.light_color = theme.light
			l.light_energy = 2.2
			l.omni_range = span * (0.85 if positions.size() == 1 else 0.7) + 6.0
			l.omni_attenuation = 0.8
			l.shadow_enabled = false
			lights.add_child(l)
			# visible fixture
			var fix := Meshes.box(Vector3(1.4, 0.15, 1.4), theme.light, 3.0)
			fix.position = Vector3(pos.x, ch - 0.08, pos.z)
			lights.add_child(fix)

static func make_environment(theme: Dictionary, quality: int) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = theme.fog
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme.ambient
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.fog_enabled = true
	env.fog_light_color = theme.fog
	env.fog_density = 0.012
	env.glow_enabled = quality >= 1
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	we.environment = env
	return we
