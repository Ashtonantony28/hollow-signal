class_name FirePool
extends Node3D
## Area-denial puddle left by Lobber globs.

var color := Color(1.0, 0.5, 0.1)
var life := 4.0
var radius := 2.0
var dps := 9.0
var tick := 0.0
var mesh: MeshInstance3D

func _ready() -> void:
	mesh = Meshes.cyl(radius, 0.05, color, 2.0, 16)
	mesh.material_override = Meshes.mat(color, 2.0, true, 0.55)
	add_child(mesh)

func _physics_process(delta: float) -> void:
	life -= delta
	mesh.transparency = clampf(1.0 - life / 4.0, 0.0, 0.9)
	tick -= delta
	if tick <= 0.0:
		tick = 0.5
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.alive:
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if d < radius and absf(p.global_position.y - global_position.y) < 1.2:
				p.take_damage(dps * 0.5, global_position)
	if life <= 0.0:
		queue_free()
