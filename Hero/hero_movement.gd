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

# Stable movement flavor
var lane_offset: float = 0.0
var combat_anchor_radius: float = 14.0
var combat_orbit_phase: float = 0.0
var combat_wobble_time: float = 0.0
var combat_target: Vector2 = Vector2.ZERO
var combat_target_timer: float = 0.0
var combat_side_bias: float = 0.0
var combat_front_bias: float = 0.0

func _init(new_hero) -> void:
	hero = new_hero

func configure_party_profile(unique_value: int) -> void:
	var safe_value: int = maxi(1, abs(unique_value))
	combat_anchor_radius = 12.0 + float(safe_value % 5) * 2.5
	combat_orbit_phase = TAU * (float(safe_value % 19) / 19.0)

	var side_slot: int = (safe_value % 7) - 3
	var front_slot: int = (safe_value % 5) - 2
	combat_side_bias = float(side_slot) * 4.0
	combat_front_bias = float(front_slot) * 2.6

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

func get_forward_direction_from_room(room_center: Vector2) -> Vector2:
	if path_index < path_points.size():
		var toward_next: Vector2 = path_points[path_index] - room_center
		if toward_next.length() > 0.001:
			return toward_next.normalized()

	if path_index > 0 and path_index < path_points.size():
		return get_path_segment_direction(path_index - 1, path_index)

	if path_points.size() >= 2:
		return get_path_segment_direction(0, 1)

	return Vector2.RIGHT

func get_room_anchor(room_center: Vector2) -> Vector2:
	var forward_dir: Vector2 = get_forward_direction_from_room(room_center)
	var side: Vector2 = Vector2(-forward_dir.y, forward_dir.x)

	return room_center + side * lane_offset * 0.95 - forward_dir * 6.0

func choose_new_combat_target(room_center: Vector2) -> void:
	var anchor: Vector2 = get_room_anchor(room_center)
	var forward_dir: Vector2 = get_forward_direction_from_room(room_center)
	var side: Vector2 = Vector2(-forward_dir.y, forward_dir.x)

	var orbit_angle: float = combat_orbit_phase + combat_wobble_time * 0.65 + randf_range(-0.20, 0.20)

	var side_push: float = lane_offset * 0.35
	side_push += combat_side_bias
	side_push += sin(orbit_angle) * combat_anchor_radius * 0.30
	side_push = clamp(side_push, -combat_anchor_radius, combat_anchor_radius)

	var front_push: float = combat_front_bias
	front_push += cos(orbit_angle * 0.9) * 3.0
	front_push += randf_range(-1.5, 1.5)

	combat_target = anchor + side * side_push + forward_dir * front_push + Vector2(
		randf_range(-1.6, 1.6),
		randf_range(-1.6, 1.6)
	)
	combat_target_timer = randf_range(0.30, 0.46)

func get_path_move_target(step_index: int) -> Vector2:
	var target: Vector2 = path_points[step_index]

	if step_index <= 0:
		return target

	var segment: Vector2 = target - path_points[step_index - 1]
	if segment.length() <= 0.001:
		return target

	var dir: Vector2 = segment.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return target + side * lane_offset * 0.85

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

func get_tracked_path_cell() -> Vector2i:
	if hero.board_ref == null:
		return Vector2i(-999, -999)

	var path_cells: Array[Vector2i] = hero.board_ref.get_path_cells()
	if path_cells.is_empty():
		return hero.board_ref.world_to_cell(hero.global_position)

	var last_index: int = path_cells.size() - 1

	if path_points.is_empty():
		var fallback_index: int = maxi(0, mini(path_index, last_index))
		return path_cells[fallback_index]

	var previous_index: int = maxi(0, mini(path_index - 1, last_index))
	var next_index: int = maxi(0, mini(path_index, last_index))

	if previous_index == next_index:
		return path_cells[next_index]

	var previous_center: Vector2 = path_points[previous_index]
	var next_center: Vector2 = path_points[next_index]
	var segment: Vector2 = next_center - previous_center
	var segment_length: float = segment.length()

	if segment_length <= 0.001:
		return path_cells[next_index]

	var direction: Vector2 = segment / segment_length
	var along_segment: float = clamp(
		(hero.global_position - previous_center).dot(direction),
		0.0,
		segment_length
	)

	if along_segment >= segment_length * 0.5:
		return path_cells[next_index]

	return path_cells[previous_index]

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
	var anchor: Vector2 = get_room_anchor(room_center)

	if hero.global_position.distance_to(anchor) > 12.0:
		hero.global_position = hero.global_position.move_toward(anchor, get_current_move_speed() * delta * 1.04)
		return

	combat_wobble_time += delta
	combat_target_timer = max(0.0, combat_target_timer - delta)

	if combat_target == Vector2.ZERO or combat_target_timer <= 0.0 or hero.global_position.distance_to(combat_target) <= 5.0:
		choose_new_combat_target(room_center)

	var combat_move_speed: float = max(62.0, get_current_move_speed() * 0.40)
	hero.global_position = hero.global_position.move_toward(combat_target, combat_move_speed * delta)

func update_forward_movement(delta: float) -> void:
	if path_index >= path_points.size():
		return

	var move_target: Vector2 = get_path_move_target(path_index)

	if hero.global_position.distance_to(move_target) <= 6.0:
		hero.global_position = move_target
		path_index += 1
		return

	hero.global_position = hero.global_position.move_toward(move_target, get_current_move_speed() * delta)
