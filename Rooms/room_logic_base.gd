class_name RoomLogicBase
extends RefCounted

var hero

func _init(new_hero) -> void:
	hero = new_hero

func on_enter(_cell: Vector2i, _level: int) -> bool:
	return false

func update_room(_cell: Vector2i, _level: int, _delta: float) -> bool:
	return false

func reset_tracking() -> void:
	pass
