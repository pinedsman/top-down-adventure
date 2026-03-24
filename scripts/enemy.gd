extends CharacterBody2D
class_name Enemy

@export var max_health: float = 100.0
@export var impact_fx_data: ImpactFXData
@export var death_sound: AudioStream

var _health: float

func _ready() -> void:
	$AnimatedSprite2D.play("idle_down")
	_health = max_health

func take_damage(amount: float) -> void:
	_health -= amount
	if _health <= 0.0:
		die()

func die() -> void:
	if death_sound:
		AudioPool.play(death_sound, global_position)
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	$AnimatedSprite2D.play("death_down")
	$AnimatedSprite2D.animation_finished.connect(queue_free)
