class_name Conductor
extends StaticBody3D
## Deck 5 boss (DESIGN.md §8). Three phases, band rotates per phase:
##  P1 LOW  — chest-height beam sweep (slide/crouch under), Tick summons.
##  P2 MID  — core sealed until 3 orbiting shield nodes are broken; Warden summons.
##  P3 HIGH — core exposed, glob volleys, Shrieker summons; enrage under 15%.

const BEAM_HEIGHT := 1.35
const BEAM_LENGTH := 34.0

var level: Node
var max_hp := 2500.0
var hp := 2500.0
var max_shield := 300.0
var shield := 300.0
var band := 0
var phase := 1
var dead := false
var core: MeshInstance3D
var shell: MeshInstance3D
var beam: MeshInstance3D
var beam_angle := 0.0
var beam_active := 0.0
var beam_cd := 5.0
var beam_hit_cd := 0.0
var summon_cd := 6.0
var volley_cd := 3.0
var nodes: Array = []   # [{body, hp, band, mesh}]
var t := 0.0
var max_tokens_backup := 0

func _ready() -> void:
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 0
	var scale_hp := Game.enemy_hp_scale()
	max_hp *= scale_hp
	hp = max_hp
	max_shield *= scale_hp
	shield = max_shield
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.6
	cs.shape = sp
	add_child(cs)
	core = Meshes.sphere(1.3, Color(0.9, 0.2, 0.3), 3.0)
	add_child(core)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.0 + i * 0.5
		tm.outer_radius = 2.15 + i * 0.5
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = Meshes.mat(Color(0.35, 0.35, 0.4))
		ring.name = "Ring%d" % i
		add_child(ring)
	shell = Meshes.sphere(1.7, ThemeData.BAND_COLORS[0], 1.0, 0.3)
	shell.material_override = Meshes.mat(ThemeData.BAND_COLORS[0], 1.2, true, 0.25)
	add_child(shell)
	beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BEAM_LENGTH, 0.25, 0.25)
	beam.mesh = bm
	beam.material_override = Meshes.mat(Color(1.0, 0.25, 0.3), 4.0, true)
	beam.top_level = true
	beam.visible = false
	add_child(beam)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.3, 0.4)
	l.light_energy = 2.0
	l.omni_range = 18.0
	add_child(l)
	_set_band(0)

func is_dead() -> bool:
	return dead

func _set_band(b: int) -> void:
	band = b
	shell.material_override = Meshes.mat(ThemeData.BAND_COLORS[b], 1.2, true, 0.25)

func _process(delta: float) -> void:
	if dead:
		return
	t += delta
	for i in 3:
		var r := get_node("Ring%d" % i) as Node3D
		r.rotation = Vector3(t * (0.6 + i * 0.3), t * (0.4 - i * 0.2), 0)
	position.y = 4.5 + sin(t) * 0.3
	var player: Player = level.player
	if player == null or not player.alive:
		return
	var enrage := 1.5 if hp < max_hp * 0.15 else 1.0
	# phase transitions
	if phase == 1 and hp <= max_hp * 0.66:
		_enter_phase(2)
	if phase == 2 and nodes.is_empty():
		_enter_phase(3)
	# beam sweep (P1 + P3)
	beam_cd -= delta * enrage
	if beam_active > 0.0:
		beam_active -= delta
		beam_angle += delta * 1.4 * enrage
		var floor_pos := Vector3(global_position.x, BEAM_HEIGHT, global_position.z)
		var dir := Vector3(cos(beam_angle), 0, sin(beam_angle))
		beam.global_position = floor_pos + dir * BEAM_LENGTH * 0.5
		beam.rotation = Vector3(0, -beam_angle, 0)
		beam_hit_cd -= delta
		var to_p := player.global_position - floor_pos
		to_p.y = 0
		var along := to_p.dot(dir)
		var perp := (to_p - dir * along).length()
		if along > 0.0 and along < BEAM_LENGTH and perp < 0.7 and not player.crouching and beam_hit_cd <= 0.0:
			beam_hit_cd = 0.6
			player.take_damage(22.0, floor_pos)
		if beam_active <= 0.0:
			beam.visible = false
	elif beam_cd <= 0.0 and phase != 2:
		beam_cd = 9.0
		beam_active = 4.5
		beam_angle = atan2(player.global_position.z - global_position.z, player.global_position.x - global_position.x) + PI * 0.5
		beam.visible = true
		Events.message.emit("SLIDE UNDER THE BEAM", 1.5)
		Synth.play(&"telegraph", 0, 0.5)
	# summons
	summon_cd -= delta
	if summon_cd <= 0.0 and level.director.alive_count() < 10:
		summon_cd = 12.0 / enrage
		var kinds := {1: &"tick", 2: &"warden", 3: &"shrieker"}
		var kind: StringName = kinds[phase]
		var count := 4 if kind == &"tick" else 2
		for i in count:
			var a := randf() * TAU
			var pos := Vector3(global_position.x + cos(a) * 9.0, 0.1, global_position.z + sin(a) * 9.0)
			level.director.spawn(kind, pos, false, true)
	# volleys (P3)
	if phase == 3:
		volley_cd -= delta * enrage
		if volley_cd <= 0.0:
			volley_cd = 2.6
			for i in 3:
				var g := Glob.new()
				g.damage = 14.0
				g.color = ThemeData.BAND_COLORS[2]
				var target := player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
				g.velocity = Lobber.ballistic(global_position, target, Glob.GRAVITY, 1.0)
				level.add_child(g)
				g.global_position = global_position
			Synth.play_at(&"glob", global_position, 2)
	# orbiting nodes (P2)
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var a := t * 0.8 + i * TAU / 3.0
		(n.body as Node3D).position = Vector3(cos(a) * 4.0, sin(t * 2.0 + i) * 0.5, sin(a) * 4.0)

func _enter_phase(p: int) -> void:
	phase = p
	_set_band(p - 1)
	shield = max_shield
	shell.visible = true
	beam_active = 0.0
	beam.visible = false
	Synth.play(&"objective", 0, 0.7)
	if p == 2:
		Events.message.emit("SHIELD NODES DEPLOYED — BREAK THEM", 2.5)
		for i in 3:
			var body := ConductorNode.new()
			body.boss = self
			body.node_band = i
			add_child(body)
			nodes.append({"body": body})
	elif p == 3:
		Events.message.emit("CORE EXPOSED", 2.0)

func node_destroyed(n: Node) -> void:
	for i in nodes.size():
		if nodes[i].body == n:
			nodes.remove_at(i)
			break

func take_hit(amount: float, hit_band: int, pos: Vector3, _dir: Vector3) -> void:
	if dead:
		return
	if phase == 2 and not nodes.is_empty():
		FX.spark(self, pos, Color(0.8, 0.9, 1.0), 0.15)
		return
	var had := shield > 0.0
	var r := DamageModel.apply_hit(amount, hit_band, false, shield, band, hp)
	shield = r.shield
	hp = r.hp
	Game.stats.damage_dealt += r.shield_damage + r.hp_damage
	if level.player:
		level.player.add_charge((r.shield_damage + r.hp_damage) * 0.1)
	shell.visible = shield > 0.0
	FX.spark(self, pos, ThemeData.BAND_COLORS[band] if had else Color(1, 0.5, 0.3), 0.25)
	if r.broke:
		Synth.play(&"shield_break")
	Events.enemy_hit.emit(self, r.shield_damage + r.hp_damage, false, had, r.matched)
	if hp <= 0.0:
		_die()

func on_pulse() -> void:
	if shield > 0.0:
		shield = maxf(0.0, shield - max_shield * 0.34)
		shell.visible = shield > 0.0

func reveal(_t: float) -> void:
	pass

func _die() -> void:
	dead = true
	beam.visible = false
	Game.stats.kills += 1
	for i in 6:
		var off := Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		FX.explosion(self, global_position + off, 3.0, Color(1.0, 0.4, 0.3))
	Synth.play(&"death", 4, 0.7)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.die()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 1.2)
	tw.tween_callback(queue_free)
