extends SceneTree
## Zero-dependency headless test runner.
##   godot --headless --path . -s tests/run_tests.gd [-- --filter=name]
## Discovers tests/test_*.gd, calls every method starting with `test_`. Methods may be
## coroutines (await) — smoke tests use that to step frames. Exit code = number of failures.

var failures := 0
var passes := 0
var current := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null:
			print("FAIL  could not load ", f)
			failures += 1
			continue
		var inst = script.new()
		if inst is Node:
			root.add_child(inst)
		if "runner" in inst:
			inst.runner = self
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			current = f.get_basename() + "::" + mname
			if filter != "" and current.find(filter) == -1:
				continue
			var before := failures
			var ts := Time.get_ticks_msec()
			await inst.call(mname)
			if failures == before:
				passes += 1
				print("PASS  %s (%d ms)" % [current, Time.get_ticks_msec() - ts])
		if inst is Node:
			inst.queue_free()
			await process_frame
	print("\n%d passed, %d failed in %.1fs" % [passes, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(failures)

func fail(msg: String) -> void:
	failures += 1
	print("FAIL  %s: %s" % [current, msg])
