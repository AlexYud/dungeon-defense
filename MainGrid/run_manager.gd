class_name RunManager
extends RefCounted

var starting_gold: int = 100
var starting_life: int = 10

var gold: int = 0
var life: int = 0
var game_over: bool = false

func configure(new_starting_gold: int, new_starting_life: int) -> void:
	starting_gold = new_starting_gold
	starting_life = new_starting_life

func reset_for_new_run() -> void:
	gold = starting_gold
	life = starting_life
	game_over = false

func room_cost(tile_type: String) -> int:
	if tile_type == "corridor":
		return 0
	if tile_type == "bat":
		return 20
	if tile_type == "spike":
		return 10
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
