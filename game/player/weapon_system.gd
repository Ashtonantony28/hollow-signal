class_name WeaponSystem
extends Node3D
## Weapons, bands, viewmodels (DESIGN.md §3.4, §4). Child of the player camera.

const RAY_MASK := 1 | 4

var player: Player
var current: StringName = &"rivet"
var band: int = 0
var cooldown := 0.0
var reloading := 0.0
var retuning := 0.0
var switching := 0.0
var charge := 0.0           # Arc Lance charge time
var charging := false
var retune_bonus := false   # Quick Tuner: first shot after retune
var models: Dictionary = {}
var accents: Array[MeshInstance3D] = []
var muzzle_flash: MeshInstance3D
var flash_light: OmniLight3D
var sway := Vector2.ZERO
var kick := 0.0
var unlocked: Array[StringName] = [&"rivet", &"scatter", &"lance", &"launcher"]
var fire_held_prev := false

func _ready() -> void:
	for id in WeaponData.ORDER:
		var m := _build_model(id)
		m.visible = false
		add_child(m)
		models[id] = m
	muzzle_flash = Meshes.sphere(0.07, Color(1, 0.9, 0.6), 6.0)
	muzzle_flash.material_override = Meshes.mat(Color(1, 0.9, 0.6), 6.0, true)
	muzzle_flash.visible = false
	add_child(muzzle_flash)
	flash_light = OmniLight3D.new()
	flash_light.light_energy = 0.0
	flash_light.omni_range = 6.0
	flash_light.light_color = Color(1, 0.85, 0.6)
	add_child(flash_light)
	equip(&"rivet", true)
	set_band(0, true)

# ---------------------------------------------------------------- viewmodels

func _build_model(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.22, -0.2, -0.42)
	var body_col := Color(0.18, 0.19, 0.22)
	var metal := Color(0.32, 0.33, 0.37)
	match id:
		&"rivet":
			_part(root, Meshes.box(Vector3(0.07, 0.09, 0.3), body_col), Vector3(0, 0, 0))
			_part(root, Meshes.box(Vector3(0.06, 0.15, 0.07), metal), Vector3(0, -0.1, 0.08), Vector3(-15, 0, 0))
			_part(root, Meshes.cyl(0.018, 0.12, metal), Vector3(0, 0.01, -0.2), Vector3(90, 0, 0))
			_accent(root, Meshes.box(Vector3(0.075, 0.015, 0.2), Color.WHITE, 3.0), Vector3(0, 0.05, -0.02))
		&"scatter":
			_part(root, Meshes.box(Vector3(0.11, 0.11, 0.5), body_col), Vector3(0, 0, -0.05))
			_part(root, Meshes.cyl(0.032, 0.28, metal), Vector3(0.025, 0.01, -0.38), Vector3(90, 0, 0))
			_part(root, Meshes.cyl(0.032, 0.28, metal), Vector3(-0.025, 0.01, -0.38), Vector3(90, 0, 0))
			_part(root, Meshes.box(Vector3(0.08, 0.16, 0.08), metal), Vector3(0, -0.11, 0.1), Vector3(-15, 0, 0))
			for i in 3:
				_accent(root, Meshes.cyl(0.06, 0.02, Color.WHITE, 3.0, 10), Vector3(0, 0.0, -0.12 - i * 0.07), Vector3(90, 0, 0))
		&"lance":
			_part(root, Meshes.box(Vector3(0.09, 0.12, 0.62), body_col), Vector3(0, 0, -0.1))
			_part(root, Meshes.prism(Vector3(0.08, 0.1, 0.2), metal), Vector3(0, 0.1, -0.05))
			_part(root, Meshes.box(Vector3(0.07, 0.15, 0.07), metal), Vector3(0, -0.12, 0.08), Vector3(-15, 0, 0))
			_accent(root, Meshes.box(Vector3(0.02, 0.02, 0.55), Color.WHITE, 3.0), Vector3(0.05, 0.03, -0.12))
			_accent(root, Meshes.box(Vector3(0.02, 0.02, 0.55), Color.WHITE, 3.0), Vector3(-0.05, 0.03, -0.12))
			_accent(root, Meshes.sphere(0.035, Color.WHITE, 4.0), Vector3(0, 0, -0.44))
		&"launcher":
			_part(root, Meshes.cyl(0.075, 0.5, body_col, 0.0, 10), Vector3(0, 0, -0.1), Vector3(90, 0, 0))
			_part(root, Meshes.box(Vector3(0.07, 0.16, 0.08), metal), Vector3(0, -0.13, 0.08), Vector3(-15, 0, 0))
			_part(root, Meshes.box(Vector3(0.05, 0.05, 0.18), metal), Vector3(0, 0.09, 0.0))
			_accent(root, Meshes.cyl(0.08, 0.03, Color.WHITE, 3.0, 10), Vector3(0, 0, -0.36), Vector3(90, 0, 0))
			_accent(root, Meshes.cyl(0.08, 0.03, Color.WHITE, 3.0, 10), Vector3(0, 0, 0.1), Vector3(90, 0, 0))
	for c in root.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

func _part(root: Node3D, mi: MeshInstance3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	mi.position = pos
	mi.rotation_degrees = rot_deg
	root.add_child(mi)

func _accent(root: Node3D, mi: MeshInstance3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	_part(root, mi, pos, rot_deg)
	accents.append(mi)

func muzzle_pos() -> Vector3:
	var m: Node3D = models[current]
	return m.global_transform * Vector3(0, 0.01, -0.5)

# ---------------------------------------------------------------- state

func equip(id: StringName, instant: bool = false) -> void:
	if id == current and not instant:
		return
	if not id in unlocked:
		return
	models[current].visible = false
	current = id
	models[current].visible = true
	reloading = 0.0
	charging = false
	charge = 0.0
	switching = 0.0 if instant else 0.3
	Events.weapon_changed.emit(id)
	_emit_ammo()

func set_band(b: int, silent: bool = false) -> void:
	band = posmod(b, 3)
	var col: Color = ThemeData.BAND_COLORS[band]
	for a in accents:
		a.material_override = Meshes.mat(col, 3.0, true)
	if not silent:
		retuning = Game.retune_time()
		retune_bonus = Game.mod_level(&"quick_tuner") > 0
		Synth.play(&"retune", -4, 0.8 + band * 0.25)
	Events.band_changed.emit(band)

func def() -> Dictionary:
	return WeaponData.get_def(current)

func ammo() -> Dictionary:
	return Game.ammo[current]

func _emit_ammo() -> void:
	var a := ammo()
	Events.ammo_changed.emit(a.mag, a.reserve)

func start_reload() -> void:
	var a := ammo()
	var d := def()
	if reloading > 0.0 or a.mag >= d.mag:
		return
	if a.reserve == 0:
		return
	reloading = d.reload_time
	charging = false
	Synth.play(&"reload", -6)

func _finish_reload() -> void:
	var a := ammo()
	var d := def()
	var need: int = d.mag - a.mag
	if a.reserve < 0:
		a.mag = d.mag
	else:
		var take := mini(need, a.reserve)
		a.mag += take
		a.reserve -= take
	_emit_ammo()

func add_feedstock(fraction: float) -> void:
	for id in WeaponData.ORDER:
		var mx := Game.reserve_max(id)
		if mx < 0:
			continue
		var a: Dictionary = Game.ammo[id]
		var f := fraction if id == current else fraction * 0.5
		a.reserve = mini(mx, a.reserve + maxi(1, int(ceil(mx * f))))
	_emit_ammo()

# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	if player == null or not player.alive:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	switching = maxf(switching - delta, 0.0)
	if retuning > 0.0:
		retuning = maxf(retuning - delta, 0.0)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			_finish_reload()
	if not player.ai_controlled:
		_handle_input()
	_handle_fire(delta)
	_animate(delta)

func _handle_input() -> void:
	for i in WeaponData.ORDER.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			equip(WeaponData.ORDER[i])
	if Input.is_action_just_pressed("weapon_next"):
		cycle(1)
	if Input.is_action_just_pressed("weapon_prev"):
		cycle(-1)
	if Input.is_action_just_pressed("retune"):
		set_band(band + 1)
	if Input.is_action_just_pressed("reload"):
		start_reload()

func cycle(dir: int) -> void:
	var idx := WeaponData.ORDER.find(current)
	equip(WeaponData.ORDER[posmod(idx + dir, WeaponData.ORDER.size())])

func can_fire() -> bool:
	return cooldown <= 0.0 and reloading <= 0.0 and retuning <= 0.0 and switching <= 0.0

func _handle_fire(delta: float) -> void:
	var held := player._pressed(&"fire")
	var just := held and not fire_held_prev
	fire_held_prev = held
	var d := def()
	var a := ammo()
	if d.kind == "beam":
		if held and can_fire() and a.mag > 0:
			if not charging:
				charging = true
				charge = 0.0
				Synth.play(&"lance_charge", -8)
			charge += delta
		elif charging and not held:
			charging = false
			if a.mag > 0:
				_fire(d)
		return
	if a.mag <= 0:
		if just:
			Synth.play(&"empty")
			start_reload()
		return
	if (just or (held and d.auto)) and can_fire():
		_fire(d)

func _fire(d: Dictionary) -> void:
	var a := ammo()
	a.mag -= 1
	cooldown = d.fire_interval
	Game.stats.shots += 1
	var mult := 1.0
	if retune_bonus:
		mult *= 1.5
		retune_bonus = false
	if Game.mod_level(&"momentum") > 0 and player.speed() > 9.0:
		mult *= 1.0 + 0.2 * Game.mod_level(&"momentum")
	Synth.play(d.sound, -3)
	player.add_recoil(d.recoil)
	kick = 1.0
	_flash()
	match d.kind:
		"hitscan":
			var any_hit := false
			for i in d.pellets:
				if _hitscan(d.damage * mult, d.spread_deg, d.range, 1):
					any_hit = true
			if any_hit:
				Game.stats.hits += 1
		"beam":
			var dmg := DamageModel.lance_damage(d.damage, d.damage_max, charge, d.charge_time) * mult
			if _hitscan(dmg, 0.0, d.range, d.pierce, 0.09):
				Game.stats.hits += 1
			charge = 0.0
		"projectile":
			_launch(d, mult)
	if a.mag <= 0:
		start_reload()
	_emit_ammo()

func _flash() -> void:
	muzzle_flash.global_position = muzzle_pos()
	muzzle_flash.visible = true
	flash_light.global_position = muzzle_pos()
	flash_light.light_energy = 2.5
	get_tree().create_timer(0.04).timeout.connect(func():
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
			flash_light.light_energy = 0.0)

## Casts one (possibly piercing) ray. Returns true if any enemy was hit.
func _hitscan(damage: float, spread_deg: float, rng: float, pierce: int, width: float = 0.03) -> bool:
	var origin := player.eye_position()
	var dir := player.aim_dir()
	if spread_deg > 0.0:
		var s := deg_to_rad(spread_deg)
		var b := player.camera.global_transform.basis
		dir = (dir + b.x * randf_range(-s, s) + b.y * randf_range(-s, s)).normalized()
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var hit_enemy := false
	var end := origin + dir * rng
	var col: Color = ThemeData.BAND_COLORS[band]
	for i in pierce:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * rng, RAY_MASK, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		end = r.position
		var c: Object = r.collider
		if c != null and c.has_method("take_hit"):
			c.take_hit(damage, band, r.position, dir)
			hit_enemy = true
			exclude.append(c.get_rid())
		else:
			FX.spark(player, r.position + r.normal * 0.05, Color(1.0, 0.8, 0.5), 0.07, 0.1)
			break
	FX.tracer(player, muzzle_pos(), end, col, width)
	return hit_enemy

func _launch(d: Dictionary, mult: float) -> void:
	var p := Projectile.new()
	p.damage = d.damage * mult
	p.radius = d.splash_radius
	p.band = band
	p.owner_player = player
	p.self_scale = d.self_damage_scale
	p.self_knockback = d.self_knockback
	p.velocity = player.aim_dir() * d.projectile_speed + Vector3.UP * 2.0
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle_pos()

func _animate(delta: float) -> void:
	var m: Node3D = models[current]
	kick = move_toward(kick, 0.0, delta * 6.0)
	var spd := player.speed()
	var t := Time.get_ticks_msec() / 1000.0
	var bob := Vector3(sin(t * 7.0) * 0.006, absf(cos(t * 7.0)) * 0.008, 0) * clampf(spd / 7.5, 0, 1.5)
	var base := Vector3(0.22, -0.2, -0.42)
	if reloading > 0.0:
		base += Vector3(0, -0.12, 0.05)
	if switching > 0.0:
		base += Vector3(0, -0.3 * switching / 0.3, 0)
	if retuning > 0.0:
		base += Vector3(-0.03, 0.02, 0)
	var charge_shake := Vector3.ZERO
	if charging:
		var c := clampf(charge / 0.8, 0, 1)
		charge_shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.003 * c
	m.position = m.position.lerp(base + bob + Vector3(0, 0, kick * 0.08) + charge_shake, clampf(delta * 18.0, 0, 1))
	m.rotation.x = lerpf(m.rotation.x, kick * 0.25, clampf(delta * 18.0, 0, 1))
	m.rotation.z = lerpf(m.rotation.z, -1.2 if retuning > 0.0 else 0.0, clampf(delta * 14.0, 0, 1))
