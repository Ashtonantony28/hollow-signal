class_name Player
extends CharacterBody3D
## First-person Lineman controller (DESIGN.md §3). Built entirely in code.

const RUN_SPEED := 7.5
const SPRINT_SPEED := 10.5
const CROUCH_SPEED := 3.5
const SLIDE_SPEED := 13.0
const SLIDE_TIME := 1.0
const SLIDE_COOLDOWN := 1.2
const GROUND_ACCEL := 70.0
const AIR_ACCEL := 21.0
const FRICTION := 10.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 15.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.12
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 0.9
const EYE_STAND := 1.6
const EYE_CROUCH := 0.75
const DASH_DIST := 8.0
const DASH_TIME := 0.18
const DASH_RECHARGE := 3.0
const PULSE_RADIUS := 12.0
const SLIDE_MIN_SPEED := 6.0
const SLIDE_BOOST := 3.0
const SLIDE_FRICTION := 5.5
const MAX_AIR_JUMPS := 1
const AIR_JUMP_VELOCITY := 5.0
const WALLRUN_MIN_SPEED := 5.0
const WALLRUN_SPEED := 9.5
const WALLRUN_TIME := 1.3
const WALLRUN_GRAVITY := 0.18
const WALLJUMP_PUSH := 7.5
const WALLJUMP_UP := 6.0
const MANTLE_TIME := 0.28
const MANTLE_MIN := 0.5
const MANTLE_MAX := 1.9
const ADS_MOVE_MULT := 0.6
const REVEAL_RADIUS := 30.0

var head: Node3D
var camera: Camera3D
var weapons: WeaponSystem
var shape: CapsuleShape3D
var col: CollisionShape3D

var level: Node = null
var alive := true
var crouching := false
var sliding := false
var slide_timer := 0.0
var slide_cd := 0.0
var slide_dir := Vector3.ZERO
var coyote_timer := 0.0
var jump_buffer := 0.0
var dash_charges := 2.0
var dash_timer := 0.0
var dash_dir := Vector3.ZERO
var bob_t := 0.0
var step_t := 0.0
var cam_kick := Vector2.ZERO      # recoil: pitch, yaw offsets (radians)
var cam_kick_vel := Vector2.ZERO
var shake := 0.0
var land_dip := 0.0
var was_on_floor := true
var hurt_flash := 0.0
var air_jumps := 1
var wall_running := false
var wall_run_t := 0.0
var wall_run_n := Vector3.ZERO
var wallrun_lock := 0.0
var mantle_t := 0.0
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var mantle_dir := Vector3.ZERO
var aiming := false
var cam_tilt := 0.0
var recoil_debt := 0.0

# Autopilot (smoke tests / attract mode). When ai_controlled, input comes from these fields.
var ai_controlled := false
var ai_move := Vector2.ZERO        # x = strafe, y = forward
var ai_fire := false
var ai_jump := false
var ai_sprint := false
var ai_crouch := false

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.3
	col = CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = STAND_HEIGHT
	col.shape = shape
	col.position.y = STAND_HEIGHT / 2.0
	add_child(col)
	head = Node3D.new()
	head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new()
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.far = 220.0
	camera.current = true
	head.add_child(camera)
	weapons = WeaponSystem.new()
	weapons.player = self
	camera.add_child(weapons)

func _unhandled_input(event: InputEvent) -> void:
	if not alive or ai_controlled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if weapons and weapons.wheel_open:
			weapons.wheel_input(event.relative)
			return
		var sens := Settings.mouse_sensitivity * (lerpf(1.0, float(weapons.def().get("ads_fov", 0.8)), weapons.ads) if weapons else 1.0)
		rotate_look(-event.relative.x * sens, -event.relative.y * sens)

func rotate_look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	head.rotation.x = clampf(head.rotation.x + pitch, deg_to_rad(-89), deg_to_rad(89))

func look_at_point(p: Vector3, max_step: float = 0.2) -> void:
	var to := p - head.global_position
	if to.length() < 0.01:
		return
	var target_yaw := atan2(-to.x, -to.z)
	var dyaw := wrapf(target_yaw - rotation.y, -PI, PI)
	rotate_y(clampf(dyaw, -max_step, max_step))
	var flat := Vector2(to.x, to.z).length()
	var target_pitch := atan2(to.y, flat)
	head.rotation.x = move_toward(head.rotation.x, target_pitch, max_step)

func _pressed(action: StringName) -> bool:
	if ai_controlled:
		match action:
			&"jump": return ai_jump
			&"sprint": return ai_sprint
			&"fire": return ai_fire
			&"crouch": return ai_crouch
		return false
	return Input.is_action_pressed(action)

func _just(action: StringName) -> bool:
	if ai_controlled:
		return action == &"jump" and ai_jump
	return Input.is_action_just_pressed(action)

func move_input() -> Vector2:
	if ai_controlled:
		return ai_move.limit_length(1.0)
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward")).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		return
	var on_floor := is_on_floor()
	coyote_timer = COYOTE if on_floor else maxf(coyote_timer - delta, 0.0)
	jump_buffer = JUMP_BUFFER if _just(&"jump") else maxf(jump_buffer - delta, 0.0)
	slide_cd = maxf(slide_cd - delta, 0.0)
	if Game.mod_level(&"snap_drive") > 0:
		dash_charges = minf(dash_charges + delta / DASH_RECHARGE, 2.0)

	var inp := move_input()
	var basis_flat := global_transform.basis
	var wish := (basis_flat * Vector3(inp.x, 0, -inp.y))
	wish.y = 0
	wish = wish.normalized() * inp.length()

	var want_crouch := _pressed(&"crouch")
	var sprinting := _pressed(&"sprint") and inp.y > 0.3 and not crouching and not aiming
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var hspeed := horiz.length()
	if on_floor:
		air_jumps = MAX_AIR_JUMPS
		wall_run_t = 0.0
		wallrun_lock = 0.0
	wallrun_lock = maxf(wallrun_lock - delta, 0.0)

	# --- mantle in progress: scripted climb, no physics
	if mantle_t > 0.0:
		mantle_t -= delta
		var k := 1.0 - mantle_t / MANTLE_TIME
		global_position = mantle_from.lerp(mantle_to, ease(k, 0.6))
		velocity = Vector3.ZERO
		if mantle_t <= 0.0:
			velocity = mantle_dir * RUN_SPEED * 0.8
		_update_camera(delta, inp, false)
		return

	# --- start slide: from sprint or any fast ground movement; keeps (and boosts) momentum
	if want_crouch and not crouching and on_floor and slide_cd <= 0.0 and hspeed > SLIDE_MIN_SPEED:
		sliding = true
		slide_timer = SLIDE_TIME
		slide_dir = horiz.normalized()
		horiz = slide_dir * maxf(hspeed + SLIDE_BOOST, SLIDE_SPEED)
		Synth.play(&"step", -6, 0.6)
	_set_crouch(want_crouch or sliding, delta)

	# --- dash (Snap Drive mod)
	if not ai_controlled and Input.is_action_just_pressed("dash") and Game.mod_level(&"snap_drive") > 0 and dash_charges >= 1.0:
		dash_charges -= 1.0
		dash_timer = DASH_TIME
		dash_dir = wish.normalized() if wish.length() > 0.1 else -global_transform.basis.z
		dash_dir.y = 0
		Synth.play(&"jump", -2, 1.6)

	# --- wall-run detection: airborne, moving fast, pushing along a wall
	var wall_n := Vector3.ZERO
	if not on_floor and is_on_wall() and wallrun_lock <= 0.0:
		wall_n = get_wall_normal()
		wall_n.y = 0
		wall_n = wall_n.normalized()
	var can_wallrun := wall_n != Vector3.ZERO and hspeed > WALLRUN_MIN_SPEED and inp.y > 0.2 \
		and absf(wall_n.dot(horiz.normalized())) < 0.75 and wall_run_t < WALLRUN_TIME
	if can_wallrun:
		if not wall_running:
			wall_running = true
			air_jumps = MAX_AIR_JUMPS
			velocity.y = maxf(velocity.y, 1.5)
			Synth.play(&"step", -6, 1.3)
		wall_run_n = wall_n
	elif wall_running:
		wall_running = false
		wallrun_lock = 0.25

	if dash_timer > 0.0:
		dash_timer -= delta
		horiz = dash_dir.normalized() * (DASH_DIST / DASH_TIME)
		velocity.y = maxf(velocity.y, 0.0)
	elif wall_running:
		wall_run_t += delta
		var along := horiz - wall_run_n * horiz.dot(wall_run_n)
		along = along.normalized() * maxf(along.length(), WALLRUN_SPEED)
		horiz = along - wall_run_n * 1.5   # hug the wall
		velocity.y -= GRAVITY * WALLRUN_GRAVITY * delta
		velocity.y = maxf(velocity.y, -2.0)
	elif sliding:
		slide_timer -= delta
		# momentum decays by friction rather than a fixed curve
		var sp := maxf(horiz.length() - SLIDE_FRICTION * delta, 0.0)
		horiz = slide_dir * sp + wish * 2.5
		slide_dir = horiz.normalized() if horiz.length() > 0.1 else slide_dir
		if slide_timer <= 0.0 or not want_crouch or sp < CROUCH_SPEED:
			sliding = false
			slide_cd = SLIDE_COOLDOWN
	else:
		var top := RUN_SPEED
		if crouching:
			top = CROUCH_SPEED
		elif sprinting:
			top = SPRINT_SPEED
		if aiming:
			top *= ADS_MOVE_MULT
		if weapons:
			top *= float(weapons.def().get("move_mult", 1.0))
		if on_floor:
			var target := wish * top
			# above top speed (after a slide-hop) bleed speed gently instead of snapping
			var accel := GROUND_ACCEL if hspeed <= top + 0.5 else FRICTION * 1.5
			horiz = horiz.move_toward(target, accel * delta)
			if inp.length() < 0.05:
				horiz = horiz.move_toward(Vector3.ZERO, FRICTION * delta * 3.0)
		else:
			# air strafing: accelerate freely up to `top`, steer (but don't add) above it
			var add := wish * AIR_ACCEL * delta
			var nh := horiz + add
			if nh.length() > maxf(hspeed, top):
				nh = nh.normalized() * maxf(hspeed, top)
			horiz = nh

	if not on_floor and not wall_running and dash_timer <= 0.0:
		velocity.y -= GRAVITY * delta

	# --- jumping: ground (with coyote), wall-jump, then air jump (thrusters)
	if jump_buffer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			if sliding:
				# slide-hop keeps the slide's speed
				sliding = false
				slide_cd = SLIDE_COOLDOWN * 0.5
			jump_buffer = 0.0
			coyote_timer = 0.0
			Synth.play(&"jump", -8)
		elif wall_running:
			horiz += wall_run_n * WALLJUMP_PUSH
			velocity.y = WALLJUMP_UP
			wall_running = false
			wallrun_lock = 0.35
			jump_buffer = 0.0
			Synth.play(&"jump", -4, 1.2)
		elif _try_mantle(horiz):
			jump_buffer = 0.0
			_update_camera(delta, inp, false)
			return
		elif air_jumps > 0:
			air_jumps -= 1
			velocity.y = AIR_JUMP_VELOCITY
			# thrusters let you redirect toward input
			if wish.length() > 0.1:
				horiz = horiz.lerp(wish * maxf(hspeed, RUN_SPEED), 0.6)
			jump_buffer = 0.0
			FX.ring(self, global_position + Vector3.UP * 0.1, 1.2, Color(0.6, 0.85, 1.0), 0.25)
			Synth.play(&"jump", -4, 1.5)
	# auto-mantle: airborne, pushing forward into a ledge
	if not on_floor and inp.y > 0.5 and velocity.y < 2.0 and is_on_wall() and not wall_running:
		if _try_mantle(horiz):
			_update_camera(delta, inp, false)
			return

	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	# landing
	if is_on_floor() and not was_on_floor:
		land_dip = 0.06
		Synth.play(&"step", -4, 0.8)
	was_on_floor = is_on_floor()

	# actions
	if not ai_controlled:
		if Input.is_action_just_pressed("pulse"):
			try_pulse()
		_pad_look(delta)
	_update_camera(delta, inp, sprinting)

func _set_crouch(c: bool, delta: float) -> void:
	if not c and crouching:
		# check headroom before standing
		var q := PhysicsShapeQueryParameters3D.new()
		var s := CapsuleShape3D.new()
		s.radius = 0.38
		s.height = STAND_HEIGHT
		q.shape = s
		q.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT / 2.0 + 0.05, 0))
		q.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(q, 1).size() > 0:
			c = true
	crouching = c
	var h := CROUCH_HEIGHT if c else STAND_HEIGHT
	shape.height = move_toward(shape.height, h, delta * 8.0)
	col.position.y = shape.height / 2.0
	head.position.y = move_toward(head.position.y, EYE_CROUCH if c else EYE_STAND, delta * 6.0)

func _update_camera(delta: float, inp: Vector2, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if recoil_debt > 0.0:
		var back := minf(recoil_debt, delta * 0.6)
		head.rotation.x -= back
		recoil_debt -= back
	# recoil spring
	cam_kick_vel += (-cam_kick * 120.0 - cam_kick_vel * 16.0) * delta
	cam_kick += cam_kick_vel * delta
	# head bob
	var bob := Vector3.ZERO
	if is_on_floor() and speed > 1.0 and not sliding:
		bob_t += delta * speed * 1.4
		if Settings.head_bob:
			bob = Vector3(cos(bob_t * 0.5) * 0.03, absf(sin(bob_t * 0.5)) * 0.045, 0)
		step_t += delta * speed
		if step_t > 2.6:
			step_t = 0.0
			Synth.play(&"step", -18)
	land_dip = move_toward(land_dip, 0.0, delta * 0.4)
	shake = maxf(shake - delta * 2.5, 0.0)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.05
	camera.position = bob + sh + Vector3(0, -land_dip, 0)
	var tilt_target := -inp.x * 0.015 + (0.04 if sliding else 0.0)
	if wall_running:
		tilt_target = -0.18 * signf(global_transform.basis.x.dot(wall_run_n))
	cam_tilt = lerpf(cam_tilt, tilt_target, clampf(delta * 10.0, 0, 1))
	camera.rotation = Vector3(cam_kick.x, cam_kick.y, cam_tilt)
	var spd_kick := clampf((speed - RUN_SPEED) / 6.0, 0.0, 1.0) * 10.0
	var target_fov := Settings.fov + spd_kick
	if aiming and weapons:
		target_fov = Settings.fov * float(weapons.def().get("ads_fov", 0.8))
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)
	hurt_flash = maxf(hurt_flash - delta * 2.0, 0.0)

## Recoil moves the real aim (pitch up, patterned yaw) and adds a visual camera kick.
## Most of the pitch is recovered automatically over the next few frames.
func add_recoil(amount: float, yaw_deg: float = 0.0) -> void:
	cam_kick_vel += Vector2(deg_to_rad(amount) * 10.0, deg_to_rad(yaw_deg) * 4.0)
	var pitch := deg_to_rad(amount * 0.35)
	rotate_look(-deg_to_rad(yaw_deg * 0.5), pitch)
	recoil_debt += pitch * 0.7

func add_shake(amount: float) -> void:
	shake = clampf(shake + amount, 0.0, 1.5)

func eye_position() -> Vector3:
	return head.global_position

func aim_dir() -> Vector3:
	return -camera.global_transform.basis.z

func speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

# ---------------------------------------------------------------- stats

func take_damage(amount: float, from_pos: Vector3) -> void:
	if not alive:
		return
	if Game.has_meta("god"):
		amount = 0.0
	var r := DamageModel.apply_to_player(amount, Game.integrity, Game.plating, Game.damage_taken_scale())
	var dealt: float = Game.integrity - r.integrity
	Game.integrity = r.integrity
	Game.plating = r.plating
	Game.stats.damage_taken += dealt
	hurt_flash = 1.0
	add_shake(0.25 + amount * 0.02)
	Synth.play(&"hurt", -2)
	Events.player_damaged.emit(amount, (from_pos - global_position).normalized())
	Events.player_stats_changed.emit()
	if Game.integrity <= 0.0:
		die()

func die() -> void:
	alive = false
	Synth.play(&"death")
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.3, 0.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(head, "rotation:z", 0.6, 0.6)
	Events.player_died.emit()

func heal(amount: float) -> void:
	Game.integrity = minf(Game.max_integrity, Game.integrity + amount)
	Events.player_stats_changed.emit()

func add_plating(amount: float) -> void:
	Game.plating = minf(Game.max_plating, Game.plating + amount)
	Events.player_stats_changed.emit()

func add_charge(amount: float) -> void:
	Game.charge = minf(100.0, Game.charge + amount)
	Events.player_stats_changed.emit()

func knockback(v: Vector3) -> void:
	velocity += v

func try_pulse() -> bool:
	var cost := Game.pulse_cost()
	if Game.charge < cost:
		Synth.play(&"empty")
		return false
	Game.charge -= cost
	Events.player_stats_changed.emit()
	Synth.play(&"pulse")
	FX.ring(self, global_position + Vector3.UP * 0.8, PULSE_RADIUS, Color(0.6, 0.9, 1.0), 0.6)
	add_shake(0.3)
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d <= PULSE_RADIUS:
			e.on_pulse()
		if d <= REVEAL_RADIUS:
			e.reveal(6.0)
	Events.pulse_fired.emit(global_position)
	return true

const PAD_DEADZONE := 0.15
const PAD_LOOK_SPEED := 3.2  # rad/s at full deflection and default sensitivity

func _pad_look(delta: float) -> void:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if v.length() < PAD_DEADZONE:
		return
	v = v.normalized() * inverse_lerp(PAD_DEADZONE, 1.0, minf(v.length(), 1.0))
	v *= v.length()  # response curve: fine aim near centre
	var k := PAD_LOOK_SPEED * delta * (Settings.mouse_sensitivity / 0.0025)
	rotate_look(-v.x * k, -v.y * k)

## Ledge check: wall ahead at chest height, free space above it, and a floor to stand on.
func _try_mantle(horiz: Vector3) -> bool:
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var chest := feet + Vector3.UP * 1.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + fwd * 0.9, 1, [get_rid()]))
	if hit.is_empty():
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.4, feet + Vector3.UP * 0.4 + fwd * 0.9, 1, [get_rid()]))
		if hit.is_empty():
			return false
	var top_probe: Vector3 = hit.position + fwd * 0.45 + Vector3.UP * (MANTLE_MAX + 0.6 - (hit.position.y - feet.y))
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3.DOWN * (MANTLE_MAX + 0.6), 1, [get_rid()]))
	if down.is_empty() or down.normal.y < 0.7:
		return false
	var rise: float = down.position.y - feet.y
	if rise < MANTLE_MIN or rise > MANTLE_MAX:
		return false
	# room for the standing capsule on top?
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = STAND_HEIGHT
	q.shape = cap
	q.transform = Transform3D(Basis(), down.position + Vector3.UP * (STAND_HEIGHT / 2.0 + 0.06))
	q.collision_mask = 1
	if space.intersect_shape(q, 1).size() > 0:
		return false
	mantle_from = global_position
	mantle_to = down.position + Vector3.UP * 0.05
	mantle_dir = fwd
	mantle_t = MANTLE_TIME
	land_dip = 0.1
	Synth.play(&"step", -2, 0.7)
	return true
