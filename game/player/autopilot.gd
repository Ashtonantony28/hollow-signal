class_name Autopilot
extends Node
## Bot that plays the game: walks the grid path to the current objective, fights visible
## enemies with band matching, uses Pulse when swarmed. Used by cloud smoke tests and
## screenshot capture so the game can be "playtested" without a human or GPU.

var player: Player
var level: Level
var path := PackedVector3Array()
var path_idx := 0
var repath := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var strafe := 1.0
var strafe_t := 0.0
var target: Node3D = null
var scan_t := 0.0

func _physics_process(delta: float) -> void:
	if player == null or level == null or not player.alive:
		return
	player.ai_controlled = true
	scan_t -= delta
	if scan_t <= 0.0:
		scan_t = 0.15
		target = _pick_target()
	var goal := level.objective_position()
	if level.phase == Level.Phase.DONE:
		player.ai_move = Vector2.ZERO
		player.ai_fire = false
		return
	# --- movement along path
	repath -= delta
	if repath <= 0.0 or path_idx >= path.size():
		repath = 0.5
		path = level.nav.path_world(player.global_position, goal)
		path_idx = 0
	var move_world := Vector3.ZERO
	var hold := level.phase == Level.Phase.HOLDOUT and level._flat_dist(player.global_position, level.uplink_node.global_position) < 4.0
	if not hold:
		while path_idx < path.size():
			var wp := path[path_idx]
			var to := Vector3(wp.x - player.global_position.x, 0, wp.z - player.global_position.z)
			if to.length() < 1.0:
				path_idx += 1
				continue
			move_world = to.normalized()
			break
		if path.is_empty():
			var to2 := goal - player.global_position
			to2.y = 0
			move_world = to2.normalized()
	# --- combat
	player.ai_fire = false
	if target and is_instance_valid(target):
		var aim_h := 0.0
		if target is Enemy:
			aim_h = float((target as Enemy).def.height) * 0.6
		var aim_at: Vector3 = target.global_position + Vector3.UP * aim_h
		player.look_at_point(aim_at, 0.3)
		var to_t: Vector3 = (aim_at - player.eye_position()).normalized()
		if player.aim_dir().dot(to_t) > 0.985:
			player.ai_fire = not player.ai_fire if player.weapons.def().kind == "hitscan" else true
		var dist := player.global_position.distance_to(target.global_position)
		var want_w: StringName = &"rivet"
		if dist < 9.0 and Game.ammo[&"scatter"].mag + Game.ammo[&"scatter"].reserve > 0:
			want_w = &"scatter"
		if player.weapons.current != want_w:
			player.weapons.equip(want_w)
		if "shield" in target and target.shield > 0.0 and player.weapons.band != target.band:
			player.weapons.set_band(target.band)
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.6, 1.5)
			strafe = -strafe
		move_world += player.global_transform.basis.x * strafe * 0.6
		var close := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(player.global_position) < 8.0:
				close += 1
		if close >= 3 and Game.charge >= Game.pulse_cost():
			player.try_pulse()
	elif move_world.length() > 0.1:
		var look := player.global_position + move_world * 5.0 + Vector3.UP * 1.6
		player.look_at_point(look, 0.15)
	# convert world move into local strafe/forward
	var local := player.global_transform.basis.inverse() * move_world
	player.ai_move = Vector2(local.x, -local.z).limit_length(1.0)
	player.ai_sprint = target == null and move_world.length() > 0.5
	# stuck → jump
	stuck_t += delta
	player.ai_jump = false
	if stuck_t > 1.5:
		if player.global_position.distance_to(last_pos) < 0.6 and move_world.length() > 0.3:
			player.ai_jump = true
			repath = 0.0
		stuck_t = 0.0
		last_pos = player.global_position

func _pick_target() -> Node3D:
	var best: Node3D = null
	var bd := 40.0
	var space := player.get_world_3d().direct_space_state
	var cands: Array = get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss")
	for e in cands:
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		var p: Vector3 = e.global_position + Vector3.UP * 0.6
		var d := player.eye_position().distance_to(p)
		if d >= bd:
			continue
		var q := PhysicsRayQueryParameters3D.create(player.eye_position(), p, 1)
		if space.intersect_ray(q).is_empty():
			bd = d
			best = e
	return best
