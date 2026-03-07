extends Camera2D

@export var board_path: NodePath
@export var pan_speed: float = 900.0
@export var zoom_step: float = 0.1

# Godot Camera2D:
# smaller = farther out
# larger = closer in
@export var farthest_zoom_out: float = 0.5
@export var closest_zoom_in: float = 2.5
@export var start_zoom: float = 0.75

var board: Node2D = null
var is_panning: bool = false

func _ready() -> void:
	if board_path != NodePath(""):
		board = get_node(board_path) as Node2D

	if board != null and board.has_method("get_board_rect_global"):
		var rect: Rect2 = board.get_board_rect_global()
		global_position = rect.position + rect.size * 0.5

	var z: float = clamp(start_zoom, farthest_zoom_out, closest_zoom_in)
	zoom = Vector2(z, z)
	clamp_to_board()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		# wheel up = zoom IN
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(+zoom_step)
		# wheel down = zoom OUT
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(-zoom_step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = true

	if event is InputEventMouseButton and not event.pressed:
		var mb_up: InputEventMouseButton = event as InputEventMouseButton
		if mb_up.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = false

	if event is InputEventMouseMotion and is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		global_position -= mm.relative / zoom.x
		clamp_to_board()

func _process(delta: float) -> void:
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

func apply_zoom(delta_zoom: float) -> void:
	var z: float = clamp(zoom.x + delta_zoom, farthest_zoom_out, closest_zoom_in)
	zoom = Vector2(z, z)
	clamp_to_board()

func clamp_to_board() -> void:
	if board == null:
		return
	if not board.has_method("get_board_rect_global"):
		return

	var rect: Rect2 = board.get_board_rect_global()
	var vp: Vector2 = get_viewport_rect().size

	# Correct world half extents for Camera2D zoom
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
