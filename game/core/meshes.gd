class_name Meshes
## Small library for building flat-shaded meshes and materials in code.

static var _mat_cache: Dictionary = {}

static func mat(color: Color, emission: float = 0.0, unshaded: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), emission, unshaded, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 0.55
	m.metallic = 0.3
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m

static func vertex_color_mat() -> StandardMaterial3D:
	if _mat_cache.has("vc"):
		return _mat_cache["vc"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	_mat_cache["vc"] = m
	return m

static func box(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = bevel_box(size)
	mi.material_override = mat(color, emission)
	return mi

static var _bevel_cache := {}

## Chamfered box (6 faces, 12 edge bevels, 8 corner tris) with flat normals, so edges catch
## highlights instead of reading as flat grey blocks. Cached per size.
static func bevel_box(size: Vector3, bevel: float = -1.0) -> ArrayMesh:
	if bevel < 0.0:
		bevel = minf(minf(size.x, size.y), size.z) * 0.14
	var key := "%s|%.4f" % [size, bevel]
	if _bevel_cache.has(key):
		return _bevel_cache[key]
	var h := size * 0.5
	var b := minf(bevel, minf(minf(h.x, h.y), h.z) * 0.9)
	var inner := h - Vector3(b, b, b)
	# pt(signs, axis): corner point pushed fully out along `axis`
	var pt := func(sx: float, sy: float, sz: float, axis: int) -> Vector3:
		var v := Vector3(sx * inner.x, sy * inner.y, sz * inner.z)
		if axis == 0: v.x = sx * h.x
		elif axis == 1: v.y = sy * h.y
		else: v.z = sz * h.z
		return v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Color.WHITE
	var q := func(a: Vector3, bb: Vector3, c: Vector3, d: Vector3) -> void:
		var f := (a + bb + c + d) * 0.25
		tri_facing(st, a, bb, c, w, f)
		tri_facing(st, a, c, d, w, f)
	var S := [-1.0, 1.0]
	# main faces
	for s in S:
		q.call(pt.call(s, -1, -1, 0), pt.call(s, 1, -1, 0), pt.call(s, 1, 1, 0), pt.call(s, -1, 1, 0))
		q.call(pt.call(-1, s, -1, 1), pt.call(1, s, -1, 1), pt.call(1, s, 1, 1), pt.call(-1, s, 1, 1))
		q.call(pt.call(-1, -1, s, 2), pt.call(1, -1, s, 2), pt.call(1, 1, s, 2), pt.call(-1, 1, s, 2))
	# edge bevels
	for s1 in S:
		for s2 in S:
			# X-Y edges (run along z)
			q.call(pt.call(s1, s2, -1, 0), pt.call(s1, s2, 1, 0), pt.call(s1, s2, 1, 1), pt.call(s1, s2, -1, 1))
			# X-Z edges (run along y)
			q.call(pt.call(s1, -1, s2, 0), pt.call(s1, 1, s2, 0), pt.call(s1, 1, s2, 2), pt.call(s1, -1, s2, 2))
			# Y-Z edges (run along x)
			q.call(pt.call(-1, s1, s2, 1), pt.call(1, s1, s2, 1), pt.call(1, s1, s2, 2), pt.call(-1, s1, s2, 2))
	# corners
	for sx in S:
		for sy in S:
			for sz in S:
				var a: Vector3 = pt.call(sx, sy, sz, 0)
				var c2: Vector3 = pt.call(sx, sy, sz, 1)
				var d: Vector3 = pt.call(sx, sy, sz, 2)
				tri_facing(st, a, c2, d, w, (a + c2 + d) / 3.0)
	var m := st.commit()
	_bevel_cache[key] = m
	return m

static func cyl(radius: float, height: float, color: Color, emission: float = 0.0, sides: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(color, emission)
	return mi

static func sphere(radius: float, color: Color, emission: float = 0.0, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(color, emission, false, alpha)
	return mi

static func prism(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat(color, emission)
	return mi

## Appends a quad (two triangles) to a SurfaceTool with flat normal + vertex colour.
## Vertices a,b,c,d must be clockwise as seen from the visible side (Godot's front-face winding).
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	st.set_color(color)
	st.set_normal(n)
	for v in [a, b, c, a, c, d]:
		st.set_uv(planar_uv(v, n))
		st.add_vertex(v)

## World-space planar UV (1 unit = 1 metre) along the dominant normal axis.
static func planar_uv(v: Vector3, n: Vector3) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(v.x, v.z)
	if an.x >= an.z:
		return Vector2(v.z * signf(n.x), -v.y)
	return Vector2(-v.x * signf(n.z), -v.y)

## Quad whose winding is chosen so the visible side faces `facing`.
static func quad_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, facing: Vector3) -> void:
	if (c - a).cross(b - a).dot(facing) < 0.0:
		quad(st, a, d, c, b, color)
	else:
		quad(st, a, b, c, d, color)

static func tri_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, facing: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot(facing) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_color(color)
	st.set_normal(n.normalized())
	for v in [a, b, c]:
		st.set_uv(planar_uv(v, n))
		st.add_vertex(v)

## Axis-aligned box appended to a SurfaceTool (all six faces, outward).
static func box_st(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return center + Vector3(x * h.x, y * h.y, z * h.z)
	quad_facing(st, p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), color.lightened(0.08), Vector3.UP)
	quad_facing(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), color.darkened(0.3), Vector3.DOWN)
	quad_facing(st, p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(1, -1, 1), color, Vector3.RIGHT)
	quad_facing(st, p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), color, Vector3.LEFT)
	quad_facing(st, p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, -1, 1), color.darkened(0.08), Vector3.BACK)
	quad_facing(st, p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, -1, -1), color.darkened(0.08), Vector3.FORWARD)

## Band shield shell: fresnel rim + a per-band pattern (stripes / dots / grid) so bands are
## distinguishable without relying on colour alone (DESIGN §3.4 colour-blind rule).
const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;
uniform vec4 col : source_color = vec4(1.0);
uniform int pattern = 0;
uniform float strength = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec2 uv = UV * vec2(28.0, 14.0);
	float p;
	if (pattern == 0) {
		p = step(0.5, fract((uv.x + uv.y) * 0.5));
	} else if (pattern == 1) {
		p = 1.0 - step(0.22, length(fract(uv) - 0.5));
	} else {
		p = step(0.82, max(fract(uv.x), fract(uv.y)));
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(f * 0.95 + p * 0.16 + 0.03, 0.0, 1.0) * strength;
}
"""
static var _shield_shader: Shader

static func shield_material(band: int) -> ShaderMaterial:
	if _shield_shader == null:
		_shield_shader = Shader.new()
		_shield_shader.code = SHIELD_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shield_shader
	m.set_shader_parameter("col", ThemeData.BAND_COLORS[band])
	m.set_shader_parameter("pattern", band)
	m.set_shader_parameter("strength", 1.0)
	return m
