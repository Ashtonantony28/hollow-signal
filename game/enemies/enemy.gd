class_name Enemy
extends CharacterBody3D
## Base class for the Choir (DESIGN.md §5). Archetypes override _build() and _think().

enum State { IDLE, ALERT, ENGAGE, STAGGER, DEAD }

const GRAVITY := 15.0
const PERCEPTION_HZ := 5.0
const PATH_REFRESH := 0.6

var kind: StringName = &"tick"
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var shield := 0.0
var max_shield := 0.0
var band := 0
var state: State = State.IDLE
var level: Node = null          # Level (nav, squad, player)
var player: Player = null
var visual: Node3D
var shield_mesh: MeshInstance3D
var weak_mesh: MeshInstance3D
var reveal_mesh: MeshInstance3D
var has_token := false
var can_see := false
var dist_to_player := 999.0
var path := PackedVector3Array()
var path_idx := 0
var path_timer := 0.0
var perceive_timer := 0.0
var stagger_timer := 0.0
var reveal_timer := 0.0
var flash_timer := 0.0
var elite := false
var flying := false
var _rng := RandomNumberGenerator.new()

func setup(p_kind: StringName, p_band: int, p_level: Node, p_elite: bool = false) -> void:
	kind = p_kind
	def = EnemyData.get_def(kind)
	band = p_band
	level = p_level
	elite = p_elite
	var scale_hp := Game.enemy_hp_scale() * (1.6 if elite else 1.0)
	max_hp = def.hp * scale_hp
	hp = max_hp
	max_shield = def.shield * scale_hp
	shield = max_shield

func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = def.radius
	cap.height = maxf(def.height, def.radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position.y = cap.height / 2.0
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	_build()
	if weak_mesh == null:
		weak_mesh = Meshes.sphere(def.weak_radius * 0.8, Color(1.0, 0.25, 0.2), 4.0)
		weak_mesh.position = def.weak_offset
		visual.add_child(weak_mesh)
	if max_shield > 0.0:
		shield_mesh = Meshes.sphere(maxf(def.height, def.radius * 2.0) * 0.6, ThemeData.BAND_COLORS[band])
		var sm := SphereMesh.new()
		sm.radius = maxf(def.height, def.radius * 2.0) * 0.6
		sm.height = sm.radius * 2.0
		sm.radial_segments = 20
		sm.rings = 12
		shield_mesh.mesh = sm
		shield_mesh.material_override = Meshes.shield_material(band)
		shield_mesh.position.y = def.height * 0.5
		shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(shield_mesh)
	if elite:
		visual.scale = Vector3.ONE * 1.2
	player = get_tree().get_first_node_in_group("player") as Player
	perceive_timer = _rng.randf() / PERCEPTION_HZ
	path_timer = _rng.randf() * PATH_REFRESH

## Override: build the procedural mesh under `visual`.
func _build() -> void:
	visual.add_child(Meshes.box(Vector3(0.6, def.height, 0.6), Color.GRAY))

## Override: per-frame behaviour while engaged. Return desired horizontal velocity.
func _think(_delta: float) -> Vector3:
	return Vector3.ZERO

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
	flash_timer = maxf(flash_timer - delta, 0.0)
	visual.scale = Vector3.ONE * (1.2 if elite else 1.0) * (1.0 + flash_timer * 0.6)
	if reveal_timer > 0.0:
		reveal_timer -= delta
		if reveal_timer <= 0.0 and reveal_mesh:
			reveal_mesh.visible = false
	perceive_timer -= delta
	if perceive_timer <= 0.0:
		perceive_timer = 1.0 / PERCEPTION_HZ
		_perceive()
	var desired := Vector3.ZERO
	if stagger_timer > 0.0:
		stagger_timer -= delta
		visual.rotation.z = sin(stagger_timer * 40.0) * 0.15
		if stagger_timer <= 0.0:
			visual.rotation.z = 0.0
			state = State.ENGAGE
	elif state == State.ENGAGE or state == State.ALERT:
		desired = _think(delta)
	if not flying:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, desired.x, 40.0 * delta)
		velocity.z = move_toward(velocity.z, desired.z, 40.0 * delta)
	else:
		velocity = velocity.move_toward(desired, 20.0 * delta)
	move_and_slide()

func _perceive() -> void:
	var eye: Vector3 = global_position + Vector3.UP * float(def.height) * 0.85
	var target := player.eye_position()
	dist_to_player = eye.distance_to(target)
	can_see = false
	if dist_to_player < 60.0 and player.alive:
		var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
		can_see = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if state == State.IDLE and (can_see or dist_to_player < 10.0):
		alert()

func alert() -> void:
	if state == State.IDLE:
		state = State.ENGAGE
		# shared squad alert
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.state == State.IDLE and e.global_position.distance_to(global_position) < 14.0:
				e.state = State.ENGAGE

# ---------------------------------------------------------------- movement helpers

## Steering toward a world target using the grid path. Returns horizontal velocity.
func seek(target: Vector3, speed: float, delta: float) -> Vector3:
	path_timer -= delta
	var direct := can_see and global_position.distance_to(target) < 12.0
	if direct:
		var d := target - global_position
		d.y = 0
		return d.normalized() * speed + separation()
	if path_timer <= 0.0 or path_idx >= path.size():
		path_timer = PATH_REFRESH
		path = level.nav.path_world(global_position, target) if level and level.nav else PackedVector3Array()
		path_idx = 0
	while path_idx < path.size():
		var wp := path[path_idx]
		var to := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
		if to.length() < 1.2:
			path_idx += 1
			continue
		return to.normalized() * speed + separation()
	return Vector3.ZERO

func separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var l := d.length()
		if l < 1.6 and l > 0.001:
			push += d / l * (1.6 - l) * 3.0
	return push

func face(target: Vector3, delta: float, rate: float = 8.0) -> void:
	var d := target - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * rate, 0, 1))

func forward() -> Vector3:
	return -global_transform.basis.z

func request_token() -> bool:
	if has_token:
		return true
	if level and level.squad:
		has_token = level.squad.request(self)
	else:
		has_token = true
	return has_token

func release_token() -> void:
	if has_token and level and level.squad:
		level.squad.release(self)
	has_token = false

# ---------------------------------------------------------------- damage

func is_weak_hit(pos: Vector3) -> bool:
	var wp := visual.global_transform * (def.weak_offset as Vector3)
	return wp.distance_to(pos) <= float(def.weak_radius) * (1.2 if elite else 1.0) + 0.05

## Returns true if the hit should be fully blocked (e.g. Bulwark frontal barrier).
func blocks_hit(_pos: Vector3, _dir: Vector3) -> bool:
	return false

func take_hit(amount: float, hit_band: int, pos: Vector3, dir: Vector3) -> void:
	if state == State.DEAD:
		return
	alert()
	if blocks_hit(pos, dir):
		FX.spark(self, pos, Color(0.8, 0.9, 1.0), 0.12, 0.12)
		Synth.play_at(&"hit", pos, -6, 0.5)
		return
	var weak := is_weak_hit(pos)
	var had_shield := shield > 0.0
	var r := DamageModel.apply_hit(amount, hit_band, weak, shield, band, hp)
	shield = r.shield
	hp = r.hp
	Game.stats.damage_dealt += r.shield_damage + r.hp_damage
	if player:
		player.add_charge((r.shield_damage + r.hp_damage) * 0.12)
	flash_timer = 0.12
	if had_shield:
		FX.spark(self, pos, ThemeData.BAND_COLORS[band], 0.1 if not r.matched else 0.2)
		if r.matched and Game.mod_level(&"harmonic") > 0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and e.global_position.distance_to(global_position) < 5.0 and e.shield > 0.0:
					e.shield = maxf(0.0, e.shield - r.shield_damage * 0.25)
					e._update_shield_visual()
	else:
		FX.spark(self, pos, Color(1.0, 0.4, 0.25) if weak else Color(1.0, 0.75, 0.4), 0.1)
	if r.broke:
		Synth.play_at(&"shield_break", pos, 0)
		FX.shards(self, global_position + Vector3.UP * def.height * 0.5, ThemeData.BAND_COLORS[band], 8)
	_update_shield_visual()
	Events.enemy_hit.emit(self, r.shield_damage + r.hp_damage, weak, had_shield, r.matched)
	if hp <= 0.0:
		die()

func _update_shield_visual() -> void:
	if shield_mesh:
		shield_mesh.visible = shield > 0.0
		if max_shield > 0.0:
			(shield_mesh.material_override as ShaderMaterial).set_shader_parameter("strength", 0.35 + 0.65 * shield / max_shield)

func heal_shield(amount: float) -> void:
	if max_shield <= 0.0 or state == State.DEAD:
		return
	shield = minf(max_shield, shield + amount)
	_update_shield_visual()

func on_pulse() -> void:
	stagger(1.2)
	if shield > 0.0:
		# strip one "layer" = 50% of max shield regardless of band
		shield = maxf(0.0, shield - max_shield * 0.5)
		if shield <= 0.0:
			FX.shards(self, global_position + Vector3.UP * def.height * 0.5, ThemeData.BAND_COLORS[band], 8)
		_update_shield_visual()

func stagger(t: float) -> void:
	if state == State.DEAD:
		return
	alert()
	state = State.STAGGER
	stagger_timer = t
	release_token()

func reveal(t: float) -> void:
	reveal_timer = t
	if reveal_mesh == null:
		reveal_mesh = Meshes.sphere(maxf(def.height, 0.8) * 0.55, Color(1.0, 0.3, 0.3))
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.25, 0.25, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		reveal_mesh.material_override = m
		reveal_mesh.position.y = def.height * 0.5
		add_child(reveal_mesh)
	reveal_mesh.visible = true

func die() -> void:
	state = State.DEAD
	release_token()
	remove_from_group("enemies")
	collision_layer = 0
	Game.stats.kills += 1
	Synth.play_at(&"kill", global_position, 0)
	FX.shards(self, global_position + Vector3.UP * def.height * 0.5, Color(1.0, 0.5, 0.2), 10)
	FX.explosion(self, global_position + Vector3.UP * def.height * 0.5, 0.8, Color(1.0, 0.55, 0.25))
	Events.enemy_killed.emit(self)
	if level and level.has_method("on_enemy_killed"):
		level.on_enemy_killed(self)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.2, 0.05, 1.2), 0.18)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	release_token()
