class_name Lamplighter
extends Warden
## Sniper: hangs back at long range, paints the player with a slow-tightening laser, then fires a
## heavy shot. The beam is visible across the room so the player can break line of sight.
## Its lamp head is the weak point.

var lamp_light: OmniLight3D

func _build() -> void:
	var c := Color(0.22, 0.2, 0.18)
	# tripod legs
	for i in 3:
		var a := i * TAU / 3.0
		var leg := Meshes.box(Vector3(0.09, 1.5, 0.09), c.darkened(0.3))
		leg.position = Vector3(sin(a) * 0.3, 0.7, cos(a) * 0.3)
		leg.rotation = Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25)
		visual.add_child(leg)
	var spine := Meshes.box(Vector3(0.28, 0.9, 0.24), c)
	spine.position.y = 1.75
	visual.add_child(spine)
	var collar := Meshes.cyl(0.26, 0.12, c.lightened(0.15), 0.0, 10)
	collar.position.y = 2.25
	visual.add_child(collar)
	var hood := Meshes.box(Vector3(0.42, 0.34, 0.42), c.lightened(0.05))
	hood.position.y = 2.48
	visual.add_child(hood)
	weak_mesh = Meshes.sphere(0.16, Color(1.0, 0.85, 0.4), 6.0)
	weak_mesh.position = Vector3(0, 2.46, -0.2)
	visual.add_child(weak_mesh)
	lamp_light = OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.8, 0.45)
	lamp_light.omni_range = 4.0
	lamp_light.light_energy = 1.2
	lamp_light.position = Vector3(0, 2.46, -0.4)
	visual.add_child(lamp_light)
	gun = Node3D.new()
	gun.position = Vector3(0.3, 1.9, -0.15)
	visual.add_child(gun)
	var barrel := Meshes.box(Vector3(0.08, 0.1, 1.5), c.darkened(0.5))
	barrel.position.z = -0.6
	gun.add_child(barrel)
	var scope := Meshes.cyl(0.05, 0.3, Color(0.1, 0.1, 0.1), 0.0, 8)
	scope.rotation.x = PI / 2
	scope.position = Vector3(0, 0.1, -0.2)
	gun.add_child(scope)
	laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, 1.0)
	laser.mesh = bm
	laser.material_override = Meshes.mat(Color(1.0, 0.85, 0.3), 4.0, true)
	laser.visible = false
	laser.top_level = true
	add_child(laser)

func _think(delta: float) -> Vector3:
	cooldown = maxf(cooldown - delta, 0.0)
	var target := player.eye_position()
	face(player.global_position, delta, 4.0)
	var muzzle := gun.global_position + forward() * 1.4
	if telegraph > 0.0:
		# break line of sight to cancel the shot
		if not can_see:
			telegraph = 0.0
			laser.visible = false
			cooldown = 1.0
			release_token()
			return Vector3.ZERO
		telegraph -= delta
		var k := clampf(telegraph / float(def.telegraph), 0.0, 1.0)
		if telegraph > 0.25:
			aim_point = target + Vector3(sin(telegraph * 9.0), cos(telegraph * 7.0), 0) * k * 0.8
		laser.scale = Vector3(1.0 + (1.0 - k) * 2.0, 1.0 + (1.0 - k) * 2.0, laser.scale.z)
		_draw_laser(muzzle, aim_point)
		lamp_light.light_energy = 1.2 + (1.0 - k) * 3.0
		if telegraph <= 0.0:
			_shoot(muzzle)
			lamp_light.light_energy = 1.2
			Synth.play_at(&"sniper", muzzle, 2.0)
		return Vector3.ZERO
	var desired := Vector3.ZERO
	var dist := dist_to_player
	if not can_see or dist > float(def.attack_range):
		release_token()
		desired = seek(player.global_position, def.speed, delta)
	elif dist < 14.0:
		var away := global_position - player.global_position
		away.y = 0
		desired = away.normalized() * def.speed * 1.3 + separation()
	if can_see and dist >= 8.0 and cooldown <= 0.0 and request_token():
		telegraph = def.telegraph
		aim_point = target
		Synth.play_at(&"telegraph", global_position, -2)
	return desired
