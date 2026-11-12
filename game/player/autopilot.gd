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
var fire_toggle := false

func _physics_process(delta: float) -> void:
	if player == null or level == null or not player.alive:
		return
	player.ai_controlled = true
	scan_t -= delta
	if scan_t <= 0.0:
		scan_t = 0.15
		target = _pick_target()
	var goal := level.objective_position()
	if OS.has_feature("debug") and Engine.get_physics_frames() % 600 == 0 and OS.get_cmdline_user_args().has("--botlog"):
		print("[bot] pos=%s goal=%s path=%d/%d target=%s phase=%s" % [player.global_position.snapped(Vector3.ONE), goal.snapped(Vector3.ONE), path_idx, path.size(), _desc(target), Level.Phase.keys()[level.phase]])
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
		if player.aim_dir().dot(to_t) > 0.97:
			# semi-auto weapons need press/release cycles; the Lance is held to charge
			fire_toggle = not fire_toggle
			player.ai_fire = fire_toggle if player.weapons.def().kind != "beam" else true
		var dist := player.global_position.distance_to(target.global_position)
		var want_w: StringName = Game.loadout[0] if not Game.loadout.is_empty() else &"rivet"
		for id in Game.loadout:
			var cls: String = WeaponData.get_def(id)["class"]
			var a: Dictionary = Game.ammo[id]
			if a.mag + maxi(a.reserve, 0) <= 0 and a.reserve >= 0:
				continue
			if dist < 9.0 and cls == "Shotgun":
				want_w = id
				break
			if cls in ["Rifle", "SMG", "LMG"]:
				want_w = id
		if player.weapons.current != want_w:
			player.weapons.equip(want_w)
		if "shield" in target and target.shield > 0.0 and player.weapons.band != target.band:
			player.weapons.set_band(target.band)
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.6, 1.5)
			strafe = -strafe
		move_world += player.global_transform.basis.x * strafe * 0.6
		# Bulwark: its barrier blocks frontal fire — Pulse it or circle to its flank
		if target is Bulwark and _in_front_of(target as Bulwark):
			if Game.charge >= Game.pulse_cost() and dist < Player.PULSE_RADIUS:
				player.try_pulse()
			move_world = player.global_transform.basis.x * strafe * 1.0 - (target.global_position - player.global_position).normalized() * (0.6 if dist < 5.0 else 0.0)
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
		# the Conductor's core is sealed while shield nodes live: target the nodes
		if e is Conductor and not (e as Conductor).nodes.is_empty():
			continue
		var p: Vector3 = e.global_position + Vector3.UP * 0.6
		var d := player.eye_position().distance_to(p)
		if e is ConductorNode:
			d *= 0.3
		elif e is Bulwark and _in_front_of(e as Bulwark):
			d *= 2.5
		if d >= bd:
			continue
		var q := PhysicsRayQueryParameters3D.create(player.eye_position(), p, 1)
		if space.intersect_ray(q).is_empty():
			bd = d
			best = e
	return best

func _desc(t: Node3D) -> String:
	if t == null or not is_instance_valid(t):
		return "none"
	if t is Enemy:
		var e := t as Enemy
		return "%s hp=%.0f sh=%.0f st=%d at=%s d=%.1f aimdot=%.3f" % [e.kind, e.hp, e.shield, e.state, e.global_position.snapped(Vector3.ONE * 0.1), e.global_position.distance_to(player.global_position), player.aim_dir().dot((e.global_position + Vector3.UP * float(e.def.height) * 0.6 - player.eye_position()).normalized())]
	return t.get_class()

func _in_front_of(b: Bulwark) -> bool:
	if b.state == Enemy.State.STAGGER:
		return false
	var to := player.global_position - b.global_position
	to.y = 0
	return to.normalized().dot(b.forward()) > 0.35
