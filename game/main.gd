extends Node
## Entry point and top-level state machine: MENU → DECK → PATCH BAY → … → SUMMARY.
##
## Command-line flags (after `--`):
##   --seed=N        run seed            --deck=N       start at deck N (0-based)
##   --autoplay      bot plays           --god          player takes no damage
##   --skip-menu     start a run immediately
##   --quit-after=S  quit after S seconds (prints a run report)
##   --screenshot=DIR  save a PNG every --shot-every=S seconds (needs a display, e.g. xvfb)
##   --timescale=X   Engine.time_scale
##   --tour=DIR      visual QA: photograph every room of decks 1-5 with a few enemies, then quit

var level: Level
var hud: HUD
var menus: Menus
var args := {}
var autopilot: Autopilot
var shot_timer := 2.0
var shot_count := 0
var run_time := 0.0
var state := "menu"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("timescale"):
		Engine.time_scale = float(args.timescale)
	if args.has("god"):
		Game.set_meta("god", true)
	menus = Menus.new()
	add_child(menus)
	menus.new_run_requested.connect(start_run)
	menus.resume_requested.connect(resume)
	menus.quit_to_menu_requested.connect(to_menu)
	menus.mod_chosen.connect(_on_mod)
	menus.retry_seed_requested.connect(func(): start_run(Game.run_seed))
	Events.deck_completed.connect(_on_deck_completed)
	Events.player_died.connect(_on_player_died)
	Events.run_finished.connect(_on_run_finished)
	Synth.start_music()
	if args.has("tour"):
		_tour.call_deferred()
		return
	if args.has("guns"):
		_gun_gallery.call_deferred()
		return
	if args.has("skip-menu") or args.has("autoplay"):
		start_run(int(args.get("seed", "-1")), int(args.get("deck", "0")))
	else:
		to_menu()

func to_menu() -> void:
	state = "menu"
	get_tree().paused = false
	_free_level()
	Game.in_run = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_backdrop()
	menus.show_main()

func _backdrop() -> void:
	# a slowly orbiting camera over a generated deck behind the main menu
	var l := Level.new(4242, 0)
	l.set_meta("backdrop", true)
	level = l
	add_child(l)
	l.director.enabled = false
	l.player.alive = false
	l.player.set_physics_process(false)
	l.player.visible = false
	var cam := Camera3D.new()
	cam.name = "BackdropCam"
	l.add_child(cam)
	var c := DeckGen.cell_to_world(l.layout.rooms[l.layout.uplink].center, 2.5)
	cam.global_position = c + Vector3(6, 1.5, 6)
	cam.look_at(c + Vector3(0, 1.0, 0))
	cam.current = true
	set_meta("backdrop_center", c)

func start_run(seed_value: int = -1, start_deck: int = 0) -> void:
	Game.new_run(seed_value)
	Game.deck_index = start_deck
	_load_deck()

func _load_deck() -> void:
	_free_level()
	state = "deck"
	menus.hide_all()
	get_tree().paused = false
	level = Level.new(Game.deck_index, Game.deck_seed())
	add_child(level)
	if hud == null:
		hud = HUD.new()
		add_child(hud)
	hud.level = level
	hud.visible = true
	Events.player_stats_changed.emit()
	if args.has("autoplay"):
		autopilot = Autopilot.new()
		autopilot.player = level.player
		autopilot.level = level
		level.add_child(autopilot)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("[deck] %d seed %d rooms %d" % [Game.deck_index, Game.deck_seed(), level.layout.rooms.size()])

func _free_level() -> void:
	if level and is_instance_valid(level):
		level.queue_free()
		remove_child(level)
	level = null
	if hud:
		hud.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "deck":
		if get_tree().paused:
			resume()
		else:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			menus.show_pause()
	elif event is InputEventMouseButton and event.pressed and state == "deck" and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func resume() -> void:
	menus.hide_all()
	get_tree().paused = false
	if state == "deck" and not args.has("autoplay"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_deck_completed(i: int) -> void:
	print("[deck] completed %d at %.1fs kills %d" % [i, Game.stats.time, Game.stats.kills])
	state = "patch"
	await get_tree().create_timer(1.2).timeout
	Game.start_next_deck()
	var offers := ModData.offers(Game.rng, Game.mods, 3)
	if args.has("autoplay"):
		_on_mod(offers[0] if not offers.is_empty() else &"")
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_patch_bay(offers)

func _on_mod(id: StringName) -> void:
	if id != &"":
		Game.apply_mod(id)
		print("[mod] ", id)
	_load_deck()

func _on_player_died() -> void:
	if state != "deck":
		return
	print("[run] died on deck %d at %.1fs kills %d" % [Game.deck_index, Game.stats.time, Game.stats.kills])
	state = "summary"
	await get_tree().create_timer(2.0).timeout
	_show_summary(false)

func _on_run_finished(victory: bool) -> void:
	print("[run] finished victory=%s at %.1fs kills %d" % [victory, Game.stats.time, Game.stats.kills])
	state = "summary"
	await get_tree().create_timer(3.0).timeout
	_show_summary(victory)

func _show_summary(victory: bool) -> void:
	Game.in_run = false
	Engine.time_scale = float(args.get("timescale", "1"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gained := Profile.award_run(Game.stats.kills, Game.deck_index, victory) if not args.has("autoplay") else 0
	menus.show_summary(victory, gained)
	if args.has("autoplay") and args.has("quit-after"):
		_report_and_quit()

func _process(delta: float) -> void:
	run_time += delta / maxf(Engine.time_scale, 0.001)
	if state == "menu" and level and has_meta("backdrop_center"):
		var cam := level.get_node_or_null("BackdropCam") as Camera3D
		if cam:
			var c: Vector3 = get_meta("backdrop_center")
			var a := run_time * 0.12
			cam.global_position = c + Vector3(cos(a) * 9.0, 2.0, sin(a) * 9.0)
			cam.look_at(c + Vector3(0, 0.5, 0))
	if args.has("screenshot"):
		shot_timer -= delta / maxf(Engine.time_scale, 0.001)
		if shot_timer <= 0.0:
			shot_timer = float(args.get("shot-every", "3"))
			_capture()
	if args.has("quit-after") and run_time >= float(args["quit-after"]):
		_report_and_quit()

func _capture() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir: String = args.screenshot
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/shot_%03d.png" % [dir, shot_count]
	img.save_png(path)
	shot_count += 1

func _report_and_quit() -> void:
	var phase_name := "-"
	if level and is_instance_valid(level) and not level.has_meta("backdrop"):
		phase_name = Level.Phase.keys()[level.phase]
	if level and is_instance_valid(level) and level.boss and is_instance_valid(level.boss):
		var b = level.boss
		print("[boss] phase=%d hp=%.0f/%.0f shield=%.0f nodes=%d dist=%.1f" % [b.phase, b.hp, b.max_hp, b.shield, b.nodes.size(), b.global_position.distance_to(level.player.global_position)])
	print("[report] state=%s deck=%d phase=%s time=%.1f kills=%d shots=%d hits=%d integrity=%.0f dealt=%.0f taken=%.0f" % [
		state, Game.deck_index, phase_name, Game.stats.time, Game.stats.kills, Game.stats.shots, Game.stats.hits,
		Game.integrity, Game.stats.damage_dealt, Game.stats.damage_taken])
	get_tree().quit(0)

## Visual QA tour: for each deck, stand in a corner of each interesting room facing its centre,
## spawn one of each unlocked enemy in view, and save a screenshot. Needs a display (xvfb).
func _tour() -> void:
	var dir: String = args.tour
	DirAccess.make_dir_recursive_absolute(dir)
	var seed_value := int(args.get("seed", "11"))
	for deck in Game.DECK_COUNT:
		Game.new_run(seed_value)
		Game.deck_index = deck
		Game.set_meta("god", true)
		_free_level()
		level = Level.new(deck, Game.deck_seed())
		add_child(level)
		if hud == null:
			hud = HUD.new()
			add_child(hud)
		hud.level = level
		hud.visible = true
		level.director.enabled = false
		var shots := 0
		for room in level.layout.rooms:
			if not (room.type in [&"arena", &"uplink", &"vault", &"hub", &"boss"]) or shots >= 3:
				continue
			shots += 1
			var r: Rect2i = room.rect
			var corner := DeckGen.cell_to_world(r.position + Vector2i(1, 1))
			var c := DeckGen.cell_to_world(room.center)
			level.player.global_position = corner + Vector3.UP * 0.1
			level.player.velocity = Vector3.ZERO
			for _i in 3:
				await get_tree().physics_frame
			level.player.look_at_point(c + Vector3.UP * 1.4, 10.0)
			var k := 0
			for kind in EnemyData.UNLOCK:
				if EnemyData.UNLOCK[kind] <= deck:
					var e := level.director.spawn_now(kind, c + Vector3((k - 2) * 2.2, 0.2, 0).rotated(Vector3.UP, level.player.rotation.y), k % 3)
					e.set_physics_process(false)
					e.global_position.y = 3.2 if kind == &"shrieker" else 0.05
					e.look_at(Vector3(level.player.global_position.x, e.global_position.y, level.player.global_position.z), Vector3.UP)
					k += 1
			for _i in 20:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/deck%d_%s_%d.png" % [dir, deck + 1, room.type, shots])
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
			await get_tree().process_frame
	get_tree().quit(0)

## Visual QA: every weapon at hip and fully aimed, saved to --guns=DIR.
func _gun_gallery() -> void:
	var dir: String = args.guns
	DirAccess.make_dir_recursive_absolute(dir)
	Game.new_run(5)
	Game.loadout = WeaponData.ALL.duplicate()
	for id in WeaponData.ALL:
		Game.ammo[id] = {"mag": WeaponData.get_def(id).mag, "reserve": 99}
	level = Level.new(0, 4242)
	add_child(level)
	hud = HUD.new()
	add_child(hud)
	hud.level = level
	level.director.enabled = false
	var room: Dictionary = level.layout.rooms[level.layout.uplink]
	level.player.global_position = DeckGen.cell_to_world(room.rect.position + Vector2i(1, 1)) + Vector3.UP * 0.1
	level.player.look_at_point(DeckGen.cell_to_world(room.center) + Vector3.UP * 1.5, 10.0)
	var ws := level.player.weapons
	level.player.set_meta("hold_ads", true)
	for id in WeaponData.ALL:
		ws.equip(id, true)
		ws.switching = 0.0
		ws.ads = 0.0
		for _i in 15:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_hip.png" % [dir, id])
		ws.ads = 1.0
		level.player.aiming = true
		for _i in 4:
			ws.ads = 1.0
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_ads.png" % [dir, id])
		level.player.aiming = false
	get_tree().quit(0)
