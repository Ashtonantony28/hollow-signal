class_name Lobber
extends Enemy
## Area denial: keeps distance and arcs explosive globs that leave burning pools.

var cooldown := 2.0
var windup := 0.0
var mortar: Node3D

func _build() -> void:
	var c := Color(0.34, 0.3, 0.26)
	var base := Meshes.cyl(0.7, 0.6, c.darkened(0.3), 0.0, 8)
	base.position.y = 0.3
	visual.add_child(base)
	var body := Meshes.sphere(0.65, c)
	body.position.y = 1.0
	visual.add_child(body)
	mortar = Node3D.new()
	mortar.position = Vector3(0, 1.3, 0.1)
	visual.add_child(mortar)
	var tube := Meshes.cyl(0.22, 0.9, c.darkened(0.2), 0.0, 8)
	tube.rotation_degrees.x = 60
	tube.position = Vector3(0, 0.2, -0.25)
	mortar.add_child(tube)
	weak_mesh = Meshes.sphere(0.22, Color(1.0, 0.45, 0.1), 5.0)
	weak_mesh.position = def.weak_offset
	visual.add_child(weak_mesh)

func _think(delta: float) -> Vector3:
	cooldown = maxf(cooldown - delta, 0.0)
	face(player.global_position, delta, 4.0)
	if windup > 0.0:
		windup -= delta
		mortar.position.y = 1.3 - windup * 0.2
		if windup <= 0.0:
			_fire()
		return Vector3.ZERO
	var dist := dist_to_player
	var desired := Vector3.ZERO
	if not can_see or dist > 22.0:
		release_token()
		desired = seek(player.global_position, def.speed, delta)
	elif dist < 10.0:
		var away := global_position - player.global_position
		away.y = 0
		desired = away.normalized() * def.speed + separation()
	if can_see and dist < def.attack_range and cooldown <= 0.0 and request_token():
		windup = 0.7
		Synth.play_at(&"telegraph", global_position, -8, 0.6)
	return desired

func _fire() -> void:
	cooldown = def.cooldown + _rng.randf_range(0.0, 1.0)
	release_token()
	var g := Glob.new()
	g.damage = def.damage
	g.color = ThemeData.BAND_COLORS[band].lerp(Color(1.0, 0.45, 0.1), 0.5)
	var start := global_position + Vector3.UP * 2.0
	var target := player.global_position + Vector3(player.velocity.x, 0, player.velocity.z) * 0.6
	g.velocity = ballistic(start, target, 12.0, 1.1)
	get_tree().current_scene.add_child(g)
	g.global_position = start
	Synth.play_at(&"glob", start, -4, 1.3)

## Velocity that lands at `target` after flight time proportional to distance.
static func ballistic(from: Vector3, to: Vector3, gravity: float, min_time: float) -> Vector3:
	var d := to - from
	var flat := Vector3(d.x, 0, d.z)
	var t := maxf(min_time, flat.length() / 14.0)
	var v := flat / t
	v.y = (d.y + 0.5 * gravity * t * t) / t
	return v
