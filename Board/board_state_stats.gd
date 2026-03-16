class_name BoardStateStats
extends RefCounted

var state: BoardState

func _init(new_state: BoardState) -> void:
	state = new_state

func register_room_damage(cell: Vector2i, amount: float) -> void:
	if amount <= 0.0:
		return

	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return

	var current_damage: float = float(data.get("damage_dealt", 0.0))
	data["damage_dealt"] = current_damage + amount
	state.set_tile_data(cell, data)

func register_room_kill(cell: Vector2i) -> void:
	var data: Dictionary = state.get_tile_data(cell)
	if data.is_empty():
		return

	var current_kills: int = int(data.get("hero_kills", 0))
	data["hero_kills"] = current_kills + 1
	state.set_tile_data(cell, data)

	state.run_total_kills += 1

func register_escape() -> void:
	state.run_total_escapes += 1

func get_room_stats_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var totals: Dictionary = {
		"bat": {"damage": 0.0, "kills": 0},
		"spike": {"damage": 0.0, "kills": 0},
		"boss": {"damage": 0.0, "kills": 0},
		"gas": {"damage": 0.0, "kills": 0},
		"slow": {"damage": 0.0, "kills": 0}
	}

	for key_variant in state.placed_tiles.keys():
		var data: Dictionary = state.placed_tiles[key_variant] as Dictionary
		var room_type: String = str(data.get("type", ""))

		if room_type == "corridor":
			continue
		if not totals.has(room_type):
			continue

		var entry: Dictionary = totals[room_type] as Dictionary
		entry["damage"] = float(entry.get("damage", 0.0)) + float(data.get("damage_dealt", 0.0))
		entry["kills"] = int(entry.get("kills", 0)) + int(data.get("hero_kills", 0))
		totals[room_type] = entry

	var top_room_type: String = "None"
	var top_kills: int = -1

	for room_type in ["bat", "spike", "boss", "gas", "slow"]:
		var entry: Dictionary = totals[room_type] as Dictionary
		var room_kills: int = int(entry.get("kills", 0))
		if room_kills > top_kills:
			top_kills = room_kills
			top_room_type = room_type

	lines.append("Heroes killed: %d" % state.run_total_kills)
	lines.append("Heroes escaped: %d" % state.run_total_escapes)
	lines.append("Top killer room: %s" % state.room_type_display_name(top_room_type))
	lines.append("")
	lines.append("Room totals:")

	for room_type in ["bat", "spike", "boss", "gas", "slow"]:
		var entry: Dictionary = totals[room_type] as Dictionary
		lines.append(
			"%s | dmg %.0f | kills %d" % [
				state.room_type_display_name(room_type),
				float(entry.get("damage", 0.0)),
				int(entry.get("kills", 0))
			]
		)

	return lines

func reset_run_stats() -> void:
	state.run_total_kills = 0
	state.run_total_escapes = 0

	for key_variant in state.placed_tiles.keys():
		var key_str: String = str(key_variant)
		var data: Dictionary = state.placed_tiles[key_variant] as Dictionary
		data["damage_dealt"] = 0.0
		data["hero_kills"] = 0
		state.placed_tiles[key_str] = data
