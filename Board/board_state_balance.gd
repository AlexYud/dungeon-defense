class_name BoardStateBalance
extends RefCounted

var state: BoardState

func _init(new_state: BoardState) -> void:
	state = new_state

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
		"boss_slam_timer": 0.0,
		"boss_slam_version": 0,
		"boss_active_recently": false,
		"damage_dealt": 0.0,
		"hero_kills": 0,
		"clear_flash": 0.0
	}

	if tile_type == "bat":
		data["mob_count"] = bat_count_for_level(safe_level)
		data["mob_hp"] = bat_room_total_hp_for_level(safe_level)
	elif tile_type == "boss":
		data["boss_hp"] = boss_hp_for_level(safe_level)
		data["boss_slam_timer"] = boss_knockback_interval_for_level(safe_level)

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
	var base_value: float = 90.0
	match clamp(level, 1, 3):
		1:
			base_value = 90.0
		2:
			base_value = 140.0
		3:
			base_value = 200.0
	return base_value * state.get_room_power_multiplier()

func boss_hp_for_level(level: int) -> float:
	var base_value: float = 220.0
	match clamp(level, 1, 3):
		1:
			base_value = 220.0
		2:
			base_value = 340.0
		3:
			base_value = 500.0
	return base_value * state.get_room_power_multiplier()

func bat_room_dps_for_level(level: int) -> float:
	var base_value: float = 14.0
	match clamp(level, 1, 3):
		1:
			base_value = 14.0
		2:
			base_value = 20.0
		3:
			base_value = 28.0
	base_value *= state.get_run_bonus_multiplier("bat_room_dps_mult")
	return base_value * state.get_room_power_multiplier()

func boss_room_dps_for_level(level: int) -> float:
	var base_value: float = 22.0
	match clamp(level, 1, 3):
		1:
			base_value = 22.0
		2:
			base_value = 34.0
		3:
			base_value = 50.0
	return base_value * state.get_room_power_multiplier()

func spike_damage_for_level(level: int) -> float:
	var base_value: float = 30.0
	match clamp(level, 1, 3):
		1:
			base_value = 30.0
		2:
			base_value = 50.0
		3:
			base_value = 75.0
	base_value *= state.get_run_bonus_multiplier("spike_damage_mult")
	return base_value * state.get_room_power_multiplier()

func gas_poison_dps_for_level(level: int) -> float:
	var base_value: float = 5.0
	match clamp(level, 1, 3):
		1:
			base_value = 5.0
		2:
			base_value = 8.0
		3:
			base_value = 12.0
	base_value *= state.get_run_bonus_multiplier("gas_poison_dps_mult")
	return base_value * state.get_room_power_multiplier()

func gas_poison_duration_for_level(level: int) -> float:
	var duration_value: float = 2.5
	match clamp(level, 1, 3):
		1:
			duration_value = 2.5
		2:
			duration_value = 3.5
		3:
			duration_value = 4.5
	return duration_value * state.get_run_bonus_multiplier("gas_poison_duration_mult")

func slow_factor_for_level(level: int) -> float:
	match clamp(level, 1, 3):
		1:
			return 0.75
		2:
			return 0.60
		3:
			return 0.45
	return 0.75

func slow_duration_for_level(level: int) -> float:
	var duration_value: float = 2.5
	match clamp(level, 1, 3):
		1:
			duration_value = 2.5
		2:
			duration_value = 3.5
		3:
			duration_value = 4.5
	return duration_value * state.get_run_bonus_multiplier("slow_duration_mult")

func boss_knockback_interval_for_level(level: int) -> float:
	var interval_value: float = 1.6
	match clamp(level, 1, 3):
		1:
			interval_value = 1.6
		2:
			interval_value = 1.35
		3:
			interval_value = 1.15

	interval_value *= state.get_run_bonus_multiplier("boss_slam_interval_mult")
	return max(0.45, interval_value)

func altar_damage_multiplier_for_level(level: int) -> float:
	var multiplier_value: float = 1.20
	match clamp(level, 1, 3):
		1:
			multiplier_value = 1.20
		2:
			multiplier_value = 1.35
		3:
			multiplier_value = 1.50

	multiplier_value += state.get_run_bonus_add("altar_bonus_add")
	return multiplier_value

func support_room_damage_multiplier(tile_type: String, level: int) -> float:
	if tile_type == "altar":
		return altar_damage_multiplier_for_level(level)
	return 1.0

func room_type_display_name(room_type: String) -> String:
	if room_type == "bat":
		return "Bat Room"
	if room_type == "spike":
		return "Spike Room"
	if room_type == "boss":
		return "Boss Room"
	if room_type == "gas":
		return "Gas Room"
	if room_type == "slow":
		return "Slow Room"
	if room_type == "altar":
		return "Altar"
	return "None"

func get_cell_path_cost(cell: Vector2i) -> float:
	if cell == state.start_cell or cell == state.chest_cell:
		return 0.0

	var tile_type: String = state.get_tile_type(cell)
	var tile_level: int = state.get_tile_level(cell)

	if tile_type == "":
		return 999999.0

	if tile_type == "corridor":
		return 0.0

	if tile_type == "altar":
		return 999999.0

	if tile_type == "spike":
		var cooldown_left: float = state.get_tile_cooldown_left(cell)
		if cooldown_left > 0.0:
			return 0.0
		return state.get_spike_damage_for_cell(cell)

	if tile_type == "gas":
		return state.get_gas_poison_dps_for_cell(cell) * gas_poison_duration_for_level(tile_level) * 0.65

	if tile_type == "slow":
		return 0.0

	if tile_type == "bat":
		if state.is_tile_beaten(cell):
			return 0.0

		var room_dps: float = state.get_bat_room_dps_for_cell(cell)
		var room_hp: float = state.get_bat_room_hp(cell)
		var fight_time: float = room_hp / max(1.0, state.path_hero_attack_dps)
		return room_dps * fight_time

	if tile_type == "boss":
		if state.is_tile_beaten(cell):
			return 0.0

		var boss_dps: float = state.get_boss_room_dps_for_cell(cell)
		var boss_hp: float = state.get_boss_room_hp(cell)
		var boss_fight_time: float = boss_hp / max(1.0, state.path_hero_attack_vs_boss_dps)
		return boss_dps * boss_fight_time

	return 0.0
