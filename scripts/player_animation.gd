@tool

extends Resource
class_name PlayerAnimation

@export var states: Array[AnimationState] = []

func get_entry(state_name: String, direction: int) -> AnimationEntry:
	for state in states:
		if state.state_name == state_name:
			if direction >= 0 and direction < state.directions.size():
				return state.directions[direction]
	return null

func get_entry_for_state(state_name: String) -> AnimationEntry:
	for state in states:
		if state.state_name == state_name:
			if state.directions.size() > 0:
				return state.directions[0]
	return null
