class_name ShockFloor
extends Node3D
## Electrified deck plate: dormant, flickers as a warning, then arcs and hurts anything standing on it.
## Jumping or wall-running over it is safe (damage needs floor contact).

const IDLE := 3.2
const WARN := 0.9
const LIVE := 2.0
const DPS := 26.0
const TICK := 0.25

var size := Vector2(4.0, 4.0)
var phase_t := 0.0
var state := 0
var tick_t := 0.0
var plate: MeshInstance3D
var lines: Array[MeshInstance3D] = []
var light: OmniLight3D
var arc_t := 0.0
var _mat_off: StandardMaterial3D
var _mat_on: StandardMaterial3D

func _ready() -> void:
	phase_t = randf() * IDLE
	plate = Meshes.box(Vector3(size.x - 0.2, 0.05, size.y - 0.2), Color(0.12, 0.13, 0.16))
	plate.position.y = 0.025
	add_child(plate)
	_mat_off = Meshes.mat(Color(0.15, 0.35, 0.6), 0.6)
	_mat_on = Meshes.mat(Color(0.5, 0.85, 1.0), 6.0)
	var n := 4
	for i in n:
		var t := -0.5 + (i + 0.5) / n
		var a := Meshes.box(Vector3(size.x - 0.4, 0.02, 0.05), Color.WHITE)
		a.position = Vector3(0, 0.06, t * (size.y - 0.4))
		var b := Meshes.box(Vector3(0.05, 0.02, size.y - 0.4), Color.WHITE)
		b.position = Vector3(t * (size.x - 0.4), 0.06, 0)
		for m in [a, b]:
			m.material_override = _mat_off
			add_child(m)
			lines.append(m)
	# hazard border
	for s in [-1.0, 1.0]:
		var e1 := Meshes.box(Vector3(size.x, 0.03, 0.12), Color(1.0, 0.75, 0.1), 0.8)
		e1.position = Vector3(0, 0.015, s * size.y * 0.5)
		add_child(e1)
		var e2 := Meshes.box(Vector3(0.12, 0.03, size.y), Color(1.0, 0.75, 0.1), 0.8)
		e2.position = Vector3(s * size.x * 0.5, 0.015, 0)
		add_child(e2)
	light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0)
	light.omni_range = 5.0
	light.light_energy = 0.0
	light.position.y = 0.6
	add_child(light)

func _set_lines(on: bool) -> void:
	for m in lines:
		m.material_override = _mat_on if on else _mat_off

func _physics_process(delta: float) -> void:
	phase_t -= delta
	if phase_t <= 0.0:
		state = (state + 1) % 3
		phase_t = [IDLE, WARN, LIVE][state]
		if state == 2:
			Synth.play_at(&"zap_floor", global_position, -2.0)
		if state == 0:
			_set_lines(false)
			light.light_energy = 0.0
	match state:
		1:
			var on := fmod(phase_t, 0.2) < 0.1
			_set_lines(on)
			light.light_energy = 0.6 if on else 0.0
		2:
			_set_lines(true)
			light.light_energy = randf_range(1.0, 2.5)
			arc_t -= delta
			if arc_t <= 0.0:
				arc_t = 0.08
				var a := global_position + Vector3(randf_range(-0.45, 0.45) * size.x, 0.08, randf_range(-0.45, 0.45) * size.y)
				var b := a + Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 0.7), randf_range(-0.8, 0.8))
				FX.tracer(self, a, b, Color(0.6, 0.9, 1.0), 0.03, 0.06)
			tick_t -= delta
			if tick_t <= 0.0:
				tick_t = TICK
				var c := Vector2(global_position.x, global_position.z)
				HazardUtil.area_tick(self, c - size * 0.5, c + size * 0.5, global_position.y, 0.6, DPS * TICK, true)

func is_live() -> bool:
	return state == 2
