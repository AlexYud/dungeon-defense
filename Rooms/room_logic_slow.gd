class_name RoomLogicSlow
extends RoomLogicBase

func on_enter(_cell: Vector2i, level: int) -> bool:
	hero.statuses.apply_slow(
		hero.board_ref.slow_duration_for_level(level),
		hero.board_ref.slow_factor_for_level(level)
	)
	return false
