extends Node2D

@export var base_radius: float = 80.0
@export var base_slow_multiplier: float = 0.4 # smaller = stronger slow

var level: int = 1
var radius: float = 80.0
var slow_multiplier: float = 0.4

func _ready() -> void:
	if has_meta("level"):
		set_level(int(get_meta("level")))
	else:
		set_level(level)

func set_level(new_level: int) -> void:
	level = max(1, new_level)
	radius = base_radius + 10.0 * float(level - 1)

	# Stronger slow as level increases (clamped)
	slow_multiplier = base_slow_multiplier * pow(0.85, float(level - 1))
	slow_multiplier = max(0.15, slow_multiplier)

	scale = Vector2.ONE * (1.0 + 0.08 * float(level - 1))

func _physics_process(_delta: float) -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue
		if global_position.distance_to(hero.global_position) <= radius:
			if hero.has_method("apply_slow"):
				hero.apply_slow(slow_multiplier)
