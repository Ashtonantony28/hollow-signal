class_name Bulwark
extends Enemy
## Heavy: frontal barrier blocks all damage from the front; must be flanked or Pulsed.

var cooldown := 2.0
var windup := 0.0
var charging := 0.0
var charge_dir := Vector3.ZERO
var barrier: MeshInstance3D
var hit_this_charge := false

func _build() -> void:
	var c := Color(0.27, 0.27, 0.3)
	var legs := Meshes.box(Vector3(1.1, 1.0, 0.8), c.darkened(0.3))
	legs.position.y = 0.5
	visual.add_child(legs)
	var torso := Meshes.box(Vector3(1.5, 1.0, 1.1), c)
	torso.position.y = 1.5
	visual.add_child(torso)
	weak_mesh = Meshes.sphere(0.3, Color(1.0, 0.3, 0.2), 5.0)
	weak_mesh.position = def.weak_offset
	visual.add_child(weak_mesh)
	barrier = Meshes.box(Vector3(1.9, 2.1, 0.12), Color(0.6, 0.85, 1.0), 1.5)
	barrier.material_override = Meshes.mat(Color(0.55, 0.8, 1.0), 1.5, true, 0.4)
	barrier.position = Vector3(0, 1.2, -0.85)
	visual.add_child(barrier)

func blocks_hit(pos: Vector3, _dir: Vector3) -> bool:
	if state == State.STAGGER:
		return false
	var to_hit := pos - global_position
	to_hit.y = 0
	return to_hit.normalized().dot(forward()) > 0.35

func on_pulse() -> void:
	super.on_pulse()
	stagger(2.5)

func stagger(t: float) -> void:
	charging = 0.0
	windup = 0.0
	super.stagger(t)
	if barrier:
		barrier.visible = false
		get_tree().create_timer(t).timeout.connect(func():
			if is_instance_valid(barrier):
				barrier.visible = true)

func _think(delta: float) -> Vector3:
	cooldown = maxf(cooldown - delta, 0.0)
	if charging > 0.0:
		charging -= delta
		var flat := player.global_position - global_position
		flat.y = 0
		if not hit_this_charge and flat.length() < 1.8:
			hit_this_charge = true
			player.take_damage(def.damage, global_position)
			player.knockback(charge_dir * 12.0 + Vector3.UP * 3.0)
		if get_slide_collision_count() > 0 and charging < 0.85:
			var n := get_slide_collision(0).get_normal()
			if n.dot(charge_dir) < -0.6:
				charging = 0.0
				stagger(1.0)
		return charge_dir * 13.0
	if windup > 0.0:
		windup -= delta
		face(player.global_position, delta, 3.0)
		if windup <= 0.0:
			charging = 1.0
			hit_this_charge = false
			charge_dir = forward()
			Synth.play_at(&"launcher", global_position, 2, 0.5)
		return Vector3.ZERO
	face(player.global_position, delta, 2.5)
	var d := dist_to_player
	if can_see and d < 12.0 and d > 3.5 and cooldown <= 0.0 and request_token():
		windup = 0.8
		cooldown = def.cooldown + 2.0
		Synth.play_at(&"telegraph", global_position, 0, 0.4)
		release_token()
		return Vector3.ZERO
	if d < def.attack_range and cooldown <= 0.0:
		cooldown = def.cooldown
		player.take_damage(def.damage * 0.6, global_position)
		var push := player.global_position - global_position
		push.y = 0
		player.knockback(push.normalized() * 9.0 + Vector3.UP * 2.5)
		Synth.play_at(&"tick_bite", global_position, 2, 0.5)
	return seek(player.global_position, def.speed, delta)
