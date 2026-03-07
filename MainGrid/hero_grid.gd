extends Node2D

signal reached_goal
signal died

@export var move_speed: float = 260.0
@export var max_hp: float = 100.0
@export var hero_attack_dps: float = 45.0
@export var hero_attack_vs_boss_dps: float = 38.0

var board_ref: Node2D = null

var hp: float = 100.0
var path_points: Array[Vector2] = []
var path_index: int = 0

var current_cell: Vector2i = Vector2i(-999, -999)
var current_tile_type: String = ""
var current_tile_level: int = 0
var last_damage_room_cell: Vector2i = Vector2i(-999, -999)

func _ready() -> void:
	hp = max_hp

func set_board_ref(new_board: Node2D) -> void:
	board_ref = new_board

func set_path(points: Array[Vector2]) -> void:
	path_points = points
	path_index = 0

	if path_points.size() > 0:
		global_position = path_points[0]

func apply_damage(amount: float, source_cell: Vector2i = Vector2i(-999, -999)) -> void:
	if amount <= 0.0:
		return

	hp -= amount

	if board_ref != null and source_cell.x > -900:
		board_ref.register_room_damage(source_cell, amount)
		last_damage_room_cell = source_cell

	if hp <= 0.0:
		hp = 0.0

		if board_ref != null and last_damage_room_cell.x > -900:
			board_ref.register_room_kill(last_damage_room_cell)

		died.emit()
		queue_free()

func _process(delta: float) -> void:
	if path_points.is_empty():
		return

	var blocked_by_room: bool = update_room_effects(delta)

	if hp <= 0.0:
		return

	if blocked_by_room:
		return

	if path_index >= path_points.size():
		reached_goal.emit()
		queue_free()
		return

	var target: Vector2 = path_points[path_index]
	var to_target: Vector2 = target - global_position

	if to_target.length() < 4.0:
		path_index += 1
		return

	global_position += to_target.normalized() * move_speed * delta

func update_room_effects(delta: float) -> bool:
	if board_ref == null:
		return false

	var cell: Vector2i = board_ref.world_to_cell(global_position)

	if cell != current_cell:
		current_cell = cell
		current_tile_type = board_ref.get_tile_type(cell)
		current_tile_level = board_ref.get_tile_level(cell)

		if current_tile_type == "spike":
			var spike_damage: float = board_ref.try_trigger_spike(cell)
			if spike_damage > 0.0:
				apply_damage(spike_damage, cell)
				if hp > 0.0:
					print("Hero hit spike L", current_tile_level, ". HP: ", hp)
				if hp <= 0.0:
					return true

	if current_tile_type == "bat":
		if not board_ref.is_tile_beaten(current_cell):
			var bat_room_dps: float = board_ref.bat_room_dps_for_level(current_tile_level)
			apply_damage(bat_room_dps * delta, current_cell)

			if hp <= 0.0:
				return true

			var bat_cleared: bool = board_ref.damage_bat_room(current_cell, hero_attack_dps * delta)
			if bat_cleared:
				print("Bat room cleared at ", current_cell)

			return not bat_cleared

	elif current_tile_type == "boss":
		if not board_ref.is_tile_beaten(current_cell):
			var boss_room_dps: float = board_ref.boss_room_dps_for_level(current_tile_level)
			apply_damage(boss_room_dps * delta, current_cell)

			if hp <= 0.0:
				return true

			var boss_cleared: bool = board_ref.damage_boss_room(current_cell, hero_attack_vs_boss_dps * delta)
			if boss_cleared:
				print("Boss room cleared at ", current_cell)

			return not boss_cleared

	return false
