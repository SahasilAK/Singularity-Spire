class_name WaveMath
extends RefCounted

static func enemy_count(wave: int) -> int:
	return 5 + wave + int(pow(float(wave), 0.72))

static func health_multiplier(wave: int) -> float:
	return pow(1.145, max(0, wave - 1)) * (1.0 + floor(float(wave) / 10.0) * 0.15)

static func speed_multiplier(wave: int) -> float:
	return 1.0 + min(1.4, float(wave - 1) * 0.018)

static func mutation_tier(wave: int) -> int:
	return int(floor(float(max(0, wave - 1)) / 8.0))

static func spawn_interval(wave: int) -> float:
	return max(0.18, 0.72 - float(wave) * 0.012)
