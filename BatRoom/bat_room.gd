extends Node2D

@export var dps: float = 25.0
@export var radius: float = 80.0

func _physics_process(delta: float) -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue

		if global_position.distance_to(hero.global_position) <= radius:
			if hero.has_method("apply_damage"):
				hero.apply_damage(dps * delta)
