class_name EnemyData
## Balance table for the Choir (DESIGN.md §5).

const DEFS := {
	&"tick": {"hp": 30.0, "shield": 0.0, "speed": 8.5, "damage": 9.0, "attack_range": 2.2,
		"cost": 1, "radius": 0.45, "height": 0.8, "weak_offset": Vector3(0, 0.55, -0.3), "weak_radius": 0.25,
		"drop_chance": 0.12},
	&"warden": {"hp": 80.0, "shield": 40.0, "speed": 4.5, "damage": 11.0, "attack_range": 26.0,
		"cost": 3, "radius": 0.45, "height": 1.9, "weak_offset": Vector3(0, 1.65, 0), "weak_radius": 0.28,
		"drop_chance": 0.35, "telegraph": 0.6, "cooldown": 1.6},
	&"lobber": {"hp": 120.0, "shield": 60.0, "speed": 3.0, "damage": 22.0, "attack_range": 24.0,
		"cost": 4, "radius": 0.7, "height": 1.6, "weak_offset": Vector3(0, 1.45, 0.35), "weak_radius": 0.3,
		"drop_chance": 0.45, "cooldown": 3.0},
	&"shrieker": {"hp": 50.0, "shield": 0.0, "speed": 6.0, "damage": 0.0, "attack_range": 10.0,
		"cost": 3, "radius": 0.5, "height": 0.9, "weak_offset": Vector3(0, 0.45, 0), "weak_radius": 0.35,
		"drop_chance": 0.5, "cooldown": 4.0, "fly_height": 3.2},
	&"bulwark": {"hp": 300.0, "shield": 150.0, "speed": 2.8, "damage": 30.0, "attack_range": 3.2,
		"cost": 7, "radius": 0.9, "height": 2.4, "weak_offset": Vector3(0, 1.9, 0.6), "weak_radius": 0.35,
		"drop_chance": 0.9, "cooldown": 2.5, "frontal": true},
}

## Unlock deck (0-based) for each archetype; the director only spawns unlocked types.
const UNLOCK := {&"tick": 0, &"warden": 0, &"lobber": 1, &"shrieker": 2, &"bulwark": 3}

static func get_def(id: StringName) -> Dictionary:
	return DEFS[id]
