class_name Level
extends Node3D
## One deck: generation → build → player → objectives (core → uplink hold-out → lift).
## DESIGN.md §7.

enum Phase { FIND_CORE, CALIBRATE, HOLDOUT, EXTRACT, BOSS, DONE }

const UPLINK_RADIUS := 7.0
const LIFT_RADIUS := 2.6

var deck_index := 0
var seed_value := 0
var layout: Dictionary
var nav: NavGrid
var squad: Squad
var director: Director
var player: Player
var phase: Phase = Phase.FIND_CORE
var has_core := false
var holdout_time := 0.0
var holdout_total := 45.0
var lift_timer := 0.0
var current_room := -1
var core_node: Node3D
var uplink_node: Node3D
var uplink_ring: MeshInstance3D
var lift_node: Node3D
var lift_ring: MeshInstance3D
var boss: Node = null
var drop_rng := RandomNumberGenerator.new()
var _uplink_tick := 0.0

func _init(p_deck: int, p_seed: int) -> void:
	deck_index = p_deck
	seed_value = p_seed
	name = "Level"

func _ready() -> void:
	layout = DeckGen.generate(seed_value, deck_index)
	drop_rng.seed = seed_value + 99
	add_child(DeckBuilder.build(layout, Settings.quality))
	nav = NavGrid.new(layout)
	squad = Squad.new(Game.attack_tokens())
	director = Director.new(self, seed_value + 5)
	director.name = "Director"
	add_child(director)
	holdout_total = 45.0 + 6.0 * deck_index
	_build_objectives()
	_place_caches()
	player = Player.new()
	player.level = self
	add_child(player)
	var start_room: Dictionary = layout.rooms[layout.start]
	player.global_position = DeckGen.cell_to_world(start_room.center, 0.1)
	# face the first corridor
	player.rotation.y = randf() * TAU
	set_objective()
	Events.message.emit("DECK %d — %s" % [deck_index + 1, ThemeData.deck(deck_index).name.to_upper()], 3.0)

func _build_objectives() -> void:
	var theme := ThemeData.deck(deck_index)
	# Tuning Core in the vault
	core_node = Node3D.new()
	add_child(core_node)
	core_node.global_position = DeckGen.cell_to_world(layout.rooms[layout.vault].center, 0.0)
	var ped := Meshes.cyl(0.6, 1.0, (theme.wall as Color).darkened(0.2), 0.0, 8)
	ped.position.y = 0.5
	core_node.add_child(ped)
	var gem := Meshes.prism(Vector3(0.5, 0.7, 0.5), Color(0.4, 1.0, 0.9), 4.0)
	gem.name = "Gem"
	gem.position.y = 1.6
	core_node.add_child(gem)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.4, 1.0, 0.9)
	gl.light_energy = 1.5
	gl.omni_range = 6.0
	gl.position.y = 1.6
	core_node.add_child(gl)
	# Uplink terminal
	uplink_node = Node3D.new()
	add_child(uplink_node)
	uplink_node.global_position = DeckGen.cell_to_world(layout.rooms[layout.uplink].center, 0.0)
	var mast := Meshes.box(Vector3(0.8, 3.2, 0.8), (theme.wall as Color).lightened(0.1))
	mast.position.y = 1.6
	uplink_node.add_child(mast)
	var dish := Meshes.cyl(1.4, 0.15, (theme.wall as Color).lightened(0.2), 0.0, 12)
	dish.position.y = 3.3
	dish.rotation_degrees.x = 25
	uplink_node.add_child(dish)
	var screen := Meshes.box(Vector3(0.6, 0.4, 0.05), theme.trim, 2.5)
	screen.position = Vector3(0, 1.4, -0.43)
	uplink_node.add_child(screen)
	uplink_ring = _ring(UPLINK_RADIUS, Color(1.0, 0.3, 0.3))
	uplink_node.add_child(uplink_ring)
	# Lift
	lift_node = Node3D.new()
	add_child(lift_node)
	lift_node.global_position = DeckGen.cell_to_world(layout.rooms[layout.lift].center, 0.0)
	if not layout.boss:
		var plat := Meshes.cyl(LIFT_RADIUS, 0.12, Color(0.2, 0.2, 0.22), 0.0, 16)
		plat.position.y = 0.06
		lift_node.add_child(plat)
		for i in 4:
			var post := Meshes.box(Vector3(0.25, 3.0, 0.25), Color(0.3, 0.3, 0.33))
			post.position = Vector3(cos(i * PI / 2) * LIFT_RADIUS, 1.5, sin(i * PI / 2) * LIFT_RADIUS)
			lift_node.add_child(post)
	lift_ring = _ring(LIFT_RADIUS, Color(1.0, 0.2, 0.2))
	lift_node.add_child(lift_ring)

func _ring(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.12
	tm.outer_radius = r
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = Meshes.mat(c, 2.5, true)
	mi.position.y = 0.05
	mi.scale.y = 0.3
	return mi

func _place_caches() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + 3
	var kinds: Array[StringName] = [&"repair", &"plating", &"ammo", &"ammo", &"charge"]
	for i in layout.rooms.size():
		var room: Dictionary = layout.rooms[i]
		var count := 0
		match room.type:
			&"cache": count = 4
			&"vault", &"uplink": count = 2
			&"arena": count = 2
			&"hub": count = 1 if r.randf() < 0.5 else 0
		for j in count:
			if room.spawns.is_empty():
				break
			var c: Vector2i = room.spawns[r.randi_range(0, room.spawns.size() - 1)]
			spawn_pickup(kinds[r.randi_range(0, kinds.size() - 1)], DeckGen.cell_to_world(c))

func spawn_pickup(kind: StringName, pos: Vector3) -> void:
	var p := Pickup.new()
	p.kind = kind
	add_child(p)
	p.global_position = pos

func set_objective() -> void:
	match phase:
		Phase.FIND_CORE: Events.objective_changed.emit("Recover the Tuning Core")
		Phase.CALIBRATE: Events.objective_changed.emit("Insert the core at the uplink  [E]")
		Phase.HOLDOUT: Events.objective_changed.emit("Hold the uplink zone")
		Phase.EXTRACT: Events.objective_changed.emit("Reach the lift")
		Phase.BOSS: Events.objective_changed.emit("Silence the Conductor")
		Phase.DONE: Events.objective_changed.emit("")

## World position the HUD compass and the autopilot should head for.
func objective_position() -> Vector3:
	match phase:
		Phase.FIND_CORE: return core_node.global_position
		Phase.CALIBRATE, Phase.HOLDOUT: return uplink_node.global_position
		Phase.BOSS:
			if boss and is_instance_valid(boss):
				return boss.global_position
			return lift_node.global_position
		_: return lift_node.global_position

func _physics_process(delta: float) -> void:
	if player == null or not player.alive:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# room tracking for the director
	var c := DeckGen.world_to_cell(player.global_position)
	if c.x >= 0 and c.y >= 0 and c.x < layout.w and c.y < layout.h:
		var rid: int = layout.room_id[c.y * layout.w + c.x]
		if rid >= 0 and rid != current_room:
			current_room = rid
			director.on_room_entered(rid)
	var pp := player.global_position
	match phase:
		Phase.FIND_CORE:
			var gem := core_node.get_node("Gem") as Node3D
			gem.rotation.y = t * 1.5
			gem.position.y = 1.6 + sin(t * 2.0) * 0.12
			if _flat_dist(pp, core_node.global_position) < 1.6:
				has_core = true
				gem.visible = false
				Synth.play(&"objective")
				Events.message.emit("TUNING CORE RECOVERED", 2.5)
				uplink_ring.material_override = Meshes.mat(Color(1.0, 0.8, 0.2), 2.5, true)
				phase = Phase.CALIBRATE
				set_objective()
		Phase.CALIBRATE:
			if _flat_dist(pp, uplink_node.global_position) < 2.5 and (Input.is_action_just_pressed("interact") or player.ai_controlled):
				phase = Phase.HOLDOUT
				holdout_time = 0.0
				director.holdout = true
				director.holdout_timer = 2.0
				Synth.play(&"objective")
				Events.message.emit("CALIBRATION STARTED — HOLD THE ZONE", 2.5)
				set_objective()
		Phase.HOLDOUT:
			var inside := _flat_dist(pp, uplink_node.global_position) < UPLINK_RADIUS
			if inside:
				holdout_time += delta
				_uplink_tick -= delta
				if _uplink_tick <= 0.0:
					_uplink_tick = 1.0
					Synth.play(&"uplink_tick", -10, 1.0 + holdout_time / holdout_total)
			uplink_ring.material_override = Meshes.mat(Color(0.3, 1.0, 0.5) if inside else Color(1.0, 0.8, 0.2), 2.5, true)
			Events.uplink_progress.emit(holdout_time / holdout_total, inside)
			if holdout_time >= holdout_total:
				director.holdout = false
				Events.uplink_progress.emit(1.0, false)
				Synth.play(&"objective")
				if layout.boss:
					phase = Phase.BOSS
					_start_boss()
				else:
					phase = Phase.EXTRACT
					Events.message.emit("SIGNAL RESTORED — LIFT ONLINE", 3.0)
					lift_ring.material_override = Meshes.mat(Color(0.3, 1.0, 0.5), 2.5, true)
				set_objective()
		Phase.EXTRACT:
			if _flat_dist(pp, lift_node.global_position) < LIFT_RADIUS:
				lift_timer += delta
				if lift_timer > 1.2:
					phase = Phase.DONE
					Synth.play(&"lift")
					director.enabled = false
					set_objective()
					Events.deck_completed.emit(deck_index)
			else:
				lift_timer = 0.0
		Phase.BOSS:
			if boss == null or not is_instance_valid(boss) or boss.is_dead():
				phase = Phase.DONE
				director.enabled = false
				set_objective()
				Events.run_finished.emit(true)

func _start_boss() -> void:
	Events.message.emit("THE CONDUCTOR AWAKENS", 3.0)
	var b := Conductor.new()
	b.level = self
	add_child(b)
	b.global_position = lift_node.global_position + Vector3.UP * 4.5
	boss = b
	director.enabled = true

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func on_enemy_killed(e: Enemy) -> void:
	var chance: float = e.def.drop_chance + 0.15 * Game.mod_level(&"reclaimer")
	if drop_rng.randf() < chance:
		var kinds: Array[StringName] = [&"ammo", &"ammo", &"repair", &"plating", &"charge"]
		if Game.mod_level(&"reclaimer") > 0 and drop_rng.randf() < 0.3:
			spawn_pickup(&"repair", e.global_position)
		else:
			spawn_pickup(kinds[drop_rng.randi_range(0, kinds.size() - 1)], e.global_position)
