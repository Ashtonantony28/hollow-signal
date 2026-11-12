class_name Menus
extends CanvasLayer
## Main menu, pause, settings, Patch Bay (mod choice) and run summary — all built in code.

signal new_run_requested(seed_value: int)
signal resume_requested
signal quit_to_menu_requested
signal mod_chosen(id: StringName)
signal retry_seed_requested

var panel: PanelContainer
var box: VBoxContainer
var dim: ColorRect

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.82)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	sb.border_color = Color(0.95, 0.55, 0.15)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	hide_all()

func hide_all() -> void:
	visible = false

func _clear() -> void:
	for c in box.get_children():
		c.queue_free()
	visible = true

func _title(text: String, size: int = 40, color: Color = Color(0.95, 0.6, 0.2)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		Synth.play(&"retune", -6)
		cb.call())
	box.add_child(b)
	return b

func show_main() -> void:
	_clear()
	_title("HOLLOW SIGNAL", 52)
	_title("Relay Hollow is still broadcasting.", 16, Color(0.7, 0.75, 0.8))
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "Seed (blank = random)"
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seed_edit)
	var b := _button("NEW RUN", func():
		var s := -1
		if seed_edit.text.strip_edges().is_valid_int():
			s = int(seed_edit.text)
		new_run_requested.emit(s))
	b.grab_focus.call_deferred()
	_difficulty_row()
	_button("SETTINGS", func(): show_settings(show_main))
	_button("CONTROLS", func(): show_controls(show_main))
	_button("QUIT", func(): get_tree().quit())

func _difficulty_row() -> void:
	var opt := OptionButton.new()
	for n in Game.DIFFICULTY_NAMES:
		opt.add_item("Difficulty: " + n)
	opt.selected = Settings.difficulty
	opt.item_selected.connect(func(i):
		Settings.difficulty = i
		Settings.save_settings())
	box.add_child(opt)

func show_pause() -> void:
	_clear()
	_title("PAUSED", 40)
	_title("Deck %d · Seed %d · %s" % [Game.deck_index + 1, Game.run_seed, Game.DIFFICULTY_NAMES[Settings.difficulty]], 15, Color(0.7, 0.75, 0.8))
	_button("RESUME", func(): resume_requested.emit()).grab_focus.call_deferred()
	_button("SETTINGS", func(): show_settings(show_pause))
	_button("CONTROLS", func(): show_controls(show_pause))
	_button("ABANDON RUN", func(): quit_to_menu_requested.emit())

func show_settings(back: Callable) -> void:
	_clear()
	_title("SETTINGS", 34)
	_slider("Mouse sensitivity", 0.0005, 0.008, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v)
	_slider("Field of view", 70, 110, Settings.fov, func(v): Settings.fov = v)
	_slider("Render scale (lower = faster)", 0.4, 1.0, Settings.render_scale, func(v):
		Settings.render_scale = v
		Settings.apply())
	_slider("Volume", 0.0, 1.0, Settings.master_volume, func(v):
		Settings.master_volume = v
		Settings.apply())
	var q := OptionButton.new()
	for n in ["Quality: Low (fastest)", "Quality: Medium", "Quality: High"]:
		q.add_item(n)
	q.selected = Settings.quality
	q.item_selected.connect(func(i): Settings.quality = i)
	box.add_child(q)
	var bob := CheckBox.new()
	bob.text = "Head bob"
	bob.button_pressed = Settings.head_bob
	bob.toggled.connect(func(on): Settings.head_bob = on)
	box.add_child(bob)
	_button("BACK", func():
		Settings.save_settings()
		back.call())

func _slider(label: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = value
	s.value_changed.connect(cb)
	box.add_child(s)

func show_controls(back: Callable) -> void:
	_clear()
	_title("CONTROLS", 34)
	var t := Label.new()
	t.text = "WASD move · Mouse look · Space jump\nShift sprint · Ctrl/C crouch (slide while sprinting)\nLMB fire (hold to charge Arc Lance) · R reload\n1-4 / wheel switch weapon · Q retune band\nF Pulse (stagger + strip shields + reveal)\nE interact · Alt dash (Snap Drive mod)\nEsc pause · F3 debug overlay\n\nMatch your band to an enemy's shield colour\nfor triple shield damage."
	t.add_theme_font_size_override("font_size", 16)
	box.add_child(t)
	_button("BACK", back)

func show_patch_bay(offers: Array[StringName]) -> void:
	_clear()
	_title("PATCH BAY", 38)
	_title("Deck %d cleared. Install one mod." % Game.deck_index, 16, Color(0.7, 0.75, 0.8))
	var first := true
	for id in offers:
		var d: Dictionary = ModData.DEFS[id]
		var lvl := Game.mod_level(id)
		var b := _button("%s%s — %s" % [d.name, "" if lvl == 0 else " (%d→%d)" % [lvl, lvl + 1], d.desc], func(): mod_chosen.emit(id))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 60)
		if first:
			b.grab_focus.call_deferred()
			first = false
	if offers.is_empty():
		_button("CONTINUE", func(): mod_chosen.emit(&""))

func show_summary(victory: bool) -> void:
	_clear()
	_title("SIGNAL RESTORED" if victory else "LINEMAN LOST", 42, Color(0.4, 1.0, 0.6) if victory else Color(1.0, 0.35, 0.3))
	var s := Game.stats
	var mins := int(s.time) / 60
	var secs := int(s.time) % 60
	var lines := "Deck reached: %d / %d\nTime: %d:%02d\nKills: %d\nAccuracy: %d%%\nDamage dealt: %d\nDamage taken: %d\nSeed: %d · %s" % [
		Game.deck_index + 1, Game.DECK_COUNT, mins, secs, s.kills, int(Game.accuracy() * 100.0),
		int(s.damage_dealt), int(s.damage_taken), Game.run_seed, Game.DIFFICULTY_NAMES[Settings.difficulty]]
	var l := Label.new()
	l.text = lines
	l.add_theme_font_size_override("font_size", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_button("RETRY SEED", func(): retry_seed_requested.emit()).grab_focus.call_deferred()
	_button("NEW RUN", func(): new_run_requested.emit(-1))
	_button("MAIN MENU", func(): quit_to_menu_requested.emit())
