class_name ModData
## Patch Bay upgrades (DESIGN.md §7.1). Effects are applied by Game.apply_mod().

const DEFS := {
	&"snap_drive": {"name": "Snap Drive", "desc": "Unlocks the dash (Alt). 2 charges.", "max": 1},
	&"harmonic": {"name": "Harmonic Rounds", "desc": "Matching-band hits splash 25% shield damage to nearby enemies.", "max": 1},
	&"reclaimer": {"name": "Reclaimer", "desc": "+15% chance for kills to drop repair.", "max": 3},
	&"deep_pockets": {"name": "Deep Pockets", "desc": "+50% max reserve ammo.", "max": 2},
	&"overclock": {"name": "Overclocked Pulse", "desc": "Pulse costs 35 charge instead of 50.", "max": 1},
	&"plated": {"name": "Plated", "desc": "+25 plating at each deck start; max plating +25.", "max": 2},
	&"quick_tuner": {"name": "Quick Tuner", "desc": "Retune in 0.1s; first shot after retune +50% damage.", "max": 1},
	&"momentum": {"name": "Momentum Core", "desc": "+20% damage while moving faster than 9 m/s.", "max": 2},
	&"vitality": {"name": "Reinforced Frame", "desc": "+25 max integrity and heal to full.", "max": 3},
}

## Deterministic pick of `count` distinct offers not yet maxed.
static func offers(rng: RandomNumberGenerator, owned: Dictionary, count: int = 3) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id in DEFS:
		if int(owned.get(id, 0)) < int(DEFS[id].max):
			pool.append(id)
	var out: Array[StringName] = []
	while out.size() < count and pool.size() > 0:
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx])
		pool.remove_at(idx)
	return out
