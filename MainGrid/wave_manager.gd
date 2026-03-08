class_name WaveManager
extends RefCounted

var wave_running: bool = false
var wave_number: int = 0
var heroes_to_spawn: int = 0

var wave_spawn_queue: Array[String] = []
var active_heroes: Array[HeroGrid] = []

var spawn_interval: float = 0.28

# Gentler economy pacing
var wave_clear_bonus_base: int = 18
var wave_clear_bonus_growth_per_wave: int = 2

func reset_for_new_run() -> void:
	wave_running = false
	wave_number = 0
	heroes_to_spawn = 0
	wave_spawn_queue.clear()
	active_heroes.clear()

func get_next_round_number() -> int:
	return wave_number + 1

func get_room_unlock_round(tile_type: String) -> int:
	match tile_type:
		"corridor":
			return 1
		"bat":
			return 1
		"spike":
			return 4
		"boss":
			return 7
	return 999999

func is_room_unlocked(tile_type: String, round_number_value: int) -> bool:
	return round_number_value >= get_room_unlock_round(tile_type)

func is_room_unlocked_for_build(tile_type: String) -> bool:
	return is_room_unlocked(tile_type, get_next_round_number())

func get_enemy_unlock_round(enemy_type: String) -> int:
	match enemy_type:
		"recruit":
			return 1
		"rogue":
			return 4
		"knight":
			return 7
		"slayer":
			return 10
	return 999999

func is_enemy_unlocked(enemy_type: String, round_number_value: int) -> bool:
	return round_number_value >= get_enemy_unlock_round(enemy_type)

func _append_enemy(queue: Array[String], enemy_type: String, count: int) -> void:
	for _i in range(max(0, count)):
		queue.append(enemy_type)

func build_wave_spawn_queue(round_number_value: int) -> Array[String]:
	var queue: Array[String] = []

	# Tutorial pacing:
	# R1-3 teach Bat Room vs Recruit
	# R4-6 teach Spike Room vs Rogue
	# R7-9 teach Boss Room vs Knight
	match round_number_value:
		1:
			_append_enemy(queue, "recruit", 1)
		2:
			_append_enemy(queue, "recruit", 2)
		3:
			_append_enemy(queue, "recruit", 3)
		4:
			_append_enemy(queue, "recruit", 3)
			_append_enemy(queue, "rogue", 2)
		5:
			_append_enemy(queue, "recruit", 4)
			_append_enemy(queue, "rogue", 2)
		6:
			_append_enemy(queue, "recruit", 5)
			_append_enemy(queue, "rogue", 3)
		7:
			_append_enemy(queue, "recruit", 4)
			_append_enemy(queue, "rogue", 2)
			_append_enemy(queue, "knight", 1)
		8:
			_append_enemy(queue, "recruit", 5)
			_append_enemy(queue, "rogue", 2)
			_append_enemy(queue, "knight", 1)
		9:
			_append_enemy(queue, "recruit", 6)
			_append_enemy(queue, "rogue", 3)
			_append_enemy(queue, "knight", 2)
		_:
			var recruit_count: int = 7 + int(floor(float(max(0, round_number_value - 10)) * 1.5))
			var rogue_count: int = 3 + int(floor(float(max(0, round_number_value - 10)) / 2.0))
			var knight_count: int = 2 + int(floor(float(max(0, round_number_value - 10)) / 3.0))
			var slayer_count: int = 1 + int(floor(float(max(0, round_number_value - 10)) / 4.0))

			_append_enemy(queue, "recruit", recruit_count)
			_append_enemy(queue, "rogue", rogue_count)
			_append_enemy(queue, "knight", knight_count)
			_append_enemy(queue, "slayer", slayer_count)

	queue.shuffle()
	return queue

func count_enemy_type_in_queue(queue: Array[String], enemy_type: String) -> int:
	var total: int = 0
	for queued_type in queue:
		if queued_type == enemy_type:
			total += 1
	return total

func get_enemy_max_hp(enemy_type: String, round_number_value: int) -> float:
	match enemy_type:
		"recruit":
			if round_number_value <= 3:
				return 40.0 + 5.0 * float(round_number_value - 1) # 40 / 45 / 50
			return 55.0 + 4.0 * float(max(0, round_number_value - 4))

		"rogue":
			return 42.0 + 4.0 * float(max(0, round_number_value - 4))

		"knight":
			return 110.0 + 10.0 * float(max(0, round_number_value - 7))

		"slayer":
			return 80.0 + 8.0 * float(max(0, round_number_value - 10))

	return 55.0

func get_enemy_speed(enemy_type: String) -> float:
	match enemy_type:
		"recruit":
			return 280.0
		"knight":
			return 220.0
		"rogue":
			return 360.0
		"slayer":
			return 270.0

	return 260.0

func get_enemy_attack_dps(enemy_type: String, round_number_value: int) -> float:
	match enemy_type:
		"recruit":
			if round_number_value <= 3:
				return 16.0
			return 17.0 + 1.0 * float(max(0, round_number_value - 4))

		"rogue":
			return 24.0 + 1.5 * float(max(0, round_number_value - 4))

		"knight":
			return 18.0 + 1.25 * float(max(0, round_number_value - 7))

		"slayer":
			return 48.0 + 3.0 * float(max(0, round_number_value - 10))

	return 18.0

func get_enemy_attack_vs_boss_dps(enemy_type: String, round_number_value: int) -> float:
	match enemy_type:
		"recruit":
			if round_number_value <= 3:
				return 10.0
			return 10.0 + 0.75 * float(max(0, round_number_value - 4))

		"rogue":
			return 16.0 + 1.0 * float(max(0, round_number_value - 4))

		"knight":
			return 16.0 + 1.0 * float(max(0, round_number_value - 7))

		"slayer":
			return 65.0 + 4.0 * float(max(0, round_number_value - 10))

	return 10.0

func get_enemy_gold_reward(enemy_type: String) -> int:
	match enemy_type:
		"recruit":
			return 4
		"knight":
			return 8
		"rogue":
			return 5
		"slayer":
			return 10

	return 4

func get_enemy_escape_damage(enemy_type: String) -> int:
	match enemy_type:
		"recruit":
			return 1
		"knight":
			return 2
		"rogue":
			return 1
		"slayer":
			return 2

	return 1

func get_enemy_tint(enemy_type: String) -> Color:
	match enemy_type:
		"recruit":
			return Color(0.70, 0.85, 1.00, 1.0)
		"knight":
			return Color(0.75, 0.78, 0.84, 1.0)
		"rogue":
			return Color(0.55, 0.95, 0.65, 1.0)
		"slayer":
			return Color(1.00, 0.70, 0.35, 1.0)

	return Color(1.0, 1.0, 1.0, 1.0)

func get_enemy_visual_scale(enemy_type: String) -> float:
	match enemy_type:
		"recruit":
			return 0.11
		"knight":
			return 0.15
		"rogue":
			return 0.10
		"slayer":
			return 0.14

	return 0.12

func get_wave_clear_bonus_for(round_number_value: int) -> int:
	match round_number_value:
		1:
			return 20
		2:
			return 18
		3:
			return 18
		4:
			return 16
		5:
			return 16
		6:
			return 16
		_:
			return wave_clear_bonus_base + wave_clear_bonus_growth_per_wave * max(0, round_number_value - 7)

func get_preview_counts(round_number_value: int) -> Dictionary:
	var preview_queue: Array[String] = build_wave_spawn_queue(round_number_value)

	return {
		"recruit": count_enemy_type_in_queue(preview_queue, "recruit"),
		"knight": count_enemy_type_in_queue(preview_queue, "knight"),
		"rogue": count_enemy_type_in_queue(preview_queue, "rogue"),
		"slayer": count_enemy_type_in_queue(preview_queue, "slayer")
	}

func get_unlock_preview_text(round_number_value: int) -> String:
	if round_number_value == 4:
		return " | New: Spike + Rogue"
	if round_number_value == 7:
		return " | New: Boss + Knight"
	if round_number_value == 10:
		return " | New: Slayer"
	return ""

func get_round_label_text(game_over: bool) -> String:
	if game_over:
		return "Round: %d" % wave_number

	if wave_running:
		return "Round %d | Queue: %d | Alive: %d" % [wave_number, heroes_to_spawn, active_heroes.size()]

	var next_round: int = get_next_round_number()
	var preview: Dictionary = get_preview_counts(next_round)

	return "Next R%d | Rec:%d Knt:%d Rog:%d Sly:%d%s" % [
		next_round,
		int(preview.get("recruit", 0)),
		int(preview.get("knight", 0)),
		int(preview.get("rogue", 0)),
		int(preview.get("slayer", 0)),
		get_unlock_preview_text(next_round)
	]

func start_wave(board: Node2D) -> void:
	board.reset_for_new_wave()

	wave_running = true
	wave_number += 1
	wave_spawn_queue = build_wave_spawn_queue(wave_number)
	heroes_to_spawn = wave_spawn_queue.size()

func spawn_next_enemy(board: Node2D, hero_scene: PackedScene, hero_parent: Node) -> Dictionary:
	if wave_spawn_queue.is_empty():
		heroes_to_spawn = 0
		return {"hero": null, "enemy_type": ""}

	var enemy_type: String = str(wave_spawn_queue[0])
	wave_spawn_queue.remove_at(0)
	heroes_to_spawn = wave_spawn_queue.size()

	board.path_hero_attack_dps = get_enemy_attack_dps(enemy_type, wave_number)
	board.path_hero_attack_vs_boss_dps = get_enemy_attack_vs_boss_dps(enemy_type, wave_number)

	var points: Array[Vector2] = board.get_path_world_points()
	if points.is_empty():
		return {"hero": null, "enemy_type": enemy_type}

	var hero_instance: HeroGrid = hero_scene.instantiate() as HeroGrid
	active_heroes.append(hero_instance)

	hero_parent.add_child(hero_instance)

	hero_instance.configure_enemy(
		enemy_type,
		get_enemy_max_hp(enemy_type, wave_number),
		get_enemy_speed(enemy_type),
		get_enemy_attack_dps(enemy_type, wave_number),
		get_enemy_attack_vs_boss_dps(enemy_type, wave_number),
		get_enemy_tint(enemy_type),
		get_enemy_visual_scale(enemy_type)
	)

	hero_instance.set_board_ref(board)
	hero_instance.set_path(points)

	return {"hero": hero_instance, "enemy_type": enemy_type}

func remove_active_hero(hero: HeroGrid) -> void:
	var index: int = active_heroes.find(hero)
	if index >= 0:
		active_heroes.remove_at(index)

func is_wave_finished() -> bool:
	return heroes_to_spawn <= 0 and active_heroes.is_empty() and wave_spawn_queue.is_empty()

func finish_wave() -> void:
	wave_running = false
