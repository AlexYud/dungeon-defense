class_name RunManager
extends RefCounted

var starting_gold: int = 100
var starting_life: int = 10

var gold: int = 0
var life: int = 0
var game_over: bool = false

var active_bonus_modifiers: Dictionary = {}
var selected_bonus_cards: Array[String] = []

func configure(new_starting_gold: int, new_starting_life: int) -> void:
	starting_gold = new_starting_gold
	starting_life = new_starting_life

func reset_for_new_run() -> void:
	gold = starting_gold
	life = starting_life
	game_over = false

	active_bonus_modifiers = {
		"spike_damage_mult": 1.0,
		"gas_poison_dps_mult": 1.0,
		"gas_poison_duration_mult": 1.0,
		"slow_duration_mult": 1.0,
		"bat_room_dps_mult": 1.0,
		"boss_slam_interval_mult": 1.0,
		"altar_bonus_add": 0.0
	}

	selected_bonus_cards.clear()

func room_cost(tile_type: String) -> int:
	if tile_type == "corridor":
		return 0
	if tile_type == "altar":
		return 18
	if tile_type == "bat":
		return 20
	if tile_type == "spike":
		return 10
	if tile_type == "gas":
		return 12
	if tile_type == "slow":
		return 14
	if tile_type == "boss":
		return 40
	return 999999

func sell_refund(tile_type: String, tile_level: int) -> int:
	var base_cost: int = room_cost(tile_type)
	if base_cost <= 0:
		return 0

	var multiplier: int = 1
	if tile_level == 2:
		multiplier = 2
	elif tile_level >= 3:
		multiplier = 4

	var invested: int = base_cost * multiplier
	return int(floor(float(invested) * 0.5))

func can_afford_room(tile_type: String) -> bool:
	return gold >= room_cost(tile_type)

func spend_gold(amount: int) -> void:
	gold = max(0, gold - max(0, amount))

func gain_gold(amount: int) -> void:
	gold += max(0, amount)

func lose_life(amount: int) -> bool:
	life = max(0, life - max(0, amount))

	if life <= 0:
		game_over = true
		return true

	return false

func get_bonus_card_pool() -> Array[String]:
	return [
		"sharp_floors",
		"lingering_fog",
		"toxic_payload",
		"crippling_halls",
		"pack_hunt",
		"brutal_slam",
		"sanctified_pressure"
	]

func get_bonus_card_title(card_id: String) -> String:
	match card_id:
		"sharp_floors":
			return "Sharp Floors"
		"lingering_fog":
			return "Lingering Fog"
		"toxic_payload":
			return "Toxic Payload"
		"crippling_halls":
			return "Crippling Halls"
		"pack_hunt":
			return "Pack Hunt"
		"brutal_slam":
			return "Brutal Slam"
		"sanctified_pressure":
			return "Sanctified Pressure"
	return "Unknown Bonus"

func get_bonus_card_description(card_id: String) -> String:
	match card_id:
		"sharp_floors":
			return "Spike Rooms deal +20% damage."
		"lingering_fog":
			return "Gas poison lasts 40% longer."
		"toxic_payload":
			return "Gas poison deals +20% DPS."
		"crippling_halls":
			return "Slow duration +25%."
		"pack_hunt":
			return "Bat Room DPS +20%."
		"brutal_slam":
			return "Boss slam cooldown 12% faster."
		"sanctified_pressure":
			return "Altar grants +10% more damage."
	return "No description."

func roll_bonus_card_choices(count: int) -> Array[String]:
	var pool: Array[String] = get_bonus_card_pool()
	var available: Array[String] = []

	for card_id_variant in pool:
		var card_id: String = str(card_id_variant)
		if selected_bonus_cards.find(card_id) < 0:
			available.append(card_id)

	if available.size() < count:
		available = pool.duplicate()

	available.shuffle()

	var results: Array[String] = []
	while results.size() < count and not available.is_empty():
		var chosen: String = str(available.pop_back())
		if results.find(chosen) < 0:
			results.append(chosen)

	return results

func apply_bonus_card(card_id: String) -> void:
	if selected_bonus_cards.find(card_id) < 0:
		selected_bonus_cards.append(card_id)

	match card_id:
		"sharp_floors":
			active_bonus_modifiers["spike_damage_mult"] = float(active_bonus_modifiers.get("spike_damage_mult", 1.0)) * 1.20

		"lingering_fog":
			active_bonus_modifiers["gas_poison_duration_mult"] = float(active_bonus_modifiers.get("gas_poison_duration_mult", 1.0)) * 1.40

		"toxic_payload":
			active_bonus_modifiers["gas_poison_dps_mult"] = float(active_bonus_modifiers.get("gas_poison_dps_mult", 1.0)) * 1.20

		"crippling_halls":
			active_bonus_modifiers["slow_duration_mult"] = float(active_bonus_modifiers.get("slow_duration_mult", 1.0)) * 1.25

		"pack_hunt":
			active_bonus_modifiers["bat_room_dps_mult"] = float(active_bonus_modifiers.get("bat_room_dps_mult", 1.0)) * 1.20

		"brutal_slam":
			active_bonus_modifiers["boss_slam_interval_mult"] = float(active_bonus_modifiers.get("boss_slam_interval_mult", 1.0)) * 0.88

		"sanctified_pressure":
			active_bonus_modifiers["altar_bonus_add"] = float(active_bonus_modifiers.get("altar_bonus_add", 0.0)) + 0.10

func get_active_bonus_modifiers() -> Dictionary:
	return active_bonus_modifiers.duplicate(true)
