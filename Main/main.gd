extends Node2D

const BAT_ROOM_PATH: String = "res://BatRoom/BatRoom.tscn"
const SLOW_ROOM_PATH: String = "res://SlowRoom/SlowRoom.tscn"
const GHOST_ROOM_PATH: String = "res://GhostRoom/GhostRoom.tscn"

@export var hero_scene: PackedScene
@export var bat_room_scene: PackedScene
@export var slow_room_scene: PackedScene
@export var ghost_room_scene: PackedScene

@export var kill_reward: int = 10
@export var heroes_per_wave: int = 3
@export var grid_size: int = 64
@export var dungeon_hp_max: int = 5

@export var bat_room_cost: int = 20
@export var slow_room_cost: int = 15

@onready var start: Marker2D = $Start
@onready var corridor_path: Path2D = $CorridorPath
@onready var bat_room: Node2D = $BatRoom
@onready var gold_label: Label = $UI/GoldLabel
@onready var hp_label: Label = $UI/HPLabel
@onready var spawn_timer: Timer = $SpawnTimer
@onready var shop_btns: Array[Button] = [
	$UI/ShopBar/ShopRow/ShopBtn1,
	$UI/ShopBar/ShopRow/ShopBtn2,
	$UI/ShopBar/ShopRow/ShopBtn3
]

var gold: int = 0
var dungeon_hp: int = 5
var game_over: bool = false

var current_wave: int = 0
var heroes_to_spawn: int = 0
var heroes_alive: int = 0
var path_points: PackedVector2Array = PackedVector2Array()

# Shop logic
var shop_offers: Array[Dictionary] = []
var selected_offer_index: int = -1

# Drag state
var is_dragging: bool = false
var dragging_offer: Dictionary = {}
var drag_preview: Node2D = null

func _ready() -> void:
	randomize()
	dungeon_hp = dungeon_hp_max
	update_ui()
	build_path()

	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	for i in range(shop_btns.size()):
		var idx := i
		shop_btns[i].pressed.connect(func(): _on_shop_pressed(idx))

	roll_shop()
	update_shop_ui()

func is_build_phase() -> bool:
	return not game_over and heroes_alive == 0 and heroes_to_spawn == 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and is_build_phase():
		start_wave()

func _unhandled_input(event: InputEvent) -> void:
	if not is_build_phase():
		return

	if is_dragging:
		if drag_preview:
			drag_preview.global_position = snap_to_grid(get_global_mouse_position())

		if event is InputEventMouseButton and (not event.pressed) and event.button_index == MOUSE_BUTTON_LEFT:
			# Drop the dragged room
			try_place_dragged_room()
			end_drag()
		return

func _process(_delta):
	if is_dragging and drag_preview:
		drag_preview.global_position = snap_to_grid(get_global_mouse_position())

func _on_shop_pressed(index: int) -> void:
	if not is_build_phase():
		return

	if is_dragging:
		return # prevent double-click during drag

	selected_offer_index = index
	dragging_offer = shop_offers[index]
	is_dragging = true

	if ghost_room_scene == null:
		ghost_room_scene = load(GHOST_ROOM_PATH)

	drag_preview = ghost_room_scene.instantiate()
	add_child(drag_preview)

	update_shop_ui()
	print("Dragging: ", dragging_offer)

func try_place_dragged_room() -> void:
	if dragging_offer.is_empty():
		return

	var id: String = str(dragging_offer.get("id", ""))
	var cost: int = int(dragging_offer.get("cost", 9999))

	if gold < cost:
		print("Not enough gold to place ", id, " need ", cost, " have ", gold)
		return

	var room_scene: PackedScene = null

	match id:
		"bat":
			if bat_room_scene == null:
				bat_room_scene = load(BAT_ROOM_PATH)
			room_scene = bat_room_scene

		"slow":
			if slow_room_scene == null:
				slow_room_scene = load(SLOW_ROOM_PATH)
			room_scene = slow_room_scene

		_:
			print("Unknown room ID:", id)
			return

	if room_scene == null:
		push_error("Failed to load room scene for id=%s" % id)
		return

	var placed: Node2D = room_scene.instantiate()
	add_child(placed)
	placed.global_position = snap_to_grid(get_global_mouse_position())

	gold -= cost
	update_ui()
	print("Placed ", id, " for $", cost, " | gold now ", gold)

func end_drag() -> void:
	is_dragging = false
	dragging_offer = {}
	selected_offer_index = -1

	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

	update_shop_ui()

func roll_shop() -> void:
	shop_offers.clear()
	selected_offer_index = -1

	var pool: Array[Dictionary] = [
		{"id":"bat", "name":"Bat Room", "cost":bat_room_cost},
		{"id":"slow","name":"Slow Room","cost":slow_room_cost}
	]

	for _i in range(shop_btns.size()):
		var offer = pool[randi() % pool.size()].duplicate()
		shop_offers.append(offer)

func update_shop_ui() -> void:
	for i in range(shop_btns.size()):
		var btn: Button = shop_btns[i]
		var offer: Dictionary = shop_offers[i]

		var offer_name: String = str(offer.get("name", "???"))
		var cost: int = int(offer.get("cost", 0))

		btn.visible = not (is_dragging and i == selected_offer_index)

		var prefix: String = "[DRAG] " if (i == selected_offer_index and is_dragging) else ""
		btn.text = "%s%s ($%d)" % [prefix, offer_name, cost]

		btn.disabled = (not is_build_phase()) or is_dragging

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

func build_path() -> void:
	var baked := corridor_path.curve.get_baked_points()
	if baked.size() < 2:
		push_error("CorridorPath has no curve points.")
		return

	path_points.clear()
	for pt in baked:
		path_points.append(corridor_path.to_global(pt))

func start_wave() -> void:
	current_wave += 1
	heroes_to_spawn = heroes_per_wave
	heroes_alive = 0
	update_shop_ui()
	print("Wave %d started" % current_wave)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if heroes_to_spawn > 0:
		spawn_hero()
		heroes_to_spawn -= 1

	if heroes_to_spawn <= 0:
		spawn_timer.stop()

func spawn_hero() -> void:
	if hero_scene == null:
		hero_scene = load("res://Hero/Hero.tscn") # your folder path
		if hero_scene == null:
			push_error("Failed to load hero scene at res://Hero/Hero.tscn")
			return

	var hero: Node2D = hero_scene.instantiate()
	add_child(hero)

	hero.global_position = start.global_position
	hero.set_path(path_points)

	heroes_alive += 1
	hero.died.connect(_on_hero_died)
	hero.reached_end.connect(_on_hero_reached_end)

func _on_hero_died() -> void:
	heroes_alive -= 1
	gold += kill_reward
	update_ui()
	check_wave_finished()

func _on_hero_reached_end() -> void:
	heroes_alive -= 1
	dungeon_hp -= 1
	update_ui()

	if dungeon_hp <= 0:
		game_over = true
		spawn_timer.stop()
		update_shop_ui()
		print("GAME OVER.")
		return

	check_wave_finished()

func check_wave_finished() -> void:
	if is_build_phase():
		roll_shop()
		update_shop_ui()

func update_ui() -> void:
	gold_label.text = "Gold: %d" % gold
	hp_label.text = "HP: %d" % dungeon_hp
