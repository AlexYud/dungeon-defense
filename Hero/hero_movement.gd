class_name HeroMovement
extends RefCounted

var hero

var path_points: Array[Vector2] = []
var path_index: int = 0

# Boss control
var is_knockback_animating: bool = false
var knockback_target: Vector2 = Vector2.ZERO
var knockback_return_path_index: int = 0
var knockback_speed: float = 950.0

# Light movement flavor
var lane_offset: float = 0.0
var combat_wobble_time: float = 0.0
var combat_target: Vector2 = Vector2.ZERO
var combat_target_timer: float = 0.0

func _init(new_hero) -> void:
	hero = new_hero

func set_lane_offset(value: float) -> void:
	lane_offset = value

func set_path(points: Array[Vector2]) -> void:
	path_points = points
	path_index = 0

	if path_points.size() > 0:
		hero.global_position = path_points[0]

func get_current_move_speed() -> float:
	return hero.move_speed * hero.statuses.slow_factor

func reset_combat_motion() -> void:
	combat_wobble_time = 0.0
	combat_target_timer = 0.0
	combat_target = Vector2.ZERO

func choose_new_combat_target(room_center: Vector2) -> void:
	var forward_bias: Vector2 = Vector2.ZERO

	if path_index < path_points.size():
		var toward_next: Vector2 = path_points[path_index] - room_center
		if toward_next.length() > 0.001:
			forward_bias = toward_next.normalized() * randf_range(2.0, 6.0)

	combat_target = room_center + Vector2(
		randf_range(-14.0, 14.0) + lane_offset * 0.45 + forward_bias.x,
		randf_range(-10.0, 10.0) + forward_bias.y
	)
	combat_target_timer = randf_range(0.12, 0.24)

func get_path_move_target(step_index: int) -> Vector2:
	var target: Vector2 = path_points[step_index]

	if step_index <= 0:
		return target

	var segment: Vector2 = target - path_points[step_index - 1]
	if segment.length() <= 0.001:
		return target

	var dir: Vector2 = segment.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return target + side * lane_offset

func get_path_segment_direction(from_index: int, to_index: int) -> Vector2:
	if from_index < 0 or to_index < 0:
		return Vector2.RIGHT
	if from_index >= path_points.size() or to_index >= path_points.size():
		return Vector2.RIGHT

	var delta: Vector2 = path_points[to_index] - path_points[from_index]
	if delta.length() <= 0.001:
		return Vector2.RIGHT

	return delta.normalized()

func get_previous_tile_entry_point(previous_room_index: int, current_room_index: int) -> Vector2:
	var previous_center: Vector2 = path_points[previous_room_index]
	var forward_dir: Vector2 = get_path_segment_direction(previous_room_index, current_room_index)
	var side: Vector2 = Vector2(-forward_dir.y, forward_dir.x)

	var tile_span: float = float(hero.board_ref.tile_size)
	var backward_offset: float = tile_span * 0.34
	var side_offset: float = lane_offset * 0.70

	return previous_center + side * side_offset - forward_dir * backward_offset

func start_knockback_one_room() -> void:
	if hero.board_ref == null:
		return
	if path_points.is_empty():
		return

	var path_cells: Array[Vector2i] = hero.board_ref.get_path_cells()
	if path_cells.is_empty():
		return

	var current_room_index: int = maxi(0, mini(path_index - 1, path_cells.size() - 1))
	var found_index: int = path_cells.find(hero.room_logic.current_cell)
	if found_index >= 0:
		current_room_index = found_index

	if current_room_index <= 0:
		return

	var previous_room_index: int = current_room_index - 1

	knockback_target = get_previous_tile_entry_point(previous_room_index, current_room_index)
	knockback_return_path_index = previous_room_index
	is_knockback_animating = true

	reset_combat_motion()
	hero.room_logic.clear_current_room_tracking()

	hero.statuses.spawn_floating_text("SLAM", Color(1.0, 0.82, 0.45, 1.0), -30.0)

func update_knockback_animation(delta: float) -> void:
	hero.global_position = hero.global_position.move_toward(knockback_target, knockback_speed * delta)

	if hero.global_position.distance_to(knockback_target) <= 2.0:
		hero.global_position = knockback_target
		is_knockback_animating = false
		path_index = knockback_return_path_index
		hero.room_logic.clear_current_room_tracking()

func move_to_room_center_or_wobble(delta: float) -> void:
	if hero.board_ref == null:
		return

	var room_center: Vector2 = hero.board_ref.cell_to_world(hero.room_logic.current_cell)
	var center_distance: float = hero.global_position.distance_to(room_center)

	if center_distance > 12.0:
		hero.global_position = hero.global_position.move_toward(room_center, get_current_move_speed() * delta * 1.25)
		return

	combat_wobble_time += delta
	combat_target_timer = max(0.0, combat_target_timer - delta)

	if combat_target == Vector2.ZERO or combat_target_timer <= 0.0 or hero.global_position.distance_to(combat_target) <= 5.0:
		choose_new_combat_target(room_center)

	var combat_move_speed: float = max(70.0, get_current_move_speed() * 0.55)
	hero.global_position = hero.global_position.move_toward(combat_target, combat_move_speed * delta)

func update_forward_movement(delta: float) -> void:
	var move_target: Vector2 = get_path_move_target(path_index)

	if hero.global_position.distance_to(move_target) < 4.0:
		path_index += 1
		return

	hero.global_position = hero.global_position.move_toward(move_target, get_current_move_speed() * delta)
