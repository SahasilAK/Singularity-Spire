extends Node2D

const WaveRules = preload("res://scripts/wave_math.gd")
const UpgradeRules = preload("res://scripts/upgrade_math.gd")
const TargetRules = preload("res://scripts/targeting.gd")
const ProgressRules = preload("res://scripts/progression.gd")

const GRID := 9
const TILE_W := 82.0
const TILE_H := 41.0
const ORIGIN := Vector2(640, 132)
const PATH: Array[Vector2i] = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 3),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5),
	Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(4, 5),
	Vector2i(4, 4)
]
const TOWER_DATA := {
	"pulse": {"name": "PULSE", "cost": 55, "damage": 14.0, "rate": 0.48, "range": 150.0, "color": Color("39f6ff")},
	"rail": {"name": "RAIL", "cost": 95, "damage": 58.0, "rate": 1.65, "range": 215.0, "color": Color("ff4fd8")},
	"nova": {"name": "NOVA", "cost": 125, "damage": 27.0, "rate": 1.15, "range": 132.0, "color": Color("9d72ff")}
}
const SAVE_PATH := "user://singularity_spire.save"

var towers: Dictionary = {}
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var selected_kind := "pulse"
var hovered_cell := Vector2i(-99, -99)
var selected_cell := Vector2i(-99, -99)
var wave := 0
var credits := 180
var core_hp := 20
var core_max := 20
var score := 0
var kills := 0
var spawn_left := 0
var spawn_timer := 0.0
var wave_active := false
var intermission := 1.5
var game_over := false
var paused := false
var time_scale := 1.0
var protocol_choices: Array[String] = []
var protocol_levels := {"power": 0, "haste": 0, "reach": 0, "yield": 0, "core": 0, "rupture": 0}
var best_wave := 0
var shards := 0
var meta_bonus := 1.0
var banner := "INITIALIZING DEFENSE GRID"
var banner_time := 2.5
var rng := RandomNumberGenerator.new()
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.randomize()
	_load_progress()
	meta_bonus = ProgressRules.meta_bonus(shards)
	queue_redraw()

func _process(delta: float) -> void:
	if paused or game_over or not protocol_choices.is_empty():
		queue_redraw()
		return
	var dt := delta * time_scale
	banner_time = max(0.0, banner_time - dt)
	if wave_active:
		_update_spawning(dt)
		_update_enemies(dt)
		_update_towers(dt)
		if spawn_left <= 0 and enemies.is_empty():
			_finish_wave()
	else:
		intermission -= dt
		if intermission <= 0.0:
			_start_wave()
	_update_effects(dt)
	queue_redraw()

func _start_wave() -> void:
	wave += 1
	wave_active = true
	spawn_left = WaveRules.enemy_count(wave)
	spawn_timer = 0.1
	banner = "WAVE %02d // BREACH DETECTED" % wave
	banner_time = 2.0

func _update_spawning(dt: float) -> void:
	if spawn_left <= 0:
		return
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_left -= 1
		spawn_timer = WaveRules.spawn_interval(wave)

func _spawn_enemy() -> void:
	var tier := WaveRules.mutation_tier(wave)
	var kind := "drone"
	var roll := rng.randf()
	if tier >= 1 and roll < 0.20:
		kind = "swift"
	elif tier >= 2 and roll < 0.38:
		kind = "bulwark"
	elif tier >= 3 and roll < 0.50:
		kind = "splitter"
	var hp := 52.0 * WaveRules.health_multiplier(wave)
	var speed := 0.68 * WaveRules.speed_multiplier(wave)
	var reward := 10 + int(wave * 0.55)
	var color := Color("54efff")
	var armor := 0.0
	if kind == "swift":
		hp *= 0.62; speed *= 1.65; color = Color("f5ec5d")
	elif kind == "bulwark":
		hp *= 2.7; speed *= 0.62; armor = 0.25; reward *= 2; color = Color("ff596f")
	elif kind == "splitter":
		hp *= 1.35; speed *= 1.08; reward = int(reward * 1.5); color = Color("b777ff")
	enemies.append({"progress": 0.0, "hp": hp, "max_hp": hp, "speed": speed, "reward": reward, "color": color, "armor": armor, "kind": kind, "alive": true})

func _update_enemies(dt: float) -> void:
	for enemy in enemies:
		enemy.progress += enemy.speed * dt
		if enemy.progress >= float(PATH.size() - 1):
			enemy.alive = false
			core_hp -= 1 if enemy.kind != "bulwark" else 2
			_burst(_enemy_position(enemy), Color("ff315d"), 12)
	for i in range(enemies.size() - 1, -1, -1):
		if not enemies[i].alive:
			enemies.remove_at(i)
	if core_hp <= 0:
		_end_run()

func _update_towers(dt: float) -> void:
	for cell in towers:
		var tower: Dictionary = towers[cell]
		tower.cooldown -= dt
		if tower.cooldown > 0.0:
			continue
		var data: Dictionary = TOWER_DATA[tower.kind]
		var range_px := UpgradeRules.range_value(tower.level + protocol_levels.reach, data.range)
		var target_index := _leading_target_in_range(grid_to_screen(cell), range_px)
		if target_index < 0:
			continue
		var damage := UpgradeRules.power(tower.level + protocol_levels.power, data.damage) * meta_bonus
		var fire_rate: float = data.rate / (1.0 + protocol_levels.haste * 0.12)
		tower.cooldown = fire_rate
		_fire_at(cell, target_index, damage, tower.kind, data.color)

func _leading_target_in_range(position: Vector2, range_px: float) -> int:
	var candidates: Array = []
	var mapping: Array[int] = []
	for i in enemies.size():
		var enemy := enemies[i]
		if enemy.alive and position.distance_to(_enemy_position(enemy)) <= range_px:
			candidates.append(enemy)
			mapping.append(i)
	var local_index := TargetRules.leading_index(candidates)
	return -1 if local_index < 0 else mapping[local_index]

func _fire_at(cell: Vector2i, target_index: int, damage: float, kind: String, color: Color) -> void:
	if target_index >= enemies.size():
		return
	var origin := grid_to_screen(cell) - Vector2(0, 27)
	var target_pos := _enemy_position(enemies[target_index]) - Vector2(0, 12)
	shots.append({"from": origin, "to": target_pos, "life": 0.13, "color": color, "width": 2.5 if kind == "pulse" else 4.0})
	if kind == "nova":
		for enemy in enemies:
			if enemy.alive and _enemy_position(enemy).distance_to(target_pos) < 72.0:
				_damage_enemy(enemy, damage)
	else:
		_damage_enemy(enemies[target_index], damage * (1.0 + protocol_levels.rupture * 0.08))

func _damage_enemy(enemy: Dictionary, amount: float) -> void:
	enemy.hp -= amount * (1.0 - enemy.armor)
	if enemy.hp <= 0.0 and enemy.alive:
		enemy.alive = false
		var reward: int = int(enemy.reward * (1.0 + protocol_levels.yield * 0.12))
		credits += reward
		score += reward * 10
		kills += 1
		_burst(_enemy_position(enemy), enemy.color, 7)

func _update_effects(dt: float) -> void:
	for shot in shots: shot.life -= dt
	for i in range(shots.size() - 1, -1, -1):
		if shots[i].life <= 0.0: shots.remove_at(i)
	for particle in particles:
		particle.life -= dt
		particle.pos += particle.vel * dt
		particle.vel *= 0.93
	for i in range(particles.size() - 1, -1, -1):
		if particles[i].life <= 0.0: particles.remove_at(i)

func _finish_wave() -> void:
	wave_active = false
	credits += 28 + wave * 4
	score += wave * 100
	intermission = 4.0
	banner = "SECTOR SECURED  +%d ENERGY" % (28 + wave * 4)
	banner_time = 2.5
	if wave % 3 == 0:
		_offer_protocols()

func _offer_protocols() -> void:
	var pool := ["power", "haste", "reach", "yield", "core", "rupture"]
	pool.shuffle()
	protocol_choices = [pool[0], pool[1], pool[2]]

func _choose_protocol(index: int) -> void:
	if index < 0 or index >= protocol_choices.size(): return
	var choice := protocol_choices[index]
	protocol_levels[choice] += 1
	if choice == "core":
		core_max += 3
		core_hp = min(core_max, core_hp + 5)
	protocol_choices.clear()
	banner = "%s PROTOCOL INSTALLED" % choice.to_upper()
	banner_time = 2.0

func _end_run() -> void:
	game_over = true
	wave_active = false
	var gained := ProgressRules.shards_for_wave(wave)
	shards += gained
	best_wave = max(best_wave, wave)
	_save_progress()
	banner = "CORE COLLAPSED // +%d MEMORY SHARDS" % gained
	banner_time = 999.0

func _reset_run() -> void:
	towers.clear(); enemies.clear(); shots.clear(); particles.clear()
	wave = 0; credits = 180; core_hp = 20; core_max = 20; score = 0; kills = 0
	spawn_left = 0; wave_active = false; intermission = 1.5; game_over = false; paused = false
	protocol_choices.clear()
	protocol_levels = {"power": 0, "haste": 0, "reach": 0, "yield": 0, "core": 0, "rupture": 0}
	meta_bonus = ProgressRules.meta_bonus(shards)
	banner = "TIMELINE RECONSTRUCTED"; banner_time = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_cell = screen_to_grid(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1: selected_kind = "pulse"
		elif event.keycode == KEY_2: selected_kind = "rail"
		elif event.keycode == KEY_3: selected_kind = "nova"
		elif event.keycode == KEY_SPACE: time_scale = 2.5 if time_scale == 1.0 else 1.0
		elif event.keycode == KEY_P: paused = not paused
		elif event.keycode == KEY_R and game_over: _reset_run()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)
	queue_redraw()

func _handle_click(pos: Vector2) -> void:
	if game_over:
		if Rect2(530, 512, 220, 52).has_point(pos): _reset_run()
		return
	if not protocol_choices.is_empty():
		for i in 3:
			if Rect2(245 + i * 275, 300, 245, 145).has_point(pos): _choose_protocol(i)
		return
	for i in 3:
		if Rect2(22 + i * 164, 642, 150, 56).has_point(pos):
			selected_kind = ["pulse", "rail", "nova"][i]
			return
	var cell := screen_to_grid(pos)
	if not _valid_cell(cell): return
	if towers.has(cell):
		selected_cell = cell
		var tower: Dictionary = towers[cell]
		var cost := UpgradeRules.cost(tower.level, int(TOWER_DATA[tower.kind].cost))
		if credits >= cost:
			credits -= cost; tower.level += 1
			_burst(grid_to_screen(cell) - Vector2(0, 24), TOWER_DATA[tower.kind].color, 10)
		return
	if PATH.has(cell): return
	var build_cost: int = TOWER_DATA[selected_kind].cost
	if credits >= build_cost:
		credits -= build_cost
		towers[cell] = {"kind": selected_kind, "level": 0, "cooldown": 0.1}
		selected_cell = cell
		_burst(grid_to_screen(cell), TOWER_DATA[selected_kind].color, 10)

func grid_to_screen(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)

func screen_to_grid(pos: Vector2) -> Vector2i:
	var rel := pos - ORIGIN
	var a := rel.x / (TILE_W * 0.5)
	var b := rel.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))

func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID

func _enemy_position(enemy: Dictionary) -> Vector2:
	var p: float = clamp(enemy.progress, 0.0, float(PATH.size() - 1))
	var i := mini(int(floor(p)), PATH.size() - 2)
	return grid_to_screen(PATH[i]).lerp(grid_to_screen(PATH[i + 1]), p - float(i))

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		particles.append({"pos": pos, "vel": Vector2.from_angle(angle) * rng.randf_range(28.0, 90.0), "life": rng.randf_range(0.25, 0.7), "color": color})

func _draw() -> void:
	_draw_background()
	_draw_board()
	_draw_units()
	_draw_hud()
	if not protocol_choices.is_empty(): _draw_protocol_overlay()
	if game_over: _draw_game_over()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("050817"))
	for i in 22:
		var y := float(i * 37)
		draw_line(Vector2(0, y), Vector2(1280, y + 180), Color(0.05, 0.17, 0.27, 0.23), 1.0)
	for i in 18:
		var x := float(i * 85)
		draw_line(Vector2(x, 0), Vector2(x - 220, 720), Color(0.08, 0.11, 0.3, 0.18), 1.0)
	draw_circle(Vector2(640, 325), 330, Color(0.02, 0.16, 0.23, 0.16))

func _diamond(center: Vector2, color: Color, outline := Color.TRANSPARENT, width := 1.0) -> void:
	var points := PackedVector2Array([center + Vector2(0, -TILE_H * .5), center + Vector2(TILE_W * .5, 0), center + Vector2(0, TILE_H * .5), center + Vector2(-TILE_W * .5, 0)])
	draw_colored_polygon(points, color)
	if outline.a > 0.0: draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), outline, width, true)

func _draw_board() -> void:
	for sum in range(GRID * 2 - 1):
		for x in GRID:
			var y := sum - x
			if y < 0 or y >= GRID: continue
			var cell := Vector2i(x, y)
			var center := grid_to_screen(cell)
			var base := Color("101a34") if (x + y) % 2 == 0 else Color("0c162d")
			if PATH.has(cell): base = Color("102f43")
			if cell == hovered_cell and not PATH.has(cell): base = Color("164255")
			_diamond(center, base, Color(0.12, 0.54, 0.65, 0.28), 1.0)
			if PATH.has(cell):
				draw_circle(center, 4.0, Color("2bddec"))
	# Core reactor
	var core := grid_to_screen(PATH[-1])
	for r in [42.0, 31.0, 20.0]: draw_arc(core - Vector2(0, 18), r, 0, TAU, 32, Color(0.1, 0.9, 1.0, 0.18 + (42.0-r)/90.0), 3.0)
	draw_circle(core - Vector2(0, 18), 12, Color("e7ffff"))

func _draw_units() -> void:
	for cell in towers:
		var tower: Dictionary = towers[cell]
		var pos := grid_to_screen(cell)
		var color: Color = TOWER_DATA[tower.kind].color
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-18, 0), pos + Vector2(0, 10), pos + Vector2(18, 0), pos + Vector2(0, -10)]), Color("17213d"))
		draw_rect(Rect2(pos.x - 7, pos.y - 30, 14, 30), color.darkened(0.35))
		draw_circle(pos - Vector2(0, 31), 8.0, color)
		draw_circle(pos - Vector2(0, 31), 3.0, Color.WHITE)
		_draw_text(Vector2(pos.x - 14, pos.y + 22), "L%d" % (tower.level + 1), 12, color)
	for enemy in enemies:
		var pos := _enemy_position(enemy) - Vector2(0, 11)
		var color: Color = enemy.color
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -12), pos + Vector2(12, 0), pos + Vector2(0, 12), pos + Vector2(-12, 0)]), color.darkened(0.25))
		draw_circle(pos, 5.0, color)
		var hp_ratio: float = max(0.0, enemy.hp / enemy.max_hp)
		draw_rect(Rect2(pos.x - 15, pos.y - 20, 30, 3), Color("301324"))
		draw_rect(Rect2(pos.x - 15, pos.y - 20, 30 * hp_ratio, 3), color)
	for shot in shots: draw_line(shot.from, shot.to, shot.color, shot.width, true)
	for particle in particles: draw_circle(particle.pos, max(1.0, particle.life * 5.0), particle.color)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 78), Color(0.02, 0.035, 0.09, 0.96))
	draw_line(Vector2(0, 78), Vector2(1280, 78), Color("27dceb"), 2.0)
	_draw_text(Vector2(28, 34), "SINGULARITY", 25, Color("ebfcff"))
	_draw_text(Vector2(28, 59), "SPIRE // NULL SECTOR", 13, Color("43dbe8"))
	_draw_stat(Vector2(300, 30), "WAVE", "%02d" % wave, Color("58f0ff"))
	_draw_stat(Vector2(440, 30), "CORE", "%d/%d" % [core_hp, core_max], Color("ff5b7c"))
	_draw_stat(Vector2(590, 30), "ENERGY", str(credits), Color("f9dc5c"))
	_draw_stat(Vector2(755, 30), "KILLS", str(kills), Color("ac8dff"))
	_draw_stat(Vector2(900, 30), "SHARDS", str(shards), Color("63ffa8"))
	_draw_stat(Vector2(1060, 30), "SPEED", "%.1fx" % time_scale, Color("58f0ff"))
	if banner_time > 0.0:
		var size := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_rect(Rect2(640 - size.x * .5 - 18, 88, size.x + 36, 34), Color(0.02, 0.05, 0.12, 0.9))
		_draw_text(Vector2(640 - size.x * .5, 111), banner, 16, Color("7ff7ff"))
	# Build bar
	draw_rect(Rect2(0, 625, 1280, 95), Color(0.02, 0.035, 0.08, 0.97))
	for i in 3:
		var kind: String = ["pulse", "rail", "nova"][i]
		var rect := Rect2(22 + i * 164, 642, 150, 56)
		var active := selected_kind == kind
		draw_rect(rect, Color("17324a") if active else Color("0d172b"), true)
		draw_rect(rect, TOWER_DATA[kind].color if active else Color("29445d"), false, 2.0)
		_draw_text(rect.position + Vector2(12, 22), "%d  %s" % [i + 1, TOWER_DATA[kind].name], 15, TOWER_DATA[kind].color)
		_draw_text(rect.position + Vector2(12, 43), "%d E" % TOWER_DATA[kind].cost, 12, Color("f9dc5c"))
	_draw_text(Vector2(530, 661), "CLICK EMPTY TILE: BUILD  •  CLICK TOWER: UPGRADE", 13, Color("91a8c8"))
	_draw_text(Vector2(530, 685), "[SPACE] TIME WARP   [P] PAUSE", 13, Color("5ce8f1"))
	if towers.has(selected_cell):
		var t: Dictionary = towers[selected_cell]
		var up_cost := UpgradeRules.cost(t.level, int(TOWER_DATA[t.kind].cost))
		_draw_text(Vector2(1000, 657), "%s L%d" % [TOWER_DATA[t.kind].name, t.level + 1], 15, TOWER_DATA[t.kind].color)
		_draw_text(Vector2(1000, 681), "NEXT: %d E" % up_cost, 13, Color("f9dc5c"))

func _draw_protocol_overlay() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.08, 0.84))
	_draw_text(Vector2(440, 225), "CHOOSE AN ENDLESS PROTOCOL", 25, Color("e8fdff"))
	_draw_text(Vector2(480, 256), "Every protocol stacks without limit", 14, Color("6cdde8"))
	var descriptions := {"power": "+18% tower power", "haste": "+12% firing speed", "reach": "+12% range curve", "yield": "+12% kill energy", "core": "+3 max core, repair 5", "rupture": "+8% focused damage"}
	for i in 3:
		var key := protocol_choices[i]
		var rect := Rect2(245 + i * 275, 300, 245, 145)
		draw_rect(rect, Color("0c1834"), true)
		draw_rect(rect, Color("42e9f5"), false, 2.0)
		_draw_text(rect.position + Vector2(18, 35), key.to_upper(), 20, Color("73f5ff"))
		_draw_text(rect.position + Vector2(18, 72), descriptions[key], 14, Color("d3e7f4"))
		_draw_text(rect.position + Vector2(18, 112), "STACK %d → %d" % [protocol_levels[key], protocol_levels[key] + 1], 12, Color("a886ff"))

func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.0, 0.06, 0.84))
	draw_rect(Rect2(390, 180, 500, 390), Color("090d22"), true)
	draw_rect(Rect2(390, 180, 500, 390), Color("ff426d"), false, 2.0)
	_draw_text(Vector2(490, 240), "TIMELINE TERMINATED", 27, Color("ff6383"))
	_draw_text(Vector2(518, 295), "WAVE REACHED", 14, Color("93a9c6"))
	_draw_text(Vector2(596, 345), str(wave), 48, Color.WHITE)
	_draw_text(Vector2(485, 395), "SCORE %08d   •   BEST %02d" % [score, best_wave], 16, Color("6eeef6"))
	_draw_text(Vector2(505, 430), "MEMORY SHARDS BANKED: %d" % shards, 14, Color("63ffa8"))
	draw_rect(Rect2(530, 512, 220, 52), Color("42204a"), true)
	draw_rect(Rect2(530, 512, 220, 52), Color("ff5b87"), false, 2.0)
	_draw_text(Vector2(568, 545), "RESTART TIMELINE [R]", 15, Color.WHITE)

func _draw_stat(pos: Vector2, label: String, value: String, color: Color) -> void:
	_draw_text(pos, label, 11, Color("7087a7"))
	_draw_text(pos + Vector2(0, 25), value, 20, color)

func _draw_text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		best_wave = int(data.get("best_wave", 0))
		shards = int(data.get("shards", 0))

func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"best_wave": best_wave, "shards": shards}))
