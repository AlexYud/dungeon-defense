class_name RoomLogicBat
extends RoomLogicBase

func update_room(cell: Vector2i, level: int, delta: float) -> bool:
	if hero.board_ref.is_tile_beaten(cell):
		hero.movement.reset_combat_motion()
		return false

	hero.movement.move_to_room_center_or_wobble(delta)

	var bat_room_dps: float = hero.board_ref.bat_room_dps_for_level(level)
	if hero.statuses.bleed_time > 0.0:
		bat_room_dps *= 1.35

	hero.statuses.apply_damage(bat_room_dps * delta, cell)

	if hero.statuses.hp <= 0.0:
		return true

	var bat_cleared: bool = hero.board_ref.damage_bat_room(cell, hero.hero_attack_dps * delta)
	if bat_cleared:
		hero.movement.reset_combat_motion()
		return false

	return true
