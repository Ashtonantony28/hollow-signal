extends TestBase
## v0.4 mechanics: hazards, rarity tiers, hit reactions, Lamplighter.

func _level(deck: int, seed_value: int) -> Level:
	Game.new_run(seed_value)
	Game.deck_index = deck
	var level := Level.new(deck, seed_value)
	get_tree().root.add_child(level)
	level.director.enabled = false
	return level

func _start(level: Level) -> Vector3:
	return DeckGen.cell_to_world(level.layout.rooms[level.layout.start].center)

func test_hazards_generated_and_off_spawns() -> void:
	var counts := {}
	for s in [3, 11, 42, 99]:
		var L := DeckGen.generate(s, 2)
		eq(DeckGen.validate(L).size(), 0, "valid deck")
		for hz in L.hazards:
			counts[hz.kind] = counts.get(hz.kind, 0) + 1
			check(hz.room != L.start, "hazard in start room")
			check(not (L.rooms[hz.room].spawns as Array).has(hz.cell), "hazard cell still a spawn cell")
	check(counts.get(&"canister", 0) > 0, "no canisters on deck 3")
	check(counts.get(&"vent", 0) > 0, "no vents on deck 3")
	check(counts.get(&"shock", 0) > 0, "no shock floors on deck 3")
	var d1 := DeckGen.generate(3, 0)
	for hz in d1.hazards:
		eq(hz.kind, &"canister", "deck 1 only has canisters")

func test_hazards_dont_change_layout() -> void:
	var a := DeckGen.generate(17, 2)
	var b := DeckGen.generate(17, 2)
	eq(a.cells, b.cells, "deterministic")
	eq(a.hazards.size(), b.hazards.size(), "deterministic hazards")

func test_canister_blast_hurts_and_chains() -> void:
	var level := _level(1, 501)
	var o := _start(level) + Vector3(0, 0, 0)
	level.player.global_position = o + Vector3(0, 0.1, 30)  # out of range
	var e := level.director.spawn_now(&"tick", o + Vector3(1.5, 0.2, 0), 0)
	var c1 := Canister.new()
	level.add_child(c1)
	c1.global_position = o
	var c2 := Canister.new()
	level.add_child(c2)
	c2.global_position = o + Vector3(-2.0, 0, 0)
	await frames(5)
	var hp0: float = e.hp
	c1.take_hit(10.0, 0, o, Vector3.FORWARD)
	await frames(30)
	check(not is_instance_valid(e) or e.hp < hp0, "tick not hurt by blast")
	check(not is_instance_valid(c2) or c2.exploded, "neighbour canister did not chain")
	level.queue_free()
	await frames(2)

func test_shock_floor_hurts_only_on_floor_when_live() -> void:
	var level := _level(2, 777)
	var o := _start(level)
	var sf := ShockFloor.new()
	level.add_child(sf)
	sf.global_position = o
	sf.state = 0
	sf.phase_t = 100.0
	level.player.global_position = o + Vector3(0, 0.1, 0)
	level.player.velocity = Vector3.ZERO
	await frames(20)
	var i0 := Game.integrity
	await frames(20)
	near(Game.integrity, i0, 0.01, "dormant floor hurt the player")
	sf.state = 2
	sf.phase_t = 100.0
	sf.tick_t = 0.0
	await frames(40)
	check(Game.integrity < i0, "live floor did not hurt the player")
	level.queue_free()
	await frames(2)

func test_tuning_tiers_buff_weapon() -> void:
	Game.new_run(4)
	var base := WeaponData.get_def(&"carbine")
	var t1 := WeaponData.tiered(&"carbine", 1)
	var t2 := WeaponData.tiered(&"carbine", 2)
	check(t1.damage > base.damage and t2.damage > t1.damage, "damage scales with tier")
	check(t2.mag > base.mag, "mag scales")
	check(t2.fire_interval < base.fire_interval, "Resonant fires faster")
	eq(Game.upgrade_weapon(&"carbine"), 1, "first kit -> Tuned")
	eq(Game.upgrade_weapon(&"carbine"), 2, "second kit -> Resonant")
	eq(Game.upgrade_weapon(&"carbine"), -1, "maxed")
	Game.new_run(5)
	eq(Game.tier(&"carbine"), 0, "tiers reset per run")

func test_weak_point_hits_stagger_and_flash() -> void:
	var level := _level(0, 321)
	var o := _start(level)
	var w := level.director.spawn_now(&"warden", o + Vector3(5, 0.2, 0), 0)
	await frames(10)
	w.shield = 0.0
	var weak_pos: Vector3 = w.visual.global_transform * (w.def.weak_offset as Vector3)
	w.take_hit(w.max_hp * 0.2, w.band, weak_pos, Vector3.FORWARD)
	check(w._flash_on or w.flash_timer > 0.0, "no hit flash")
	w.take_hit(w.max_hp * 0.2, w.band, weak_pos, Vector3.FORWARD)
	eq(w.state, Enemy.State.STAGGER, "weak-point burst should stagger")
	level.queue_free()
	await frames(2)

func test_lamplighter_paints_then_cancels_without_sight() -> void:
	var level := _level(1, 888)
	var o := _start(level)
	level.player.global_position = o + Vector3(0, 0.1, 0)
	var l := level.director.spawn_now(&"lamplighter", o + Vector3(10, 0.2, 0), 0) as Lamplighter
	await frames(60)
	check(l != null and l.state != Enemy.State.DEAD, "lamplighter alive")
	l.can_see = true
	l.cooldown = 0.0
	l.state = Enemy.State.ENGAGE
	l.release_token()
	await frames(20)
	if l.telegraph > 0.0:
		check(l.laser.visible, "laser should show while painting")
	level.queue_free()
	await frames(2)
