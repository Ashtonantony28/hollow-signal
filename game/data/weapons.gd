class_name WeaponData
## Balance table for the Lineman's arsenal (DESIGN.md §4). Edit numbers here, not in code.

const ORDER: Array[StringName] = [&"rivet", &"scatter", &"lance", &"launcher"]

const DEFS := {
	&"rivet": {
		"name": "Rivet Driver", "kind": "hitscan", "damage": 18.0, "pellets": 1, "spread_deg": 0.4,
		"fire_interval": 0.2, "mag": 12, "reserve_max": -1, "reload_time": 1.0, "range": 120.0,
		"recoil": 1.2, "sound": &"rivet", "auto": false,
	},
	&"scatter": {
		"name": "Scattercoil", "kind": "hitscan", "damage": 9.0, "pellets": 9, "spread_deg": 6.0,
		"fire_interval": 0.8, "mag": 6, "reserve_max": 24, "reload_time": 1.6, "range": 40.0,
		"recoil": 4.0, "sound": &"scatter", "auto": false,
	},
	&"lance": {
		"name": "Arc Lance", "kind": "beam", "damage": 30.0, "damage_max": 110.0, "charge_time": 0.8,
		"pierce": 3, "pellets": 1, "spread_deg": 0.0, "fire_interval": 0.35, "mag": 8, "reserve_max": 40,
		"reload_time": 1.8, "range": 150.0, "recoil": 3.0, "sound": &"lance", "auto": false,
	},
	&"launcher": {
		"name": "Pressure Launcher", "kind": "projectile", "damage": 85.0, "splash_radius": 4.0,
		"projectile_speed": 28.0, "pellets": 1, "spread_deg": 0.0, "fire_interval": 0.9, "mag": 3,
		"reserve_max": 10, "reload_time": 2.0, "range": 80.0, "recoil": 5.0, "sound": &"launcher",
		"auto": false, "self_damage_scale": 0.35, "self_knockback": 11.0,
	},
}

static func get_def(id: StringName) -> Dictionary:
	return DEFS[id]
