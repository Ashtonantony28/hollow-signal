class_name Projectile
extends Node3D
## Pressure Launcher canister: arcing projectile with splash damage and self-boost.

const GRAVITY := 9.0
var velocity := Vector3.ZERO
var damage := 85.0
var radius := 4.0
var band := 0
var owner_player: Player
var self_scale := 0.35
var self_knockback := 11.0
var life := 4.0
var mesh: MeshInstance3D

func _ready() -> void:
	mesh = Meshes.sphere(0.12, ThemeData.BAND_COLORS[band], 3.0)
	add_child(mesh)

func _physics_process(delta: float) -> void:
	life -= delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	if owner_player:
		q.exclude = [owner_player.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		explode(r.position + r.normal * 0.1)
		return
	global_position = to
	if life <= 0.0:
		explode(global_position)

func explode(at: Vector3) -> void:
	FX.explosion(self, at, radius, ThemeData.BAND_COLORS[band])
	FX.smoke(self, at, Color(0.25, 0.25, 0.27, 0.6), 10, radius * 0.5, 1.4)
	Synth.play_at(&"explosion", at, 2.0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(e):
			continue
		var d: float = (e.global_position + Vector3.UP * 0.8).distance_to(at)
		var dmg := DamageModel.splash(damage, d, radius)
		if dmg > 0.0:
			e.take_hit(dmg, band, e.global_position + Vector3.UP * 0.8, (e.global_position - at).normalized())
			hit_any = true
	if hit_any:
		Game.stats.hits += 1
	if owner_player and is_instance_valid(owner_player):
		var pd := (owner_player.global_position + Vector3.UP * 0.9).distance_to(at)
		if pd < radius:
			var dir := (owner_player.global_position + Vector3.UP * 0.9 - at).normalized()
			owner_player.knockback(dir * self_knockback * (1.0 - pd / radius) + Vector3.UP * 3.0)
			owner_player.take_damage(DamageModel.splash(damage, pd, radius) * self_scale, at)
		owner_player.add_shake(clampf(1.0 - pd / 20.0, 0.0, 1.0) * 0.6)
	queue_free()
