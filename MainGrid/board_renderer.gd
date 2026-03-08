class_name BoardRenderer
extends RefCounted

func tile_base_color(tile_type: String) -> Color:
	if tile_type == "corridor":
		return Color(0.35, 0.35, 0.42, 1.0)
	if tile_type == "bat":
		return Color(0.55, 0.25, 0.55, 1.0)
	if tile_type == "spike":
		return Color(0.75, 0.25, 0.25, 1.0)
	if tile_type == "boss":
		return Color(0.25, 0.25, 0.25, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)

func tile_color(tile_type: String, tile_level: int, beaten: bool, cooldown_left: float) -> Color:
	var base: Color = tile_base_color(tile_type)
	var boost: float = min(0.30, 0.10 * float(tile_level - 1))

	var result: Color = Color(
		min(1.0, base.r + boost),
		min(1.0, base.g + boost),
		min(1.0, base.b + boost),
		1.0
	)

	if beaten:
		result = result.darkened(0.35)

	if tile_type == "spike" and cooldown_left > 0.0:
		result = result.darkened(0.40)

	return result

func draw_level_pips(board: Node2D, cell_x: int, cell_y: int, tile_level: int, tile_size: int) -> void:
	for i in range(tile_level):
		var pip_pos: Vector2 = Vector2(
			float(cell_x * tile_size + 14 + i * 14),
			float(cell_y * tile_size + 14)
		)
		board.draw_circle(pip_pos, 4.0, Color(1.0, 1.0, 1.0, 0.95))

func draw_corridor_symbol(board: Node2D, tile_rect: Rect2, tile_size: int) -> void:
	var inset: float = float(tile_size) * 0.28
	var inner_rect: Rect2 = Rect2(
		tile_rect.position + Vector2(inset, inset),
		tile_rect.size - Vector2(inset * 2.0, inset * 2.0)
	)
	board.draw_rect(inner_rect, Color(0.82, 0.82, 0.90, 0.22), true)

func draw_spike_symbol(board: Node2D, tile_rect: Rect2, cooldown_left: float) -> void:
	var base_y: float = tile_rect.position.y + tile_rect.size.y * 0.72
	var left_x: float = tile_rect.position.x + tile_rect.size.x * 0.18
	var width: float = tile_rect.size.x * 0.64
	var spike_count: int = 4
	var spike_w: float = width / float(spike_count)

	var spike_color: Color = Color(0.95, 0.88, 0.88, 0.95)
	if cooldown_left > 0.0:
		spike_color = Color(0.55, 0.45, 0.45, 0.95)

	for i in range(spike_count):
		var x0: float = left_x + spike_w * float(i)
		var x1: float = x0 + spike_w * 0.5
		var x2: float = x0 + spike_w

		var points: PackedVector2Array = PackedVector2Array([
			Vector2(x0, base_y),
			Vector2(x1, tile_rect.position.y + tile_rect.size.y * 0.30),
			Vector2(x2, base_y)
		])
		board.draw_colored_polygon(points, spike_color)

func draw_bat_symbol(board: Node2D, tile_rect: Rect2, mob_count: int, beaten: bool) -> void:
	var wing_color: Color = Color(0.92, 0.86, 0.96, 0.95)
	if beaten:
		wing_color = Color(0.60, 0.56, 0.66, 0.95)

	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	var display_count: int = min(mob_count, 5)

	for i in range(display_count):
		var row: int = int(floor(float(i) / 3.0))
		var col: int = i % 3
		var offset: Vector2

		if row == 0:
			offset = Vector2(-18.0 + 18.0 * float(col), -6.0)
		else:
			offset = Vector2(-9.0 + 18.0 * float(i - 3), 14.0)

		var c: Vector2 = center + offset
		board.draw_circle(c + Vector2(-5.0, 0.0), 5.0, wing_color)
		board.draw_circle(c + Vector2(5.0, 0.0), 5.0, wing_color)
		board.draw_circle(c, 2.2, Color(0.10, 0.10, 0.10, 1.0))

func draw_boss_symbol(board: Node2D, tile_rect: Rect2, beaten: bool) -> void:
	var crown_color: Color = Color(0.95, 0.92, 0.72, 0.95)
	if beaten:
		crown_color = Color(0.62, 0.60, 0.50, 0.95)

	var left: float = tile_rect.position.x + tile_rect.size.x * 0.22
	var right: float = tile_rect.position.x + tile_rect.size.x * 0.78
	var top: float = tile_rect.position.y + tile_rect.size.y * 0.28
	var mid_y: float = tile_rect.position.y + tile_rect.size.y * 0.54
	var bottom: float = tile_rect.position.y + tile_rect.size.y * 0.72
	var mid_x: float = tile_rect.position.x + tile_rect.size.x * 0.50

	var points: PackedVector2Array = PackedVector2Array([
		Vector2(left, bottom),
		Vector2(left + 8.0, mid_y),
		Vector2(left + 18.0, top + 10.0),
		Vector2(mid_x, top),
		Vector2(right - 18.0, top + 10.0),
		Vector2(right - 8.0, mid_y),
		Vector2(right, bottom)
	])

	board.draw_colored_polygon(points, crown_color)
	board.draw_rect(
		Rect2(
			Vector2(left + 4.0, bottom - 6.0),
			Vector2((right - left) - 8.0, 8.0)
		),
		crown_color,
		true
	)

func draw_beaten_overlay(board: Node2D, tile_rect: Rect2) -> void:
	var overlay: Color = Color(1.0, 1.0, 1.0, 0.16)
	board.draw_rect(tile_rect, overlay, true)

	var line_color: Color = Color(0.95, 0.95, 0.95, 0.35)
	board.draw_line(
		tile_rect.position + Vector2(14.0, 14.0),
		tile_rect.position + tile_rect.size - Vector2(14.0, 14.0),
		line_color,
		4.0
	)
	board.draw_line(
		tile_rect.position + Vector2(tile_rect.size.x - 14.0, 14.0),
		tile_rect.position + Vector2(14.0, tile_rect.size.y - 14.0),
		line_color,
		4.0
	)

func draw_tile_symbol(board: Node2D, tile_rect: Rect2, tile_data: Dictionary, tile_size: int) -> void:
	var tile_type: String = str(tile_data.get("type", ""))
	var beaten: bool = bool(tile_data.get("beaten", false))
	var cooldown_left: float = float(tile_data.get("cooldown_left", 0.0))
	var mob_count: int = int(tile_data.get("mob_count", 0))

	if tile_type == "corridor":
		draw_corridor_symbol(board, tile_rect, tile_size)
	elif tile_type == "spike":
		draw_spike_symbol(board, tile_rect, cooldown_left)
	elif tile_type == "bat":
		draw_bat_symbol(board, tile_rect, mob_count, beaten)
	elif tile_type == "boss":
		draw_boss_symbol(board, tile_rect, beaten)

	if beaten and (tile_type == "bat" or tile_type == "boss"):
		draw_beaten_overlay(board, tile_rect)

func draw_clear_flash(board: Node2D, tile_rect: Rect2, clear_flash: float) -> void:
	if clear_flash <= 0.0:
		return

	var alpha: float = min(0.45, clear_flash * 0.9)

	board.draw_rect(
		tile_rect,
		Color(1.0, 0.96, 0.70, alpha),
		true
	)

	board.draw_rect(
		tile_rect.grow(-4.0),
		Color(1.0, 1.0, 1.0, alpha * 0.75),
		false,
		4.0
	)

func draw(board: Node2D, state: BoardState) -> void:
	var w: float = float(state.cols * state.tile_size)
	var h: float = float(state.rows * state.tile_size)

	board.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.12, 0.12, 0.12, 1.0), true)

	for key_variant in state.placed_tiles.keys():
		var key_str: String = str(key_variant)
		var parts: PackedStringArray = key_str.split(",")
		if parts.size() != 2:
			continue

		var cx: int = int(parts[0])
		var cy: int = int(parts[1])

		var tile_data: Dictionary = state.placed_tiles[key_variant] as Dictionary
		var tile_type: String = str(tile_data.get("type", ""))
		var tile_level: int = int(tile_data.get("level", 1))
		var beaten: bool = bool(tile_data.get("beaten", false))
		var cooldown_left: float = float(tile_data.get("cooldown_left", 0.0))
		var clear_flash: float = float(tile_data.get("clear_flash", 0.0))

		var tile_rect: Rect2 = Rect2(
			Vector2(float(cx * state.tile_size), float(cy * state.tile_size)),
			Vector2(float(state.tile_size), float(state.tile_size))
		)

		board.draw_rect(
			tile_rect,
			tile_color(tile_type, tile_level, beaten, cooldown_left),
			true
		)

		draw_tile_symbol(board, tile_rect, tile_data, state.tile_size)
		draw_clear_flash(board, tile_rect, clear_flash)

		if tile_level > 1:
			draw_level_pips(board, cx, cy, tile_level, state.tile_size)

	board.draw_rect(
		Rect2(
			Vector2(float(state.start_cell.x * state.tile_size), float(state.start_cell.y * state.tile_size)),
			Vector2(float(state.tile_size), float(state.tile_size))
		),
		Color(0.2, 0.6, 0.2, 1.0),
		true
	)

	board.draw_rect(
		Rect2(
			Vector2(float(state.chest_cell.x * state.tile_size), float(state.chest_cell.y * state.tile_size)),
			Vector2(float(state.tile_size), float(state.tile_size))
		),
		Color(0.7, 0.6, 0.2, 1.0),
		true
	)

	for x in range(state.cols + 1):
		var px: float = float(x * state.tile_size)
		board.draw_line(Vector2(px, 0.0), Vector2(px, h), Color(0.25, 0.25, 0.25, 1.0), 2.0)

	for y in range(state.rows + 1):
		var py: float = float(y * state.tile_size)
		board.draw_line(Vector2(0.0, py), Vector2(w, py), Color(0.25, 0.25, 0.25, 1.0), 2.0)
