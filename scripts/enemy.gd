extends CharacterBody2D
class_name Enemy

@export var max_health: float = 100.0
@export var contact_damage: float = 10.0
@export_range(0.0, 1.0) var knockback_scale: float = 1.0
@export var impact_fx_data: ImpactFXData
@export var death_sound: AudioStream
var _health: float
var _knockback_velocity: Vector2 = Vector2.ZERO
var _flash_tween: Tween

func _ready() -> void:
	$AnimatedSprite2D.play("idle_down")
	_health = max_health

func _physics_process(_delta: float) -> void:
	if _knockback_velocity != Vector2.ZERO:
		velocity = _knockback_velocity
		_knockback_velocity = lerp(_knockback_velocity, Vector2.ZERO, 0.2)
		if _knockback_velocity.length() < 1.0:
			_knockback_velocity = Vector2.ZERO
		move_and_slide()

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	_health -= amount
	_knockback_velocity = knockback_direction * knockback_scale
	var sprite := $AnimatedSprite2D as CanvasItem
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	sprite.modulate = Color(5.0, 5.0, 5.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if _health <= 0.0:
		die()

func die() -> void:
	if death_sound:
		AudioPool.play(death_sound, global_position)
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	$AnimatedSprite2D.play("death_down")
	$AnimatedSprite2D.animation_finished.connect(queue_free)
