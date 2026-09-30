class_name Targeting
extends RefCounted

static func leading_index(targets: Array) -> int:
	var best_index := -1
	var best_progress := -INF
	for i in targets.size():
		var target: Dictionary = targets[i]
		if bool(target.get("alive", false)) and float(target.get("progress", -INF)) > best_progress:
			best_progress = float(target.progress)
			best_index = i
	return best_index

