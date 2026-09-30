class_name UpgradeMath
extends RefCounted

static func cost(level: int, base_cost: int) -> int:
	return int(ceil(float(base_cost) * pow(1.32, level)))

static func power(level: int, base_power: float) -> float:
	return base_power * pow(1.18, level)

static func range_value(level: int, base_range: float) -> float:
	return base_range * (1.0 + log(1.0 + float(level)) * 0.12)

