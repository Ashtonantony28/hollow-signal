class_name Glob
extends Node3D
## Lobber projectile: ballistic arc, explodes into a burning pool.

const GRAVITY := 12.0
var velocity := Vector3.ZERO
var damage := 22.0
var color := Color(1.0, 0.5, 0.1)
var shooter: Node = null
var life := 5.0

func _ready() -> void:
	add_child(Meshes.sphere(0.25, color, 3.0))

func _physics_process(delta: float) -> void:
	life -= delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() or life <= 0.0:
		_burst(r.position if not r.is_empty() else from)
		return
	global_position = to

func _burst(at: Vector3) -> void:
	FX.explosion(self, at, 2.5, color)
	Synth.play_at(&"glob", at, 0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.global_position.distance_to(at) < 2.5:
		p.take_damage(damage, at)
	var pool := FirePool.new()
	pool.color = color
	get_tree().current_scene.add_child(pool)
	pool.global_position = Vector3(at.x, at.y - 0.05, at.z)
	queue_free()
