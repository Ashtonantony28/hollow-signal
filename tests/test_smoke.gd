extends TestBase
## Boots real decks headless and lets the autopilot play them (god mode) for a while.

func _play(deck: int, seconds: float) -> Level:
	Game.new_run(77)
	Game.deck_index = deck
	Game.set_meta("god", true)
	var level := Level.new(deck, Game.deck_seed())
	get_tree().root.add_child(level)
	var bot := Autopilot.new()
	bot.player = level.player
	bot.level = level
	level.add_child(bot)
	Engine.time_scale = 4.0
	await frames(int(seconds * 60.0))
	Engine.time_scale = 1.0
	return level

func test_bot_progresses_on_deck_1() -> void:
	var start_kills: int = Game.stats.kills
	var level := await _play(0, 25.0)
	check(level.player.global_position.distance_to(DeckGen.cell_to_world(level.layout.rooms[level.layout.start].center)) > 4.0, "player never left start room")
	check(level.director.spawned_total > 0, "director spawned nothing")
	check(level.phase != Level.Phase.FIND_CORE or Game.stats.kills > start_kills, "no progress: phase %s kills %d" % [Level.Phase.keys()[level.phase], Game.stats.kills])
	level.queue_free()
	Game.remove_meta("god")
	await frames(2)

func test_every_enemy_type_spawns_and_dies() -> void:
	Game.new_run(5)
	Game.deck_index = 3
	var level := Level.new(3, 12345)
	get_tree().root.add_child(level)
	level.director.enabled = false
	var origin := DeckGen.cell_to_world(level.layout.rooms[level.layout.start].center)
	var enemies := []
	var i := 0
	for kind in Director.SPAWN_SCRIPTS:
		enemies.append(level.director.spawn_now(kind, origin + Vector3(6 + i * 1.5, 0.2, 0), i % 3))
		i += 1
	await frames(30)
	for e in enemies:
		if not is_instance_valid(e):
			continue
		check(e.state != Enemy.State.DEAD, "%s died on its own" % e.kind)
		for k in 20:
			if is_instance_valid(e) and e.state != Enemy.State.DEAD:
				e.stagger(0.1)  # bypass Bulwark barrier
				e.take_hit(200.0, e.band, e.global_position + Vector3.UP, Vector3.FORWARD)
		check(not is_instance_valid(e) or e.state == Enemy.State.DEAD, "%s survived 20 big hits" % e.kind)
	await frames(30)
	eq(get_tree().get_nodes_in_group("enemies").size(), 0, "enemies left")
	level.queue_free()
	await frames(2)

func test_boss_phases_advance() -> void:
	Game.new_run(9)
	Game.deck_index = 4
	var level := Level.new(4, 999)
	get_tree().root.add_child(level)
	level.director.enabled = false
	Game.set_meta("god", true)
	level._start_boss()
	await frames(5)
	var b: Conductor = level.boss
	b.shield = 0.0
	b.take_hit(b.max_hp * 0.4, b.band, b.global_position, Vector3.FORWARD)
	await frames(3)
	eq(b.phase, 2, "phase after 40% damage")
	eq(b.nodes.size(), 3, "shield nodes")
	var hp_before := b.hp
	b.take_hit(100.0, 1, b.global_position, Vector3.FORWARD)
	near(b.hp, hp_before, 0.01, "core must be sealed while nodes live")
	for n in b.nodes.duplicate():
		n.body.take_hit(1000.0, n.body.band, n.body.global_position, Vector3.FORWARD)
	await frames(3)
	eq(b.phase, 3, "phase after nodes broken")
	b.shield = 0.0
	b.take_hit(99999.0, b.band, b.global_position, Vector3.FORWARD)
	check(b.is_dead(), "boss should be dead")
	Game.remove_meta("god")
	level.queue_free()
	await frames(2)

func test_mod_offers_are_distinct_and_respect_max() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var owned := {&"snap_drive": 1, &"harmonic": 1}
	for k in 50:
		var o := ModData.offers(rng, owned, 3)
		eq(o.size(), 3)
		check(not (&"snap_drive" in o) and not (&"harmonic" in o), "maxed mod offered")
		check(o[0] != o[1] and o[1] != o[2] and o[0] != o[2], "duplicate offer")

func test_synth_bank_complete() -> void:
	for k in Synth.RECIPES:
		check(Synth.bank.has(k), "missing sound %s" % k)
		check((Synth.bank[k] as AudioStreamWAV).data.size() > 100, "empty sound %s" % k)

func test_player_can_climb_ramp_onto_dais() -> void:
	var l: Dictionary = {}
	var seed_used := 0
	for s in 200:
		l = DeckGen.generate(s + 1, 2)
		if not l.platforms.is_empty():
			seed_used = s + 1
			break
	check(not l.platforms.is_empty(), "no platform found")
	Game.new_run(1)
	Game.deck_index = 2
	var level := Level.new(2, seed_used)
	get_tree().root.add_child(level)
	level.director.enabled = false
	await frames(2)
	var pl: Dictionary = level.layout.platforms[0]
	var dir := Vector3(pl.dir.x, 0, pl.dir.y)
	var p := level.player
	p.global_position = DeckGen.cell_to_world(pl.ramp[1]) + dir * 1.0 + Vector3.UP * 0.2
	p.rotation.y = atan2(dir.x, dir.z)  # face back toward the dais (-dir)
	p.ai_controlled = true
	p.ai_move = Vector2(0, 1)
	await frames(150)
	check(p.global_position.y > pl.height - 0.2, "player did not reach dais top: y=%.2f" % p.global_position.y)
	level.queue_free()
	await frames(2)
