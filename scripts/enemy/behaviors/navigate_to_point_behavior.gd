extends EnemyBehavior
class_name NavigateToPointBehavior

var _agent: NavigationAgent2D
var _target: Vector2

func _init(agent: NavigationAgent2D, target: Vector2) -> void:
	_agent = agent
	_target = target

func execute(enemy: EnemyBase, _delta: float) -> void:
	if _agent.target_position != _target:
		_agent.target_position = _target
	if _agent.is_navigation_finished():
		enemy.velocity = Vector2.ZERO
		return
	var next_pos := _agent.get_next_path_position()
	var dir := (next_pos - enemy.global_position).normalized()
	enemy._facing = dir
	enemy.velocity = dir * enemy.move_speed
