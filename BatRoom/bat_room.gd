extends Node2D

@export var base_dps: float = 25.0
@export var base_radius: float = 80.0

var level: int = 1
var dps: float = 25.0
var radius: float = 80.0

func _ready() -> void:
	# If Main sets meta("level"), pick it up; otherwise keep level=1
	if has_meta("level"):
		set_level(int(get_meta("level")))
	else:
		set_level(level)

func set_level(new_level: int) -> void:
	level = max(1, new_level)
	dps = base_dps * pow(1.6, float(level - 1))
	radius = base_radius + 10.0 * float(level - 1)

	# Tiny visual cue (optional)
	scale = Vector2.ONE * (1.0 + 0.08 * float(level - 1))

func _physics_process(delta: float) -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue
		if global_position.distance_to(hero.global_position) <= radius:
			if hero.has_method("apply_damage"):
				hero.apply_damage(dps * delta)
