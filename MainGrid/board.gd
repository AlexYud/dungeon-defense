extends Node2D

const FLOATING_TEXT_PATH: String = "res://MainGrid/FloatingText.tscn"

@export var cols: int = 10
@export var rows: int = 10
@export var tile_size: int = 128
@export var min_start_chest_distance: int = 6

@export var path_hero_attack_dps: float = 45.0
@export var path_hero_attack_vs_boss_dps: float = 38.0

var floating_text_scene: PackedScene = null

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
		path_hero_attack_vs_boss_dps
	)

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

func boss_room_dps_for_level(level: int) -> float:
	return state.boss_room_dps_for_level(level)

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
	state.reset_for_new_wave()
	queue_redraw()

func reset_board_for_new_run() -> void:
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
