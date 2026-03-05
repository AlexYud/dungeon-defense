extends Node2D

@export var radius: float = 80.0
@export var slow_multiplier: float = 0.4

func _physics_process(_delta: float) -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue

		if global_position.distance_to(hero.global_position) <= radius:
			if hero.has_method("apply_slow"):
				hero.apply_slow(slow_multiplier)
