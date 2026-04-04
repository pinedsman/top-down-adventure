extends CanvasLayer
class_name InteractPrompt

# Displays "[Key] Weapon Name" when the player is focused on an interactable.
# Follows the player's world position by converting it to CanvasLayer space
# each frame — avoids YSort issues that would occur if parented to the player.

@onready var _label: Label = $Container/Label

var _follow_target: Node2D = null
const BELOW_OFFSET := Vector2(0, 0)


func _ready() -> void:
	hide_prompt()


func _process(_delta: float) -> void:
	if _follow_target == null or not $Container.visible:
		return
	var screen_pos := get_viewport().get_canvas_transform() * _follow_target.global_position
	$Container.position = screen_pos + BELOW_OFFSET


func show_prompt(text: String, target: Node2D) -> void:
	_follow_target = target
	_label.text = text
	$Container.show()


func hide_prompt() -> void:
	_follow_target = null
	$Container.hide()
