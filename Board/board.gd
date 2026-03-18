extends Node2D

const FLOATING_TEXT_PATH: String = "res://UI/FloatingText.tscn"

@export var cols: int = 7
@export var rows: int = 7
@export var tile_size: int = 128
@export var min_start_chest_distance: int = 6

@export var path_hero_attack_dps: float = 45.0
@export var path_hero_attack_vs_boss_dps: float = 38.0
@export var dungeon_level: int = 1

var floating_text_scene: PackedScene = null
var run_bonus_modifiers: Dictionary = {}

var state: BoardState = BoardState.new()
var pathfinder: BoardPathfinder = BoardPathfinder.new(state)
var renderer: BoardRenderer = BoardRenderer.new()

func _ready() -> void:
	randomize()
	_sync_state_config()
	state.roll_start_and_chest()
	queue_redraw()

func _process(delta: float) -> void:
	_sync_state_config()
	if state.update_room_timers(delta):
		queue_redraw()

func _sync_state_config() -> void:
	state.configure(
		cols,
		rows,
		tile_size,
		min_start_chest_distance,
		path_hero_attack_dps,
		path_hero_attack_vs_boss_dps,
		dungeon_level,
		run_bonus_modifiers
	)

func set_run_bonus_modifiers(new_modifiers: Dictionary) -> void:
	run_bonus_modifiers = new_modifiers.duplicate(true)
	_sync_state_config()
	queue_redraw()

func ensure_floating_text_scene() -> void:
	if floating_text_scene == null:
		floating_text_scene = load(FLOATING_TEXT_PATH)

func spawn_room_popup(cell: Vector2i, text_value: String, color_value: Color) -> void:
	ensure_floating_text_scene()
	if floating_text_scene == null:
		return

	var popup: Node2D = floating_text_scene.instantiate() as Node2D
	if popup == null:
		return

	add_child(popup)
	popup.position = Vector2(
		float(cell.x * tile_size + tile_size / 2),
		float(cell.y * tile_size + tile_size * 0.42)
	)

	if popup.has_method("setup"):
		popup.call("setup", text_value, color_value)

func _damage_gain_percent_from_ratio(ratio: float) -> int:
	return max(1, int(round((ratio - 1.0) * 100.0)))

func _spawn_damage_gain_popup(cell: Vector2i, ratio: float, color_value: Color) -> void:
	if ratio <= 1.001:
		return

	var percent: int = _damage_gain_percent_from_ratio(ratio)
	spawn_room_popup(cell, "+%d%% DMG" % percent, color_value)

func _spawn_duration_gain_popup(cell: Vector2i, ratio: float, color_value: Color) -> void:
	if ratio <= 1.001:
		return

	var percent: int = _damage_gain_percent_from_ratio(ratio)
	spawn_room_popup(cell, "+%d%% DUR" % percent, color_value)

func _spawn_cooldown_reduction_popup(cell: Vector2i, reduction_ratio: float, color_value: Color) -> void:
	if reduction_ratio <= 0.001:
		return

	var percent: int = max(1, int(round(reduction_ratio * 100.0)))
	spawn_room_popup(cell, "-%d%% CD" % percent, color_value)

func trigger_bonus_card_pick_feedback(card_id: String) -> void:
	for key_variant in state.placed_tiles.keys():
		var key_str: String = str(key_variant)
		var cell: Vector2i = state.cell_from_key(key_str)
		var tile_type: String = state.get_tile_type(cell)

		match card_id:
			"sharp_floors":
				if tile_type == "spike":
					_spawn_damage_gain_popup(cell, 1.20, Color(1.0, 0.78, 0.58, 1.0))

			"lingering_fog":
				if tile_type == "gas":
					_spawn_duration_gain_popup(cell, 1.40, Color(0.62, 1.0, 0.62, 1.0))

			"toxic_payload":
				if tile_type == "gas":
					_spawn_damage_gain_popup(cell, 1.20, Color(0.62, 1.0, 0.62, 1.0))

			"crippling_halls":
				if tile_type == "slow":
					_spawn_duration_gain_popup(cell, 1.25, Color(0.72, 0.92, 1.0, 1.0))

			"pack_hunt":
				if tile_type == "bat":
					_spawn_damage_gain_popup(cell, 1.20, Color(0.98, 0.72, 1.0, 1.0))

			"brutal_slam":
				if tile_type == "boss":
					spawn_room_popup(cell, "SLAM UP", Color(1.0, 0.84, 0.52, 1.0))
					_spawn_cooldown_reduction_popup(cell, 0.12, Color(1.0, 0.84, 0.52, 1.0))

			"sanctified_pressure":
				if tile_type == "altar":
					spawn_room_popup(cell, "ALTAR UP", Color(1.0, 0.90, 0.46, 1.0))
				elif state.is_damage_buffable_room_type(tile_type):
					var support_multiplier: float = state.get_adjacent_support_damage_multiplier(cell)
					if support_multiplier > 1.001:
						_spawn_damage_gain_popup(cell, 1.10, Color(1.0, 0.90, 0.46, 1.0))

func _damage_room_value_for_level(tile_type: String, level: int) -> float:
	if tile_type == "spike":
		return state.spike_damage_for_level(level)
	if tile_type == "gas":
		return state.gas_poison_dps_for_level(level)
	if tile_type == "bat":
		return state.bat_room_dps_for_level(level)
	if tile_type == "boss":
		return state.boss_room_dps_for_level(level)
	return 0.0

func trigger_merge_stat_popup(cell: Vector2i, tile_type: String, old_level: int, new_level: int) -> void:
	if new_level <= old_level:
		return

	if tile_type == "slow":
		spawn_room_popup(cell, "SLOW UP", Color(0.78, 0.92, 1.0, 1.0))
		return

	if not state.is_damage_buffable_room_type(tile_type):
		return

	var old_value: float = _damage_room_value_for_level(tile_type, old_level)
	var new_value: float = _damage_room_value_for_level(tile_type, new_level)

	if old_value <= 0.0 or new_value <= old_value:
		return

	_spawn_damage_gain_popup(cell, new_value / max(0.001, old_value), Color(1.0, 0.92, 0.56, 1.0))

func trigger_dungeon_level_stat_popups(old_dungeon_level: int, new_dungeon_level: int) -> void:
	if new_dungeon_level <= old_dungeon_level:
		return

	var old_power: float = 1.0 + 0.06 * float(max(0, old_dungeon_level - 1))
	var new_power: float = 1.0 + 0.06 * float(max(0, new_dungeon_level - 1))
	if old_power <= 0.0 or new_power <= old_power:
		return

	var ratio: float = new_power / old_power

	for key_variant in state.placed_tiles.keys():
		var key_str: String = str(key_variant)
		var cell: Vector2i = state.cell_from_key(key_str)
		var tile_type: String = state.get_tile_type(cell)

		if not state.is_damage_buffable_room_type(tile_type):
			continue

		_spawn_damage_gain_popup(cell, ratio, Color(1.0, 0.96, 0.72, 1.0))

func trigger_support_room_stat_popups(support_cell: Vector2i, old_level: int, new_level: int) -> void:
	var support_type: String = state.get_tile_type(support_cell)
	if not state.is_support_room_type(support_type):
		return

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in dirs:
		var neighbor: Vector2i = support_cell + dir
		if not state.is_cell_inside(neighbor):
			continue

		var neighbor_type: String = state.get_tile_type(neighbor)
		if not state.is_damage_buffable_room_type(neighbor_type):
			continue

		var old_multiplier: float = state.get_adjacent_support_damage_multiplier_with_override(
			neighbor,
			support_cell,
			support_type,
			old_level,
			old_level > 0
		)

		var new_multiplier: float = state.get_adjacent_support_damage_multiplier_with_override(
			neighbor,
			support_cell,
			support_type,
			new_level,
			new_level > 0
		)

		if new_multiplier <= old_multiplier + 0.001:
			continue

		_spawn_damage_gain_popup(neighbor, new_multiplier / max(0.001, old_multiplier), Color(1.0, 0.90, 0.46, 1.0))

func trigger_room_support_gain_popup(cell: Vector2i) -> void:
	var tile_type: String = state.get_tile_type(cell)
	if not state.is_damage_buffable_room_type(tile_type):
		return

	var support_multiplier: float = state.get_adjacent_support_damage_multiplier(cell)
	if support_multiplier <= 1.001:
		return

	_spawn_damage_gain_popup(cell, support_multiplier, Color(1.0, 0.90, 0.46, 1.0))

func refresh_room_scaling() -> void:
	_sync_state_config()
	state.refresh_room_scaling()
	queue_redraw()

func trigger_merge_feedback(cell: Vector2i) -> void:
	state.trigger_merge_flash(cell)
	queue_redraw()

func trigger_level_up_feedback() -> void:
	state.trigger_level_up_flash_for_scaled_rooms()
	queue_redraw()

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

func get_tile_type(cell: Vector2i) -> String:
	return state.get_tile_type(cell)

func get_tile_level(cell: Vector2i) -> int:
	return state.get_tile_level(cell)

func is_tile_beaten(cell: Vector2i) -> bool:
	return state.is_tile_beaten(cell)

func get_tile_cooldown_left(cell: Vector2i) -> float:
	return state.get_tile_cooldown_left(cell)

func can_place_tile(tile_type: String, cell: Vector2i) -> bool:
	return state.can_place_tile(tile_type, cell)

func can_merge_tile(tile_type: String, tile_level: int, cell: Vector2i) -> bool:
	return state.can_merge_tile(tile_type, tile_level, cell)

func place_tile(tile_type: String, cell: Vector2i, tile_level: int = 1) -> bool:
	var placed: bool = state.place_tile(tile_type, cell, tile_level)
	if placed:
		queue_redraw()
	return placed

func merge_tile(tile_type: String, tile_level: int, cell: Vector2i) -> int:
	var new_level: int = state.merge_tile(tile_type, tile_level, cell)
	if new_level > 0:
		queue_redraw()
	return new_level

func remove_tile(cell: Vector2i) -> bool:
	var removed: bool = state.remove_tile(cell)
	if removed:
		queue_redraw()
	return removed

func try_trigger_spike(cell: Vector2i) -> float:
	var damage: float = state.try_trigger_spike(cell)
	if damage > 0.0:
		queue_redraw()
	return damage

func bat_room_dps_for_level(level: int) -> float:
	return state.bat_room_dps_for_level(level)

func bat_room_dps_for_cell(cell: Vector2i) -> float:
	return state.get_bat_room_dps_for_cell(cell)

func boss_room_dps_for_level(level: int) -> float:
	return state.boss_room_dps_for_level(level)

func boss_room_dps_for_cell(cell: Vector2i) -> float:
	return state.get_boss_room_dps_for_cell(cell)

func gas_poison_dps_for_level(level: int) -> float:
	return state.gas_poison_dps_for_level(level)

func gas_poison_dps_for_cell(cell: Vector2i) -> float:
	return state.get_gas_poison_dps_for_cell(cell)

func gas_poison_duration_for_level(level: int) -> float:
	return state.gas_poison_duration_for_level(level)

func slow_factor_for_level(level: int) -> float:
	return state.slow_factor_for_level(level)

func slow_duration_for_level(level: int) -> float:
	return state.slow_duration_for_level(level)

func boss_knockback_interval_for_level(level: int) -> float:
	return state.boss_knockback_interval_for_level(level)

func mark_boss_room_active(cell: Vector2i) -> void:
	state.mark_boss_room_active(cell)

func get_boss_slam_version(cell: Vector2i) -> int:
	return state.get_boss_slam_version(cell)

func get_boss_slam_timer_left(cell: Vector2i) -> float:
	return state.get_boss_slam_timer_left(cell)

func damage_bat_room(cell: Vector2i, amount: float) -> bool:
	var result: Dictionary = state.damage_bat_room(cell, amount)
	if bool(result.get("changed", false)):
		queue_redraw()
	if bool(result.get("cleared", false)):
		spawn_room_popup(cell, "CLEARED!", Color(0.95, 0.80, 1.0, 1.0))
	return bool(result.get("cleared", false))

func damage_boss_room(cell: Vector2i, amount: float) -> bool:
	var result: Dictionary = state.damage_boss_room(cell, amount)
	if bool(result.get("changed", false)):
		queue_redraw()
	if bool(result.get("cleared", false)):
		spawn_room_popup(cell, "CLEARED!", Color(1.0, 0.86, 0.55, 1.0))
	return bool(result.get("cleared", false))

func get_bat_room_hp(cell: Vector2i) -> float:
	return state.get_bat_room_hp(cell)

func get_boss_room_hp(cell: Vector2i) -> float:
	return state.get_boss_room_hp(cell)

func register_room_damage(cell: Vector2i, amount: float) -> void:
	state.register_room_damage(cell, amount)

func register_room_kill(cell: Vector2i) -> void:
	state.register_room_kill(cell)

func register_escape() -> void:
	state.register_escape()

func get_room_stats_summary_lines() -> PackedStringArray:
	return state.get_room_stats_summary_lines()

func reset_run_stats() -> void:
	state.reset_run_stats()
	queue_redraw()

func reset_for_new_wave() -> void:
	_sync_state_config()
	state.reset_for_new_wave()
	queue_redraw()

func reset_board_for_new_run() -> void:
	_sync_state_config()
	state.reset_board_for_new_run()
	queue_redraw()

func has_valid_connection() -> bool:
	_sync_state_config()
	return pathfinder.has_valid_connection()

func get_path_cells() -> Array[Vector2i]:
	_sync_state_config()
	return pathfinder.get_path_cells()

func get_path_world_points() -> Array[Vector2]:
	var cells: Array[Vector2i] = get_path_cells()
	var points: Array[Vector2] = []

	for cell in cells:
		points.append(cell_to_world(cell))

	return points

func _draw() -> void:
	renderer.draw(self, state)
