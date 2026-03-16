class_name RoomLogicSpike
extends RoomLogicBase

func on_enter(cell: Vector2i, _level: int) -> bool:
	var spike_damage: float = hero.board_ref.try_trigger_spike(cell)
	if spike_damage > 0.0:
		hero.statuses.apply_damage(spike_damage, cell, true)
		if hero.statuses.hp <= 0.0:
			return true

	return false
