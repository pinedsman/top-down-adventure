extends Node2D

@export var color: Color = Color.WHITE

func play() -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.modulate = color
	sprite.play("swipe")


func _on_animation_finished() -> void:
	queue_free()
