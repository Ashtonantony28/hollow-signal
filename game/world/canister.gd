class_name Canister
extends StaticBody3D
## Explosive coolant canister: one shot (or a nearby blast) sets it off. Chains into neighbours.

const DAMAGE := 70.0
const RADIUS := 4.5

var exploded := false

func _ready() -> void:
	add_to_group("canisters")
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 1.2
	cs.shape = cyl
	cs.position.y = 0.6
	add_child(cs)
	var body := Meshes.cyl(0.36, 1.1, Color(0.62, 0.12, 0.08), 0.0, 12)
	body.position.y = 0.6
	add_child(body)
	for y in [0.3, 0.9]:
		var band := Meshes.cyl(0.375, 0.1, Color(1.0, 0.75, 0.1), 1.2, 12)
		band.position.y = y
		add_child(band)
	var cap := Meshes.cyl(0.2, 0.12, Color(0.3, 0.3, 0.32), 0.0, 8)
	cap.position.y = 1.2
	add_child(cap)
	var lamp := Meshes.sphere(0.06, Color(1.0, 0.3, 0.1), 5.0)
	lamp.position = Vector3(0, 1.0, -0.37)
	add_child(lamp)

func take_hit(_amount: float, _band: int, _pos: Vector3, _dir: Vector3) -> void:
	explode()

func chain() -> void:
	if not exploded:
		get_tree().create_timer(0.15).timeout.connect(explode)

func explode() -> void:
	if exploded or not is_inside_tree():
		return
	exploded = true
	remove_from_group("canisters")
	collision_layer = 0
	var at := global_position + Vector3.UP * 0.6
	FX.explosion(self, at, RADIUS * 0.6, Color(1.0, 0.5, 0.15))
	FX.smoke(self, at, Color(0.15, 0.15, 0.16, 0.7), 12, 1.0, 1.8)
	FX.shards(self, at, Color(0.62, 0.12, 0.08), 8)
	Synth.play_at(&"explosion", at, 4.0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.global_position.distance_to(at) < 14.0:
		p.add_shake(0.6)
	HazardUtil.blast(self, at, DAMAGE, RADIUS)
	queue_free()
