class_name RoomLogicBoss
extends RoomLogicBase

var seen_slam_version: int = -1

func on_enter(cell: Vector2i, _level: int) -> bool:
	seen_slam_version = hero.board_ref.get_boss_slam_version(cell)
	return false

func update_room(cell: Vector2i, level: int, delta: float) -> bool:
	if hero.board_ref.is_tile_beaten(cell):
		hero.movement.reset_combat_motion()
		return false

	hero.board_ref.mark_boss_room_active(cell)
	hero.movement.move_to_room_center_or_wobble(delta)

	var boss_room_dps: float = hero.board_ref.boss_room_dps_for_level(level)
	hero.statuses.apply_damage(boss_room_dps * delta, cell)

	if hero.statuses.hp <= 0.0:
		return true

	var boss_cleared: bool = hero.board_ref.damage_boss_room(cell, hero.hero_attack_vs_boss_dps * delta)
	if boss_cleared:
		hero.movement.reset_combat_motion()
		return false

	var latest_slam_version: int = hero.board_ref.get_boss_slam_version(cell)
	if latest_slam_version > seen_slam_version:
		seen_slam_version = latest_slam_version
		hero.movement.start_knockback_one_room()
		return true

	return true

func reset_tracking() -> void:
	seen_slam_version = -1
