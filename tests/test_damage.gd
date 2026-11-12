extends TestBase

func test_matching_band_triples_shield_damage() -> void:
	var r := DamageModel.apply_hit(10.0, 1, false, 100.0, 1, 50.0)
	near(r.shield, 70.0)
	check(r.matched, "should be matched")
	near(r.hp, 50.0)

func test_offband_halves_shield_damage() -> void:
	var r := DamageModel.apply_hit(10.0, 0, false, 100.0, 2, 50.0)
	near(r.shield, 95.0)
	check(not r.matched)

func test_overflow_carries_into_hp() -> void:
	# 30 matched = 90 effective vs 60 shield -> 30 effective leftover -> 10 raw to hp
	var r := DamageModel.apply_hit(30.0, 2, false, 60.0, 2, 100.0)
	check(r.broke, "shield should break")
	near(r.shield, 0.0)
	near(r.hp, 90.0)

func test_weak_point_doubles_body_damage() -> void:
	var r := DamageModel.apply_hit(18.0, 0, true, 0.0, 0, 80.0)
	near(r.hp, 44.0)

func test_no_overkill_below_zero() -> void:
	var r := DamageModel.apply_hit(500.0, 0, false, 0.0, 0, 30.0)
	near(r.hp, 0.0)
	near(r.hp_damage, 30.0)

func test_plating_absorbs_sixty_percent() -> void:
	var r := DamageModel.apply_to_player(20.0, 100.0, 50.0)
	near(r.integrity, 92.0)
	near(r.plating, 38.0)

func test_plating_runs_out() -> void:
	var r := DamageModel.apply_to_player(20.0, 100.0, 5.0)
	near(r.plating, 0.0)
	near(r.integrity, 85.0)

func test_lance_charge_curve() -> void:
	near(DamageModel.lance_damage(30, 110, 0.0, 0.8), 30.0)
	near(DamageModel.lance_damage(30, 110, 0.4, 0.8), 70.0)
	near(DamageModel.lance_damage(30, 110, 5.0, 0.8), 110.0)

func test_splash_falloff() -> void:
	near(DamageModel.splash(100, 0, 4), 100.0)
	near(DamageModel.splash(100, 4, 4), 30.0)
	near(DamageModel.splash(100, 4.1, 4), 0.0)
