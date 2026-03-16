class_name RoomRegistry
extends RefCounted

static func create_handlers(hero) -> Dictionary:
	return {
		"spike": RoomLogicSpike.new(hero),
		"gas": RoomLogicGas.new(hero),
		"slow": RoomLogicSlow.new(hero),
		"bat": RoomLogicBat.new(hero),
		"boss": RoomLogicBoss.new(hero)
	}

static func reset_handlers(room_handlers: Dictionary) -> void:
	for handler in room_handlers.values():
		var room_handler: RoomLogicBase = handler as RoomLogicBase
		if room_handler != null:
			room_handler.reset_tracking()
