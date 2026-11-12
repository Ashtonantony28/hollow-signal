class_name DamageModel
## Pure damage math (DESIGN.md §3.4). No scene dependencies, fully unit-tested.

const MATCH_MULT := 3.0
const OFFBAND_MULT := 0.5
const WEAK_MULT := 2.0
const PLATING_ABSORB := 0.6

## Applies `amount` of band-`band` damage to a target with `shield` (on `shield_band`) and `hp`.
## Returns {shield, hp, shield_damage, hp_damage, matched, broke}.
static func apply_hit(amount: float, band: int, weak: bool, shield: float, shield_band: int, hp: float) -> Dictionary:
	var res := {"shield": shield, "hp": hp, "shield_damage": 0.0, "hp_damage": 0.0, "matched": false, "broke": false}
	var remaining := amount
	if shield > 0.0:
		var matched := band == shield_band
		res.matched = matched
		var mult := MATCH_MULT if matched else OFFBAND_MULT
		var eff := remaining * mult
		if eff >= shield:
			res.shield_damage = shield
			res.shield = 0.0
			res.broke = true
			# leftover converts back to raw damage at the same multiplier
			remaining = (eff - shield) / mult
		else:
			res.shield_damage = eff
			res.shield = shield - eff
			return res
	var body := remaining * (WEAK_MULT if weak else 1.0)
	res.hp_damage = minf(body, hp)
	res.hp = maxf(hp - body, 0.0)
	return res

## Player side: plating absorbs a share of damage while it lasts.
## Returns {integrity, plating}.
static func apply_to_player(amount: float, integrity: float, plating: float, damage_scale: float = 1.0) -> Dictionary:
	var dmg := amount * damage_scale
	var absorbed := minf(dmg * PLATING_ABSORB, plating)
	return {"integrity": maxf(integrity - (dmg - absorbed), 0.0), "plating": plating - absorbed}

## Arc Lance charge curve: linear from min to max over charge_time.
static func lance_damage(min_d: float, max_d: float, charge: float, charge_time: float) -> float:
	return lerpf(min_d, max_d, clampf(charge / charge_time, 0.0, 1.0))

## Splash falloff: full at centre, 30% at the edge, 0 outside.
static func splash(amount: float, dist: float, radius: float) -> float:
	if dist > radius:
		return 0.0
	return amount * lerpf(1.0, 0.3, dist / radius)
