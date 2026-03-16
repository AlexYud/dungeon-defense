class_name HeroRoomLogic
extends RefCounted

const INVALID_CELL: Vector2i = Vector2i(-999, -999)

var hero

var current_cell: Vector2i = INVALID_CELL
var current_tile_type: String = ""
var current_tile_level: int = 0

var room_handlers: Dictionary = {}

func _init(new_hero) -> void:
	hero = new_hero
	room_handlers = RoomRegistry.create_handlers(hero)

func clear_current_room_tracking() -> void:
	current_cell = INVALID_CELL
	current_tile_type = ""
	current_tile_level = 0

	RoomRegistry.reset_handlers(room_handlers)

func get_handler(tile_type: String) -> RoomLogicBase:
	return room_handlers.get(tile_type, null) as RoomLogicBase

func process_room_entry(cell: Vector2i) -> bool:
	current_cell = cell
	current_tile_type = hero.board_ref.get_tile_type(cell)
	current_tile_level = hero.board_ref.get_tile_level(cell)

	hero.movement.reset_combat_motion()

	var handler: RoomLogicBase = get_handler(current_tile_type)
	if handler == null:
		return false

	return handler.on_enter(cell, current_tile_level)

func update_room_effects(delta: float) -> bool:
	if hero.board_ref == null:
		return false

	var cell: Vector2i = hero.board_ref.world_to_cell(hero.global_position)

	if cell != current_cell:
		var died_on_entry: bool = process_room_entry(cell)
		if died_on_entry:
			return true

	var handler: RoomLogicBase = get_handler(current_tile_type)
	if handler == null:
		return false

	return handler.update_room(current_cell, current_tile_level, delta)
