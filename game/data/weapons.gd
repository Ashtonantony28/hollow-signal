class_name WeaponData
## Balance table for the Lineman's arsenal (DESIGN.md §4, OVERHAUL.md §3). Edit numbers here.
## spread_deg = hip-fire base spread; ads_spread = spread while aiming; bloom = extra spread per shot.
## recoil = vertical kick (deg); recoil_yaw = horizontal pattern amplitude (deg).

const ALL: Array[StringName] = [&"rivet", &"hammer", &"needle", &"carbine", &"scatter", &"longwire", &"lance", &"launcher", &"hailstorm"]
const DEFAULT_LOADOUT: Array[StringName] = [&"rivet", &"carbine", &"scatter", &"launcher"]
const STARTER_UNLOCKS: Array[StringName] = [&"rivet", &"carbine", &"scatter", &"needle", &"launcher"]
## Legacy alias used by older code paths/tests.
const ORDER: Array[StringName] = [&"rivet", &"scatter", &"lance", &"launcher"]

const DEFS := {
	&"rivet": {
		"name": "Rivet Driver", "class": "Sidearm", "kind": "hitscan", "damage": 18.0, "pellets": 1,
		"spread_deg": 1.0, "ads_spread": 0.15, "bloom": 0.6, "fire_interval": 0.16, "mag": 12, "reserve_max": -1,
		"reload_time": 1.0, "range": 120.0, "recoil": 1.2, "recoil_yaw": 0.3, "sound": &"rivet", "auto": false,
		"ads_fov": 0.8, "unlock_cost": 0,
	},
	&"hammer": {
		"name": "Hammer", "class": "Revolver", "kind": "hitscan", "damage": 55.0, "pellets": 1,
		"spread_deg": 1.2, "ads_spread": 0.1, "bloom": 2.0, "fire_interval": 0.42, "mag": 6, "reserve_max": 36,
		"reload_time": 1.8, "range": 140.0, "recoil": 5.0, "recoil_yaw": 1.0, "sound": &"hammer", "auto": false,
		"ads_fov": 0.75, "unlock_cost": 120,
	},
	&"needle": {
		"name": "Needle", "class": "SMG", "kind": "hitscan", "damage": 10.0, "pellets": 1,
		"spread_deg": 2.4, "ads_spread": 1.0, "bloom": 0.25, "fire_interval": 0.06, "mag": 36, "reserve_max": 216,
		"reload_time": 1.4, "range": 60.0, "recoil": 0.55, "recoil_yaw": 0.45, "sound": &"needle", "auto": true,
		"ads_fov": 0.85, "unlock_cost": 0,
	},
	&"carbine": {
		"name": "Arc Carbine", "class": "Rifle", "kind": "hitscan", "damage": 19.0, "pellets": 1,
		"spread_deg": 1.6, "ads_spread": 0.25, "bloom": 0.3, "fire_interval": 0.1, "mag": 30, "reserve_max": 180,
		"reload_time": 1.6, "range": 120.0, "recoil": 0.9, "recoil_yaw": 0.35, "sound": &"carbine", "auto": true,
		"ads_fov": 0.7, "unlock_cost": 0,
	},
	&"scatter": {
		"name": "Scattercoil", "class": "Shotgun", "kind": "hitscan", "damage": 9.0, "pellets": 10,
		"spread_deg": 6.0, "ads_spread": 4.2, "bloom": 0.0, "fire_interval": 0.75, "mag": 6, "reserve_max": 30,
		"reload_time": 1.6, "range": 40.0, "recoil": 4.0, "recoil_yaw": 0.8, "sound": &"scatter", "auto": false,
		"ads_fov": 0.85, "unlock_cost": 0,
	},
	&"longwire": {
		"name": "Longwire", "class": "Marksman", "kind": "hitscan", "damage": 95.0, "pellets": 1, "pierce": 2,
		"spread_deg": 4.0, "ads_spread": 0.0, "bloom": 0.0, "fire_interval": 0.7, "mag": 5, "reserve_max": 30,
		"reload_time": 2.1, "range": 220.0, "recoil": 6.0, "recoil_yaw": 0.6, "sound": &"longwire", "auto": false,
		"ads_fov": 0.33, "scope": true, "unlock_cost": 180,
	},
	&"lance": {
		"name": "Arc Lance", "class": "Beam", "kind": "beam", "damage": 30.0, "damage_max": 110.0, "charge_time": 0.8,
		"pierce": 3, "pellets": 1, "spread_deg": 0.0, "ads_spread": 0.0, "bloom": 0.0, "fire_interval": 0.35,
		"mag": 8, "reserve_max": 40, "reload_time": 1.8, "range": 150.0, "recoil": 3.0, "recoil_yaw": 0.4,
		"sound": &"lance", "auto": false, "ads_fov": 0.6, "unlock_cost": 150,
	},
	&"launcher": {
		"name": "Pressure Launcher", "class": "Heavy", "kind": "projectile", "damage": 85.0, "splash_radius": 4.0,
		"projectile_speed": 28.0, "pellets": 1, "spread_deg": 0.0, "ads_spread": 0.0, "bloom": 0.0,
		"fire_interval": 0.9, "mag": 3, "reserve_max": 10, "reload_time": 2.0, "range": 80.0, "recoil": 5.0,
		"recoil_yaw": 0.5, "sound": &"launcher", "auto": false, "self_damage_scale": 0.35, "self_knockback": 11.0,
		"ads_fov": 0.85, "unlock_cost": 0,
	},
	&"hailstorm": {
		"name": "Hailstorm", "class": "LMG", "kind": "hitscan", "damage": 15.0, "pellets": 1, "spinup": 0.45,
		"spread_deg": 3.0, "ads_spread": 0.9, "bloom": 0.08, "fire_interval": 0.07, "mag": 90, "reserve_max": 270,
		"reload_time": 3.0, "range": 100.0, "recoil": 0.7, "recoil_yaw": 0.6, "sound": &"hailstorm", "auto": true,
		"ads_fov": 0.75, "move_mult": 0.85, "unlock_cost": 220,
	},
}

static func get_def(id: StringName) -> Dictionary:
	return DEFS[id]
