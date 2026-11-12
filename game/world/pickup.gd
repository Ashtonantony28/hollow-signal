class_name Pickup
extends Area3D
## Repair / plating / feedstock / charge pickups.

const COLORS := {&"repair": Color(0.3, 1.0, 0.45), &"plating": Color(0.4, 0.7, 1.0),
	&"ammo": Color(1.0, 0.85, 0.3), &"charge": Color(0.75, 0.5, 1.0)}

var kind: StringName = &"ammo"
var mesh: MeshInstance3D
var t := 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.9
	cs.shape = sp
	cs.position.y = 0.6
	add_child(cs)
	var c: Color = COLORS[kind]
	match kind:
		&"repair":
			mesh = Meshes.box(Vector3(0.45, 0.45, 0.45), c, 2.0)
			var cross := Meshes.box(Vector3(0.5, 0.12, 0.12), Color.WHITE, 3.0)
			mesh.add_child(cross)
			var cross2 := Meshes.box(Vector3(0.12, 0.5, 0.12), Color.WHITE, 3.0)
			mesh.add_child(cross2)
		&"plating":
			mesh = Meshes.prism(Vector3(0.5, 0.55, 0.2), c, 2.0)
		&"charge":
			mesh = Meshes.sphere(0.25, c, 3.0)
		_:
			mesh = Meshes.cyl(0.18, 0.45, c, 2.0, 6)
	mesh.position.y = 0.7
	add_child(mesh)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	t += delta
	mesh.rotation.y = t * 2.0
	mesh.position.y = 0.7 + sin(t * 3.0) * 0.1

func _on_body(b: Node) -> void:
	if not (b is Player) or not b.alive:
		return
	var p := b as Player
	match kind:
		&"repair":
			if Game.integrity >= Game.max_integrity:
				return
			p.heal(25.0)
		&"plating":
			if Game.plating >= Game.max_plating:
				return
			p.add_plating(25.0)
		&"charge":
			p.add_charge(30.0)
		_:
			p.weapons.add_feedstock(0.35)
	Synth.play(&"pickup", -4)
	Events.message.emit("+ %s" % String(kind).to_upper(), 1.0)
	queue_free()
