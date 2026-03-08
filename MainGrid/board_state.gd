class_name BoardState
extends RefCounted

var cols: int = 10
var rows: int = 10
var tile_size: int = 128
var min_start_chest_distance: int = 6

var path_hero_attack_dps: float = 45.0
var path_hero_attack_vs_boss_dps: float = 38.0

var start_cell: Vector2i = Vector2i.ZERO
var chest_cell: Vector2i = Vector2i.ONE

# "x,y" -> room data dictionary
var placed_tiles: Dictionary = {}

# Run stats
var run_total_kills: int = 0
var run_total_escapes: int = 0

func configure(
	new_cols: int,
	new_rows: int,
	new_tile_size: int,
	new_min_start_chest_distance: int,
	new_path_hero_attack_dps: float,
	new_path_hero_attack_vs_boss_dps: float
) -> void:
	cols = new_cols
	rows = new_rows
	tile_size = new_tile_size
	min_start_chest_distance = new_min_start_chest_distance
	path_hero_attack_dps = new_path_hero_attack_dps
	path_hero_attack_vs_boss_dps = new_path_hero_attack_vs_boss_dps

func roll_start_and_chest() -> void:
	start_cell = Vector2i(randi_range(0, cols - 1), randi_range(0, rows - 1))
	chest_cell = start_cell

	while chest_cell == start_cell or manhattan_distance(start_cell, chest_cell) < min_start_chest_distance:
		chest_cell = Vector2i(randi_range(0, cols - 1), randi_range(0, rows - 1))

func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func cell_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i(-999, -999)
	return Vector2i(int(parts[0]), int(parts[1]))

func is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

func is_cell_blocked(cell: Vector2i) -> bool:
	return cell == start_cell or cell == chest_cell

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
		"damage_dealt": 0.0,
		"hero_kills": 0,
		"clear_flash": 0.0
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
	return true

func merge_tile(tile_type: String, tile_level: int, cell: Vector2i) -> int:
	if not can_merge_tile(tile_type, tile_level, cell):
		return 0

	var new_level: int = min(3, tile_level + 1)
	placed_tiles[cell_key(cell)] = make_room_data(tile_type, new_level)
	return new_level

func remove_tile(cell: Vector2i) -> bool:
	var key: String = cell_key(cell)
	if not placed_tiles.has(key):
		return false

	placed_tiles.erase(key)
	return true

func update_room_timers(delta: float) -> bool:
	var changed: bool = false

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = placed_tiles[key_variant] as Dictionary
		var local_changed: bool = false

		var cooldown_left: float = float(data.get("cooldown_left", 0.0))
		if cooldown_left > 0.0:
			cooldown_left = max(0.0, cooldown_left - delta)
			data["cooldown_left"] = cooldown_left
			local_changed = true

		var clear_flash: float = float(data.get("clear_flash", 0.0))
		if clear_flash > 0.0:
			clear_flash = max(0.0, clear_flash - delta)
			data["clear_flash"] = clear_flash
			local_changed = true

		if local_changed:
			placed_tiles[key_str] = data
			changed = true

	return changed

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

func damage_bat_room(cell: Vector2i, amount: float) -> Dictionary:
	var result: Dictionary = {"cleared": false, "changed": false}

	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return result
	if str(data.get("type", "")) != "bat":
		return result
	if bool(data.get("beaten", false)):
		result["cleared"] = true
		return result

	var level: int = int(data.get("level", 1))
	var hp: float = float(data.get("mob_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["mob_hp"] = hp
	result["changed"] = true

	if hp <= 0.0:
		data["mob_hp"] = 0.0
		data["mob_count"] = 0
		data["beaten"] = true
		data["clear_flash"] = 0.55
		set_tile_data(cell, data)
		result["cleared"] = true
		return result

	var total_hp: float = bat_room_total_hp_for_level(level)
	var total_bats: int = bat_count_for_level(level)
	var ratio: float = hp / max(1.0, total_hp)
	var remaining_bats: int = max(1, int(ceil(ratio * float(total_bats))))

	data["mob_count"] = remaining_bats
	set_tile_data(cell, data)
	return result

func get_boss_room_hp(cell: Vector2i) -> float:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "boss":
		return 0.0
	return float(data.get("boss_hp", 0.0))

func damage_boss_room(cell: Vector2i, amount: float) -> Dictionary:
	var result: Dictionary = {"cleared": false, "changed": false}

	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return result
	if str(data.get("type", "")) != "boss":
		return result
	if bool(data.get("beaten", false)):
		result["cleared"] = true
		return result

	var hp: float = float(data.get("boss_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["boss_hp"] = hp
	result["changed"] = true

	if hp <= 0.0:
		data["boss_hp"] = 0.0
		data["beaten"] = true
		data["clear_flash"] = 0.55
		set_tile_data(cell, data)
		result["cleared"] = true
		return result

	set_tile_data(cell, data)
	return result

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

func room_type_display_name(room_type: String) -> String:
	if room_type == "bat":
		return "Bat Room"
	if room_type == "spike":
		return "Spike Room"
	if room_type == "boss":
		return "Boss Room"
	return "None"

func get_room_stats_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var totals: Dictionary = {
		"bat": {"damage": 0.0, "kills": 0},
		"spike": {"damage": 0.0, "kills": 0},
		"boss": {"damage": 0.0, "kills": 0}
	}

	for key_variant in placed_tiles.keys():
		var data: Dictionary = placed_tiles[key_variant] as Dictionary
		var room_type: String = str(data.get("type", ""))

		if room_type == "corridor":
			continue
		if not totals.has(room_type):
			continue

		var entry: Dictionary = totals[room_type] as Dictionary
		entry["damage"] = float(entry.get("damage", 0.0)) + float(data.get("damage_dealt", 0.0))
		entry["kills"] = int(entry.get("kills", 0)) + int(data.get("hero_kills", 0))
		totals[room_type] = entry

	var top_room_type: String = "None"
	var top_kills: int = -1

	for room_type in ["bat", "spike", "boss"]:
		var entry: Dictionary = totals[room_type] as Dictionary
		var room_kills: int = int(entry.get("kills", 0))
		if room_kills > top_kills:
			top_kills = room_kills
			top_room_type = room_type

	lines.append("Heroes killed: %d" % run_total_kills)
	lines.append("Heroes escaped: %d" % run_total_escapes)
	lines.append("Top killer room: %s" % room_type_display_name(top_room_type))
	lines.append("")
	lines.append("Room totals:")
	lines.append(
		"Bat Room   | dmg %.0f | kills %d" % [
			float((totals["bat"] as Dictionary).get("damage", 0.0)),
			int((totals["bat"] as Dictionary).get("kills", 0))
		]
	)
	lines.append(
		"Spike Room | dmg %.0f | kills %d" % [
			float((totals["spike"] as Dictionary).get("damage", 0.0)),
			int((totals["spike"] as Dictionary).get("kills", 0))
		]
	)
	lines.append(
		"Boss Room  | dmg %.0f | kills %d" % [
			float((totals["boss"] as Dictionary).get("damage", 0.0)),
			int((totals["boss"] as Dictionary).get("kills", 0))
		]
	)

	return lines

func reset_run_stats() -> void:
	run_total_kills = 0
	run_total_escapes = 0

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = placed_tiles[key_variant] as Dictionary
		data["damage_dealt"] = 0.0
		data["hero_kills"] = 0
		placed_tiles[key_str] = data

func reset_for_new_wave() -> void:
	var reset_tiles: Dictionary = {}

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var old_data: Dictionary = placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(old_data.get("type", ""))
		var tile_level: int = int(old_data.get("level", 1))

		var fresh_data: Dictionary = make_room_data(tile_type, tile_level)
		fresh_data["damage_dealt"] = float(old_data.get("damage_dealt", 0.0))
		fresh_data["hero_kills"] = int(old_data.get("hero_kills", 0))

		reset_tiles[key_str] = fresh_data

	placed_tiles = reset_tiles

func reset_board_for_new_run() -> void:
	placed_tiles.clear()
	reset_run_stats()
	roll_start_and_chest()

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
