extends SceneTree

var failures := 0

func _init() -> void:
	_test_wave_scaling()
	_test_endless_upgrade_scaling()
	_test_target_selection()
	_test_meta_progression()
	if failures == 0:
		print("ALL TESTS PASSED (4/4)")
	quit(failures)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)

func _test_wave_scaling() -> void:
	var wave = load("res://scripts/wave_math.gd")
	_expect(wave.enemy_count(1) == 7, "wave 1 starts with seven enemies")
	_expect(wave.enemy_count(50) > wave.enemy_count(49), "enemy count remains endless")
	_expect(wave.health_multiplier(25) > wave.health_multiplier(10), "health scales with wave")
	_expect(wave.mutation_tier(30) >= 3, "late waves gain mutation tiers")

func _test_endless_upgrade_scaling() -> void:
	var upgrades = load("res://scripts/upgrade_math.gd")
	_expect(upgrades.cost(0, 40) == 40, "first upgrade uses base cost")
	_expect(upgrades.cost(20, 40) > upgrades.cost(19, 40), "upgrade costs remain increasing")
	_expect(upgrades.power(20, 10.0) > upgrades.power(10, 10.0), "power has no level cap")

func _test_target_selection() -> void:
	var targeting = load("res://scripts/targeting.gd")
	var targets := [{"progress": 0.2, "alive": true}, {"progress": 0.9, "alive": true}, {"progress": 1.0, "alive": false}]
	_expect(targeting.leading_index(targets) == 1, "tower targets leading living enemy")

func _test_meta_progression() -> void:
	var progression = load("res://scripts/progression.gd")
	_expect(progression.shards_for_wave(1) == 1, "a short run earns a shard")
	_expect(progression.shards_for_wave(20) > progression.shards_for_wave(10), "longer runs earn more shards")
	_expect(progression.meta_bonus(9) > progression.meta_bonus(0), "shards grant persistent power")
