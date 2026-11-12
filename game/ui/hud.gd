class_name HUD
extends CanvasLayer
## In-game HUD, built from code (DESIGN.md §9).

var level: Level
var integrity_bar: ProgressBar
var plating_bar: ProgressBar
var integrity_label: Label
var charge_bar: ProgressBar
var charge_label: Label
var weapon_label: Label
var ammo_label: Label
var band_label: Label
var objective_label: Label
var compass_label: Label
var message_label: Label
var prompt_label: Label
var uplink_bar: ProgressBar
var debug_label: Label
var crosshair: Control
var hitmarker: Label
var vignette: ColorRect
var boss_bar: ProgressBar
var boss_label: Label
var message_timer := 0.0
var hit_timer := 0.0
var debug := false
var cross_parts: Array[ColorRect] = []
var dmg_root: Control
var dmg_arrows: Array = []   # {node, dir (world), t}
const DMG_RADIUS := 120.0

## Edge-only damage vignette: alpha rises toward the screen border, centre stays clear.
const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.75, length(d * vec2(1.2, 1.0)));
	COLOR = vec4(COLOR.rgb, COLOR.a * edge * 1.6);
}
"""

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# crosshair
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	for r in [Rect2(-12, -1, 7, 2), Rect2(5, -1, 7, 2), Rect2(-1, -12, 2, 7), Rect2(-1, 5, 2, 7), Rect2(-1, -1, 2, 2)]:
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)
		cross_parts.append(cr)
	hitmarker = _label(root, "✕", 26, Color(1, 1, 1, 0))
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.position = Vector2(-9, -18)

	# bottom-left: integrity + plating
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(28, -118)
	bl.custom_minimum_size = Vector2(300, 90)
	root.add_child(bl)
	integrity_label = _label(bl, "INTEGRITY 100", 18, Color(0.9, 0.95, 1.0))
	integrity_bar = _bar(bl, Color(0.35, 1.0, 0.5), 300, 14)
	_label(bl, "PLATING", 13, Color(0.6, 0.75, 1.0))
	plating_bar = _bar(bl, Color(0.45, 0.7, 1.0), 300, 8)

	# bottom-right: weapon, ammo, band, charge
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-300, -150)
	br.custom_minimum_size = Vector2(270, 120)
	br.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(br)
	weapon_label = _label(br, "RIVET DRIVER", 16, Color(0.85, 0.88, 0.92))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _label(br, "12 / ∞", 34, Color.WHITE)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	band_label = _label(br, "BAND: LOW  [Q]", 18, ThemeData.BAND_COLORS[0])
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charge_label = _label(br, "PULSE [F]", 13, Color(0.7, 0.8, 1.0))
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charge_bar = _bar(br, Color(0.6, 0.85, 1.0), 270, 8)

	# top: objective + compass + uplink
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-300, 16)
	top.custom_minimum_size = Vector2(600, 80)
	root.add_child(top)
	objective_label = _label(top, "", 20, Color(1.0, 0.92, 0.7))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_label = _label(top, "", 16, Color(1.0, 0.85, 0.4))
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uplink_bar = _bar(top, Color(0.3, 1.0, 0.5), 600, 10)
	uplink_bar.visible = false
	boss_label = _label(top, "THE CONDUCTOR", 16, Color(1.0, 0.4, 0.45))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	boss_bar = _bar(top, Color(1.0, 0.3, 0.35), 600, 12)
	boss_bar.visible = false

	message_label = _label(root, "", 28, Color(1, 1, 1))
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position = Vector2(-400, -150)
	message_label.custom_minimum_size = Vector2(800, 40)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label = _label(root, "", 18, Color(1.0, 0.95, 0.6))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-300, 60)
	prompt_label.custom_minimum_size = Vector2(600, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_root = Control.new()
	dmg_root.set_anchors_preset(Control.PRESET_CENTER)
	dmg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dmg_root)
	for i in 4:
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(-34, 0), Vector2(34, 0), Vector2(0, -16)])
		arrow.color = Color(1.0, 0.2, 0.15, 0.0)
		dmg_root.add_child(arrow)
		dmg_arrows.append({"node": arrow, "dir": Vector3.ZERO, "t": 0.0})
	debug_label = _label(root, "", 13, Color(0.7, 1.0, 0.7))
	debug_label.position = Vector2(10, 10)
	debug_label.visible = false

	Events.player_stats_changed.connect(_refresh_stats)
	Events.ammo_changed.connect(_on_ammo)
	Events.weapon_changed.connect(_on_weapon)
	Events.band_changed.connect(_on_band)
	Events.objective_changed.connect(func(t): objective_label.text = t)
	Events.message.connect(_on_message)
	Events.enemy_hit.connect(_on_hit)
	Events.enemy_killed.connect(_on_kill)
	Events.player_damaged.connect(_on_damaged)
	Events.uplink_progress.connect(_on_uplink)
	_refresh_stats()
	_on_band(0)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bar(parent: Node, color: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.max_value = 100.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	b.add_theme_stylebox_override("fill", fg)
	b.add_theme_stylebox_override("background", bg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b

func _refresh_stats() -> void:
	integrity_bar.max_value = Game.max_integrity
	integrity_bar.value = Game.integrity
	integrity_label.text = "INTEGRITY %d" % ceili(Game.integrity)
	plating_bar.max_value = Game.max_plating
	plating_bar.value = Game.plating
	charge_bar.value = Game.charge
	var pulse_ready := Game.charge >= Game.pulse_cost()
	charge_label.text = "PULSE READY [F]" if pulse_ready else "PULSE %d%%" % int(Game.charge)
	charge_label.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0) if pulse_ready else Color(0.6, 0.7, 0.85))

func _on_ammo(mag: int, reserve: int) -> void:
	ammo_label.text = "%d / %s" % [mag, "∞" if reserve < 0 else str(reserve)]
	ammo_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if mag == 0 else Color.WHITE)

func _on_weapon(id: StringName) -> void:
	weapon_label.text = (WeaponData.get_def(id).name as String).to_upper()

func _on_band(b: int) -> void:
	var c: Color = ThemeData.BAND_COLORS[b]
	band_label.text = "BAND: %s  [Q]" % ThemeData.BAND_NAMES[b]
	band_label.add_theme_color_override("font_color", c)
	for p in cross_parts:
		p.color = c

func _on_message(text: String, seconds: float) -> void:
	message_label.text = text
	message_timer = seconds
	message_label.modulate.a = 1.0

func _on_hit(_e: Node, _dmg: float, weak: bool, shield_hit: bool, matched: bool) -> void:
	hit_timer = 0.15
	var c := Color.WHITE
	if weak:
		c = Color(1.0, 0.35, 0.3)
	elif shield_hit and matched:
		c = Color(0.5, 1.0, 1.0)
	elif shield_hit:
		c = Color(0.6, 0.6, 0.6)
	hitmarker.add_theme_color_override("font_color", c)
	Synth.play(&"hit_match" if matched else &"hit", -8)

func _on_kill(_e: Node) -> void:
	hit_timer = 0.3
	hitmarker.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))

func _on_uplink(f: float, active: bool) -> void:
	uplink_bar.visible = f < 1.0
	uplink_bar.value = f * 100.0
	(uplink_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.3, 1.0, 0.5) if active else Color(1.0, 0.75, 0.2)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		debug = not debug
		debug_label.visible = debug
	message_timer -= delta
	if message_timer < 0.6:
		message_label.modulate.a = clampf(message_timer / 0.6, 0.0, 1.0)
	hit_timer = maxf(hit_timer - delta, 0.0)
	hitmarker.modulate.a = clampf(hit_timer / 0.15, 0.0, 1.0)
	vignette.color.a = maxf(vignette.color.a - delta * 0.8, 0.0)
	_update_damage_arrows(delta)
	if Game.integrity < 30.0:
		vignette.color.a = maxf(vignette.color.a, 0.12 + sin(Time.get_ticks_msec() / 250.0) * 0.05)
	if level == null or level.player == null:
		return
	var p := level.player
	# compass toward objective
	var target := level.objective_position()
	var to := target - p.global_position
	var dist := Vector2(to.x, to.z).length()
	var yaw_to := atan2(-to.x, -to.z)
	var rel := wrapf(yaw_to - p.rotation.y, -PI, PI)
	var arrow := "▲"
	if absf(rel) > 2.4:
		arrow = "▼"
	elif rel > 0.35:
		arrow = "◀"
	elif rel < -0.35:
		arrow = "▶"
	compass_label.text = "%s  %dm" % [arrow, int(dist)] if level.phase != Level.Phase.DONE else ""
	# interaction prompt
	prompt_label.text = ""
	if level.phase == Level.Phase.CALIBRATE and level._flat_dist(p.global_position, level.uplink_node.global_position) < 2.5:
		prompt_label.text = "[E] INSERT TUNING CORE"
	# boss bar
	var b = level.boss
	boss_bar.visible = b != null and is_instance_valid(b) and not b.dead
	boss_label.visible = boss_bar.visible
	if boss_bar.visible:
		boss_bar.max_value = b.max_hp
		boss_bar.value = b.hp
		boss_label.text = "THE CONDUCTOR — PHASE %d  [%s]" % [b.phase, ThemeData.BAND_NAMES[b.band]]
	_refresh_stats()
	if debug:
		debug_label.text = "FPS %d | seed %d deck %d | enemies %d | tokens %d | intensity %.2f | draw %d | pos %s" % [
			Engine.get_frames_per_second(), Game.run_seed, Game.deck_index + 1,
			get_tree().get_nodes_in_group("enemies").size(), level.squad.active(), level.director.intensity,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			str(p.global_position.snapped(Vector3.ONE * 0.1))]

func _on_damaged(_amount: float, from_dir: Vector3) -> void:
	vignette.color.a = 0.35
	if from_dir.length() < 0.01:
		return
	# reuse the oldest arrow
	var slot: Dictionary = dmg_arrows[0]
	for a in dmg_arrows:
		if a.t < slot.t:
			slot = a
	slot.dir = from_dir
	slot.t = 1.0

func _update_damage_arrows(delta: float) -> void:
	if level == null or level.player == null:
		return
	var yaw := level.player.rotation.y
	for a in dmg_arrows:
		a.t = maxf(a.t - delta, 0.0)
		var node: Polygon2D = a.node
		node.color.a = a.t * 0.85
		if a.t <= 0.0:
			continue
		var d: Vector3 = a.dir
		# angle of the source relative to where the player faces (0 = straight ahead)
		var rel := wrapf(atan2(-d.x, -d.z) - yaw, -PI, PI)
		var screen_angle := -rel
		node.position = Vector2(sin(screen_angle), -cos(screen_angle)) * DMG_RADIUS
		node.rotation = screen_angle
