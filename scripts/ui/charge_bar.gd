extends CanvasLayer
class_name ChargeBar

# Displays a charge progress bar above the player while a charge weapon is active.
# Follows the player's world position via canvas transform (avoids YSort issues).
# Scene structure expected:
#   ChargeBar (CanvasLayer)
#   └── Container (Control, anchor top-left, no anchors — position driven by script)
#       └── ProgressBar  (max_value = 1.0, step = 0.0)

@onready var _container: Control = $Container
@onready var _bar: ProgressBar = $Container/ProgressBar

var _follow_target: Node2D = null
const ABOVE_OFFSET := Vector2(0, -28)


func _ready() -> void:
	_container.hide()


func _process(_delta: float) -> void:
	if _follow_target == null or not _container.visible:
		return
	var screen_pos := get_viewport().get_canvas_transform() * _follow_target.global_position
	# Centre the bar horizontally on the player
	_container.position = screen_pos + ABOVE_OFFSET - Vector2(_container.size.x * 0.5, 0.0)


func show_bar(target: Node2D) -> void:
	_follow_target = target
	_container.show()


func hide_bar() -> void:
	_follow_target = null
	_container.hide()


func set_progress(value: float) -> void:
	_bar.value = value
