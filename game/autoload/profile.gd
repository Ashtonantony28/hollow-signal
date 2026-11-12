extends Node
## Persistent meta progression between runs: Salvage currency, unlocked weapons, saved loadout.

const PATH := "user://profile.cfg"
const LOADOUT_SIZE := 4

var salvage := 0
var unlocked: Array[StringName] = []
var loadout: Array[StringName] = []
var best_deck := 0
var runs := 0

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	unlocked = WeaponData.STARTER_UNLOCKS.duplicate()
	loadout = WeaponData.DEFAULT_LOADOUT.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	salvage = cfg.get_value("profile", "salvage", 0)
	best_deck = cfg.get_value("profile", "best_deck", 0)
	runs = cfg.get_value("profile", "runs", 0)
	for id in cfg.get_value("profile", "unlocked", []):
		if WeaponData.DEFS.has(StringName(id)) and not StringName(id) in unlocked:
			unlocked.append(StringName(id))
	var lo: Array = cfg.get_value("profile", "loadout", [])
	if lo.size() == LOADOUT_SIZE:
		var tmp: Array[StringName] = []
		for id in lo:
			if WeaponData.DEFS.has(StringName(id)) and StringName(id) in unlocked:
				tmp.append(StringName(id))
		if tmp.size() == LOADOUT_SIZE:
			loadout = tmp

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "salvage", salvage)
	cfg.set_value("profile", "best_deck", best_deck)
	cfg.set_value("profile", "runs", runs)
	cfg.set_value("profile", "unlocked", unlocked.map(func(x): return String(x)))
	cfg.set_value("profile", "loadout", loadout.map(func(x): return String(x)))
	cfg.save(PATH)

func is_unlocked(id: StringName) -> bool:
	return id in unlocked

func try_unlock(id: StringName) -> bool:
	var cost: int = WeaponData.get_def(id).unlock_cost
	if is_unlocked(id) or salvage < cost:
		return false
	salvage -= cost
	unlocked.append(id)
	save_profile()
	return true

## Toggle a weapon in/out of the loadout, keeping exactly LOADOUT_SIZE entries (replaces the last slot).
func toggle_loadout(id: StringName) -> void:
	if not is_unlocked(id):
		return
	if id in loadout:
		return
	loadout[LOADOUT_SIZE - 1] = id
	save_profile()

func set_slot(slot: int, id: StringName) -> void:
	if not is_unlocked(id) or slot < 0 or slot >= LOADOUT_SIZE:
		return
	var existing := loadout.find(id)
	if existing >= 0:
		loadout[existing] = loadout[slot]
	loadout[slot] = id
	save_profile()

## Salvage earned for a finished run.
static func salvage_for(kills: int, decks_cleared: int, victory: bool) -> int:
	return kills + decks_cleared * 30 + (150 if victory else 0)

func award_run(kills: int, deck_reached: int, victory: bool) -> int:
	var cleared := deck_reached + (1 if victory else 0)
	var gained := salvage_for(kills, cleared, victory)
	salvage += gained
	runs += 1
	best_deck = maxi(best_deck, deck_reached + 1)
	save_profile()
	return gained
