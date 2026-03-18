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
	if tile_type == "gas":
		return Color(0.25, 0.55, 0.25, 1.0)
	if tile_type == "slow":
		return Color(0.25, 0.50, 0.75, 1.0)
	if tile_type == "altar":
		return Color(0.64, 0.54, 0.18, 1.0)
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

func draw_level_pips(board: Node2D, tile_rect: Rect2, tile_level: int) -> void:
	for i in range(tile_level):
		var pip_pos: Vector2 = tile_rect.position + Vector2(14.0 + i * 14.0, 14.0)
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

func draw_gas_symbol(board: Node2D, tile_rect: Rect2) -> void:
	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	board.draw_circle(center + Vector2(-10.0, 4.0), 12.0, Color(0.85, 1.0, 0.85, 0.60))
	board.draw_circle(center + Vector2(10.0, 2.0), 14.0, Color(0.82, 1.0, 0.82, 0.55))
	board.draw_circle(center + Vector2(0.0, -8.0), 10.0, Color(0.90, 1.0, 0.90, 0.50))

func draw_slow_symbol(board: Node2D, tile_rect: Rect2) -> void:
	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	var color_main: Color = Color(0.85, 0.95, 1.0, 0.85)

	board.draw_line(center + Vector2(-16.0, -12.0), center + Vector2(16.0, -12.0), color_main, 4.0)
	board.draw_line(center + Vector2(-8.0, 0.0), center + Vector2(8.0, 0.0), color_main, 4.0)
	board.draw_line(center + Vector2(-16.0, 12.0), center + Vector2(16.0, 12.0), color_main, 4.0)

func draw_altar_symbol(board: Node2D, tile_rect: Rect2) -> void:
	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	var glow_color: Color = Color(1.0, 0.94, 0.70, 0.28)
	var stone_color: Color = Color(0.98, 0.92, 0.76, 0.92)

	board.draw_circle(center + Vector2(0.0, -10.0), 18.0, glow_color)

	board.draw_rect(
		Rect2(center + Vector2(-18.0, 18.0), Vector2(36.0, 10.0)),
		Color(0.32, 0.28, 0.18, 0.85),
		true
	)

	board.draw_rect(
		Rect2(center + Vector2(-10.0, -8.0), Vector2(20.0, 28.0)),
		stone_color,
		true
	)

	board.draw_line(
		center + Vector2(-12.0, 6.0),
		center + Vector2(12.0, 6.0),
		Color(0.78, 0.68, 0.28, 0.90),
		3.0
	)
	board.draw_line(
		center + Vector2(0.0, -6.0),
		center + Vector2(0.0, 18.0),
		Color(0.78, 0.68, 0.28, 0.90),
		3.0
	)
	board.draw_circle(center + Vector2(0.0, -12.0), 5.0, Color(1.0, 0.97, 0.80, 0.95))

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
	elif tile_type == "gas":
		draw_gas_symbol(board, tile_rect)
	elif tile_type == "slow":
		draw_slow_symbol(board, tile_rect)
	elif tile_type == "altar":
		draw_altar_symbol(board, tile_rect)

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

func draw_merge_feedback(board: Node2D, tile_rect: Rect2, merge_flash: float) -> void:
	if merge_flash <= 0.0:
		return

	var alpha: float = 0.38 * merge_flash
	var outer_rect: Rect2 = tile_rect.grow(4.0 * merge_flash)

	board.draw_rect(
		outer_rect,
		Color(1.0, 0.93, 0.62, alpha * 0.42),
		true
	)

	board.draw_rect(
		outer_rect.grow(-3.0),
		Color(1.0, 0.98, 0.84, alpha),
		false,
		4.0
	)

func draw_level_up_feedback(board: Node2D, tile_rect: Rect2, level_up_flash: float) -> void:
	if level_up_flash <= 0.0:
		return

	var alpha: float = 0.34 * level_up_flash
	var sweep_t: float = 1.0 - level_up_flash
	var sweep_x: float = lerp(
		tile_rect.position.x + tile_rect.size.x * 0.14,
		tile_rect.position.x + tile_rect.size.x * 0.86,
		sweep_t
	)

	board.draw_rect(
		tile_rect,
		Color(1.0, 0.96, 0.72, alpha * 0.30),
		true
	)

	board.draw_rect(
		tile_rect.grow(2.0),
		Color(1.0, 0.96, 0.72, alpha * 0.95),
		false,
		4.0
	)

	board.draw_line(
		Vector2(sweep_x - 12.0, tile_rect.position.y + 12.0),
		Vector2(sweep_x + 12.0, tile_rect.position.y + tile_rect.size.y - 12.0),
		Color(1.0, 1.0, 1.0, alpha * 0.95),
		4.0
	)

func draw_support_buff_overlay(board: Node2D, tile_rect: Rect2, damage_multiplier: float) -> void:
	if damage_multiplier <= 1.001:
		return

	var strength: float = clamp((damage_multiplier - 1.0) / 0.50, 0.0, 1.0)
	var fill_alpha: float = 0.05 + 0.08 * strength
	var border_alpha: float = 0.34 + 0.30 * strength
	var glow_color: Color = Color(1.0, 0.92, 0.52, fill_alpha)
	var edge_color: Color = Color(1.0, 0.94, 0.70, border_alpha)

	board.draw_rect(tile_rect.grow(-6.0), glow_color, true)
	board.draw_rect(tile_rect.grow(-3.0), edge_color, false, 4.0)
	board.draw_circle(tile_rect.position + Vector2(14.0, tile_rect.size.y - 14.0), 4.0, edge_color)

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
		var merge_flash: float = float(tile_data.get("merge_flash", 0.0))
		var level_up_flash: float = float(tile_data.get("level_up_flash", 0.0))
		var cell: Vector2i = Vector2i(cx, cy)
		var damage_multiplier: float = state.get_room_damage_multiplier_for_cell(cell)

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
		draw_merge_feedback(board, tile_rect, merge_flash)
		draw_level_up_feedback(board, tile_rect, level_up_flash)
		draw_support_buff_overlay(board, tile_rect, damage_multiplier)

		if tile_level > 1:
			draw_level_pips(board, tile_rect, tile_level)

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
