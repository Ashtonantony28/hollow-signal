class_name Warden
extends Enemy
## Ranged line unit: telegraphed hitscan rifle, keeps distance, strafes, uses attack tokens.

var cooldown := 1.0
var telegraph := 0.0
var aim_point := Vector3.ZERO
var strafe_dir := 1.0
var strafe_timer := 0.0
var laser: MeshInstance3D
var gun: Node3D

func _build() -> void:
	var c := Color(0.3, 0.31, 0.34)
	var legs := Meshes.box(Vector3(0.5, 0.9, 0.35), c.darkened(0.3))
	legs.position.y = 0.45
	visual.add_child(legs)
	var torso := Meshes.box(Vector3(0.75, 0.65, 0.45), c)
	torso.position.y = 1.2
	visual.add_child(torso)
	var head := Meshes.box(Vector3(0.38, 0.32, 0.38), c.lightened(0.1))
	head.position.y = 1.68
	visual.add_child(head)
	weak_mesh = Meshes.box(Vector3(0.3, 0.08, 0.05), Color(1.0, 0.25, 0.2), 5.0)
	weak_mesh.position = Vector3(0, 1.68, -0.2)
	visual.add_child(weak_mesh)
	gun = Node3D.new()
	gun.position = Vector3(0.45, 1.25, -0.2)
	visual.add_child(gun)
	var barrel := Meshes.box(Vector3(0.12, 0.12, 0.8), c.darkened(0.4))
	barrel.position.z = -0.3
	gun.add_child(barrel)
	laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 1.0)
	laser.mesh = bm
	laser.material_override = Meshes.mat(Color(1.0, 0.15, 0.1), 3.0, true)
	laser.visible = false
	laser.top_level = true
	add_child(laser)

func _think(delta: float) -> Vector3:
	cooldown = maxf(cooldown - delta, 0.0)
	var target := player.eye_position()
	face(player.global_position, delta)
	var muzzle := gun.global_position + forward() * 0.7
	if telegraph > 0.0:
		telegraph -= delta
		# track until the last 0.15s, then lock (fair dodge window)
		if telegraph > 0.15:
			aim_point = target + player.velocity * 0.1
		_draw_laser(muzzle, aim_point)
		if telegraph <= 0.0:
			_shoot(muzzle)
		return Vector3.ZERO
	var desired := Vector3.ZERO
	var dist := dist_to_player
	if not can_see or dist > 20.0:
		release_token()
		desired = seek(player.global_position, def.speed, delta)
	elif dist < 7.0:
		var away := global_position - player.global_position
		away.y = 0
		desired = away.normalized() * def.speed + separation()
	else:
		strafe_timer -= delta
		if strafe_timer <= 0.0:
			strafe_timer = _rng.randf_range(0.8, 2.0)
			strafe_dir = -strafe_dir if _rng.randf() < 0.6 else strafe_dir
		desired = global_transform.basis.x * strafe_dir * def.speed * 0.6 + separation()
	if can_see and dist < def.attack_range and cooldown <= 0.0 and request_token():
		telegraph = def.telegraph
		aim_point = target
		Synth.play_at(&"telegraph", global_position, -6)
	return desired

func _draw_laser(a: Vector3, b: Vector3) -> void:
	laser.visible = true
	var len := a.distance_to(b)
	laser.scale = Vector3(1, 1, len)
	laser.global_position = (a + b) * 0.5
	if len > 0.01:
		laser.look_at(b, Vector3.UP)

func _shoot(muzzle: Vector3) -> void:
	laser.visible = false
	cooldown = def.cooldown + _rng.randf_range(0.0, 0.8)
	release_token()
	var dir := (aim_point - muzzle).normalized()
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + dir * 80.0, 1 | 2, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := muzzle + dir * 80.0
	Synth.play_at(&"enemy_shot", muzzle, 0)
	if not r.is_empty():
		end = r.position
		if r.collider is Player:
			(r.collider as Player).take_damage(def.damage, global_position)
	FX.tracer(self, muzzle, end, Color(1.0, 0.3, 0.2), 0.06, 0.1)

func stagger(t: float) -> void:
	telegraph = 0.0
	if laser:
		laser.visible = false
	super.stagger(t)

func die() -> void:
	if laser:
		laser.visible = false
	super.die()
