class_name BoardStateRuntime
extends RefCounted

var state: BoardState

func _init(new_state: BoardState) -> void:
	state = new_state

func get_boss_slam_version(cell: Vector2i) -> int:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return 0
	if str(data.get("type", "")) != "boss":
		return 0
	return int(data.get("boss_slam_version", 0))

func get_boss_slam_timer_left(cell: Vector2i) -> float:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "boss":
		return 0.0
	return float(data.get("boss_slam_timer", 0.0))

func mark_boss_room_active(cell: Vector2i) -> void:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return
	if str(data.get("type", "")) != "boss":
		return
	if bool(data.get("beaten", false)):
		return

	if not bool(data.get("boss_active_recently", false)):
		data["boss_active_recently"] = true
		state.set_tile_data(cell, data)

func update_room_timers(delta: float) -> bool:
	var changed: bool = false

	for key_variant in state.placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = state.placed_tiles[key_variant] as Dictionary
		var local_changed: bool = false

		var cooldown_left: float = float(data.get("cooldown_left", 0.0))
		if cooldown_left > 0.0:
			cooldown_left = max(0.0, cooldown_left - delta)
			data["cooldown_left"] = cooldown_left
			local_changed = true

		var clear_flash: float = float(data.get("clear_flash", 0.0))
		if clear_flash > 0.0:
			clear_flash = max(0.0, clear_flash - delta)
			data["clear_flash"] = clear_flash
			local_changed = true

		var tile_type: String = str(data.get("type", ""))
		if tile_type == "boss":
			var was_active: bool = bool(data.get("boss_active_recently", false))
			var beaten: bool = bool(data.get("beaten", false))

			if was_active and not beaten:
				var level: int = int(data.get("level", 1))
				var slam_timer: float = float(data.get("boss_slam_timer", state.boss_knockback_interval_for_level(level)))
				slam_timer = max(0.0, slam_timer - delta)

				if slam_timer <= 0.0:
					slam_timer = state.boss_knockback_interval_for_level(level)
					data["boss_slam_version"] = int(data.get("boss_slam_version", 0)) + 1
					data["clear_flash"] = max(float(data.get("clear_flash", 0.0)), 0.12)

				data["boss_slam_timer"] = slam_timer
				local_changed = true

			if was_active:
				data["boss_active_recently"] = false
				local_changed = true

		if local_changed:
			state.placed_tiles[key_str] = data
			changed = true

	return changed

func try_trigger_spike(cell: Vector2i) -> float:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return 0.0

	var tile_type: String = str(data.get("type", ""))
	if tile_type != "spike":
		return 0.0

	var cooldown_left: float = float(data.get("cooldown_left", 0.0))
	if cooldown_left > 0.0:
		return 0.0

	var damage: float = state.get_spike_damage_for_cell(cell)

	data["cooldown_left"] = 3.0
	state.set_tile_data(cell, data)

	return damage

func get_bat_room_hp(cell: Vector2i) -> float:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "bat":
		return 0.0
	return float(data.get("mob_hp", 0.0))

func damage_bat_room(cell: Vector2i, amount: float) -> Dictionary:
	var result: Dictionary = {"cleared": false, "changed": false}

	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return result
	if str(data.get("type", "")) != "bat":
		return result
	if bool(data.get("beaten", false)):
		result["cleared"] = true
		return result

	var level: int = int(data.get("level", 1))
	var hp: float = float(data.get("mob_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["mob_hp"] = hp
	result["changed"] = true

	if hp <= 0.0:
		data["mob_hp"] = 0.0
		data["mob_count"] = 0
		data["beaten"] = true
		data["clear_flash"] = 0.55
		state.set_tile_data(cell, data)
		result["cleared"] = true
		return result

	var total_hp: float = state.bat_room_total_hp_for_level(level)
	var total_bats: int = state.bat_count_for_level(level)
	var ratio: float = hp / max(1.0, total_hp)
	var remaining_bats: int = max(1, int(ceil(ratio * float(total_bats))))

	data["mob_count"] = remaining_bats
	state.set_tile_data(cell, data)
	return result

func get_boss_room_hp(cell: Vector2i) -> float:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return 0.0
	if str(data.get("type", "")) != "boss":
		return 0.0
	return float(data.get("boss_hp", 0.0))

func damage_boss_room(cell: Vector2i, amount: float) -> Dictionary:
	var result: Dictionary = {"cleared": false, "changed": false}

	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return result
	if str(data.get("type", "")) != "boss":
		return result
	if bool(data.get("beaten", false)):
		result["cleared"] = true
		return result

	var hp: float = float(data.get("boss_hp", 0.0))
	hp = max(0.0, hp - amount)
	data["boss_hp"] = hp
	result["changed"] = true

	if hp <= 0.0:
		data["boss_hp"] = 0.0
		data["beaten"] = true
		data["clear_flash"] = 0.55
		state.set_tile_data(cell, data)
		result["cleared"] = true
		return result

	state.set_tile_data(cell, data)
	return result
