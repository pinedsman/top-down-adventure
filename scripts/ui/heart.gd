extends Control
class_name Heart

@export var heartImages : Array[ Texture2D ]
@onready var texture = $TextureRect

var value: int = 2:
	set(_value):
		value = _value
		update_heart()

func update_heart() -> void:
	texture.texture = heartImages[value]
