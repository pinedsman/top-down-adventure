extends Node2D
class_name ImpactFX

func play_impact(data: ImpactFXData) -> void:
	$AnimatedSprite2D.position += data.offset
	$AnimatedSprite2D.scale = data.scale
	show()
	$AnimatedSprite2D.play(data.animation_name)
	if data.sound:
		AudioPool.play(data.sound, global_position)

func _on_animation_finished() -> void:
	queue_free()
