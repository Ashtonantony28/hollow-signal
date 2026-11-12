extends Node
## Player settings + input map. The input map is defined here in code (not project.godot)
## so bindings are reviewable as plain text and testable.

const SAVE_PATH := "user://settings.cfg"

var mouse_sensitivity: float = 0.0025
var fov: float = 90.0
var render_scale: float = 1.0
var master_volume: float = 0.8
var head_bob: bool = true
var quality: int = 1 # 0 low, 1 medium, 2 high
var difficulty: int = 0 # 0 Lineman, 1 Foreman, 2 Story

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL, KEY_C],
	"sprint": [KEY_SHIFT],
	"reload": [KEY_R],
	"retune": [KEY_Q],
	"pulse": [KEY_F],
	"interact": [KEY_E],
	"dash": [KEY_ALT],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],
	"pause": [KEY_ESCAPE, KEY_P],
	"debug_overlay": [KEY_F3],
	"weapon_wheel": [KEY_TAB],
}
const MOUSE_BINDINGS := {
	"fire": MOUSE_BUTTON_LEFT,
	"alt_fire": MOUSE_BUTTON_RIGHT,
	"weapon_next": MOUSE_BUTTON_WHEEL_DOWN,
	"weapon_prev": MOUSE_BUTTON_WHEEL_UP,
}
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"reload": JOY_BUTTON_X,
	"retune": JOY_BUTTON_Y,
	"pulse": JOY_BUTTON_RIGHT_SHOULDER,
	"dash": JOY_BUTTON_LEFT_SHOULDER,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"pause": JOY_BUTTON_START,
	"interact": JOY_BUTTON_X,
}

func _ready() -> void:
	register_inputs()
	load_settings()
	apply()

func register_inputs() -> void:
	for action in BINDINGS:
		_ensure(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE_BINDINGS:
		_ensure(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BINDINGS[action]
		InputMap.action_add_event(action, mb)
	for action in PAD_BUTTONS:
		_ensure(action)
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	_ensure("fire")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("fire", rt)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)

func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

func apply() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(render_scale, 0.4, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))

## Renderer tier: 0 = Fast (Compatibility/OpenGL), 1 = Quality (Forward+/Vulkan). Switching writes
## override.cfg beside the executable (or project) and restarts, because Godot picks the renderer at boot.
func current_tier() -> int:
	return 1 if RenderingServer.get_rendering_device() != null else 0

func override_path() -> String:
	if OS.has_feature("editor") or not OS.has_feature("template"):
		return ProjectSettings.globalize_path("res://override.cfg")
	return OS.get_executable_path().get_base_dir().path_join("override.cfg")

func set_tier_and_restart(tier: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(override_path())
	var method := "forward_plus" if tier == 1 else "gl_compatibility"
	cfg.set_value("rendering", "renderer/rendering_method", method)
	cfg.set_value("rendering", "rendering_device/driver", "vulkan")
	cfg.save(override_path())
	save_settings()
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in ["mouse_sensitivity", "fov", "render_scale", "master_volume", "head_bob", "quality", "difficulty"]:
		cfg.set_value("settings", k, get(k))
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in ["mouse_sensitivity", "fov", "render_scale", "master_volume", "head_bob", "quality", "difficulty"]:
		set(k, cfg.get_value("settings", k, get(k)))
