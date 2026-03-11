class_name HeroGrid
extends Node2D

const FLOATING_TEXT_PATH: String = "res://MainGrid/FloatingText.tscn"

signal reached_goal
signal died

@export var move_speed: float = 260.0
@export var max_hp: float = 100.0
@export var hero_attack_dps: float = 45.0
@export var hero_attack_vs_boss_dps: float = 38.0
@export var damage_popup_interval: float = 0.22

@onready var sprite: Sprite2D = $Sprite2D

var board_ref: Node2D = null
var floating_text_scene: PackedScene = null

var hp: float = 100.0
var path_points: Array[Vector2] = []
var path_index: int = 0

var current_cell: Vector2i = Vector2i(-999, -999)
var current_tile_type: String = ""
var current_tile_level: int = 0
var last_damage_room_cell: Vector2i = Vector2i(-999, -999)

var pending_damage_popup: float = 0.0
var pending_damage_popup_timer: float = 0.0

# Future-ready for spike bleed card
var bleed_time: float = 0.0

# Persistent statuses
var poison_time: float = 0.0
var poison_dps: float = 0.0

var slow_time: float = 0.0
var slow_factor: float = 1.0

# Boss control
var boss_knockback_timer: float = 0.0

func _ready() -> void:
	hp = max_hp

func configure_enemy(
	enemy_name: String,
	new_max_hp: float,
	new_move_speed: float,
	new_attack_dps: float,
	new_attack_vs_boss_dps: float,
	tint: Color,
	visual_scale: float
) -> void:
	max_hp = new_max_hp
	hp = max_hp
	move_speed = new_move_speed
	hero_attack_dps = new_attack_dps
	hero_attack_vs_boss_dps = new_attack_vs_boss_dps

	sprite.modulate = tint
	sprite.scale = Vector2.ONE * visual_scale

	name = enemy_name.capitalize()

func set_board_ref(new_board: Node2D) -> void:
	board_ref = new_board

func set_path(points: Array[Vector2]) -> void:
	path_points = points
	path_index = 0

	if path_points.size() > 0:
		global_position = path_points[0]

func ensure_floating_text_scene() -> void:
	if floating_text_scene == null:
		floating_text_scene = load(FLOATING_TEXT_PATH)

func spawn_floating_text(text_value: String, color_value: Color, y_offset: float = -24.0) -> void:
	ensure_floating_text_scene()
	if floating_text_scene == null:
		return

	var popup: Node2D = floating_text_scene.instantiate() as Node2D
	if popup == null:
		return

	get_parent().add_child(popup)
	popup.global_position = global_position + Vector2(0.0, y_offset)

	if popup.has_method("setup"):
		popup.call("setup", text_value, color_value)

func flush_pending_damage_popup() -> void:
	if pending_damage_popup <= 0.0:
		return

	var shown_damage: int = maxi(1, int(round(pending_damage_popup)))
	spawn_floating_text(str(shown_damage), Color(1.0, 0.78, 0.78, 1.0))
	pending_damage_popup = 0.0
	pending_damage_popup_timer = damage_popup_interval

func queue_damage_popup(amount: float) -> void:
	if amount <= 0.0:
		return

	pending_damage_popup += amount
	if pending_damage_popup_timer <= 0.0:
		pending_damage_popup_timer = damage_popup_interval

func apply_damage(amount: float, source_cell: Vector2i = Vector2i(-999, -999), immediate_popup: bool = false) -> void:
	if amount <= 0.0:
		return

	hp -= amount

	if board_ref != null and source_cell.x > -900:
		board_ref.register_room_damage(source_cell, amount)
		last_damage_room_cell = source_cell

	if immediate_popup:
		var burst_value: int = maxi(1, int(round(amount)))
		spawn_floating_text(str(burst_value), Color(1.0, 0.90, 0.35, 1.0), -28.0)
	else:
		queue_damage_popup(amount)

	if hp <= 0.0:
		hp = 0.0
		flush_pending_damage_popup()
		spawn_floating_text("KO", Color(1.0, 0.55, 0.35, 1.0), -34.0)

		if board_ref != null and last_damage_room_cell.x > -900:
			board_ref.register_room_kill(last_damage_room_cell)

		died.emit()
		queue_free()

func apply_poison(duration: float, dps: float) -> void:
	poison_time = max(poison_time, duration)
	poison_dps = max(poison_dps, dps)

func apply_slow(duration: float, factor: float) -> void:
	slow_time = max(slow_time, duration)
	slow_factor = min(slow_factor, factor)

func update_status_timers(delta: float) -> void:
	if poison_time > 0.0:
		poison_time = max(0.0, poison_time - delta)
		apply_damage(poison_dps * delta)

		if poison_time <= 0.0:
			poison_dps = 0.0

	if slow_time > 0.0:
		slow_time = max(0.0, slow_time - delta)

		if slow_time <= 0.0:
			slow_factor = 1.0

	if bleed_time > 0.0:
		bleed_time = max(0.0, bleed_time - delta)

func get_current_move_speed() -> float:
	return move_speed * slow_factor

func knockback_one_room() -> void:
	if path_points.is_empty():
		return
	if path_index < 2:
		return

	path_index = max(1, path_index - 1)
	global_position = path_points[path_index - 1]

	current_cell = Vector2i(-999, -999)
	current_tile_type = ""
	current_tile_level = 0

	spawn_floating_text("SLAM", Color(1.0, 0.82, 0.45, 1.0), -30.0)

func _process(delta: float) -> void:
	if pending_damage_popup_timer > 0.0:
		pending_damage_popup_timer = max(0.0, pending_damage_popup_timer - delta)
		if pending_damage_popup_timer <= 0.0:
			flush_pending_damage_popup()

	update_status_timers(delta)

	if hp <= 0.0:
		return

	if path_points.is_empty():
		return

	var blocked_by_room: bool = update_room_effects(delta)

	if hp <= 0.0:
		return

	if blocked_by_room:
		return

	if path_index >= path_points.size():
		reached_goal.emit()
		queue_free()
		return

	var target: Vector2 = path_points[path_index]
	var to_target: Vector2 = target - global_position

	if to_target.length() < 4.0:
		path_index += 1
		return

	global_position += to_target.normalized() * get_current_move_speed() * delta

func update_room_effects(delta: float) -> bool:
	if board_ref == null:
		return false

	var cell: Vector2i = board_ref.world_to_cell(global_position)

	if cell != current_cell:
		current_cell = cell
		current_tile_type = board_ref.get_tile_type(cell)
		current_tile_level = board_ref.get_tile_level(cell)

		if current_tile_type == "spike":
			var spike_damage: float = board_ref.try_trigger_spike(cell)
			if spike_damage > 0.0:
				apply_damage(spike_damage, cell, true)
				if hp <= 0.0:
					return true

		elif current_tile_type == "gas":
			apply_poison(
				board_ref.gas_poison_duration_for_level(current_tile_level),
				board_ref.gas_poison_dps_for_level(current_tile_level)
			)

		elif current_tile_type == "slow":
			apply_slow(
				board_ref.slow_duration_for_level(current_tile_level),
				board_ref.slow_factor_for_level(current_tile_level)
			)

		elif current_tile_type == "boss":
			boss_knockback_timer = board_ref.boss_knockback_interval_for_level(current_tile_level)

	if current_tile_type == "bat":
		if not board_ref.is_tile_beaten(current_cell):
			var bat_room_dps: float = board_ref.bat_room_dps_for_level(current_tile_level)

			# Future-ready: if spike later applies bleed, bats become the payoff
			if bleed_time > 0.0:
				bat_room_dps *= 1.35

			apply_damage(bat_room_dps * delta, current_cell)

			if hp <= 0.0:
				return true

			var bat_cleared: bool = board_ref.damage_bat_room(current_cell, hero_attack_dps * delta)
			return not bat_cleared

	elif current_tile_type == "boss":
		if not board_ref.is_tile_beaten(current_cell):
			var boss_room_dps: float = board_ref.boss_room_dps_for_level(current_tile_level)
			apply_damage(boss_room_dps * delta, current_cell)

			if hp <= 0.0:
				return true

			var boss_cleared: bool = board_ref.damage_boss_room(current_cell, hero_attack_vs_boss_dps * delta)
			if boss_cleared:
				return false

			boss_knockback_timer -= delta
			if boss_knockback_timer <= 0.0:
				boss_knockback_timer = board_ref.boss_knockback_interval_for_level(current_tile_level)
				knockback_one_room()
				return true

			return true

	return false
