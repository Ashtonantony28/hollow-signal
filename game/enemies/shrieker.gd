class_name Shrieker
extends Enemy
## Flying support: hovers near allies, recharges their shields, flees when targeted.

var cooldown := 2.0
var bob := 0.0
var wings: Array[Node3D] = []
var flee_timer := 0.0

func _ready() -> void:
	flying = true
	super._ready()
	collision_mask = 1

func _build() -> void:
	var c := Color(0.28, 0.26, 0.32)
	var core := Meshes.sphere(0.4, c)
	core.position.y = 0.45
	visual.add_child(core)
	weak_mesh = Meshes.sphere(0.22, Color(0.9, 0.3, 1.0), 5.0)
	weak_mesh.position = def.weak_offset + Vector3(0, 0, -0.25)
	visual.add_child(weak_mesh)
	for s in [-1.0, 1.0]:
		var w := Meshes.box(Vector3(0.9, 0.04, 0.4), c.lightened(0.15))
		w.position = Vector3(s * 0.7, 0.5, 0)
		visual.add_child(w)
		wings.append(w)

func _think(delta: float) -> Vector3:
	bob += delta
	cooldown = maxf(cooldown - delta, 0.0)
	for i in wings.size():
		wings[i].rotation.z = sin(bob * 18.0) * 0.4 * (1.0 if i == 0 else -1.0)
	face(player.global_position, delta)
	var ground_y := 0.0
	var want_y := ground_y + float(def.fly_height) + sin(bob * 2.0) * 0.4
	var desired := Vector3.ZERO
	# flee when the player is aiming at us
	var to_me := (global_position + Vector3.UP * 0.45 - player.eye_position()).normalized()
	if can_see and player.aim_dir().dot(to_me) > 0.97 and dist_to_player < 25.0:
		flee_timer = 1.0
	if flee_timer > 0.0:
		flee_timer -= delta
		desired = global_transform.basis.x * (1.0 if int(bob) % 2 == 0 else -1.0) * def.speed * 1.4
	else:
		var ally := _nearest_ally()
		var goal: Vector3 = ally.global_position if ally else player.global_position
		var keep := 5.0 if ally else 12.0
		var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
		if flat.length() > keep:
			desired = seek(goal, def.speed, delta)
	desired.y = (want_y - global_position.y) * 3.0
	if cooldown <= 0.0:
		_recharge()
	return desired

func _nearest_ally() -> Enemy:
	var best: Enemy = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e is Shrieker:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best

func _recharge() -> void:
	cooldown = def.cooldown
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e.max_shield <= 0.0:
			continue
		if e.global_position.distance_to(global_position) < float(def.attack_range):
			e.heal_shield(e.max_shield * 0.4)
			FX.tracer(self, global_position + Vector3.UP * 0.45, e.global_position + Vector3.UP, ThemeData.BAND_COLORS[e.band], 0.05, 0.25)
			any = true
	if any:
		Synth.play_at(&"retune", global_position, 0, 1.6)
