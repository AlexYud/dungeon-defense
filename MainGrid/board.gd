extends Node2D

@export var cols: int = 10
@export var rows: int = 10
@export var tile_size: int = 128
@export var min_start_chest_distance: int = 6

@export var path_corridor_cost: float = 0.0
@export var path_hero_attack_dps: float = 45.0
@export var path_hero_attack_vs_boss_dps: float = 38.0

var start_cell: Vector2i = Vector2i.ZERO
var chest_cell: Vector2i = Vector2i.ONE

# "x,y" -> room data dictionary
var placed_tiles: Dictionary = {}

# Run stats
var run_total_kills: int = 0
var run_total_escapes: int = 0

func _ready() -> void:
	randomize()
	roll_start_and_chest()
	queue_redraw()

func _process(delta: float) -> void:
	update_room_timers(delta)

func roll_start_and_chest() -> void:
	start_cell = Vector2i(randi_range(0, cols - 1), randi_range(0, rows - 1))
	chest_cell = start_cell

	while chest_cell == start_cell or manhattan_distance(start_cell, chest_cell) < min_start_chest_distance:
		chest_cell = Vector2i(randi_range(0, cols - 1), randi_range(0, rows - 1))

func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_board_rect_global() -> Rect2:
	var size: Vector2 = Vector2(float(cols * tile_size), float(rows * tile_size))
	return Rect2(global_position, size)

func cell_to_world(cell: Vector2i) -> Vector2:
	return global_position + Vector2(
		float(cell.x * tile_size + tile_size / 2),
		float(cell.y * tile_size + tile_size / 2)
	)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - global_position
	return Vector2i(
		int(floor(local.x / float(tile_size))),
		int(floor(local.y / float(tile_size)))
	)

func is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

func is_cell_blocked(cell: Vector2i) -> bool:
	return cell == start_cell or cell == chest_cell

func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func cell_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i(-999, -999)
	return Vector2i(int(parts[0]), int(parts[1]))

func make_room_data(tile_type: String, tile_level: int) -> Dictionary:
	var safe_level: int = clamp(tile_level, 1, 3)

	var data: Dictionary = {
		"type": tile_type,
		"level": safe_level,
		"beaten": false,
		"cooldown_left": 0.0,
		"mob_count": 0,
		"mob_hp": 0.0,
		"boss_hp": 0.0,

		# Stats
		"damage_dealt": 0.0,
		"hero_kills": 0
	}

	if tile_type == "bat":
		data["mob_count"] = bat_count_for_level(safe_level)
		data["mob_hp"] = bat_room_total_hp_for_level(safe_level)
	elif tile_type == "boss":
		data["boss_hp"] = boss_hp_for_level(safe_level)

	return data

func bat_count_for_level(level: int) -> int:
	match clamp(level, 1, 3):
		1:
			return 3
		2:
			return 4
		3:
			return 5
	return 3

func bat_room_total_hp_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 90.0
		2:
			return 140.0
		3:
			return 200.0
	return 90.0

func boss_hp_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 220.0
		2:
			return 340.0
		3:
			return 500.0
	return 220.0

func bat_room_dps_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 14.0
		2:
			return 20.0
		3:
			return 28.0
	return 14.0

func boss_room_dps_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 22.0
		2:
			return 34.0
		3:
			return 50.0
	return 22.0

func spike_damage_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 30.0
		2:
			return 50.0
		3:
			return 75.0
	return 30.0

func get_tile_data(cell: Vector2i) -> Dictionary:
	var key: String = cell_key(cell)
	if not placed_tiles.has(key):
		return {}
	return placed_tiles[key] as Dictionary

func set_tile_data(cell: Vector2i, data: Dictionary) -> void:
	placed_tiles[cell_key(cell)] = data
	queue_redraw()

func get_tile_type(cell: Vector2i) -> String:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return ""
	return str(data.get("type", ""))

func get_tile_level(cell: Vector2i) -> int:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0
	return int(data.get("level", 0))

func is_tile_beaten(cell: Vector2i) -> bool:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return false
	return bool(data.get("beaten", false))

func get_tile_cooldown_left(cell: Vector2i) -> float:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0.0
	return float(data.get("cooldown_left", 0.0))

func has_tile(cell: Vector2i) -> bool:
	return get_tile_type(cell) != ""

func is_mergeable_type(tile_type: String) -> bool:
	return tile_type != "" and tile_type != "corridor"

func can_place_tile(tile_type: String, cell: Vector2i) -> bool:
	if tile_type == "":
		return false
	if not is_cell_inside(cell):
		return false
	if is_cell_blocked(cell):
		return false
	if has_tile(cell):
		return false
	return true

func can_merge_tile(tile_type: String, tile_level: int, cell: Vector2i) -> bool:
	if not is_mergeable_type(tile_type):
		return false
	if tile_level >= 3:
		return false
	if not is_cell_inside(cell):
		return false
	if is_cell_blocked(cell):
		return false
	if not has_tile(cell):
		return false

	var existing_type: String = get_tile_type(cell)
	var existing_level: int = get_tile_level(cell)

	if existing_level >= 3:
		return false

	return existing_type == tile_type and existing_level == tile_level

func place_tile(tile_type: String, cell: Vector2i, tile_level: int = 1) -> bool:
	if not can_place_tile(tile_type, cell):
		return false

	placed_tiles[cell_key(cell)] = make_room_data(tile_type, tile_level)
	queue_redraw()
	return true

func merge_tile(tile_type: String, tile_level: int, cell: Vector2i) -> int:
	if not can_merge_tile(tile_type, tile_level, cell):
		return 0

	var new_level: int = min(3, tile_level + 1)
	placed_tiles[cell_key(cell)] = make_room_data(tile_type, new_level)
	queue_redraw()
	return new_level

func remove_tile(cell: Vector2i) -> bool:
	var key: String = cell_key(cell)
	if not placed_tiles.has(key):
		return false

	placed_tiles.erase(key)
	queue_redraw()
	return true

func update_room_timers(delta: float) -> void:
	var changed: bool = false

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = placed_tiles[key_variant] as Dictionary

		var cooldown_left: float = float(data.get("cooldown_left", 0.0))
		if cooldown_left > 0.0:
			cooldown_left = max(0.0, cooldown_left - delta)
			data["cooldown_left"] = cooldown_left
			placed_tiles[key_str] = data
			changed = true

	if changed:
		queue_redraw()

func try_trigger_spike(cell: Vector2i) -> float:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0.0

	var tile_type: String = str(data.get("type", ""))
	if tile_type != "spike":
		return 0.0

	var cooldown_left: float = float(data.get("cooldown_left", 0.0))
	if cooldown_left > 0.0:
		return 0.0

	var tile_level: int = int(data.get("level", 1))
	var damage: float = spike_damage_for_level(tile_level)

	data["cooldown_left"] = 3.0
	set_tile_data(cell, data)

	return damage

func get_bat_room_hp(cell: Vector2i) -> float:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "bat":
		return 0.0
	return float(data.get("mob_hp", 0.0))

func damage_bat_room(cell: Vector2i, amount: float) -> bool:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return false
	if str(data.get("type", "")) != "bat":
		return false
	if bool(data.get("beaten", false)):
		return true

	var level: int = int(data.get("level", 1))
	var hp: float = float(data.get("mob_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["mob_hp"] = hp

	if hp <= 0.0:
		data["mob_hp"] = 0.0
		data["mob_count"] = 0
		data["beaten"] = true
		set_tile_data(cell, data)
		return true

	var total_hp: float = bat_room_total_hp_for_level(level)
	var total_bats: int = bat_count_for_level(level)
	var ratio: float = hp / total_hp
	var remaining_bats: int = maxi(1, ceili(ratio * float(total_bats)))

	data["mob_count"] = remaining_bats
	set_tile_data(cell, data)
	return false

func get_boss_room_hp(cell: Vector2i) -> float:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "boss":
		return 0.0
	return float(data.get("boss_hp", 0.0))

func damage_boss_room(cell: Vector2i, amount: float) -> bool:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return false
	if str(data.get("type", "")) != "boss":
		return false
	if bool(data.get("beaten", false)):
		return true

	var hp: float = float(data.get("boss_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["boss_hp"] = hp

	if hp <= 0.0:
		data["boss_hp"] = 0.0
		data["beaten"] = true
		set_tile_data(cell, data)
		return true

	set_tile_data(cell, data)
	return false

# -------- Stats --------

func register_room_damage(cell: Vector2i, amount: float) -> void:
	if amount <= 0.0:
		return

	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return

	var current_damage: float = float(data.get("damage_dealt", 0.0))
	data["damage_dealt"] = current_damage + amount
	set_tile_data(cell, data)

func register_room_kill(cell: Vector2i) -> void:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return

	var current_kills: int = int(data.get("hero_kills", 0))
	data["hero_kills"] = current_kills + 1
	set_tile_data(cell, data)

	run_total_kills += 1

func register_escape() -> void:
	run_total_escapes += 1

func get_room_stats_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var best_room_text: String = "None"
	var best_room_kills: int = -1

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = placed_tiles[key_variant] as Dictionary

		var room_type: String = str(data.get("type", ""))
		var room_level: int = int(data.get("level", 1))
		var room_damage: float = float(data.get("damage_dealt", 0.0))
		var room_kills: int = int(data.get("hero_kills", 0))

		if room_type == "corridor":
			continue

		var line: String = "%s L%d @ %s | dmg %.0f | kills %d" % [
			room_type.capitalize(), room_level, key_str, room_damage, room_kills
		]
		lines.append(line)

		if room_kills > best_room_kills:
			best_room_kills = room_kills
			best_room_text = "%s L%d @ %s (%d kills)" % [
				room_type.capitalize(), room_level, key_str, room_kills
			]

	lines.sort()

	var summary: PackedStringArray = []
	summary.append("Heroes killed: %d" % run_total_kills)
	summary.append("Heroes escaped: %d" % run_total_escapes)
	summary.append("Top killer: %s" % best_room_text)
	summary.append("")
	summary.append("Room stats:")

	for line_text in lines:
		summary.append(line_text)

	return summary

func reset_run_stats() -> void:
	run_total_kills = 0
	run_total_escapes = 0

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = placed_tiles[key_variant] as Dictionary
		data["damage_dealt"] = 0.0
		data["hero_kills"] = 0
		placed_tiles[key_str] = data

	queue_redraw()

func reset_board_for_new_run() -> void:
	placed_tiles.clear()
	reset_run_stats()
	roll_start_and_chest()
	queue_redraw()

func reset_for_new_wave() -> void:
	var reset_tiles: Dictionary = {}

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var old_data: Dictionary = placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(old_data.get("type", ""))
		var tile_level: int = int(old_data.get("level", 1))

		var fresh_data: Dictionary = make_room_data(tile_type, tile_level)

		# preserve run stats across waves
		fresh_data["damage_dealt"] = float(old_data.get("damage_dealt", 0.0))
		fresh_data["hero_kills"] = int(old_data.get("hero_kills", 0))

		reset_tiles[key_str] = fresh_data

	placed_tiles = reset_tiles
	queue_redraw()

# -------- Pathfinding --------

func is_cell_traversable(cell: Vector2i) -> bool:
	if not is_cell_inside(cell):
		return false
	if cell == start_cell:
		return true
	if cell == chest_cell:
		return true
	return has_tile(cell)

func get_cell_path_cost(cell: Vector2i) -> float:
	if cell == start_cell or cell == chest_cell:
		return 0.0

	var tile_type: String = get_tile_type(cell)
	var tile_level: int = get_tile_level(cell)

	if tile_type == "":
		return 999999.0

	if tile_type == "corridor":
		return 0.0

	if tile_type == "spike":
		var cooldown_left: float = get_tile_cooldown_left(cell)
		if cooldown_left > 0.0:
			return 0.0
		return spike_damage_for_level(tile_level)

	if tile_type == "bat":
		if is_tile_beaten(cell):
			return 0.0

		var room_dps: float = bat_room_dps_for_level(tile_level)
		var room_hp: float = get_bat_room_hp(cell)
		var fight_time: float = room_hp / max(1.0, path_hero_attack_dps)
		return room_dps * fight_time

	if tile_type == "boss":
		if is_tile_beaten(cell):
			return 0.0

		var boss_dps: float = boss_room_dps_for_level(tile_level)
		var boss_hp: float = get_boss_room_hp(cell)
		var boss_fight_time: float = boss_hp / max(1.0, path_hero_attack_vs_boss_dps)
		return boss_dps * boss_fight_time

	return 0.0

func has_valid_connection() -> bool:
	return get_path_cells().size() > 0

func get_path_cells() -> Array[Vector2i]:
	var open_cells: Array[Vector2i] = [start_cell]
	var dist: Dictionary = {}
	var came_from: Dictionary = {}
	var visited: Dictionary = {}

	var start_key: String = cell_key(start_cell)
	var chest_key: String = cell_key(chest_cell)

	dist[start_key] = 0.0

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	while not open_cells.is_empty():
		var best_index: int = 0
		var best_cell: Vector2i = open_cells[0]
		var best_key: String = cell_key(best_cell)
		var best_cost: float = float(dist.get(best_key, 999999999.0))

		for i in range(1, open_cells.size()):
			var candidate: Vector2i = open_cells[i]
			var candidate_key: String = cell_key(candidate)
			var candidate_cost: float = float(dist.get(candidate_key, 999999999.0))

			if candidate_cost < best_cost:
				best_index = i
				best_cell = candidate
				best_key = candidate_key
				best_cost = candidate_cost

		open_cells.remove_at(best_index)

		if visited.has(best_key):
			continue

		visited[best_key] = true

		if best_key == chest_key:
			break

		for dir in dirs:
			var next_cell: Vector2i = best_cell + dir
			if not is_cell_inside(next_cell):
				continue
			if not is_cell_traversable(next_cell):
				continue

			var next_key: String = cell_key(next_cell)
			if visited.has(next_key):
				continue

			var move_cost: float = get_cell_path_cost(next_cell)
			var tentative_cost: float = best_cost + move_cost
			var old_cost: float = float(dist.get(next_key, 999999999.0))

			if tentative_cost < old_cost:
				dist[next_key] = tentative_cost
				came_from[next_key] = best_key

				if not open_cells.has(next_cell):
					open_cells.append(next_cell)

	if not visited.has(chest_key):
		return []

	var reverse_path: Array[Vector2i] = []
	var current_key: String = chest_key

	while true:
		reverse_path.append(cell_from_key(current_key))

		if current_key == start_key:
			break

		if not came_from.has(current_key):
			return []

		current_key = str(came_from[current_key])

	reverse_path.reverse()
	return reverse_path

func get_path_world_points() -> Array[Vector2]:
	var cells: Array[Vector2i] = get_path_cells()
	var points: Array[Vector2] = []

	for cell in cells:
		points.append(cell_to_world(cell))

	return points

# -------- Drawing --------

func tile_base_color(tile_type: String) -> Color:
	if tile_type == "corridor":
		return Color(0.35, 0.35, 0.42, 1.0)
	if tile_type == "bat":
		return Color(0.55, 0.25, 0.55, 1.0)
	if tile_type == "spike":
		return Color(0.75, 0.25, 0.25, 1.0)
	if tile_type == "boss":
		return Color(0.25, 0.25, 0.25, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)

func tile_color(tile_type: String, tile_level: int, beaten: bool, cooldown_left: float) -> Color:
	var base: Color = tile_base_color(tile_type)
	var boost: float = min(0.30, 0.10 * float(tile_level - 1))

	var result: Color = Color(
		min(1.0, base.r + boost),
		min(1.0, base.g + boost),
		min(1.0, base.b + boost),
		1.0
	)

	if beaten:
		result = result.darkened(0.35)

	if tile_type == "spike" and cooldown_left > 0.0:
		result = result.darkened(0.40)

	return result

func draw_level_pips(cell_x: int, cell_y: int, tile_level: int) -> void:
	for i in range(tile_level):
		var pip_pos: Vector2 = Vector2(
			float(cell_x * tile_size + 14 + i * 14),
			float(cell_y * tile_size + 14)
		)
		draw_circle(pip_pos, 4.0, Color(1.0, 1.0, 1.0, 0.95))

func _draw() -> void:
	var w: float = float(cols * tile_size)
	var h: float = float(rows * tile_size)

	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.12, 0.12, 0.12, 1.0), true)

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var parts: PackedStringArray = key_str.split(",")
		if parts.size() != 2:
			continue

		var cx: int = int(parts[0])
		var cy: int = int(parts[1])

		var tile_data: Dictionary = placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(tile_data.get("type", ""))
		var tile_level: int = int(tile_data.get("level", 1))
		var beaten: bool = bool(tile_data.get("beaten", false))
		var cooldown_left: float = float(tile_data.get("cooldown_left", 0.0))

		draw_rect(
			Rect2(
				Vector2(float(cx * tile_size), float(cy * tile_size)),
				Vector2(float(tile_size), float(tile_size))
			),
			tile_color(tile_type, tile_level, beaten, cooldown_left),
			true
		)

		if tile_level > 1:
			draw_level_pips(cx, cy, tile_level)

	draw_rect(
		Rect2(
			Vector2(float(start_cell.x * tile_size), float(start_cell.y * tile_size)),
			Vector2(float(tile_size), float(tile_size))
		),
		Color(0.2, 0.6, 0.2, 1.0),
		true
	)

	draw_rect(
		Rect2(
			Vector2(float(chest_cell.x * tile_size), float(chest_cell.y * tile_size)),
			Vector2(float(tile_size), float(tile_size))
		),
		Color(0.7, 0.6, 0.2, 1.0),
		true
	)

	for x in range(cols + 1):
		var px: float = float(x * tile_size)
		draw_line(Vector2(px, 0.0), Vector2(px, h), Color(0.25, 0.25, 0.25, 1.0), 2.0)

	for y in range(rows + 1):
		var py: float = float(y * tile_size)
		draw_line(Vector2(0.0, py), Vector2(w, py), Color(0.25, 0.25, 0.25, 1.0), 2.0)
