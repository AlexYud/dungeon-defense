class_name HeroStatuses
extends RefCounted

const FLOATING_TEXT_PATH: String = "res://UI/FloatingText.tscn"
const INVALID_CELL: Vector2i = Vector2i(-999, -999)

var hero
var floating_text_scene: PackedScene = null

var hp: float = 100.0

var pending_damage_popup: float = 0.0
var pending_damage_popup_timer: float = 0.0

var pending_poison_popup: float = 0.0
var pending_poison_popup_timer: float = 0.0

# Future-ready for spike bleed card
var bleed_time: float = 0.0

# Persistent statuses
var poison_time: float = 0.0
var poison_dps: float = 0.0
var poison_source_cell: Vector2i = INVALID_CELL

var slow_time: float = 0.0
var slow_factor: float = 1.0

var last_damage_room_cell: Vector2i = INVALID_CELL

func _init(new_hero) -> void:
	hero = new_hero

func ensure_floating_text_scene() -> void:
	if floating_text_scene == null:
		floating_text_scene = load(FLOATING_TEXT_PATH)

func spawn_floating_text(text_value: String, color_value: Color, y_offset: float = -24.0) -> void:
	ensure_floating_text_scene()
	if floating_text_scene == null:
		return
	if hero.get_parent() == null:
		return

	var popup: Node2D = floating_text_scene.instantiate() as Node2D
	if popup == null:
		return

	hero.get_parent().add_child(popup)
	popup.global_position = hero.global_position + Vector2(0.0, y_offset)

	if popup.has_method("setup"):
		popup.call("setup", text_value, color_value)

func flush_pending_damage_popup() -> void:
	if pending_damage_popup <= 0.0:
		return

	var shown_damage: int = maxi(1, int(round(pending_damage_popup)))
	spawn_floating_text(str(shown_damage), Color(1.0, 0.78, 0.78, 1.0))
	pending_damage_popup = 0.0
	pending_damage_popup_timer = hero.damage_popup_interval

func queue_damage_popup(amount: float) -> void:
	if amount <= 0.0:
		return

	pending_damage_popup += amount
	if pending_damage_popup_timer <= 0.0:
		pending_damage_popup_timer = hero.damage_popup_interval

func flush_pending_poison_popup() -> void:
	if pending_poison_popup <= 0.0:
		return

	var shown_damage: int = maxi(1, int(round(pending_poison_popup)))
	spawn_floating_text(str(shown_damage), Color(0.72, 1.0, 0.72, 1.0))
	pending_poison_popup = 0.0
	pending_poison_popup_timer = hero.damage_popup_interval

func queue_poison_popup(amount: float) -> void:
	if amount <= 0.0:
		return

	pending_poison_popup += amount
	if pending_poison_popup_timer <= 0.0:
		pending_poison_popup_timer = hero.damage_popup_interval

func update_popup_timers(delta: float) -> void:
	if pending_damage_popup_timer > 0.0:
		pending_damage_popup_timer = max(0.0, pending_damage_popup_timer - delta)
		if pending_damage_popup_timer <= 0.0:
			flush_pending_damage_popup()

	if pending_poison_popup_timer > 0.0:
		pending_poison_popup_timer = max(0.0, pending_poison_popup_timer - delta)
		if pending_poison_popup_timer <= 0.0:
			flush_pending_poison_popup()

func apply_damage(amount: float, source_cell: Vector2i = INVALID_CELL, immediate_popup: bool = false) -> void:
	if amount <= 0.0:
		return

	hp -= amount

	if hero.board_ref != null and source_cell.x > -900:
		hero.board_ref.register_room_damage(source_cell, amount)
		last_damage_room_cell = source_cell

	if immediate_popup:
		var burst_value: int = maxi(1, int(round(amount)))
		spawn_floating_text(str(burst_value), Color(1.0, 0.90, 0.35, 1.0), -28.0)
	else:
		queue_damage_popup(amount)

	if hp <= 0.0:
		hp = 0.0
		kill_hero()

func apply_poison(duration: float, dps: float, source_cell: Vector2i) -> void:
	poison_time = max(poison_time, duration)
	poison_dps = max(poison_dps, dps)
	poison_source_cell = source_cell
	spawn_floating_text("POISON", Color(0.72, 1.0, 0.72, 1.0), -30.0)

func apply_slow(duration: float, factor: float) -> void:
	slow_time = max(slow_time, duration)
	slow_factor = min(slow_factor, factor)
	spawn_floating_text("SLOW", Color(0.75, 0.90, 1.0, 1.0), -30.0)

func update_status_timers(delta: float) -> void:
	if poison_time > 0.0:
		poison_time = max(0.0, poison_time - delta)

		var tick_damage: float = poison_dps * delta
		if tick_damage > 0.0:
			hp -= tick_damage

			if hero.board_ref != null and poison_source_cell.x > -900:
				hero.board_ref.register_room_damage(poison_source_cell, tick_damage)
				last_damage_room_cell = poison_source_cell

			queue_poison_popup(tick_damage)

			if hp <= 0.0:
				hp = 0.0
				kill_hero()
				return

		if poison_time <= 0.0:
			poison_dps = 0.0
			poison_source_cell = INVALID_CELL

	if slow_time > 0.0:
		slow_time = max(0.0, slow_time - delta)

		if slow_time <= 0.0:
			slow_factor = 1.0

	if bleed_time > 0.0:
		bleed_time = max(0.0, bleed_time - delta)

func kill_hero() -> void:
	flush_pending_damage_popup()
	flush_pending_poison_popup()
	spawn_floating_text("KO", Color(1.0, 0.55, 0.35, 1.0), -34.0)

	if hero.board_ref != null and last_damage_room_cell.x > -900:
		hero.board_ref.register_room_kill(last_damage_room_cell)

	hero.died.emit()
	hero.queue_free()
