class_name SteamVent
extends Node3D
## Floor vent that hisses (warning) then blasts a scalding steam column on a cycle.

const IDLE := 3.5
const WARN := 0.7
const BLAST := 1.4
const RADIUS := 1.1
const DPS := 22.0
const TICK := 0.25

var phase_t := 0.0
var state := 0          # 0 idle, 1 warn, 2 blast
var tick_t := 0.0
var steam: CPUParticles3D
var wisps: CPUParticles3D

func _ready() -> void:
	phase_t = randf() * IDLE
	var grate := Meshes.box(Vector3(1.6, 0.06, 1.6), Color(0.18, 0.18, 0.2))
	grate.position.y = 0.03
	add_child(grate)
	for i in 5:
		var slat := Meshes.box(Vector3(1.3, 0.03, 0.08), Color(0.05, 0.05, 0.06))
		slat.position = Vector3(0, 0.07, -0.5 + i * 0.25)
		add_child(slat)
	var ring := Meshes.box(Vector3(1.75, 0.04, 1.75), Color(1.0, 0.7, 0.1), 0.8)
	ring.position.y = 0.01
	add_child(ring)
	steam = _make_particles(70, 1.1, 5.5, 0.55)
	wisps = _make_particles(10, 0.8, 0.8, 0.25)

func _make_particles(amount: int, life: float, vel: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = vel * 0.7
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 0.5
	p.damping_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.95, 1.0, 0.55))
	g.set_color(1, Color(0.9, 0.9, 0.95, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	phase_t -= delta
	if phase_t <= 0.0:
		state = (state + 1) % 3
		match state:
			0:
				phase_t = IDLE
				steam.emitting = false
				wisps.emitting = false
			1:
				phase_t = WARN
				wisps.emitting = true
			2:
				phase_t = BLAST
				steam.emitting = true
				wisps.emitting = false
				Synth.play_at(&"steam", global_position, -4.0)
	if state == 2:
		tick_t -= delta
		if tick_t <= 0.0:
			tick_t = TICK
			var c := Vector2(global_position.x, global_position.z)
			HazardUtil.area_tick(self, c - Vector2.ONE * RADIUS, c + Vector2.ONE * RADIUS, global_position.y, 3.0, DPS * TICK, false)

func is_active() -> bool:
	return state == 2
