class_name TestBase
extends Node
## Assertion helpers shared by test files.

var runner

func check(cond: bool, msg: String = "check failed") -> bool:
	if not cond:
		runner.fail(msg)
	return cond

func eq(a, b, msg: String = "") -> bool:
	if a != b:
		runner.fail("%s expected %s == %s" % [msg, str(a), str(b)])
		return false
	return true

func near(a: float, b: float, eps: float = 0.001, msg: String = "") -> bool:
	if absf(a - b) > eps:
		runner.fail("%s expected %f ≈ %f" % [msg, a, b])
		return false
	return true

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
