extends Node2D

const HERO_GRID_PATH: String = "res://MainGrid/HeroGrid.tscn"

@onready var board: Node2D = $Board
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var game_over_summary_label: Label = $UI/GameOverPanel/VBox/SummaryLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var gold_label: Label = $UI/GoldLabel
@onready var life_label: Label = $UI/LifeLabel
@onready var shop_bar: PanelContainer = $UI/ShopBar
@onready var wave_spawn_timer: Timer = $WaveSpawnTimer
@onready var restart_button: Button = $UI/GameOverPanel/VBox/RestartButton

@onready var corridor_card: PanelContainer = $UI/ShopBar/ShopRow/CorridorCard
@onready var bat_card: PanelContainer = $UI/ShopBar/ShopRow/BatCard
@onready var boss_card: PanelContainer = $UI/ShopBar/ShopRow/BossCard
@onready var spike_card: PanelContainer = $UI/ShopBar/ShopRow/SpikeCard

var dragged_tile_type: String = ""
var dragged_tile_level: int = 1
var dragged_from_board: bool = false
var drag_origin_cell: Vector2i = Vector2i(-999, -999)
var drag_preview: ColorRect = null

var hero_scene: PackedScene = null
var active_heroes: Array[Node2D] = []

var wave_running: bool = false
var heroes_to_spawn: int = 0
var heroes_per_wave: int = 5
var wave_number: int = 0

@export var starting_gold: int = 100
@export var starting_life: int = 10
var gold: int = 100
var life: int = 10
var game_over: bool = false

@export var gold_per_kill: int = 8
@export var life_loss_on_escape: int = 1

func _ready() -> void:
	hint_label.text = "Build: drag from shop/board | same room+level merges | RMB sell | Space = start wave"

	corridor_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "corridor"))
	bat_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "bat"))
	boss_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "boss"))
	spike_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "spike"))

	wave_spawn_timer.timeout.connect(_on_wave_spawn_timer_timeout)

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_afford_visuals()
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart_button_pressed)
	gold = starting_gold
	life = starting_life
	board.reset_run_stats()

func _process(_delta: float) -> void:
	if dragged_tile_type != "":
		update_drag_preview()

		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var placed: bool = try_drop_tile()

			if (not placed) and dragged_from_board:
				var restored: bool = board.place_tile(dragged_tile_type, drag_origin_cell, dragged_tile_level)
				if restored:
					print("Reverted ", dragged_tile_type, " L", dragged_tile_level, " to ", drag_origin_cell)

			end_drag()
			update_connection_status()
			update_shop_afford_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return

	if event.is_action_pressed("ui_accept"):
		if can_start_wave():
			start_wave()
		return

	if wave_running:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if dragged_tile_type == "":
				try_pickup_board_tile()

		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if dragged_tile_type == "":
				try_sell_tile()

func room_cost(tile_type: String) -> int:
	if tile_type == "corridor":
		return 0
	if tile_type == "bat":
		return 20
	if tile_type == "spike":
		return 10
	if tile_type == "boss":
		return 40
	return 999999

func sell_refund(tile_type: String, tile_level: int) -> int:
	var base_cost: int = room_cost(tile_type)
	if base_cost <= 0:
		return 0

	var multiplier: int = 1
	if tile_level == 2:
		multiplier = 2
	elif tile_level >= 3:
		multiplier = 4

	var invested: int = base_cost * multiplier
	return int(floor(float(invested) * 0.5))

func can_afford_room(tile_type: String) -> bool:
	return gold >= room_cost(tile_type)

func spend_gold(amount: int) -> void:
	gold = max(0, gold - amount)
	update_gold_life_ui()

func gain_gold(amount: int) -> void:
	gold += max(0, amount)
	update_gold_life_ui()

func lose_life(amount: int) -> void:
	life = max(0, life - max(0, amount))
	update_gold_life_ui()

	if life <= 0:
		game_over = true
		wave_running = false
		wave_spawn_timer.stop()
		hint_label.text = "Game Over"
		update_build_run_ui()
		update_connection_status()
		show_game_over_summary()

func update_gold_life_ui() -> void:
	gold_label.text = "Gold: %d" % gold
	life_label.text = "Life: %d" % life

func can_start_wave() -> bool:
	if game_over:
		return false
	if wave_running:
		return false
	if dragged_tile_type != "":
		return false
	return board.has_valid_connection()

func start_wave() -> void:
	board.reset_for_new_wave()

	wave_running = true
	wave_number += 1
	heroes_to_spawn = heroes_per_wave

	print("Wave ", wave_number, " started")
	update_build_run_ui()
	update_connection_status()

	wave_spawn_timer.start()

func _on_wave_spawn_timer_timeout() -> void:
	if not wave_running:
		wave_spawn_timer.stop()
		return

	if heroes_to_spawn > 0:
		spawn_wave_hero()
		heroes_to_spawn -= 1
		update_connection_status()

	if heroes_to_spawn <= 0:
		wave_spawn_timer.stop()

func spawn_wave_hero() -> void:
	if hero_scene == null:
		hero_scene = load(HERO_GRID_PATH)
		if hero_scene == null:
			push_error("Could not load hero scene at " + HERO_GRID_PATH)
			return

	var points: Array[Vector2] = board.get_path_world_points()
	if points.is_empty():
		print("No path points found")
		return

	var hero_instance: Node2D = hero_scene.instantiate() as Node2D
	active_heroes.append(hero_instance)

	add_child(hero_instance)
	hero_instance.set_board_ref(board)
	hero_instance.set_path(points)
	hero_instance.reached_goal.connect(_on_wave_hero_reached_goal.bind(hero_instance))
	hero_instance.died.connect(_on_wave_hero_died.bind(hero_instance))

func _on_wave_hero_reached_goal(hero: Node2D) -> void:
	print("Hero reached chest")
	board.register_escape()
	lose_life(life_loss_on_escape)
	remove_active_hero(hero)
	check_wave_finished()

func _on_wave_hero_died(hero: Node2D) -> void:
	print("Hero died before reaching chest")
	gain_gold(gold_per_kill)
	remove_active_hero(hero)
	check_wave_finished()

func remove_active_hero(hero: Node2D) -> void:
	var index: int = active_heroes.find(hero)
	if index >= 0:
		active_heroes.remove_at(index)
	update_connection_status()

func check_wave_finished() -> void:
	if heroes_to_spawn > 0:
		return
	if not active_heroes.is_empty():
		return

	wave_running = false
	print("Wave ", wave_number, " finished")

	update_build_run_ui()
	update_connection_status()
	update_shop_afford_visuals()

func update_build_run_ui() -> void:
	game_over_panel.visible = game_over
	shop_bar.visible = not wave_running and not game_over
	game_over_panel.visible = game_over

	if game_over:
		hint_label.text = "Game Over"
	elif wave_running:
		hint_label.text = "Run phase: shop hidden | camera free | wait for heroes"
	else:
		hint_label.text = "Build: drag from shop/board | same room+level merges | RMB sell | Space = start wave"

func _on_card_gui_input(event: InputEvent, tile_type: String) -> void:
	if game_over:
		return
	if wave_running:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not can_afford_room(tile_type):
				print("Not enough gold for ", tile_type)
				return
			start_drag(tile_type, 1, false, Vector2i(-999, -999))

func start_drag(tile_type: String, tile_level: int, from_board: bool, origin_cell: Vector2i) -> void:
	if game_over:
		return
	if wave_running:
		return
	if dragged_tile_type != "":
		return

	dragged_tile_type = tile_type
	dragged_tile_level = tile_level
	dragged_from_board = from_board
	drag_origin_cell = origin_cell

	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(float(board.tile_size), float(board.tile_size))
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)

	update_drag_preview()

func try_pickup_board_tile() -> void:
	if wave_running:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)
	var existing_type: String = board.get_tile_type(cell)
	var existing_level: int = board.get_tile_level(cell)

	if existing_type == "":
		return

	var removed: bool = board.remove_tile(cell)
	if not removed:
		return

	print("Picked up ", existing_type, " L", existing_level, " from ", cell)
	start_drag(existing_type, existing_level, true, cell)
	update_connection_status()

func try_sell_tile() -> void:
	if wave_running:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)
	var existing_type: String = board.get_tile_type(cell)
	var existing_level: int = board.get_tile_level(cell)

	if existing_type == "":
		return

	var removed: bool = board.remove_tile(cell)
	if removed:
		var refund: int = sell_refund(existing_type, existing_level)
		gain_gold(refund)
		print("Sold/removed ", existing_type, " L", existing_level, " at ", cell, " | refund=", refund)
		update_connection_status()
		update_shop_afford_visuals()

func update_drag_preview() -> void:
	if drag_preview == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)
	var snapped_pos: Vector2 = board.cell_to_world(cell)

	drag_preview.global_position = snapped_pos - drag_preview.size * 0.5

	if (not dragged_from_board) and (not can_afford_room(dragged_tile_type)):
		drag_preview.color = Color(0.9, 0.2, 0.2, 0.55)
		return

	if board.can_place_tile(dragged_tile_type, cell):
		drag_preview.color = preview_color(dragged_tile_type, false)
	elif board.can_merge_tile(dragged_tile_type, dragged_tile_level, cell):
		drag_preview.color = preview_color(dragged_tile_type, true)
	else:
		drag_preview.color = Color(0.9, 0.2, 0.2, 0.55)

func preview_color(tile_type: String, merge_preview: bool) -> Color:
	if merge_preview:
		return Color(1.0, 0.85, 0.25, 0.70)

	if tile_type == "corridor":
		return Color(0.7, 0.7, 0.9, 0.55)
	if tile_type == "bat":
		return Color(0.75, 0.35, 0.75, 0.55)
	if tile_type == "spike":
		return Color(0.9, 0.35, 0.35, 0.55)
	if tile_type == "boss":
		return Color(0.45, 0.45, 0.45, 0.55)
	return Color(1.0, 1.0, 1.0, 0.55)

func try_drop_tile() -> bool:
	if dragged_tile_type == "":
		return false

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)

	if not dragged_from_board:
		var buy_cost: int = room_cost(dragged_tile_type)
		if gold < buy_cost:
			print("Not enough gold to place ", dragged_tile_type)
			return false

	if board.can_place_tile(dragged_tile_type, cell):
		var placed: bool = board.place_tile(dragged_tile_type, cell, dragged_tile_level)
		if placed:
			if not dragged_from_board:
				spend_gold(room_cost(dragged_tile_type))
			print("Placed ", dragged_tile_type, " L", dragged_tile_level, " at ", cell)
			update_shop_afford_visuals()
			return true

	if board.can_merge_tile(dragged_tile_type, dragged_tile_level, cell):
		var new_level: int = board.merge_tile(dragged_tile_type, dragged_tile_level, cell)
		if new_level > 0:
			if not dragged_from_board:
				spend_gold(room_cost(dragged_tile_type))
			print("Merged ", dragged_tile_type, " L", dragged_tile_level, " -> L", new_level, " at ", cell)
			update_shop_afford_visuals()
			return true

	print("Invalid drop for ", dragged_tile_type, " L", dragged_tile_level, " at ", cell)
	return false

func end_drag() -> void:
	dragged_tile_type = ""
	dragged_tile_level = 1
	dragged_from_board = false
	drag_origin_cell = Vector2i(-999, -999)

	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

func update_shop_afford_visuals() -> void:
	update_card_afford_visual(corridor_card, "corridor")
	update_card_afford_visual(bat_card, "bat")
	update_card_afford_visual(spike_card, "spike")
	update_card_afford_visual(boss_card, "boss")

func update_card_afford_visual(card: PanelContainer, tile_type: String) -> void:
	var affordable: bool = can_afford_room(tile_type)

	if wave_running or game_over:
		card.modulate = Color(0.65, 0.65, 0.65, 1.0)
		return

	if affordable:
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		card.modulate = Color(0.65, 0.45, 0.45, 1.0)

func update_connection_status() -> void:
	if game_over:
		status_label.text = "Game Over"
		status_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		return

	if wave_running:
		status_label.text = "Wave %d running | To spawn: %d | Alive: %d" % [wave_number, heroes_to_spawn, active_heroes.size()]
		status_label.modulate = Color(0.9, 0.9, 1.0, 1.0)
		return

	var connected: bool = board.has_valid_connection()

	if connected:
		status_label.text = "Path: Connected"
		status_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		status_label.text = "Path: Not connected"
		status_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

func show_game_over_summary() -> void:
	var lines: PackedStringArray = board.get_room_stats_summary_lines()
	var full_text: String = ""

	for i in range(lines.size()):
		full_text += lines[i]
		if i < lines.size() - 1:
			full_text += "\n"

	game_over_summary_label.text = full_text
	game_over_panel.visible = true
	
func _on_restart_button_pressed() -> void:
	restart_run()

func restart_run() -> void:
	cleanup_active_heroes()

	wave_running = false
	game_over = false
	heroes_to_spawn = 0
	wave_number = 0

	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	dragged_tile_type = ""
	dragged_tile_level = 1
	dragged_from_board = false
	drag_origin_cell = Vector2i(-999, -999)

	gold = starting_gold
	life = starting_life

	wave_spawn_timer.stop()

	board.reset_board_for_new_run()

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_afford_visuals()

	print("Run restarted")

func cleanup_active_heroes() -> void:
	for hero in active_heroes:
		if is_instance_valid(hero):
			hero.queue_free()

	active_heroes.clear()
