extends Node2D

@export var lifetime: float = 0.80
@export var rise_speed: float = 48.0
@export var grow_amount: float = 0.24
@export var start_scale_multiplier: float = 0.82
@export var horizontal_drift_range: float = 28.0
@export var fade_start_ratio: float = 0.16

@onready var label: Label = $Label

var age: float = 0.0
var start_scale: Vector2 = Vector2.ONE
var base_color: Color = Color.WHITE
var drift_x: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	start_scale = scale
	rng.randomize()

	label.position = Vector2(-34.0, -14.0)
	label.size = Vector2(68.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	drift_x = rng.randf_range(-horizontal_drift_range, horizontal_drift_range)
	scale = start_scale * start_scale_multiplier

func setup(new_text: String, new_color: Color) -> void:
	label.text = new_text
	base_color = new_color
	label.modulate = new_color

func _process(delta: float) -> void:
	age += delta
	position.y -= rise_speed * delta
	position.x += drift_x * delta * 0.35

	var t: float = clamp(age / max(lifetime, 0.001), 0.0, 1.0)
	var fade_t: float = clamp((t - fade_start_ratio) / max(0.001, 1.0 - fade_start_ratio), 0.0, 1.0)
	var alpha: float = 1.0 - fade_t

	var punch_t: float = clamp(t / 0.28, 0.0, 1.0)
	var settle_scale: float = lerp(start_scale_multiplier, 1.0, clamp(t / 0.18, 0.0, 1.0))
	var punch_scale: float = sin(punch_t * PI) * grow_amount
	scale = start_scale * (settle_scale + punch_scale)

	label.modulate = base_color
	label.modulate.a = alpha

	if age >= lifetime:
		queue_free()
