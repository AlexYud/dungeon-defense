class_name RoomLogicGas
extends RoomLogicBase

func on_enter(cell: Vector2i, level: int) -> bool:
	hero.statuses.apply_poison(
		hero.board_ref.gas_poison_duration_for_level(level),
		hero.board_ref.gas_poison_dps_for_level(level),
		cell
	)
	return false
