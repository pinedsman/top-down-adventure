extends Node

## Tracks whether the active input device is a gamepad or mouse+keyboard.
## Subscribe to input_mode_changed to react to switches.
##
##   InputManager.input_mode_changed.connect(_on_input_mode_changed)
##   if InputManager.is_gamepad: ...

signal input_mode_changed(is_gamepad: bool)

const STICK_DEADZONE := 0.2

var is_gamepad: bool = false:
	set(value):
		if value == is_gamepad:
			return
		is_gamepad = value
		input_mode_changed.emit(is_gamepad)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) <= STICK_DEADZONE:
			return
		is_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		is_gamepad = false


func get_move_vector() -> Vector2:
	if Console.is_visible():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_vector() -> Vector2:
	if Console.is_visible():
		return Vector2.ZERO
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")


func is_action_pressed(action: StringName) -> bool:
	if Console.is_visible():
		return false
	return Input.is_action_pressed(action)
