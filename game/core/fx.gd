class_name FX
## Cheap visual effects built from primitives: tracers, sparks, flashes, rings.

static func _scene(from: Node) -> Node:
	var tree := from.get_tree()
	return tree.current_scene if tree and tree.current_scene else from

static func tracer(from: Node, a: Vector3, b: Vector3, color: Color, width: float = 0.04, life: float = 0.07) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, len)
	mi.mesh = bm
	mi.material_override = Meshes.mat(color, 3.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(from).add_child(mi)
	mi.global_position = (a + b) * 0.5
	if absf((b - a).normalized().dot(Vector3.UP)) > 0.99:
		mi.look_at(b, Vector3.FORWARD)
	else:
		mi.look_at(b, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), life)
	tw.tween_callback(mi.queue_free)

static func spark(from: Node, pos: Vector3, color: Color, size: float = 0.18, life: float = 0.15) -> void:
	var mi := Meshes.sphere(size, color, 4.0)
	mi.material_override = Meshes.mat(color, 4.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(from).add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, life)
	tw.tween_callback(mi.queue_free)

static func shards(from: Node, pos: Vector3, color: Color, count: int = 6) -> void:
	var root := _scene(from)
	for i in count:
		var mi := Meshes.box(Vector3(0.12, 0.12, 0.12), color, 3.0)
		root.add_child(mi)
		mi.global_position = pos
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", pos + dir * randf_range(0.8, 1.8), 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "scale", Vector3.ZERO, 0.35)
		tw.tween_callback(mi.queue_free)

static func explosion(from: Node, pos: Vector3, radius: float, color: Color) -> void:
	var root := _scene(from)
	var mi := Meshes.sphere(0.5, color, 4.0, 0.8)
	mi.material_override = Meshes.mat(color, 4.0, true, 0.7)
	root.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.3)
	tw.tween_callback(mi.queue_free)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 4.0
	l.omni_range = radius * 3.0
	root.add_child(l)
	l.global_position = pos + Vector3.UP * 0.5
	var tl := l.create_tween()
	tl.tween_property(l, "light_energy", 0.0, 0.3)
	tl.tween_callback(l.queue_free)

static func ring(from: Node, pos: Vector3, radius: float, color: Color, life: float = 0.5) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = Meshes.mat(color, 3.0, true, 0.9)
	_scene(from).add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.5
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), life).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, life)
	tw.tween_callback(mi.queue_free)

# --- particles (CPUParticles3D works in both Compatibility and Forward+) ---

static var _marks: Array = []
const MAX_MARKS := 80

static func _burst(from: Node, pos: Vector3, mesh: Mesh, mat: Material, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.mesh = mesh
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(from).add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p

static var _spark_mesh: BoxMesh
static func spark_mesh() -> BoxMesh:
	if not _spark_mesh:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3(0.015, 0.12, 0.015)
	return _spark_mesh

## Bullet impact on world geometry: stretched sparks along the normal, a dust puff and a mark.
static func impact(from: Node, pos: Vector3, normal: Vector3, color: Color = Color(1.0, 0.75, 0.4)) -> void:
	var sp := _burst(from, pos + normal * 0.03, spark_mesh(), Meshes.mat(color, 5.0, true), 10, 0.35)
	sp.direction = normal
	sp.spread = 55.0
	sp.initial_velocity_min = 3.0
	sp.initial_velocity_max = 7.5
	sp.gravity = Vector3(0, -14, 0)
	sp.particle_flag_align_y = true
	sp.scale_amount_min = 0.6
	sp.scale_amount_max = 1.2
	smoke(from, pos + normal * 0.08, Color(0.55, 0.55, 0.58, 0.5), 4, 0.25)
	mark(from, pos, normal)

static func smoke(from: Node, pos: Vector3, color: Color, amount: int = 6, size: float = 0.35, life: float = 0.7) -> void:
	var qm := SphereMesh.new()
	qm.radius = size * 0.5
	qm.height = size
	qm.radial_segments = 6
	qm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, color.a)
	var p := _burst(from, pos, qm, m, amount, life)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g

## Persistent bullet mark: a small dark quad flush with the surface (Decals are Forward+ only in 4.3).
static func mark(from: Node, pos: Vector3, normal: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var s := randf_range(0.09, 0.14)
	qm.size = Vector2(s, s)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.04, 0.035, 0.03, 0.85)
	m.albedo_texture = _mark_tex()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(from).add_child(mi)
	mi.global_position = pos + normal * 0.012
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.look_at(mi.global_position - normal, up)
	mi.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	_marks.append(mi)
	while _marks.size() > MAX_MARKS:
		var old = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()

static var _mtex: ImageTexture
static func _mark_tex() -> ImageTexture:
	if _mtex:
		return _mtex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 0.6) if d > 0.25 else 1.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_mtex = ImageTexture.create_from_image(img)
	return _mtex

## Spent casing flicked out of the ejection port.
static func casing(from: Node, pos: Vector3, right: Vector3, color: Color = Color(0.85, 0.65, 0.3)) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.03
	cm.radial_segments = 6
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.9
	m.roughness = 0.3
	var p := _burst(from, pos, cm, m, 1, 0.7)
	p.direction = (right + Vector3.UP * 0.8).normalized()
	p.spread = 15.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = 400.0
	p.angular_velocity_max = 900.0
