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
				var trio := []
				for _i in 3:
					var t := SurfaceTool.new()
					t.begin(Mesh.PRIMITIVE_TRIANGLES)
					trio.append(t)
				tools[ck] = trio
			var st_floor: SurfaceTool = tools[ck][0]
			var st_ceil: SurfaceTool = tools[ck][1]
			var st: SurfaceTool = tools[ck][2]
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
			Meshes.quad(st_floor, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), fcol)
			var ccol: Color = (theme.wall as Color).darkened(0.3)
			Meshes.quad(st_ceil, Vector3(x0, ch, z0), Vector3(x0, ch, z1), Vector3(x1, ch, z1), Vector3(x1, ch, z0), ccol)
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

	var mats := [TexGen.material(TexGen.floor_set(), 0.5, 0.35), TexGen.material(TexGen.ceiling_set(), 0.25, 0.1), TexGen.material(TexGen.wall_set(), 0.15, 0.15)]
	var body := StaticBody3D.new()
	body.name = "WorldBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for ck in tools:
		var mesh := ArrayMesh.new()
		var faces := PackedVector3Array()
		for i in 3:
			var st: SurfaceTool = tools[ck][i]
			var arrays := st.commit_to_arrays()
			if arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
				continue
			var st2 := SurfaceTool.new()
			st2.create_from_arrays(arrays)
			st2.generate_tangents()
			arrays = st2.commit_to_arrays()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[i])
			faces.append_array(arrays[Mesh.ARRAY_VERTEX])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Chunk_%d_%d" % [ck.x, ck.y]
		root.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
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
	_build_platforms(root, layout, theme)
	_build_dressing(root, layout, theme)
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
		var pm := TexGen.material(TexGen.wall_set(), 1.0, 0.25)
		pm.vertex_color_use_as_albedo = false
		pm.albedo_color = col
		pm.uv1_scale = Vector3(size.x * 0.5, size.y * 0.5, 1.0) if p.kind != &"pillar" else Vector3(1, 2, 1)
		mi.material_override = pm
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
			# shadows only in the Quality tier, only for the big rooms' lights
			l.shadow_enabled = is_quality_renderer() and quality >= 1 and room.type in [&"arena", &"uplink", &"boss", &"vault"]
			l.light_volumetric_fog_energy = 1.5
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
	if is_quality_renderer():
		# Forward+ "Quality" tier: screen-space AO/GI, volumetric fog, stronger bloom
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.2
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.2
		env.ssil_enabled = quality >= 1
		env.ssil_intensity = 0.8
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = (theme.light as Color).lerp(theme.fog, 0.5)
		env.volumetric_fog_emission = (theme.fog as Color) * 0.3
		env.volumetric_fog_length = 48.0
		env.fog_enabled = false
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.12
		env.glow_hdr_threshold = 0.9
		env.ambient_light_energy = 1.15
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.1
	we.environment = env
	return we

static func _v3(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)

## Raised daises with ramps (generated by DeckGen as "platforms").
static func _build_platforms(root: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	if not layout.has("platforms") or layout.platforms.is_empty():
		return
	var node := Node3D.new()
	node.name = "Platforms"
	root.add_child(node)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	node.add_child(body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col: Color = (theme.floor as Color).lightened(0.12)
	col.a = 1.0
	for pl in layout.platforms:
		var H: float = pl.height
		var dir := _v3(pl.dir)
		var perp := Vector3(absf(dir.z), 0, absf(dir.x))
		var dais: Array = pl.dais
		var a := DeckGen.cell_to_world(dais[0])
		var b := DeckGen.cell_to_world(dais[dais.size() - 1])
		var center := (a + b) * 0.5 + Vector3.UP * H * 0.5
		var size := perp * C + Vector3(absf(dir.x), 0, absf(dir.z)) * (dais.size() * C) + Vector3.UP * H
		Meshes.box_st(st, center, size, col)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = center
		body.add_child(cs)
		# glowing lip along both long edges of the dais top
		for s in [-1.0, 1.0]:
			var lip_c: Vector3 = Vector3(center.x, H + 0.03, center.z) + perp * (C * 0.5 - 0.08) * s
			var lip_size: Vector3 = Vector3(absf(dir.x), 0, absf(dir.z)) * (dais.size() * C) + perp * 0.12 + Vector3.UP * 0.06
			Meshes.box_st(trim, lip_c, lip_size, theme.trim)
		# ramp wedge: high edge touches the dais, low edge at the far end of the row
		var ramp: Array = pl.ramp
		var hi := DeckGen.cell_to_world(ramp[0]) - dir * C * 0.5
		var lo := DeckGen.cell_to_world(ramp[1]) + dir * C * 0.5
		var P := perp * C * 0.5
		var up := Vector3.UP * H
		var slope_n := (Vector3.UP * (2.0 * C) + dir * H).normalized()
		Meshes.quad_facing(st, hi - P + up, hi + P + up, lo + P, lo - P, col.lightened(0.05), slope_n)
		Meshes.tri_facing(st, hi - P, hi - P + up, lo - P, col.darkened(0.15), -perp)
		Meshes.tri_facing(st, hi + P, hi + P + up, lo + P, col.darkened(0.15), perp)
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([hi - P + up, hi + P + up, hi - P, hi + P, lo - P, lo + P])
		var cs2 := CollisionShape3D.new()
		cs2.shape = shape
		body.add_child(cs2)
		# hazard stripes at the foot of the ramp
		Meshes.box_st(trim, lo - dir * 0.15 + Vector3.UP * 0.02, perp * C + dir * 0.2 + Vector3.UP * 0.04, theme.trim)
	var mi := MeshInstance3D.new()
	st.generate_tangents()
	mi.mesh = st.commit()
	mi.material_override = TexGen.material(TexGen.floor_set(), 0.5, 0.35)
	node.add_child(mi)
	var tm := MeshInstance3D.new()
	tm.mesh = trim.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	tm.material_override = m
	node.add_child(tm)

## Non-structural set dressing: wall pipes in corridors, consoles in rooms.
static func _build_dressing(root: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	var w: int = layout.w
	var h: int = layout.h
	var cells: PackedByteArray = layout.cells
	var ceil_h: PackedFloat32Array = layout.ceil
	var room_id: PackedInt32Array = layout.room_id
	var blocked: PackedByteArray = layout.blocked
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout.seed) * 13 + 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var node := Node3D.new()
	node.name = "Dressing"
	root.add_child(node)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	node.add_child(body)
	var pipe_col: Color = (theme.wall as Color).lerp(theme.trim, 0.15).darkened(0.2)
	pipe_col.a = 1.0
	var con_col: Color = (theme.wall as Color).darkened(0.25)
	con_col.a = 1.0
	var consoles := 0
	for y in h:
		for x in w:
			var k := y * w + x
			if cells[k] != DeckGen.FLOOR:
				continue
			var ch := ceil_h[k]
			var center := DeckGen.cell_to_world(Vector2i(x, y))
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				var solid := nx < 0 or ny < 0 or nx >= w or ny >= h or cells[ny * w + nx] != DeckGen.FLOOR
				if not solid:
					continue
				var out := Vector3(d.x, 0, d.y)
				var along := Vector3(absf(d.y), 0, absf(d.x))
				# pipes: decided per wall *line* so runs are continuous
				var line: int = (x * 2 + d.x) if d.x != 0 else (y * 2 + d.y)
				if room_id[k] < 0 and posmod(line * 7 + (1 if d.x != 0 else 3), 3) == 0:
					var pc := center + out * (C * 0.5 - 0.22) + Vector3.UP * (ch - 0.55)
					Meshes.box_st(st, pc, along * C + Vector3(0.24, 0.24, 0.24) - along * 0.24, pipe_col)
					Meshes.box_st(st, pc - Vector3.UP * 0.36, along * C + Vector3(0.14, 0.14, 0.14) - along * 0.14, pipe_col.darkened(0.15))
				# consoles against room walls
				elif room_id[k] >= 0 and blocked[k] == 0 and consoles < 40:
					var t: StringName = layout.rooms[room_id[k]].type
					if t in [&"hub", &"vault", &"uplink", &"cache", &"start"] and rng.randf() < 0.08 \
							and not DeckGen._near_doorway(cells, room_id, w, h, x, y, room_id[k]):
						consoles += 1
						var cc := center + out * (C * 0.5 - 0.35) + Vector3.UP * 0.55
						var csize := along * 1.6 + out.abs() * 0.7 + Vector3.UP * 1.1
						Meshes.box_st(st, cc, csize, con_col)
						var scr := cc + Vector3.UP * 0.62 - out * 0.05
						Meshes.box_st(glow, scr, along * 1.3 + out.abs() * 0.06 + Vector3.UP * 0.45, (theme.trim as Color).lerp(Color(0.4, 0.9, 1.0), 0.5))
						var cs := CollisionShape3D.new()
						var bs := BoxShape3D.new()
						bs.size = csize
						cs.shape = bs
						cs.position = cc
						body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Meshes.vertex_color_mat()
	node.add_child(mi)
	var gm := MeshInstance3D.new()
	gm.mesh = glow.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	gm.material_override = m
	node.add_child(gm)

static func is_quality_renderer() -> bool:
	return RenderingServer.get_rendering_device() != null
