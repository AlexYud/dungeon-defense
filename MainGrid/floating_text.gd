extends Node2D

@export var lifetime: float = 0.75
@export var rise_speed: float = 42.0
@export var grow_amount: float = 0.18

@onready var label: Label = $Label

var age: float = 0.0
var start_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	label.position = Vector2(-30.0, -12.0)
	label.size = Vector2(60.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func setup(new_text: String, new_color: Color) -> void:
	label.text = new_text
	label.modulate = new_color

func _process(delta: float) -> void:
	age += delta
	position.y -= rise_speed * delta

	var t: float = min(1.0, age / lifetime)
	var alpha: float = 1.0 - t
	label.modulate.a = alpha

	scale = start_scale * (1.0 + grow_amount * t)

	if age >= lifetime:
		queue_free()
