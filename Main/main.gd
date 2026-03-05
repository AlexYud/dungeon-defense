extends Node2D

@export var hero_scene: PackedScene
@export var bat_room_scene: PackedScene
@export var slow_room_scene: PackedScene

@export var kill_reward: int = 10
@export var heroes_per_wave: int = 3
@export var grid_size: int = 64

@export var bat_room_cost: int = 20
@export var slow_room_cost: int = 15

@export var dungeon_hp_max: int = 5

@onready var start: Marker2D = $Start
@onready var corridor_path: Path2D = $CorridorPath
@onready var bat_room: Node2D = $BatRoom
@onready var gold_label: Label = $UI/GoldLabel
@onready var hp_label: Label = $UI/HPLabel
@onready var spawn_timer: Timer = $SpawnTimer

var gold: int = 0
var dungeon_hp: int = 5
var game_over: bool = false

var current_wave: int = 0
var heroes_to_spawn: int = 0
var heroes_alive: int = 0
var path_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	dungeon_hp = dungeon_hp_max
	update_ui()
	build_path()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func is_build_phase() -> bool:
	return (not game_over) and heroes_alive == 0 and heroes_to_spawn == 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_build_phase():
			start_wave()

func _unhandled_input(event: InputEvent) -> void:
	if not is_build_phase():
		return

	# Move starter BatRoom with left click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		bat_room.global_position = snap_to_grid(mouse_pos)
		print("Starter BatRoom moved to: ", bat_room.global_position)

	# Buy/place a NEW BatRoom with key B
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		try_buy_place_bat_room()

	# Buy/place a NEW SlowRoom with key S
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		try_buy_place_slow_room()

func try_buy_place_bat_room() -> void:
	if gold < bat_room_cost:
		print("Not enough gold for BatRoom. Need ", bat_room_cost, " (have ", gold, ")")
		return

	if bat_room_scene == null:
		bat_room_scene = load("res://BatRoom/BatRoom.tscn")

	if bat_room_scene == null:
		push_error("bat_room_scene is null and failed to load BatRoom.tscn")
		return

	var new_room = bat_room_scene.instantiate()
	add_child(new_room)
	new_room.global_position = snap_to_grid(get_global_mouse_position())

	gold -= bat_room_cost
	update_ui()

	print("Bought BatRoom for ", bat_room_cost, ". Gold now: ", gold)

func try_buy_place_slow_room() -> void:
	if gold < slow_room_cost:
		print("Not enough gold for SlowRoom. Need ", slow_room_cost, " (have ", gold, ")")
		return

	if slow_room_scene == null:
		slow_room_scene = load("res://SlowRoom/SlowRoom.tscn")

	if slow_room_scene == null:
		push_error("slow_room_scene is null and failed to load SlowRoom.tscn")
		return

	var new_room = slow_room_scene.instantiate()
	add_child(new_room)
	new_room.global_position = snap_to_grid(get_global_mouse_position())

	gold -= slow_room_cost
	update_ui()

	print("Bought SlowRoom for ", slow_room_cost, ". Gold now: ", gold)

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
		hero_scene = load("res://Hero/Hero.tscn")

	var hero = hero_scene.instantiate()
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
	print("Hero escaped! HP now: ", dungeon_hp)

	if dungeon_hp <= 0:
		game_over = true
		spawn_timer.stop()
		print("GAME OVER. (HP reached 0)")
		return

	check_wave_finished()

func check_wave_finished() -> void:
	if is_build_phase():
		print("Wave %d finished. Click to move starter. Press B to buy BatRoom. Press S to buy SlowRoom. Press Space for next wave." % current_wave)

func update_ui() -> void:
	gold_label.text = "Gold: %d" % gold
	hp_label.text = "HP: %d" % dungeon_hp
