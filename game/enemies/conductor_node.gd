class_name ConductorNode
extends StaticBody3D
## Orbiting shield node for the Conductor's phase 2. Only breakable on its own band
## (off-band hits still chip at 0.5x).

var boss: Node
var node_band := 0
var shield := 160.0
var mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.7
	cs.shape = sp
	add_child(cs)
	mesh = Meshes.prism(Vector3(0.9, 1.2, 0.9), ThemeData.BAND_COLORS[node_band], 3.0)
	add_child(mesh)
	shield *= Game.enemy_hp_scale()

func _process(delta: float) -> void:
	mesh.rotation.y += delta * 3.0

func take_hit(amount: float, hit_band: int, pos: Vector3, _dir: Vector3) -> void:
	var r := DamageModel.apply_hit(amount, hit_band, false, shield, node_band, 0.0)
	shield = r.shield
	FX.spark(self, pos, ThemeData.BAND_COLORS[node_band], 0.2 if r.matched else 0.1)
	Events.enemy_hit.emit(self, r.shield_damage, false, true, r.matched)
	if shield <= 0.0:
		FX.explosion(self, global_position, 2.0, ThemeData.BAND_COLORS[node_band])
		Synth.play(&"shield_break")
		boss.node_destroyed(self)
		queue_free()

func on_pulse() -> void:
	pass

func reveal(_t: float) -> void:
	pass
