class_name ShopManager
extends RefCounted

var dungeon_level: int = 1
var rerolls_used_this_build: int = 0
var offer_slots: Array[String] = []

func reset_for_new_run() -> void:
	dungeon_level = 1
	start_build_phase()

func start_build_phase() -> void:
	rerolls_used_this_build = 0
	refill_offers()

func get_room_unlock_level(tile_type: String) -> int:
	match tile_type:
		"altar":
			return 1
		"bat":
			return 1
		"spike":
			return 5
		"gas":
			return 10
		"boss":
			return 15
		"slow":
			return 20
	return 999999

func is_room_unlocked(tile_type: String) -> bool:
	return dungeon_level >= get_room_unlock_level(tile_type)

func get_unlocked_room_pool() -> Array[String]:
	var pool: Array[String] = []

	if is_room_unlocked("altar"):
		pool.append("altar")
	if is_room_unlocked("bat"):
		pool.append("bat")
	if is_room_unlocked("spike"):
		pool.append("spike")
	if is_room_unlocked("gas"):
		pool.append("gas")
	if is_room_unlocked("boss"):
		pool.append("boss")
	if is_room_unlocked("slow"):
		pool.append("slow")

	return pool

func _random_room_from_pool(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

func refill_offers() -> void:
	var pool: Array[String] = get_unlocked_room_pool()
	var new_offers: Array[String] = []

	for _i in range(3):
		new_offers.append(_random_room_from_pool(pool))

	offer_slots = new_offers

func get_offer(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= offer_slots.size():
		return ""
	return offer_slots[slot_index]

func clear_offer(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= offer_slots.size():
		return
	offer_slots[slot_index] = ""

func get_rotate_cost() -> int:
	if rerolls_used_this_build == 0:
		return 0
	return int(pow(2.0, float(rerolls_used_this_build - 1)))

func rotate_offers() -> void:
	rerolls_used_this_build += 1
	refill_offers()

func get_level_up_cost() -> int:
	return 4 + dungeon_level * 4

func level_up() -> String:
	dungeon_level += 1

	if dungeon_level == 5:
		return "spike"
	if dungeon_level == 10:
		return "gas"
	if dungeon_level == 15:
		return "boss"
	if dungeon_level == 20:
		return "slow"

	return ""

func get_room_power_multiplier() -> float:
	return 1.0 + 0.06 * float(max(0, dungeon_level - 1))
