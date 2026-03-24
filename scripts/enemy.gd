extends CharacterBody2D
class_name Enemy

@export var max_health: float = 100.0
@export var death_sound: AudioStream

var _health: float

func _ready() -> void:
	$AnimatedSprite2D.play("idle_down")
	_health = max_health

func take_damage(amount: float) -> void:
	_health -= amount
	if _health <= 0.0:
		die()

func _play_sound(stream: AudioStream) -> void:
	var player = AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.play()
	
func die() -> void:
	_play_sound(death_sound)
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	$AnimatedSprite2D.play("death_down")
	$AnimatedSprite2D.animation_finished.connect(queue_free)
