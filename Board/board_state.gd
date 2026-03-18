class_name BoardState
extends RefCounted

var cols: int = 10
var rows: int = 10
var tile_size: int = 128
var min_start_chest_distance: int = 6

var path_hero_attack_dps: float = 45.0
var path_hero_attack_vs_boss_dps: float = 38.0
var dungeon_level: int = 1
var run_bonus_modifiers: Dictionary = {}

var start_cell: Vector2i = Vector2i.ZERO
var chest_cell: Vector2i = Vector2i.ONE

var placed_tiles: Dictionary = {}

var run_total_kills: int = 0
var run_total_escapes: int = 0

var balance: BoardStateBalance
var runtime: BoardStateRuntime
var stats: BoardStateStats

func _init() -> void:
	balance = BoardStateBalance.new(self)
	runtime = BoardStateRuntime.new(self)
	stats = BoardStateStats.new(self)

func configure(
	new_cols: int,
	new_rows: int,
	new_tile_size: int,
	new_min_start_chest_distance: int,
	new_path_hero_attack_dps: float,
	new_path_hero_attack_vs_boss_dps: float,
	new_dungeon_level: int,
	new_run_bonus_modifiers: Dictionary = {}
) -> void:
	cols = new_cols
	rows = new_rows
	tile_size = new_tile_size
	min_start_chest_distance = new_min_start_chest_distance
	path_hero_attack_dps = new_path_hero_attack_dps
	path_hero_attack_vs_boss_dps = new_path_hero_attack_vs_boss_dps
	dungeon_level = new_dungeon_level
	run_bonus_modifiers = new_run_bonus_modifiers.duplicate(true)

func get_room_power_multiplier() -> float:
	return 1.0 + 0.06 * float(max(0, dungeon_level - 1))

func get_run_bonus_multiplier(key: String) -> float:
	return float(run_bonus_modifiers.get(key, 1.0))

func get_run_bonus_add(key: String) -> float:
	return float(run_bonus_modifiers.get(key, 0.0))

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

func is_support_room_type(tile_type: String) -> bool:
	return tile_type == "altar"

func is_damage_buffable_room_type(tile_type: String) -> bool:
	if tile_type == "spike":
		return true
	if tile_type == "gas":
		return true
	if tile_type == "bat":
		return true
	if tile_type == "boss":
		return true
	return false

func make_room_data(tile_type: String, tile_level: int) -> Dictionary:
	return balance.make_room_data(tile_type, tile_level)

func bat_count_for_level(level: int) -> int:
	return balance.bat_count_for_level(level)

func bat_room_total_hp_for_level(level: int) -> float:
	return balance.bat_room_total_hp_for_level(level)

func boss_hp_for_level(level: int) -> float:
	return balance.boss_hp_for_level(level)

func bat_room_dps_for_level(level: int) -> float:
	return balance.bat_room_dps_for_level(level)

func boss_room_dps_for_level(level: int) -> float:
	return balance.boss_room_dps_for_level(level)

func spike_damage_for_level(level: int) -> float:
	return balance.spike_damage_for_level(level)

func gas_poison_dps_for_level(level: int) -> float:
	return balance.gas_poison_dps_for_level(level)

func gas_poison_duration_for_level(level: int) -> float:
	return balance.gas_poison_duration_for_level(level)

func slow_factor_for_level(level: int) -> float:
	return balance.slow_factor_for_level(level)

func slow_duration_for_level(level: int) -> float:
	return balance.slow_duration_for_level(level)

func boss_knockback_interval_for_level(level: int) -> float:
	return balance.boss_knockback_interval_for_level(level)

func support_room_damage_multiplier(tile_type: String, level: int) -> float:
	return balance.support_room_damage_multiplier(tile_type, level)

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

func get_boss_slam_version(cell: Vector2i) -> int:
	return runtime.get_boss_slam_version(cell)

func get_boss_slam_timer_left(cell: Vector2i) -> float:
	return runtime.get_boss_slam_timer_left(cell)

func mark_boss_room_active(cell: Vector2i) -> void:
	runtime.mark_boss_room_active(cell)

func has_tile(cell: Vector2i) -> bool:
	return get_tile_type(cell) != ""

func is_mergeable_type(tile_type: String) -> bool:
	return tile_type != "" and tile_type != "corridor"

func is_scalable_room_type(tile_type: String) -> bool:
	return tile_type != "" and tile_type != "corridor" and not is_support_room_type(tile_type)

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

func trigger_merge_flash(cell: Vector2i) -> void:
	var data: Dictionary = get_tile_data(cell)
	if data.is_empty():
		return

	data["merge_flash"] = 1.0
	set_tile_data(cell, data)

func trigger_level_up_flash_for_scaled_rooms() -> void:
	for key_variant in placed_tiles.keys():
		var data: Dictionary = placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(data.get("type", ""))

		if not is_scalable_room_type(tile_type):
			continue

		data["level_up_flash"] = 1.0
		placed_tiles[key_variant] = data

func update_visual_feedback_timers(delta: float) -> bool:
	var changed: bool = false

	for key_variant in placed_tiles.keys():
		var data: Dictionary = placed_tiles[key_variant] as Dictionary

		var old_merge_flash: float = float(data.get("merge_flash", 0.0))
		var old_level_up_flash: float = float(data.get("level_up_flash", 0.0))

		var new_merge_flash: float = move_toward(old_merge_flash, 0.0, 4.2 * delta)
		var new_level_up_flash: float = move_toward(old_level_up_flash, 0.0, 1.8 * delta)

		if not is_equal_approx(new_merge_flash, old_merge_flash):
			data["merge_flash"] = new_merge_flash
			changed = true

		if not is_equal_approx(new_level_up_flash, old_level_up_flash):
			data["level_up_flash"] = new_level_up_flash
			changed = true

		placed_tiles[key_variant] = data

	return changed

func update_room_timers(delta: float) -> bool:
	var runtime_changed: bool = runtime.update_room_timers(delta)
	var visual_changed: bool = update_visual_feedback_timers(delta)
	return runtime_changed or visual_changed

func try_trigger_spike(cell: Vector2i) -> float:
	return runtime.try_trigger_spike(cell)

func get_bat_room_hp(cell: Vector2i) -> float:
	return runtime.get_bat_room_hp(cell)

func damage_bat_room(cell: Vector2i, amount: float) -> Dictionary:
	return runtime.damage_bat_room(cell, amount)

func get_boss_room_hp(cell: Vector2i) -> float:
	return runtime.get_boss_room_hp(cell)

func damage_boss_room(cell: Vector2i, amount: float) -> Dictionary:
	return runtime.damage_boss_room(cell, amount)

func register_room_damage(cell: Vector2i, amount: float) -> void:
	stats.register_room_damage(cell, amount)

func register_room_kill(cell: Vector2i) -> void:
	stats.register_room_kill(cell)

func register_escape() -> void:
	stats.register_escape()

func room_type_display_name(room_type: String) -> String:
	return balance.room_type_display_name(room_type)

func get_room_stats_summary_lines() -> PackedStringArray:
	return stats.get_room_stats_summary_lines()

func reset_run_stats() -> void:
	stats.reset_run_stats()

func get_adjacent_support_damage_multiplier(cell: Vector2i) -> float:
	var best_multiplier: float = 1.0
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in dirs:
		var neighbor: Vector2i = cell + dir
		if not is_cell_inside(neighbor):
			continue

		var neighbor_type: String = get_tile_type(neighbor)
		if not is_support_room_type(neighbor_type):
			continue

		var neighbor_level: int = get_tile_level(neighbor)
		var neighbor_multiplier: float = support_room_damage_multiplier(neighbor_type, neighbor_level)
		if neighbor_multiplier > best_multiplier:
			best_multiplier = neighbor_multiplier

	return best_multiplier

func get_adjacent_support_damage_multiplier_with_override(
	cell: Vector2i,
	override_cell: Vector2i,
	override_type: String,
	override_level: int,
	override_present: bool
) -> float:
	var best_multiplier: float = 1.0
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in dirs:
		var neighbor: Vector2i = cell + dir
		if not is_cell_inside(neighbor):
			continue

		var neighbor_type: String = ""
		var neighbor_level: int = 0

		if neighbor == override_cell:
			if not override_present:
				continue
			neighbor_type = override_type
			neighbor_level = override_level
		else:
			neighbor_type = get_tile_type(neighbor)
			if not is_support_room_type(neighbor_type):
				continue
			neighbor_level = get_tile_level(neighbor)

		if not is_support_room_type(neighbor_type):
			continue

		var neighbor_multiplier: float = support_room_damage_multiplier(neighbor_type, neighbor_level)
		if neighbor_multiplier > best_multiplier:
			best_multiplier = neighbor_multiplier

	return best_multiplier

func get_room_damage_multiplier_for_cell(cell: Vector2i) -> float:
	var tile_type: String = get_tile_type(cell)
	if not is_damage_buffable_room_type(tile_type):
		return 1.0
	return get_adjacent_support_damage_multiplier(cell)

func get_spike_damage_for_cell(cell: Vector2i) -> float:
	var level: int = get_tile_level(cell)
	if level <= 0:
		return 0.0
	return spike_damage_for_level(level) * get_room_damage_multiplier_for_cell(cell)

func get_gas_poison_dps_for_cell(cell: Vector2i) -> float:
	var level: int = get_tile_level(cell)
	if level <= 0:
		return 0.0
	return gas_poison_dps_for_level(level) * get_room_damage_multiplier_for_cell(cell)

func get_bat_room_dps_for_cell(cell: Vector2i) -> float:
	var level: int = get_tile_level(cell)
	if level <= 0:
		return 0.0
	return bat_room_dps_for_level(level) * get_room_damage_multiplier_for_cell(cell)

func get_boss_room_dps_for_cell(cell: Vector2i) -> float:
	var level: int = get_tile_level(cell)
	if level <= 0:
		return 0.0
	return boss_room_dps_for_level(level) * get_room_damage_multiplier_for_cell(cell)

func refresh_room_scaling() -> void:
	var refreshed_tiles: Dictionary = {}

	for key_variant in placed_tiles.keys():
		var key_str: String = str(key_variant)
		var old_data: Dictionary = placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(old_data.get("type", ""))
		var tile_level: int = int(old_data.get("level", 1))

		var new_data: Dictionary = make_room_data(tile_type, tile_level)

		new_data["damage_dealt"] = float(old_data.get("damage_dealt", 0.0))
		new_data["hero_kills"] = int(old_data.get("hero_kills", 0))
		new_data["cooldown_left"] = float(old_data.get("cooldown_left", 0.0))
		new_data["clear_flash"] = float(old_data.get("clear_flash", 0.0))
		new_data["merge_flash"] = float(old_data.get("merge_flash", 0.0))
		new_data["level_up_flash"] = float(old_data.get("level_up_flash", 0.0))

		var beaten: bool = bool(old_data.get("beaten", false))
		new_data["beaten"] = beaten

		if beaten:
			if tile_type == "bat":
				new_data["mob_count"] = 0
				new_data["mob_hp"] = 0.0
			elif tile_type == "boss":
				new_data["boss_hp"] = 0.0

		refreshed_tiles[key_str] = new_data

	placed_tiles = refreshed_tiles

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
		fresh_data["merge_flash"] = float(old_data.get("merge_flash", 0.0))
		fresh_data["level_up_flash"] = float(old_data.get("level_up_flash", 0.0))

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

	var tile_type: String = get_tile_type(cell)
	if tile_type == "":
		return false
	if is_support_room_type(tile_type):
		return false

	return true

func get_cell_path_cost(cell: Vector2i) -> float:
	return balance.get_cell_path_cost(cell)
