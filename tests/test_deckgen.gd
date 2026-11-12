extends TestBase

const SEEDS := 120

func test_all_decks_valid_across_seeds() -> void:
	for deck in ThemeData.DECKS.size():
		for s in SEEDS:
			var l := DeckGen.generate(s + 1, deck)
			if not check(not l.is_empty(), "deck %d seed %d failed to generate" % [deck, s]):
				return
			var errs := DeckGen.validate(l)
			if not check(errs.is_empty(), "deck %d seed %d: %s" % [deck, s, ", ".join(errs)]):
				return

func test_deterministic() -> void:
	var a := DeckGen.generate(42, 1)
	var b := DeckGen.generate(42, 1)
	eq(a.cells, b.cells, "cells")
	eq(a.props.size(), b.props.size(), "props")
	eq(a.vault, b.vault, "vault")

func test_different_seeds_differ() -> void:
	var a := DeckGen.generate(1, 0)
	var b := DeckGen.generate(2, 0)
	check(a.cells != b.cells, "seeds 1 and 2 produced identical decks")

func test_vault_off_critical_path() -> void:
	for s in 50:
		var l := DeckGen.generate(s + 100, 2)
		var adj := DeckGen._adjacency(l.rooms.size(), l.edges)
		var path := DeckGen._shortest_path(adj, l.start, l.lift)
		check(not (l.vault in path), "seed %d vault on shortest path" % s)

func test_required_room_types_present() -> void:
	var l := DeckGen.generate(7, 0)
	var types := {}
	for r in l.rooms:
		types[r.type] = true
	for t in [&"start", &"vault", &"uplink", &"lift"]:
		check(types.has(t), "missing room type %s" % t)

func test_boss_deck_has_boss_room() -> void:
	var l := DeckGen.generate(3, ThemeData.DECKS.size() - 1)
	eq(l.rooms[l.lift].type, &"boss")

func test_generation_under_budget() -> void:
	var t0 := Time.get_ticks_usec()
	for s in 10:
		DeckGen.generate(s + 500, 3)
	var avg_ms := (Time.get_ticks_usec() - t0) / 10000.0
	check(avg_ms < 400.0, "avg generation %.1f ms over budget" % avg_ms)

func test_navgrid_paths_start_to_all_objectives() -> void:
	for s in 20:
		var l := DeckGen.generate(s + 900, s % 5)
		var nav := NavGrid.new(l)
		var start := DeckGen.cell_to_world(l.rooms[l.start].center)
		for key in ["vault", "uplink", "lift"]:
			var target := DeckGen.cell_to_world(l.rooms[l[key]].center)
			var p := nav.path_world(start, target)
			check(p.size() > 0, "seed %d no path to %s" % [s, key])

func test_builder_produces_geometry_and_collision() -> void:
	var l := DeckGen.generate(11, 0)
	var root := DeckBuilder.build(l)
	var meshes := 0
	var tris := 0
	for c in root.get_children():
		if c is MeshInstance3D and c.mesh is ArrayMesh:
			meshes += 1
	for cs in root.get_node("WorldBody").get_children():
		tris += (cs.shape as ConcavePolygonShape3D).get_faces().size() / 3
	check(meshes > 4, "too few chunk meshes: %d" % meshes)
	check(tris < 150000, "triangle budget exceeded: %d" % tris)
	check(root.get_node("WorldBody").get_child_count() > 0, "no world collision")
	root.free()

func test_platforms_generated_and_blocked_for_nav() -> void:
	var total := 0
	for s in 40:
		var l := DeckGen.generate(s + 300, s % 5)
		for pl in l.platforms:
			total += 1
			check(pl.dais.size() >= 3, "dais too short")
			eq(pl.ramp.size(), 2, "ramp cells")
			for c in pl.dais + pl.ramp:
				check(not DeckGen.is_walkable(l, c), "platform cell walkable for nav")
	check(total >= 10, "only %d platforms in 40 decks" % total)
