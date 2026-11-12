class_name Tick
extends Enemy
## Swarm melee crawler: fast, leaps the last few metres.

var bite_cd := 0.0
var leap_cd := 0.0
var legs: Array[Node3D] = []
var t := 0.0

func _build() -> void:
	var body_col := Color(0.25, 0.24, 0.22)
	var b := Meshes.box(Vector3(0.7, 0.35, 0.9), body_col)
	b.position.y = 0.4
	visual.add_child(b)
	var head := Meshes.prism(Vector3(0.5, 0.3, 0.4), body_col.lightened(0.1))
	head.position = Vector3(0, 0.45, -0.55)
	head.rotation_degrees.x = -90
	visual.add_child(head)
	weak_mesh = Meshes.sphere(0.13, Color(1.0, 0.3, 0.15), 5.0)
	weak_mesh.position = def.weak_offset
	visual.add_child(weak_mesh)
	for i in 6:
		var leg := Meshes.box(Vector3(0.08, 0.08, 0.6), body_col.darkened(0.3))
		var side := -1.0 if i < 3 else 1.0
		leg.position = Vector3(side * 0.45, 0.25, -0.3 + (i % 3) * 0.3)
		leg.rotation_degrees.y = 90
		leg.rotation_degrees.z = side * 30
		visual.add_child(leg)
		legs.append(leg)

func _think(delta: float) -> Vector3:
	t += delta
	bite_cd = maxf(bite_cd - delta, 0.0)
	leap_cd = maxf(leap_cd - delta, 0.0)
	for i in legs.size():
		legs[i].rotation_degrees.x = sin(t * 22.0 + i) * 20.0
	var target := player.global_position
	face(target, delta, 12.0)
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := flat.length()
	if d < 1.4 and bite_cd <= 0.0 and absf(target.y - global_position.y) < 1.5:
		bite_cd = 1.1
		player.take_damage(def.damage, global_position)
		Synth.play_at(&"tick_bite", global_position, -2)
	if d < 4.0 and d > 1.6 and leap_cd <= 0.0 and is_on_floor() and can_see:
		leap_cd = 2.2
		velocity = flat.normalized() * 11.0 + Vector3.UP * 4.0
		return velocity * Vector3(1, 0, 1)
	if not is_on_floor():
		return Vector3(velocity.x, 0, velocity.z)
	return seek(target, def.speed, delta)
