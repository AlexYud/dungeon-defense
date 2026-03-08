extends Node2D

const HERO_GRID_PATH: String = "res://MainGrid/HeroGrid.tscn"

@onready var board: Node2D = $Board
@onready var camera_controller = $Camera2D

@onready var hint_label: Label = $UI/HintLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var gold_label: Label = $UI/GoldLabel
@onready var life_label: Label = $UI/LifeLabel
@onready var round_label: Label = $UI/RoundLabel

@onready var shop_bar: PanelContainer = $UI/ShopBar
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var game_over_summary_label: Label = $UI/GameOverPanel/VBox/SummaryLabel
@onready var restart_button: Button = $UI/GameOverPanel/VBox/RestartButton
@onready var start_round_button: Button = $UI/StartRoundButton
@onready var wave_spawn_timer: Timer = $WaveSpawnTimer

@onready var corridor_card: PanelContainer = $UI/ShopBar/ShopRow/CorridorCard
@onready var bat_card: PanelContainer = $UI/ShopBar/ShopRow/BatCard
@onready var boss_card: PanelContainer = $UI/ShopBar/ShopRow/BossCard
@onready var spike_card: PanelContainer = $UI/ShopBar/ShopRow/SpikeCard

@onready var corridor_card_label: Label = $UI/ShopBar/ShopRow/CorridorCard/Label
@onready var bat_card_label: Label = $UI/ShopBar/ShopRow/BatCard/Label
@onready var spike_card_label: Label = $UI/ShopBar/ShopRow/SpikeCard/Label
@onready var boss_card_label: Label = $UI/ShopBar/ShopRow/BossCard/Label

@export var starting_gold: int = 20
@export var starting_life: int = 10
@export var wave_clear_bonus_base: int = 18
@export var wave_clear_bonus_growth_per_wave: int = 2

var dragged_tile_type: String = ""
var dragged_tile_level: int = 1
var dragged_from_board: bool = false
var drag_origin_cell: Vector2i = Vector2i(-999, -999)
var drag_preview: ColorRect = null

var hero_scene: PackedScene = null

var wave_manager: WaveManager = WaveManager.new()
var run_manager: RunManager = RunManager.new()

func _ready() -> void:
	hint_label.text = "Build: drag from shop/board | same room+level merges | RMB sell | Click Start Round"

	corridor_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "corridor"))
	bat_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "bat"))
	boss_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "boss"))
	spike_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "spike"))

	wave_spawn_timer.timeout.connect(_on_wave_spawn_timer_timeout)
	restart_button.pressed.connect(_on_restart_button_pressed)
	start_round_button.pressed.connect(_on_start_round_button_pressed)

	wave_manager.wave_clear_bonus_base = wave_clear_bonus_base
	wave_manager.wave_clear_bonus_growth_per_wave = wave_clear_bonus_growth_per_wave

	run_manager.configure(starting_gold, starting_life)
	run_manager.reset_for_new_run()

	wave_spawn_timer.wait_time = wave_manager.spawn_interval
	camera_controller.follow_while_space_held = true

	game_over_panel.visible = false
	board.reset_run_stats()

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_afford_visuals()
	update_shop_card_texts()
	update_shop_visibility()
	update_round_ui()

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
	if run_manager.game_over:
		return

	if event.is_action_pressed("ui_accept"):
		if can_start_wave():
			start_wave()
		return

	if wave_manager.wave_running:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if dragged_tile_type == "":
				try_pickup_board_tile()

		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if dragged_tile_type == "":
				try_sell_tile()

func spend_gold(amount: int) -> void:
	run_manager.spend_gold(amount)
	update_gold_life_ui()

func gain_gold(amount: int) -> void:
	run_manager.gain_gold(amount)
	update_gold_life_ui()

func lose_life(amount: int) -> void:
	var did_game_over: bool = run_manager.lose_life(amount)
	update_gold_life_ui()

	if did_game_over:
		wave_manager.wave_running = false
		wave_spawn_timer.stop()
		hint_label.text = "Game Over"
		update_build_run_ui()
		update_connection_status()
		show_game_over_summary()

func update_gold_life_ui() -> void:
	gold_label.text = "Gold: %d" % run_manager.gold
	life_label.text = "Life: %d" % run_manager.life

func update_round_ui() -> void:
	round_label.text = wave_manager.get_round_label_text(run_manager.game_over)

func can_start_wave() -> bool:
	if run_manager.game_over:
		return false
	if wave_manager.wave_running:
		return false
	if dragged_tile_type != "":
		return false
	return board.has_valid_connection()

func start_wave() -> void:
	wave_manager.start_wave(board)

	print("Wave ", wave_manager.wave_number, " started")
	update_build_run_ui()
	update_connection_status()
	update_round_ui()

	wave_spawn_timer.start()

func _on_start_round_button_pressed() -> void:
	if can_start_wave():
		start_wave()

func _on_wave_spawn_timer_timeout() -> void:
	if not wave_manager.wave_running:
		wave_spawn_timer.stop()
		return

	if wave_manager.wave_spawn_queue.is_empty():
		wave_spawn_timer.stop()
		update_connection_status()
		update_round_ui()
		return

	if hero_scene == null:
		hero_scene = load(HERO_GRID_PATH)
		if hero_scene == null:
			push_error("Could not load hero scene at " + HERO_GRID_PATH)
			return

	var spawn_result: Dictionary = wave_manager.spawn_next_enemy(board, hero_scene, self)
	var hero_instance: HeroGrid = spawn_result.get("hero", null) as HeroGrid
	var enemy_type: String = str(spawn_result.get("enemy_type", ""))

	if hero_instance != null:
		update_camera_follow_target()

		var gold_reward: int = wave_manager.get_enemy_gold_reward(enemy_type)
		var escape_damage: int = wave_manager.get_enemy_escape_damage(enemy_type)

		hero_instance.reached_goal.connect(_on_wave_hero_reached_goal.bind(hero_instance, escape_damage))
		hero_instance.died.connect(_on_wave_hero_died.bind(hero_instance, gold_reward))

	update_connection_status()
	update_round_ui()

	if wave_manager.wave_spawn_queue.is_empty():
		wave_spawn_timer.stop()

func _on_wave_hero_reached_goal(hero: HeroGrid, escape_damage: int) -> void:
	print(hero.name, " reached chest")
	board.register_escape()
	lose_life(escape_damage)
	wave_manager.remove_active_hero(hero)
	update_camera_follow_target()
	update_connection_status()
	update_round_ui()
	check_wave_finished()

func _on_wave_hero_died(hero: HeroGrid, gold_reward: int) -> void:
	print(hero.name, " died")
	gain_gold(gold_reward)
	wave_manager.remove_active_hero(hero)
	update_camera_follow_target()
	update_connection_status()
	update_round_ui()
	check_wave_finished()

func check_wave_finished() -> void:
	if run_manager.game_over:
		return
	if not wave_manager.is_wave_finished():
		return

	wave_manager.finish_wave()

	var clear_bonus: int = wave_manager.get_wave_clear_bonus_for(wave_manager.wave_number)
	gain_gold(clear_bonus)

	print("Wave ", wave_manager.wave_number, " finished | clear bonus=", clear_bonus)

	update_build_run_ui()
	update_connection_status()
	update_shop_afford_visuals()
	update_shop_card_texts()
	update_shop_visibility()
	update_round_ui()

func update_build_run_ui() -> void:
	shop_bar.visible = not wave_manager.wave_running and not run_manager.game_over
	game_over_panel.visible = run_manager.game_over
	start_round_button.visible = not wave_manager.wave_running and not run_manager.game_over
	start_round_button.disabled = not can_start_wave()

	if run_manager.game_over:
		hint_label.text = "Game Over"
	elif wave_manager.wave_running:
		hint_label.text = "Run phase: shop hidden | hold Space to follow first enemy | camera free otherwise"
	else:
		hint_label.text = "Build: drag from shop/board | same room+level merges | RMB sell | Click Start Round"

func _on_card_gui_input(event: InputEvent, tile_type: String) -> void:
	if run_manager.game_over:
		return
	if wave_manager.wave_running:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not wave_manager.is_room_unlocked_for_build(tile_type):
				print(tile_type, " unlocks on round ", wave_manager.get_room_unlock_round(tile_type))
				return

			if not run_manager.can_afford_room(tile_type):
				print("Not enough gold for ", tile_type)
				return

			start_drag(tile_type, 1, false, Vector2i(-999, -999))

func start_drag(tile_type: String, tile_level: int, from_board: bool, origin_cell: Vector2i) -> void:
	if run_manager.game_over:
		return
	if wave_manager.wave_running:
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
	if wave_manager.wave_running:
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
	if wave_manager.wave_running:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)
	var existing_type: String = board.get_tile_type(cell)
	var existing_level: int = board.get_tile_level(cell)

	if existing_type == "":
		return

	var removed: bool = board.remove_tile(cell)
	if removed:
		var refund: int = run_manager.sell_refund(existing_type, existing_level)
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

	if (not dragged_from_board) and (not run_manager.can_afford_room(dragged_tile_type)):
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
		var buy_cost: int = run_manager.room_cost(dragged_tile_type)
		if run_manager.gold < buy_cost:
			print("Not enough gold to place ", dragged_tile_type)
			return false

	if board.can_place_tile(dragged_tile_type, cell):
		var placed: bool = board.place_tile(dragged_tile_type, cell, dragged_tile_level)
		if placed:
			if not dragged_from_board:
				spend_gold(run_manager.room_cost(dragged_tile_type))
			print("Placed ", dragged_tile_type, " L", dragged_tile_level, " at ", cell)
			update_shop_afford_visuals()
			return true

	if board.can_merge_tile(dragged_tile_type, dragged_tile_level, cell):
		var new_level: int = board.merge_tile(dragged_tile_type, dragged_tile_level, cell)
		if new_level > 0:
			if not dragged_from_board:
				spend_gold(run_manager.room_cost(dragged_tile_type))
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
	var unlocked: bool = wave_manager.is_room_unlocked_for_build(tile_type)
	var affordable: bool = run_manager.can_afford_room(tile_type)

	if wave_manager.wave_running or run_manager.game_over:
		card.modulate = Color(0.65, 0.65, 0.65, 1.0)
		return

	if not unlocked:
		card.modulate = Color(0.42, 0.42, 0.52, 1.0)
		return

	if affordable:
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		card.modulate = Color(0.65, 0.45, 0.45, 1.0)

func update_shop_card_texts() -> void:
	update_card_label_text(corridor_card_label, "Corridor", 0, "corridor")
	update_card_label_text(bat_card_label, "Bat Room", 20, "bat")
	update_card_label_text(spike_card_label, "Spike Room", 10, "spike")
	update_card_label_text(boss_card_label, "Boss Room", 40, "boss")

func update_card_label_text(label_node: Label, display_name: String, cost: int, tile_type: String) -> void:
	if wave_manager.is_room_unlocked_for_build(tile_type):
		label_node.text = "%s\n$%d" % [display_name, cost]
	else:
		var unlock_round: int = wave_manager.get_room_unlock_round(tile_type)
		label_node.text = "%s\n$%d\nUnlock R%d" % [display_name, cost, unlock_round]

func update_shop_visibility() -> void:
	corridor_card.visible = wave_manager.is_room_unlocked_for_build("corridor")
	bat_card.visible = wave_manager.is_room_unlocked_for_build("bat")
	spike_card.visible = wave_manager.is_room_unlocked_for_build("spike")
	boss_card.visible = wave_manager.is_room_unlocked_for_build("boss")

func update_connection_status() -> void:
	if run_manager.game_over:
		status_label.text = "Game Over"
		status_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		return

	if wave_manager.wave_running:
		status_label.text = "Wave %d running | To spawn: %d | Alive: %d" % [
			wave_manager.wave_number,
			wave_manager.heroes_to_spawn,
			wave_manager.active_heroes.size()
		]
		status_label.modulate = Color(0.9, 0.9, 1.0, 1.0)
		return

	var connected: bool = board.has_valid_connection()

	if connected:
		status_label.text = "Path: Connected"
		status_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		status_label.text = "Path: Not connected"
		status_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

	if not run_manager.game_over and not wave_manager.wave_running:
		start_round_button.disabled = not can_start_wave()

func show_game_over_summary() -> void:
	var lines: PackedStringArray = board.get_room_stats_summary_lines()
	var full_text: String = ""

	for i in range(lines.size()):
		full_text += lines[i]
		if i < lines.size() - 1:
			full_text += "\n"

	game_over_summary_label.text = full_text
	game_over_panel.visible = true

func update_camera_follow_target() -> void:
	if wave_manager.active_heroes.is_empty():
		camera_controller.clear_follow_target()
		return

	for hero in wave_manager.active_heroes:
		if hero != null and is_instance_valid(hero):
			camera_controller.set_follow_target(hero)
			return

	camera_controller.clear_follow_target()

func _on_restart_button_pressed() -> void:
	restart_run()

func restart_run() -> void:
	cleanup_active_heroes()
	camera_controller.clear_follow_target()

	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	dragged_tile_type = ""
	dragged_tile_level = 1
	dragged_from_board = false
	drag_origin_cell = Vector2i(-999, -999)

	run_manager.reset_for_new_run()

	wave_spawn_timer.stop()
	wave_manager.reset_for_new_run()

	board.reset_board_for_new_run()

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_afford_visuals()
	update_shop_card_texts()
	update_shop_visibility()
	update_round_ui()

	print("Run restarted")

func cleanup_active_heroes() -> void:
	for hero in wave_manager.active_heroes:
		if is_instance_valid(hero):
			hero.queue_free()

	wave_manager.active_heroes.clear()
