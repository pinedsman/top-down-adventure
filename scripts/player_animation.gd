@tool

extends Resource
class_name PlayerAnimation

@export var states: Array[AnimationState] = []

var _cache: Dictionary = {}  # String -> AnimationState

func _init() -> void:
	_rebuild_cache()

func _rebuild_cache() -> void:
	_cache.clear()
	for state in states:
		_cache[state.state_name] = state

func get_entry(state_name: String, direction: int) -> AnimationEntry:
	if _cache.is_empty() and not states.is_empty():
		_rebuild_cache()
	assert(_cache.has(state_name), "PlayerAnimation: no state named '%s' — check anim_data resource" % state_name)
	var state: AnimationState = _cache[state_name]
	assert(direction >= 0 and direction < state.directions.size(),
		"PlayerAnimation: state '%s' has no entry for direction %d" % [state_name, direction])
	return state.directions[direction]

func get_entry_for_state(state_name: String) -> AnimationEntry:
	for state in states:
		if state.state_name == state_name:
			if state.directions.size() > 0:
				return state.directions[0]
	return null

static func direction_to_index(direction: Vector2) -> int:
	var angle_deg := fmod(rad_to_deg(atan2(direction.x, -direction.y)) + 360.0, 360.0)
	var per_slice := 360.0 / 8.0
	for i in range(7):
		if angle_deg >= per_slice * (i + 0.5) and angle_deg < per_slice * (i + 1.5):
			return i + 1
	return 0
