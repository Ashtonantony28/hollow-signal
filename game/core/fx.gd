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
