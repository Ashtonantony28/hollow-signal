extends Node
## Global signal bus. Systems emit here instead of holding references to each other.

signal player_damaged(amount: float, from_dir: Vector3)
signal player_died
signal player_stats_changed
signal weapon_changed(weapon_id: StringName)
signal ammo_changed(in_mag: int, reserve: int)
signal band_changed(band: int)
signal enemy_hit(enemy: Node, damage: float, weak: bool, shield_hit: bool, matched: bool)
signal enemy_killed(enemy: Node)
signal objective_changed(text: String)
signal message(text: String, seconds: float)
signal uplink_progress(fraction: float, active: bool)
signal deck_completed(deck_index: int)
signal run_finished(victory: bool)
signal pulse_fired(origin: Vector3)
signal intensity_changed(value: float)
