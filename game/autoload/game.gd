extends Node
## Run state (DESIGN.md §7): seed, deck index, player stats carried between decks, mods, stats.

const DECK_COUNT := 5
const DIFFICULTY_NAMES := ["Lineman", "Foreman", "Story"]

var run_seed: int = 0
var deck_index: int = 0
var in_run := false

# carried player stats
var max_integrity := 100.0
var integrity := 100.0
var plating := 0.0
var max_plating := 100.0
var charge := 0.0
var ammo: Dictionary = {}     # weapon id -> {mag, reserve}
var mods: Dictionary = {}     # mod id -> stacks
var loadout: Array[StringName] = []  # the 4 weapons carried this run

# run statistics
var stats := {"kills": 0, "shots": 0, "hits": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "time": 0.0}

var rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	if in_run and not get_tree().paused:
		stats.time += delta

func new_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi() % 1000000
	run_seed = seed_value
	rng.seed = seed_value
	deck_index = 0
	in_run = true
	max_integrity = 100.0
	integrity = max_integrity
	plating = 0.0
	max_plating = 100.0
	charge = 0.0
	mods = {}
	ammo = {}
	loadout = Profile.loadout.duplicate()
	for id in WeaponData.ALL:
		var d: Dictionary = WeaponData.get_def(id)
		ammo[id] = {"mag": d.mag, "reserve": reserve_max(id) if d.reserve_max > 0 else -1}
	stats = {"kills": 0, "shots": 0, "hits": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "time": 0.0}

func deck_seed() -> int:
	return run_seed * 101 + deck_index * 7

func reserve_max(id: StringName) -> int:
	var base: int = WeaponData.get_def(id).reserve_max
	if base < 0:
		return -1
	return int(base * (1.0 + 0.5 * mod_level(&"deep_pockets")))

func mod_level(id: StringName) -> int:
	return int(mods.get(id, 0))

func apply_mod(id: StringName) -> void:
	mods[id] = mod_level(id) + 1
	match id:
		&"vitality":
			max_integrity += 25.0
			integrity = max_integrity
		&"plated":
			max_plating += 25.0

func pulse_cost() -> float:
	return 35.0 if mod_level(&"overclock") > 0 else 50.0

func retune_time() -> float:
	return 0.1 if mod_level(&"quick_tuner") > 0 else 0.25

## Difficulty scalars.
func enemy_hp_scale() -> float:
	return [1.0, 1.3, 0.85][Settings.difficulty] * (1.0 + 0.08 * deck_index)

func damage_taken_scale() -> float:
	return [1.0, 1.25, 0.5][Settings.difficulty]

func attack_tokens() -> int:
	return [3, 4, 2][Settings.difficulty] + (1 if deck_index >= 3 else 0)

func wave_budget(base: int) -> int:
	return int(round(base * pow(1.25, deck_index) * [1.0, 1.25, 0.8][Settings.difficulty]))

func start_next_deck() -> void:
	deck_index += 1
	if mod_level(&"plated") > 0:
		plating = minf(max_plating, plating + 25.0 * mod_level(&"plated"))

func accuracy() -> float:
	return 0.0 if stats.shots == 0 else float(stats.hits) / float(stats.shots)
