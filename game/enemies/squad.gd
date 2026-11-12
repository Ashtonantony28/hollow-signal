class_name Squad
extends RefCounted
## Attack-token coordinator: at most `max_tokens` enemies may commit to an attack at once.

var max_tokens := 3
var holders: Dictionary = {}

func _init(n: int = 3) -> void:
	max_tokens = n

func request(e: Object) -> bool:
	_prune()
	if holders.has(e):
		return true
	if holders.size() < max_tokens:
		holders[e] = true
		return true
	return false

func release(e: Object) -> void:
	holders.erase(e)

func active() -> int:
	_prune()
	return holders.size()

func _prune() -> void:
	for k in holders.keys():
		if not is_instance_valid(k):
			holders.erase(k)
