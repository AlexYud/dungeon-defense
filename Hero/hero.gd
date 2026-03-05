extends CharacterBody2D

signal died
signal reached_end

@export var speed: float = 120.0
@export var max_hp: float = 50.0

var hp: float
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var speed_multiplier: float = 1.0

func _ready() -> void:
	hp = max_hp
	add_to_group("heroes")

func set_path(new_path: PackedVector2Array) -> void:
	path = new_path
	path_index = 0

func apply_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit()
		queue_free()

func apply_slow(multiplier: float) -> void:
	speed_multiplier = min(speed_multiplier, multiplier)

func _physics_process(_delta: float) -> void:
	if path.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		speed_multiplier = 1.0
		return

	if path_index >= path.size():
		reached_end.emit()
		queue_free()
		return

	var target: Vector2 = path[path_index]
	var to_target: Vector2 = target - global_position

	if to_target.length() < 4.0:
		path_index += 1
		speed_multiplier = 1.0
		return

	velocity = to_target.normalized() * speed * speed_multiplier
	move_and_slide()

	# reset every frame, so rooms must reapply their effect continuously
	speed_multiplier = 1.0
