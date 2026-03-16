extends Camera2D

@export var board_path: NodePath
@export var pan_speed: float = 900.0
@export var zoom_step: float = 0.1

# Godot Camera2D:
# smaller = farther out
# larger = closer in
@export var farthest_zoom_out: float = 0.45
@export var closest_zoom_in: float = 1.8
@export var start_zoom: float = 0.7

@export var follow_zoom: float = 1.25
@export var follow_lerp_speed: float = 8.0

@export var boundary_padding: float = 160.0

@export var slam_shake_amount: float = 5.0
@export var merge_shake_amount: float = 3.0
@export var level_up_shake_amount: float = 6.0
@export var max_shake_offset: float = 10.0
@export var shake_decay: float = 22.0
@export var shake_follow_speed: float = 10.0

@export var merge_zoom_punch: float = 0.04
@export var level_up_zoom_punch: float = 0.10
@export var max_zoom_punch: float = 0.16
@export var zoom_punch_decay: float = 4.0
@export var zoom_lerp_speed: float = 10.0

var board: Node2D = null
var is_panning: bool = false

var follow_target: Node2D = null
var follow_while_space_held: bool = false

var shake_strength: float = 0.0
var shake_time: float = 0.0

var manual_zoom: float = 0.7
var zoom_punch: float = 0.0

func _ready() -> void:
	if board_path != NodePath(""):
		board = get_node(board_path) as Node2D

	if board != null and board.has_method("get_board_rect_global"):
		var rect: Rect2 = board.get_board_rect_global()
		global_position = rect.position + rect.size * 0.5

	manual_zoom = clamp(start_zoom, farthest_zoom_out, closest_zoom_in)
	zoom = Vector2(manual_zoom, manual_zoom)
	offset = Vector2.ZERO
	clamp_to_board()

func set_follow_target(target: Node2D) -> void:
	follow_target = target

func clear_follow_target() -> void:
	follow_target = null

func shake_hit(_intensity: float = 1.0) -> void:
	pass

func shake_slam(intensity: float = 1.0) -> void:
	add_shake(slam_shake_amount * max(intensity, 0.55))

func trigger_merge_event() -> void:
	add_shake(merge_shake_amount)
	add_zoom_punch(merge_zoom_punch)

func trigger_level_up_event() -> void:
	add_shake(level_up_shake_amount)
	add_zoom_punch(level_up_zoom_punch)

func add_shake(amount: float) -> void:
	shake_strength = min(max_shake_offset, shake_strength + amount)

func add_zoom_punch(amount: float) -> void:
	zoom_punch = min(max_zoom_punch, zoom_punch + amount)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(+zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(-zoom_step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = true

	if event is InputEventMouseButton and not event.pressed:
		var mb_up: InputEventMouseButton = event as InputEventMouseButton
		if mb_up.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = false

	if event is InputEventMouseMotion and is_panning and not is_follow_mode_active():
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		global_position -= mm.relative / zoom.x
		clamp_to_board()

func _process(delta: float) -> void:
	if is_follow_mode_active():
		var target_pos: Vector2 = follow_target.global_position
		global_position = global_position.lerp(target_pos, min(1.0, follow_lerp_speed * delta))
	else:
		var dir: Vector2 = Vector2.ZERO

		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1.0

		if dir.length() > 0.0:
			dir = dir.normalized()
			global_position += dir * pan_speed * delta / zoom.x
			clamp_to_board()

	update_camera_zoom(delta)
	update_screen_shake(delta)

func is_follow_mode_active() -> bool:
	return (
		follow_while_space_held
		and Input.is_key_pressed(KEY_SPACE)
		and follow_target != null
		and is_instance_valid(follow_target)
	)

func apply_zoom(delta_zoom: float) -> void:
	manual_zoom = clamp(manual_zoom + delta_zoom, farthest_zoom_out, closest_zoom_in)

func update_camera_zoom(delta: float) -> void:
	var desired_zoom: float = manual_zoom

	if is_follow_mode_active():
		desired_zoom = clamp(follow_zoom, farthest_zoom_out, closest_zoom_in)

	desired_zoom = clamp(desired_zoom + zoom_punch, farthest_zoom_out, closest_zoom_in)

	var lerp_speed: float = zoom_lerp_speed
	if is_follow_mode_active():
		lerp_speed = max(zoom_lerp_speed, follow_lerp_speed)

	var new_zoom: float = lerp(zoom.x, desired_zoom, min(1.0, lerp_speed * delta))
	zoom = Vector2(new_zoom, new_zoom)

	zoom_punch = move_toward(zoom_punch, 0.0, zoom_punch_decay * delta)
	clamp_to_board()

func update_screen_shake(delta: float) -> void:
	if shake_strength <= 0.01:
		offset = offset.lerp(Vector2.ZERO, min(1.0, shake_follow_speed * delta))
		return

	shake_time += delta * 26.0

	var shake_dir: Vector2 = Vector2(
		sin(shake_time * 2.2) + sin(shake_time * 5.8) * 0.25,
		cos(shake_time * 2.8) + cos(shake_time * 6.4) * 0.20
	)

	if shake_dir.length_squared() > 0.0001:
		var target_offset: Vector2 = shake_dir.normalized() * shake_strength
		offset = offset.lerp(target_offset, min(1.0, shake_follow_speed * delta))

	shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)

func clamp_to_board() -> void:
	if board == null:
		return
	if not board.has_method("get_board_rect_global"):
		return

	var rect: Rect2 = board.get_board_rect_global().grow(boundary_padding)
	var vp: Vector2 = get_viewport_rect().size
	var half: Vector2 = (vp * 0.5) / zoom

	var min_x: float = rect.position.x + half.x
	var max_x: float = rect.position.x + rect.size.x - half.x
	var min_y: float = rect.position.y + half.y
	var max_y: float = rect.position.y + rect.size.y - half.y

	if min_x > max_x:
		global_position.x = rect.position.x + rect.size.x * 0.5
	else:
		global_position.x = clamp(global_position.x, min_x, max_x)

	if min_y > max_y:
		global_position.y = rect.position.y + rect.size.y * 0.5
	else:
		global_position.y = clamp(global_position.y, min_y, max_y)
