class_name Progression
extends RefCounted

static func shards_for_wave(wave: int) -> int:
	return max(1, int(floor(pow(float(max(1, wave)), 0.82))))

static func meta_bonus(shards: int) -> float:
	return 1.0 + sqrt(float(max(0, shards))) * 0.025
