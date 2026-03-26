extends CharacterBody2D
class_name CharacterBase

@export var anim_data: DirectionalAnimData
@export var weapons: Array[Weapon]
@export var max_health: float = 100.0
@export var hurt_sound: AudioStream
@export var death_sound: AudioStream
@export var hit_stop_duration: float = 0.1
@export var hit_impact_fx: ImpactFXData

signal health_changed(current: float, maximum: float)

var _health: float
var _is_dead: bool = false
var _flash_tween: Tween
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_shot_id: int = -1
var _facing: Vector2 = Vector2.DOWN
var _current_anim_entry: AnimationEntry


func _ready() -> void:
	_health = max_health


func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO, impact_position: Vector2 = global_position, shot_id: int = -1) -> void:
	if _is_dead:
		return
	var same_shot := shot_id >= 0 and shot_id == _last_shot_id
	if not same_shot and not _can_take_damage():
		return
	_last_shot_id = shot_id
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, max_health)

	var scale := _get_knockback_scale()
	if same_shot:
		_knockback_velocity += knockback_direction * scale
		_on_take_damage(true, knockback_direction, impact_position)
		return

	if hurt_sound:
		AudioPool.play(hurt_sound, global_position)
	_knockback_velocity = knockback_direction * scale
	_apply_hit_flash()
	_spawn_hit_impact(impact_position)
	if hit_stop_duration > 0.0:
		HitStop.request(hit_stop_duration)
	_on_take_damage(false, knockback_direction, impact_position)

	if _health <= 0.0:
		die()


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if death_sound:
		AudioPool.play(death_sound, global_position)
	set_physics_process(false)
	_on_die()


func _connect_weapon(w: Weapon) -> void:
	if w == null:
		return
	w.owner_node = self
	if not w.fired.is_connected(_on_weapon_fired):
		w.fired.connect(_on_weapon_fired)


# — Virtual hooks —

func _can_take_damage() -> bool:
	return true

func _get_knockback_scale() -> float:
	return 1.0

func _on_take_damage(_same_shot: bool, _knockback_direction: Vector2, _impact_position: Vector2) -> void:
	pass

func _on_die() -> void:
	pass

func _on_weapon_fired(_direction: Vector2) -> void:
	pass

func has_ammo(_w: Weapon) -> bool:
	return true  # default: infinite; Player overrides to check _ammo dict


# — Helpers —

func _apply_hit_flash() -> void:
	var sprite := $AnimatedSprite2D as CanvasItem
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	sprite.modulate = Color(5.0, 5.0, 5.0)
	_flash_tween = create_tween()
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _spawn_hit_impact(impact_position: Vector2) -> void:
	if hit_impact_fx == null:
		return
	hit_impact_fx.spawn(impact_position, Node.PROCESS_MODE_ALWAYS)
