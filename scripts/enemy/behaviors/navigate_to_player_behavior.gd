extends EnemyBehavior
class_name NavigateToPlayerBehavior

var _agent: NavigationAgent2D

func _init(agent: NavigationAgent2D) -> void:
	_agent = agent

func execute(enemy: EnemyBase, _delta: float) -> void:
	var target := enemy.player_position()
	if target.distance_squared_to(_agent.target_position) > 64.0:  # ~8px threshold
		_agent.target_position = target
	if _agent.is_navigation_finished():
		enemy.velocity = Vector2.ZERO
		return
	var next_pos := _agent.get_next_path_position()
	var dir := (next_pos - enemy.global_position).normalized()
	enemy._facing = dir
	enemy.velocity = dir * enemy.move_speed
	if (_agent.debug_enabled):
		DebugDraw.add_line(enemy.global_position, enemy.global_position + enemy.velocity)
		DebugDraw.add_circle(next_pos, 5, Color.GREEN)
