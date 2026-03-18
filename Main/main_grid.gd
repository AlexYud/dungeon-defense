extends Node2D

const HERO_GRID_PATH: String = "res://Hero/HeroGrid.tscn"
const LEVEL_BUTTON_PULSE_DURATION: float = 0.28

@onready var board: Node2D = $Board
@onready var camera_controller = $Camera2D
@onready var ui_root: Node = $UI

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

@onready var level_button: Button = $UI/ShopBar/ShopRow/LevelButton
@onready var rotate_button: Button = $UI/ShopBar/ShopRow/RotateButton

@onready var corridor_card: PanelContainer = $UI/ShopBar/ShopRow/CorridorCard
@onready var corridor_card_label: Label = $UI/ShopBar/ShopRow/CorridorCard/Label

@onready var offer1_card: PanelContainer = $UI/ShopBar/ShopRow/BatCard
@onready var offer1_label: Label = $UI/ShopBar/ShopRow/BatCard/Label

@onready var offer2_card: PanelContainer = $UI/ShopBar/ShopRow/SpikeCard
@onready var offer2_label: Label = $UI/ShopBar/ShopRow/SpikeCard/Label

@onready var offer3_card: PanelContainer = $UI/ShopBar/ShopRow/BossCard
@onready var offer3_label: Label = $UI/ShopBar/ShopRow/BossCard/Label

@export var starting_gold: int = 20000000000000
@export var starting_life: int = 10
@export var wave_clear_bonus_base: int = 18
@export var wave_clear_bonus_growth_per_wave: int = 2

var dragged_tile_type: String = ""
var dragged_tile_level: int = 1
var dragged_from_board: bool = false
var dragged_offer_slot: int = -1
var drag_origin_cell: Vector2i = Vector2i(-999, -999)
var drag_preview: ColorRect = null
var painting_corridor: bool = false
var painted_corridor_keys: Dictionary = {}

var hero_scene: PackedScene = null

var wave_manager: WaveManager = WaveManager.new()
var run_manager: RunManager = RunManager.new()
var shop_manager: ShopManager = ShopManager.new()

var current_game_speed: float = 1.0
var speed_panel: PanelContainer = null
var speed_buttons: Array[Button] = []

var level_button_pulse_time: float = 0.0

var bonus_card_panel: PanelContainer = null
var bonus_card_title_label: Label = null
var bonus_card_buttons: Array[Button] = []
var pending_bonus_choices: Array[String] = []
var awaiting_bonus_pick: bool = false

func _ready() -> void:
	hint_label.text = "Build: L-drag empty tiles = corridor brush | level up, buy offers, rotate shop"

	corridor_card.gui_input.connect(_on_corridor_card_gui_input)
	offer1_card.gui_input.connect(func(event: InputEvent): _on_offer_card_gui_input(event, 0))
	offer2_card.gui_input.connect(func(event: InputEvent): _on_offer_card_gui_input(event, 1))
	offer3_card.gui_input.connect(func(event: InputEvent): _on_offer_card_gui_input(event, 2))

	level_button.pressed.connect(_on_level_button_pressed)
	rotate_button.pressed.connect(_on_rotate_button_pressed)

	wave_spawn_timer.timeout.connect(_on_wave_spawn_timer_timeout)
	restart_button.pressed.connect(_on_restart_button_pressed)
	start_round_button.pressed.connect(_on_start_round_button_pressed)

	wave_manager.wave_clear_bonus_base = wave_clear_bonus_base
	wave_manager.wave_clear_bonus_growth_per_wave = wave_clear_bonus_growth_per_wave

	run_manager.configure(starting_gold, starting_life)
	run_manager.reset_for_new_run()

	shop_manager.reset_for_new_run()

	board.dungeon_level = shop_manager.dungeon_level
	board.set_run_bonus_modifiers(run_manager.get_active_bonus_modifiers())
	board.refresh_room_scaling()

	wave_spawn_timer.wait_time = wave_manager.spawn_interval
	camera_controller.follow_while_space_held = true

	game_over_panel.visible = false
	board.reset_run_stats()

	create_speed_controls()
	create_bonus_card_panel()
	set_game_speed(1.0)

	call_deferred("_refresh_ui_feedback_pivots")

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_ui()
	update_round_ui()
	update_bonus_card_panel()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	update_level_button_feedback(delta)

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
			update_shop_ui()

func _refresh_ui_feedback_pivots() -> void:
	level_button.pivot_offset = level_button.size * 0.5

func trigger_level_button_feedback() -> void:
	level_button_pulse_time = LEVEL_BUTTON_PULSE_DURATION
	level_button.pivot_offset = level_button.size * 0.5

func update_level_button_feedback(delta: float) -> void:
	if level_button_pulse_time > 0.0:
		level_button_pulse_time = max(0.0, level_button_pulse_time - delta)

		var progress: float = 1.0 - (level_button_pulse_time / LEVEL_BUTTON_PULSE_DURATION)
		var pulse: float = sin(progress * PI)
		var scale_boost: float = 0.08 * pulse

		level_button.scale = Vector2.ONE * (1.0 + scale_boost)
		level_button.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(
			Color(1.0, 0.95, 0.72, 1.0),
			0.80 * pulse
		)
	else:
		level_button.scale = level_button.scale.lerp(Vector2.ONE, min(1.0, 14.0 * delta))
		level_button.modulate = level_button.modulate.lerp(Color(1.0, 1.0, 1.0, 1.0), min(1.0, 14.0 * delta))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.keycode == KEY_1:
			set_game_speed(1.0)
			return
		elif key_event.keycode == KEY_2:
			set_game_speed(2.0)
			return
		elif key_event.keycode == KEY_3:
			set_game_speed(3.0)
			return

	if run_manager.game_over:
		return

	if awaiting_bonus_pick:
		return

	if event.is_action_pressed("ui_accept"):
		if can_start_wave():
			start_wave()
		return

	if wave_manager.wave_running:
		return

	if event is InputEventMouseMotion:
		if painting_corridor and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var paint_cell: Vector2i = board.world_to_cell(get_global_mouse_position())
			paint_corridor_at(paint_cell)
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if dragged_tile_type == "":
					var mouse_pos: Vector2 = get_global_mouse_position()
					var cell: Vector2i = board.world_to_cell(mouse_pos)

					if board.can_place_tile("corridor", cell):
						painting_corridor = true
						painted_corridor_keys.clear()
						paint_corridor_at(cell)
					else:
						try_pickup_board_tile()
			else:
				stop_painting_corridor()

		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if dragged_tile_type == "":
				try_sell_tile()

func corridor_paint_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func paint_corridor_at(cell: Vector2i) -> void:
	if awaiting_bonus_pick:
		return

	if not board.can_place_tile("corridor", cell):
		return

	var key: String = corridor_paint_key(cell)
	if painted_corridor_keys.has(key):
		return

	var placed: bool = board.place_tile("corridor", cell, 1)
	if placed:
		painted_corridor_keys[key] = true
		update_connection_status()

func stop_painting_corridor() -> void:
	painting_corridor = false
	painted_corridor_keys.clear()

func room_display_name(tile_type: String) -> String:
	if tile_type == "corridor":
		return "Corridor"
	if tile_type == "altar":
		return "Altar"
	if tile_type == "bat":
		return "Bat Room"
	if tile_type == "spike":
		return "Spike Room"
	if tile_type == "gas":
		return "Gas Room"
	if tile_type == "slow":
		return "Slow Room"
	if tile_type == "boss":
		return "Boss Room"
	return "Unknown"

func is_damage_room_for_support_feedback(tile_type: String) -> bool:
	if tile_type == "spike":
		return true
	if tile_type == "gas":
		return true
	if tile_type == "bat":
		return true
	if tile_type == "boss":
		return true
	return false

func create_speed_controls() -> void:
	if ui_root == null:
		return

	if speed_panel != null and is_instance_valid(speed_panel):
		return

	speed_panel = PanelContainer.new()
	speed_panel.name = "SpeedPanel"
	ui_root.add_child(speed_panel)

	speed_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	speed_panel.offset_left = -190.0
	speed_panel.offset_top = 12.0
	speed_panel.offset_right = -12.0
	speed_panel.offset_bottom = 58.0

	var row: HBoxContainer = HBoxContainer.new()
	speed_panel.add_child(row)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_top = 6.0
	row.offset_right = -8.0
	row.offset_bottom = -6.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)

	speed_buttons.clear()

	for speed_value in [1.0, 2.0, 3.0]:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(48.0, 0.0)
		button.set_meta("speed", speed_value)
		button.pressed.connect(_on_speed_button_pressed.bind(float(speed_value)))
		row.add_child(button)
		speed_buttons.append(button)

	update_speed_button_visuals()

func create_bonus_card_panel() -> void:
	if ui_root == null:
		return

	if bonus_card_panel != null and is_instance_valid(bonus_card_panel):
		return

	bonus_card_panel = PanelContainer.new()
	bonus_card_panel.name = "BonusCardPanel"
	ui_root.add_child(bonus_card_panel)

	bonus_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	bonus_card_panel.offset_left = -380.0
	bonus_card_panel.offset_top = -150.0
	bonus_card_panel.offset_right = 380.0
	bonus_card_panel.offset_bottom = 150.0
	bonus_card_panel.visible = false

	var root_vbox: VBoxContainer = VBoxContainer.new()
	bonus_card_panel.add_child(root_vbox)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 14.0
	root_vbox.offset_top = 14.0
	root_vbox.offset_right = -14.0
	root_vbox.offset_bottom = -14.0
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 10)

	bonus_card_title_label = Label.new()
	bonus_card_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_card_title_label.text = "Choose a bonus"
	root_vbox.add_child(bonus_card_title_label)

	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(card_row)

	bonus_card_buttons.clear()

	for i in range(3):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(220.0, 150.0)
		button.text = ""
		button.clip_text = false
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_bonus_card_button_pressed.bind(i))
		card_row.add_child(button)
		bonus_card_buttons.append(button)

func update_bonus_card_panel() -> void:
	if bonus_card_panel == null:
		return

	bonus_card_panel.visible = awaiting_bonus_pick and not run_manager.game_over

	if not bonus_card_panel.visible:
		return

	bonus_card_title_label.text = "Choose 1 bonus for Round %d" % wave_manager.get_next_round_number()

	for i in range(bonus_card_buttons.size()):
		var button: Button = bonus_card_buttons[i]

		if i < pending_bonus_choices.size():
			var card_id: String = pending_bonus_choices[i]
			button.visible = true
			button.disabled = false
			button.text = "%s\n\n%s" % [
				run_manager.get_bonus_card_title(card_id),
				run_manager.get_bonus_card_description(card_id)
			]
		else:
			button.visible = false

func present_bonus_card_choices() -> void:
	pending_bonus_choices = run_manager.roll_bonus_card_choices(3)
	awaiting_bonus_pick = not pending_bonus_choices.is_empty()
	update_bonus_card_panel()

func _on_bonus_card_button_pressed(choice_index: int) -> void:
	if not awaiting_bonus_pick:
		return
	if choice_index < 0 or choice_index >= pending_bonus_choices.size():
		return

	var chosen_card: String = pending_bonus_choices[choice_index]

	run_manager.apply_bonus_card(chosen_card)
	board.set_run_bonus_modifiers(run_manager.get_active_bonus_modifiers())
	board.refresh_room_scaling()

	awaiting_bonus_pick = false
	pending_bonus_choices.clear()
	update_bonus_card_panel()

	shop_manager.start_build_phase()
	board.trigger_bonus_card_pick_feedback(chosen_card)

	print("Picked bonus card: ", run_manager.get_bonus_card_title(chosen_card))

	update_build_run_ui()
	update_connection_status()
	update_shop_ui()
	update_round_ui()

func _on_speed_button_pressed(multiplier: float) -> void:
	set_game_speed(multiplier)

func set_game_speed(multiplier: float) -> void:
	current_game_speed = clamp(multiplier, 1.0, 3.0)
	Engine.time_scale = current_game_speed
	update_speed_button_visuals()
	update_connection_status()

func update_speed_button_visuals() -> void:
	for button in speed_buttons:
		if button == null or not is_instance_valid(button):
			continue

		var button_speed: float = float(button.get_meta("speed"))
		var is_active: bool = is_equal_approx(button_speed, current_game_speed)

		button.text = "%dx" % int(button_speed)
		if is_active:
			button.text += " ✓"
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.86, 0.86, 0.86, 1.0)

func get_speed_status_text() -> String:
	return " | Speed %dx" % int(current_game_speed)

func spend_gold(amount: int) -> void:
	run_manager.spend_gold(amount)
	update_gold_life_ui()
	update_shop_ui()

func gain_gold(amount: int) -> void:
	run_manager.gain_gold(amount)
	update_gold_life_ui()
	update_shop_ui()

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
	if awaiting_bonus_pick:
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

func _on_level_button_pressed() -> void:
	if run_manager.game_over or wave_manager.wave_running or awaiting_bonus_pick:
		return

	var cost: int = shop_manager.get_level_up_cost()
	if run_manager.gold < cost:
		print("Not enough gold to level up")
		return

	var old_dungeon_level: int = shop_manager.dungeon_level

	spend_gold(cost)

	var newly_unlocked_room: String = shop_manager.level_up()
	board.dungeon_level = shop_manager.dungeon_level
	board.refresh_room_scaling()
	board.trigger_level_up_feedback()
	board.trigger_dungeon_level_stat_popups(old_dungeon_level, shop_manager.dungeon_level)
	trigger_level_button_feedback()

	if newly_unlocked_room != "":
		print("Unlocked ", room_display_name(newly_unlocked_room))
		shop_manager.refill_offers()

	update_shop_ui()

func _on_rotate_button_pressed() -> void:
	if run_manager.game_over or wave_manager.wave_running or awaiting_bonus_pick:
		return

	var cost: int = shop_manager.get_rotate_cost()
	if run_manager.gold < cost:
		print("Not enough gold to rotate")
		return

	if cost > 0:
		spend_gold(cost)

	shop_manager.rotate_offers()
	update_shop_ui()

func _on_corridor_card_gui_input(event: InputEvent) -> void:
	if run_manager.game_over or wave_manager.wave_running or awaiting_bonus_pick:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			start_drag("corridor", 1, false, Vector2i(-999, -999), -1)

func _on_offer_card_gui_input(event: InputEvent, slot_index: int) -> void:
	if run_manager.game_over or wave_manager.wave_running or awaiting_bonus_pick:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var offered_type: String = shop_manager.get_offer(slot_index)
			if offered_type == "":
				return

			if not run_manager.can_afford_room(offered_type):
				print("Not enough gold for ", offered_type)
				return

			start_drag(offered_type, 1, false, Vector2i(-999, -999), slot_index)

func start_drag(tile_type: String, tile_level: int, from_board: bool, origin_cell: Vector2i, offer_slot: int) -> void:
	if run_manager.game_over:
		return
	if wave_manager.wave_running:
		return
	if awaiting_bonus_pick:
		return
	if dragged_tile_type != "":
		return

	dragged_tile_type = tile_type
	dragged_tile_level = tile_level
	dragged_from_board = from_board
	dragged_offer_slot = offer_slot
	drag_origin_cell = origin_cell

	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(float(board.tile_size), float(board.tile_size))
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)

	update_drag_preview()

func try_pickup_board_tile() -> void:
	if wave_manager.wave_running or awaiting_bonus_pick:
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
	start_drag(existing_type, existing_level, true, cell, -1)
	update_connection_status()

func try_sell_tile() -> void:
	if wave_manager.wave_running or awaiting_bonus_pick:
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

func update_drag_preview() -> void:
	if drag_preview == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)
	var snapped_pos: Vector2 = board.cell_to_world(cell)

	drag_preview.global_position = snapped_pos - drag_preview.size * 0.5

	if (not dragged_from_board) and dragged_offer_slot >= 0 and (not run_manager.can_afford_room(dragged_tile_type)):
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
	if tile_type == "altar":
		return Color(0.92, 0.78, 0.30, 0.55)
	if tile_type == "bat":
		return Color(0.75, 0.35, 0.75, 0.55)
	if tile_type == "spike":
		return Color(0.9, 0.35, 0.35, 0.55)
	if tile_type == "gas":
		return Color(0.35, 0.75, 0.35, 0.55)
	if tile_type == "slow":
		return Color(0.35, 0.65, 0.9, 0.55)
	if tile_type == "boss":
		return Color(0.45, 0.45, 0.45, 0.55)
	return Color(1.0, 1.0, 1.0, 0.55)

func try_drop_tile() -> bool:
	if dragged_tile_type == "":
		return false

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i = board.world_to_cell(mouse_pos)

	if not dragged_from_board and dragged_offer_slot >= 0:
		var buy_cost: int = run_manager.room_cost(dragged_tile_type)
		if run_manager.gold < buy_cost:
			print("Not enough gold to place ", dragged_tile_type)
			return false

	if board.can_place_tile(dragged_tile_type, cell):
		var placed: bool = board.place_tile(dragged_tile_type, cell, dragged_tile_level)
		if placed:
			if not dragged_from_board and dragged_offer_slot >= 0:
				spend_gold(run_manager.room_cost(dragged_tile_type))
				shop_manager.clear_offer(dragged_offer_slot)
				update_shop_ui()

			if dragged_tile_type == "altar":
				board.trigger_support_room_stat_popups(cell, 0, dragged_tile_level)
			elif is_damage_room_for_support_feedback(dragged_tile_type):
				board.trigger_room_support_gain_popup(cell)

			print("Placed ", dragged_tile_type, " L", dragged_tile_level, " at ", cell)
			return true

	if board.can_merge_tile(dragged_tile_type, dragged_tile_level, cell):
		var new_level: int = board.merge_tile(dragged_tile_type, dragged_tile_level, cell)
		if new_level > 0:
			if not dragged_from_board and dragged_offer_slot >= 0:
				spend_gold(run_manager.room_cost(dragged_tile_type))
				shop_manager.clear_offer(dragged_offer_slot)
				update_shop_ui()

			board.trigger_merge_feedback(cell)
			board.trigger_merge_stat_popup(cell, dragged_tile_type, dragged_tile_level, new_level)

			if dragged_tile_type == "altar":
				board.trigger_support_room_stat_popups(cell, dragged_tile_level, new_level)

			print("Merged ", dragged_tile_type, " L", dragged_tile_level, " -> L", new_level, " at ", cell)
			return true

	print("Invalid drop for ", dragged_tile_type, " L", dragged_tile_level, " at ", cell)
	return false

func end_drag() -> void:
	dragged_tile_type = ""
	dragged_tile_level = 1
	dragged_from_board = false
	dragged_offer_slot = -1
	drag_origin_cell = Vector2i(-999, -999)

	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

func update_shop_ui() -> void:
	update_level_button_text()
	update_rotate_button_text()
	update_corridor_card_ui()
	update_offer_card_ui(offer1_card, offer1_label, 0)
	update_offer_card_ui(offer2_card, offer2_label, 1)
	update_offer_card_ui(offer3_card, offer3_label, 2)
	update_shop_afford_visuals()
	update_shop_visibility()

func update_level_button_text() -> void:
	var level_cost: int = shop_manager.get_level_up_cost()
	level_button.text = "Dungeon Lv %d\nUp $%d" % [shop_manager.dungeon_level, level_cost]
	level_button.disabled = wave_manager.wave_running or run_manager.game_over or awaiting_bonus_pick or run_manager.gold < level_cost

func update_rotate_button_text() -> void:
	var rotate_cost: int = shop_manager.get_rotate_cost()
	if rotate_cost <= 0:
		rotate_button.text = "Rotate\nFree"
	else:
		rotate_button.text = "Rotate\n$%d" % rotate_cost

	rotate_button.disabled = wave_manager.wave_running or run_manager.game_over or awaiting_bonus_pick or run_manager.gold < rotate_cost

func update_corridor_card_ui() -> void:
	corridor_card_label.text = "Corridor\n$0"

func update_offer_card_ui(card: PanelContainer, label_node: Label, slot_index: int) -> void:
	var offer_type: String = shop_manager.get_offer(slot_index)

	if offer_type == "":
		label_node.text = ""
		return

	label_node.text = "%s\n$%d" % [room_display_name(offer_type), run_manager.room_cost(offer_type)]

func update_shop_visibility() -> void:
	corridor_card.visible = true
	offer1_card.visible = shop_manager.get_offer(0) != ""
	offer2_card.visible = shop_manager.get_offer(1) != ""
	offer3_card.visible = shop_manager.get_offer(2) != ""

func update_shop_afford_visuals() -> void:
	update_corridor_card_visual()
	update_offer_card_visual(offer1_card, shop_manager.get_offer(0))
	update_offer_card_visual(offer2_card, shop_manager.get_offer(1))
	update_offer_card_visual(offer3_card, shop_manager.get_offer(2))

func update_corridor_card_visual() -> void:
	if wave_manager.wave_running or run_manager.game_over or awaiting_bonus_pick:
		corridor_card.modulate = Color(0.65, 0.65, 0.65, 1.0)
	else:
		corridor_card.modulate = Color(1.0, 1.0, 1.0, 1.0)

func update_offer_card_visual(card: PanelContainer, offer_type: String) -> void:
	if offer_type == "":
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	if wave_manager.wave_running or run_manager.game_over or awaiting_bonus_pick:
		card.modulate = Color(0.65, 0.65, 0.65, 1.0)
		return

	if run_manager.can_afford_room(offer_type):
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		card.modulate = Color(0.65, 0.45, 0.45, 1.0)

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
		hero_instance.impact_feedback.connect(_on_hero_impact_feedback)

	update_connection_status()
	update_round_ui()

	if wave_manager.wave_spawn_queue.is_empty():
		wave_spawn_timer.stop()

func _on_hero_impact_feedback(_world_position: Vector2, strength: float, kind: String) -> void:
	if camera_controller == null:
		return

	if kind == "slam":
		if camera_controller.has_method("shake_slam"):
			camera_controller.shake_slam(strength)

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

	present_bonus_card_choices()

	print("Wave ", wave_manager.wave_number, " finished | clear bonus=", clear_bonus)

	update_build_run_ui()
	update_connection_status()
	update_shop_ui()
	update_round_ui()

func update_build_run_ui() -> void:
	var normal_build_phase: bool = not wave_manager.wave_running and not run_manager.game_over and not awaiting_bonus_pick

	shop_bar.visible = normal_build_phase
	game_over_panel.visible = run_manager.game_over
	start_round_button.visible = normal_build_phase
	start_round_button.disabled = not can_start_wave()

	if bonus_card_panel != null:
		bonus_card_panel.visible = awaiting_bonus_pick and not run_manager.game_over

	if run_manager.game_over:
		hint_label.text = "Game Over"
	elif wave_manager.wave_running:
		hint_label.text = "Run phase: shop hidden | hold Space to follow first enemy | use 1x / 2x / 3x top-right"
	elif awaiting_bonus_pick:
		hint_label.text = "Reward phase: choose 1 bonus card before building"
	else:
		hint_label.text = "Build: level up, buy offers, rotate shop, set speed, then start round"

func update_connection_status() -> void:
	if run_manager.game_over:
		status_label.text = "Game Over"
		status_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		return

	if wave_manager.wave_running:
		status_label.text = "Wave %d running | To spawn: %d | Alive: %d%s" % [
			wave_manager.wave_number,
			wave_manager.heroes_to_spawn,
			wave_manager.active_heroes.size(),
			get_speed_status_text()
		]
		status_label.modulate = Color(0.9, 0.9, 1.0, 1.0)
		return

	if awaiting_bonus_pick:
		status_label.text = "Choose a bonus card%s" % get_speed_status_text()
		status_label.modulate = Color(1.0, 0.92, 0.55, 1.0)
		return

	var connected: bool = board.has_valid_connection()

	if connected:
		status_label.text = "Path: Connected%s" % get_speed_status_text()
		status_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		status_label.text = "Path: Not connected%s" % get_speed_status_text()
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
	dragged_offer_slot = -1
	drag_origin_cell = Vector2i(-999, -999)

	run_manager.reset_for_new_run()
	shop_manager.reset_for_new_run()

	awaiting_bonus_pick = false
	pending_bonus_choices.clear()
	update_bonus_card_panel()

	wave_spawn_timer.stop()
	wave_manager.reset_for_new_run()

	board.dungeon_level = shop_manager.dungeon_level
	board.set_run_bonus_modifiers(run_manager.get_active_bonus_modifiers())
	board.reset_board_for_new_run()
	board.refresh_room_scaling()

	stop_painting_corridor()
	set_game_speed(1.0)

	level_button_pulse_time = 0.0
	level_button.scale = Vector2.ONE
	level_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	update_gold_life_ui()
	update_connection_status()
	update_build_run_ui()
	update_shop_ui()
	update_round_ui()

	print("Run restarted")

func cleanup_active_heroes() -> void:
	for hero in wave_manager.active_heroes:
		if is_instance_valid(hero):
			hero.queue_free()

	wave_manager.active_heroes.clear()
