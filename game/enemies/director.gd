class_name Director
extends Node
## Pacing system (DESIGN.md §5.1): spawns waves when the player enters rooms, trickles
## pressure over time, spikes during uplink calibration, backs off when the player is hurt.

const MAX_ALIVE := 22
const SPAWN_SCRIPTS := {
	&"tick": preload("res://game/enemies/tick.gd"),
	&"warden": preload("res://game/enemies/warden.gd"),
	&"lobber": preload("res://game/enemies/lobber.gd"),
	&"shrieker": preload("res://game/enemies/shrieker.gd"),
	&"bulwark": preload("res://game/enemies/bulwark.gd"),
}

var level: Node
var rng := RandomNumberGenerator.new()
var visited: Dictionary = {}
var trickle_timer := 30.0
var holdout := false
var holdout_timer := 3.0
var intensity := 0.0
var spawned_total := 0
var enabled := true

func _init(p_level: Node, seed_value: int) -> void:
	level = p_level
	rng.seed = seed_value

func alive_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("spawning").size()

func _process(delta: float) -> void:
	if not enabled or level.player == null or not level.player.alive:
		return
	var near := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(level.player.global_position) < 15.0:
			near += 1
	var target_int := clampf(near / 8.0 + (1.0 - Game.integrity / Game.max_integrity) * 0.4 + (0.4 if holdout else 0.0), 0.0, 1.0)
	intensity = lerpf(intensity, target_int, delta * 0.8)
	Synth.set_intensity(intensity)
	if holdout:
		holdout_timer -= delta
		if holdout_timer <= 0.0:
			holdout_timer = rng.randf_range(6.0, 9.0)
			spawn_wave_near(level.layout.uplink, Game.wave_budget(4), false)
	else:
		trickle_timer -= delta
		if trickle_timer <= 0.0:
			trickle_timer = rng.randf_range(28.0, 45.0)
			# back off when the player is low
			if Game.integrity / Game.max_integrity > 0.35:
				var room := _random_unseen_room()
				if room >= 0:
					spawn_wave(room, Game.wave_budget(3), false, true)

## Called when the player enters a room for the first time.
func on_room_entered(room: int) -> void:
	if visited.has(room):
		return
	visited[room] = true
	var t: StringName = level.layout.rooms[room].type
	match t:
		&"start", &"lift", &"boss":
			return
		&"arena":
			spawn_wave(room, Game.wave_budget(7), false)
		&"vault":
			spawn_wave(room, Game.wave_budget(6), true)
		&"cache":
			if rng.randf() < 0.5:
				spawn_wave(room, Game.wave_budget(3), false)
		&"uplink":
			spawn_wave(room, Game.wave_budget(3), false)
		_:
			if rng.randf() < 0.75:
				spawn_wave(room, Game.wave_budget(4), false)

func compose(budget: int, elite_ok: bool) -> Array:
	var types: Array[StringName] = []
	for k in EnemyData.UNLOCK:
		if EnemyData.UNLOCK[k] <= Game.deck_index:
			types.append(k)
	var out := []
	var remaining := budget
	var guard := 0
	while remaining > 0 and guard < 50:
		guard += 1
		var k: StringName = types[rng.randi_range(0, types.size() - 1)]
		var cost: int = EnemyData.DEFS[k].cost
		if cost > remaining:
			if remaining >= 1:
				k = &"tick"
				cost = 1
			else:
				break
		if k == &"tick":
			var pack := mini(rng.randi_range(2, 4), maxi(1, remaining))
			for i in pack:
				out.append({"kind": k, "elite": false})
			remaining -= pack
		else:
			var elite := elite_ok and rng.randf() < 0.25 + 0.08 * Game.deck_index
			out.append({"kind": k, "elite": elite})
			remaining -= cost
	return out

func spawn_wave(room: int, budget: int, elite_ok: bool, ambient: bool = false) -> int:
	var group := compose(budget, elite_ok)
	var cells: Array = level.layout.rooms[room].spawns.duplicate()
	var ppos: Vector3 = level.player.global_position
	cells.sort_custom(func(a, b): return DeckGen.cell_to_world(a).distance_to(ppos) > DeckGen.cell_to_world(b).distance_to(ppos))
	var n := 0
	for i in group.size():
		if alive_count() >= MAX_ALIVE:
			break
		if cells.is_empty():
			break
		var c: Vector2i = cells[mini(i, cells.size() - 1)] if i < cells.size() else cells[rng.randi_range(0, cells.size() - 1)]
		var pos := DeckGen.cell_to_world(c) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if pos.distance_to(ppos) < 7.0 and not ambient:
			continue
		spawn(group[i].kind, pos, group[i].elite, ambient)
		n += 1
	return n

func spawn_wave_near(room: int, budget: int, elite_ok: bool) -> void:
	# pick a neighbour room (or the room itself) as the spawn source
	var options: Array[int] = [room]
	for e in level.layout.edges:
		if e.x == room:
			options.append(e.y)
		elif e.y == room:
			options.append(e.x)
	spawn_wave(options[rng.randi_range(0, options.size() - 1)], budget, elite_ok, true)

func _random_unseen_room() -> int:
	var opts: Array[int] = []
	for i in level.layout.rooms.size():
		if not visited.has(i) and level.layout.rooms[i].type in [&"hub", &"corridor", &"cache", &"arena"]:
			opts.append(i)
	if opts.is_empty():
		for i in level.layout.rooms.size():
			if level.layout.rooms[i].type == &"hub":
				opts.append(i)
	return -1 if opts.is_empty() else opts[rng.randi_range(0, opts.size() - 1)]

## Spawns with a short warp-in telegraph so ambushes are readable and fair.
func spawn(kind: StringName, pos: Vector3, elite: bool, aggressive: bool) -> void:
	var b := rng.randi_range(0, 2)
	var marker := Node3D.new()
	marker.add_to_group("spawning")
	level.add_child(marker)
	marker.global_position = pos
	var orb := Meshes.sphere(0.3, ThemeData.BAND_COLORS[b], 4.0, 0.7)
	orb.material_override = Meshes.mat(ThemeData.BAND_COLORS[b], 4.0, true, 0.7)
	orb.position.y = 1.0
	marker.add_child(orb)
	var tw := marker.create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 3.0, 0.7)
	tw.tween_callback(func():
		if not is_instance_valid(level):
			return
		var e: Enemy = SPAWN_SCRIPTS[kind].new()
		e.setup(kind, b, level, elite)
		level.add_child(e)
		e.global_position = pos + Vector3.UP * 0.1
		if aggressive:
			e.state = Enemy.State.ENGAGE
		spawned_total += 1
		marker.queue_free())

## Spawns immediately with no telegraph (tests, debug).
func spawn_now(kind: StringName, pos: Vector3, b: int = 0, elite: bool = false) -> Enemy:
	var e: Enemy = SPAWN_SCRIPTS[kind].new()
	e.setup(kind, b, level, elite)
	level.add_child(e)
	e.global_position = pos
	spawned_total += 1
	return e
