extends TestBase
## Physics checks for the movement kit (OVERHAUL.md §2) on a hand-built test course.

var course: Node3D

func _box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = center

func _setup() -> Player:
	Game.new_run(1)
	course = Node3D.new()
	get_tree().root.add_child(course)
	_box(course, Vector3(0, -0.5, 0), Vector3(200, 1, 200))         # floor
	_box(course, Vector3(0, 0.6, -10), Vector3(6, 1.2, 2))           # 1.2 m ledge ahead (z = -9 face)
	_box(course, Vector3(12, 3, -30), Vector3(0.6, 6, 40))           # long wall along -z at x = 11.7
	var p := Player.new()
	course.add_child(p)
	p.global_position = Vector3(0, 0.1, 0)
	p.ai_controlled = true
	await frames(5)
	return p

func _teardown() -> void:
	course.queue_free()
	await frames(2)

func test_mantle_onto_ledge() -> void:
	var p := await _setup()
	p.ai_move = Vector2(0, 1)      # walk forward (-z) into the ledge
	await frames(60)
	p.ai_jump = true
	await frames(2)
	p.ai_jump = false
	var top := 0.0
	var stood := false
	for i in 70:
		await frames(1)
		top = maxf(top, p.global_position.y)
		if p.is_on_floor() and p.global_position.y > 1.15:
			stood = true
			p.ai_move = Vector2.ZERO
	check(stood, "did not mantle onto ledge (max y=%.2f)" % top)
	await _teardown()

func test_double_jump_goes_higher() -> void:
	var p := await _setup()
	p.global_position = Vector3(-30, 0.1, 0)
	await frames(10)
	p.ai_jump = true
	await frames(1)
	p.ai_jump = false
	var peak1 := 0.0
	for i in 60:
		await frames(1)
		peak1 = maxf(peak1, p.global_position.y)
	await frames(40)
	p.ai_jump = true
	await frames(1)
	p.ai_jump = false
	await frames(18)
	p.ai_jump = true   # second jump near the apex
	await frames(1)
	p.ai_jump = false
	var peak2 := 0.0
	for i in 70:
		await frames(1)
		peak2 = maxf(peak2, p.global_position.y)
	check(peak2 > peak1 + 0.5, "double jump peak %.2f vs single %.2f" % [peak2, peak1])
	await _teardown()

func test_slide_boosts_and_keeps_momentum() -> void:
	var p := await _setup()
	p.global_position = Vector3(-30, 0.1, 30)
	p.ai_move = Vector2(0, 1)
	p.ai_sprint = true
	await frames(60)
	var run_speed := p.speed()
	check(run_speed > 9.0, "sprint speed too low: %.2f" % run_speed)
	p.ai_crouch = true
	await frames(3)
	check(p.sliding, "slide did not start")
	check(p.speed() > run_speed + 1.0, "slide gave no boost: %.2f -> %.2f" % [run_speed, p.speed()])
	await frames(20)
	p.ai_jump = true
	await frames(1)
	p.ai_jump = false
	await frames(10)
	check(p.speed() > run_speed, "slide-hop lost speed: %.2f" % p.speed())
	p.ai_crouch = false
	await _teardown()

func test_wallrun_extends_airtime() -> void:
	var p := await _setup()
	# run parallel to the wall at x≈11, heading -z, then jump into it
	p.global_position = Vector3(10.6, 0.1, -12)
	p.rotation.y = 0.0
	p.ai_move = Vector2(0.35, 1)
	p.ai_sprint = true
	await frames(30)
	p.ai_jump = true
	await frames(1)
	p.ai_jump = false
	var air := 0
	var ran := false
	for i in 150:
		await frames(1)
		if p.wall_running:
			ran = true
		if not p.is_on_floor():
			air += 1
		elif i > 10:
			break
	check(ran, "never entered wall-run")
	check(air > 60, "air time only %d frames" % air)
	await _teardown()
