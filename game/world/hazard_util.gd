class_name HazardUtil
## Shared damage helpers for environmental hazards (band-neutral damage).

## Damages the player and enemies inside a sphere, with linear falloff.
static func blast(from: Node, at: Vector3, damage: float, radius: float) -> void:
	var tree := from.get_tree()
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var c: Vector3 = e.global_position + Vector3.UP * 0.8
		var dmg := DamageModel.splash(damage, c.distance_to(at), radius)
		if dmg > 0.0:
			e.take_hit(dmg, e.band, c, (c - at).normalized())
	var p := tree.get_first_node_in_group("player") as Player
	if p and p.alive:
		var pc := p.global_position + Vector3.UP * 0.9
		var d := pc.distance_to(at)
		var dmg := DamageModel.splash(damage * 0.6, d, radius)
		if dmg > 0.0:
			p.take_damage(dmg, at)
			p.knockback((pc - at).normalized() * 9.0 * (1.0 - d / radius) + Vector3.UP * 3.0)
	for c in tree.get_nodes_in_group("canisters"):
		if is_instance_valid(c) and c.global_position.distance_to(at) < radius and c.has_method("chain"):
			c.chain()

## Damage tick for anything standing inside an axis-aligned XZ box [lo, hi] up to `height` above `base_y`.
static func area_tick(from: Node, lo: Vector2, hi: Vector2, base_y: float, height: float, damage: float, need_floor: bool) -> void:
	var tree := from.get_tree()
	var inside := func(pos: Vector3) -> bool:
		return pos.x >= lo.x and pos.x <= hi.x and pos.z >= lo.y and pos.z <= hi.y \
			and pos.y >= base_y - 0.3 and pos.y <= base_y + height
	var p := tree.get_first_node_in_group("player") as Player
	if p and p.alive and inside.call(p.global_position) and (not need_floor or p.is_on_floor()):
		p.take_damage(damage, p.global_position + Vector3.DOWN)
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.flying and inside.call(e.global_position):
			e.take_hit(damage * 1.5, e.band, e.global_position + Vector3.UP * 0.5, Vector3.UP)
