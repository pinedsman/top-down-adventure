extends Node2D

func flash() -> void:
	show()
	$Muzzleflash.play("flash")

func _on_animation_finished() -> void:
	queue_free()
