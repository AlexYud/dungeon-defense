class_name HeroGrid
extends Node2D

const INVALID_CELL: Vector2i = Vector2i(-999, -999)

signal reached_goal
signal died
signal impact_feedback(world_position: Vector2, strength: float, kind: String)

@export var move_speed: float = 260.0
@export var max_hp: float = 100.0
@export var hero_attack_dps: float = 45.0
@export var hero_attack_vs_boss_dps: float = 38.0
@export var damage_popup_interval: float = 0.22

@export var combat_attack_interval: float = 0.42

@export var warrior_frames: SpriteFrames
@export var archer_frames: SpriteFrames
@export var lancer_frames: SpriteFrames

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var board_ref: Node2D = null

var statuses: HeroStatuses
var movement: HeroMovement
var room_logic: HeroRoomLogic

var sprite_scene_scale: Vector2 = Vector2.ONE
var current_visual_scale: float = 1.0

var combat_attack_timer: float = 0.0
var next_attack_index: int = 0

func _init() -> void:
	statuses = HeroStatuses.new(self)
	movement = HeroMovement.new(self)
	room_logic = HeroRoomLogic.new(self)

func _ready() -> void:
	statuses.hp = max_hp
	sprite_scene_scale = sprite.scale
	apply_sprite_visual_scale()
	play_anim("idle")

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
	statuses.hp = max_hp
	move_speed = new_move_speed
	hero_attack_dps = new_attack_dps
	hero_attack_vs_boss_dps = new_attack_vs_boss_dps

	current_visual_scale = visual_scale
	combat_attack_timer = 0.0
	next_attack_index = 0

	apply_visual_set(enemy_name)

	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	apply_sprite_visual_scale()

	name = enemy_name.capitalize()

	var lane_slot: int = int(get_instance_id()) % 3
	movement.set_lane_offset(float(lane_slot - 1) * 10.0)

func apply_visual_set(enemy_name: String) -> void:
	if sprite == null:
		return

	var selected_frames: SpriteFrames = null

	match enemy_name:
		"warrior":
			selected_frames = warrior_frames
		"archer":
			selected_frames = archer_frames
		"lancer":
			selected_frames = lancer_frames
		_:
			selected_frames = warrior_frames

	if selected_frames != null:
		sprite.sprite_frames = selected_frames

func apply_sprite_visual_scale() -> void:
	if sprite == null:
		return

	sprite.scale = sprite_scene_scale * current_visual_scale

func set_board_ref(new_board: Node2D) -> void:
	board_ref = new_board

func set_path(points: Array[Vector2]) -> void:
	movement.set_path(points)

func _process(delta: float) -> void:
	var hp_before_frame: float = statuses.hp
	var knockback_before_frame: bool = movement.is_knockback_animating

	combat_attack_timer = max(0.0, combat_attack_timer - delta)

	statuses.update_popup_timers(delta)
	statuses.update_status_timers(delta)

	if statuses.hp <= 0.0:
		play_anim("idle")
		emit_frame_feedback(hp_before_frame, knockback_before_frame)
		return

	if movement.path_points.is_empty():
		play_anim("idle")
		emit_frame_feedback(hp_before_frame, knockback_before_frame)
		return

	if movement.is_knockback_animating:
		play_anim("run")
		movement.update_knockback_animation(delta)
		emit_frame_feedback(hp_before_frame, knockback_before_frame)
		return

	var blocked_by_room: bool = room_logic.update_room_effects(delta)
	emit_frame_feedback(hp_before_frame, knockback_before_frame)

	if statuses.hp <= 0.0:
		play_anim("idle")
		return

	if blocked_by_room:
		update_combat_animation()
		return

	if movement.path_index >= movement.path_points.size():
		play_anim("idle")
		reached_goal.emit()
		queue_free()
		return

	play_anim("run")
	movement.update_forward_movement(delta)

func update_combat_animation() -> void:
	if is_attack_anim_playing():
		return

	if combat_attack_timer <= 0.0:
		if play_next_attack_animation():
			combat_attack_timer = combat_attack_interval
			return

	if has_anim("guard"):
		play_anim("guard")
	else:
		play_anim("idle")

func play_next_attack_animation() -> bool:
	var attack_names: Array[String] = ["attack_1", "attack_2"]

	for i in range(attack_names.size()):
		var index: int = (next_attack_index + i) % attack_names.size()
		var anim_name: String = attack_names[index]

		if has_anim(anim_name):
			next_attack_index = (index + 1) % attack_names.size()
			play_anim(anim_name)
			return true

	return false

func is_attack_anim_playing() -> bool:
	return sprite != null and sprite.is_playing() and (
		sprite.animation == "attack_1" or sprite.animation == "attack_2"
	)

func has_anim(anim_name: String) -> bool:
	if sprite == null:
		return false
	if sprite.sprite_frames == null:
		return false
	return sprite.sprite_frames.has_animation(anim_name)

func play_anim(anim_name: String) -> void:
	if not has_anim(anim_name):
		return

	if sprite.animation != anim_name:
		sprite.play(anim_name)
	elif not sprite.is_playing():
		sprite.play(anim_name)

func emit_frame_feedback(hp_before_frame: float, knockback_before_frame: bool) -> void:
	var damage_taken: float = hp_before_frame - statuses.hp

	if damage_taken > 0.01:
		impact_feedback.emit(global_position, compute_hit_feedback_strength(damage_taken), "hit")

	if (not knockback_before_frame) and movement.is_knockback_animating:
		impact_feedback.emit(global_position, 1.0, "slam")

func compute_hit_feedback_strength(damage_taken: float) -> float:
	var baseline: float = max(10.0, max_hp * 0.12)
	return clamp(0.35 + damage_taken / baseline, 0.35, 1.1)
