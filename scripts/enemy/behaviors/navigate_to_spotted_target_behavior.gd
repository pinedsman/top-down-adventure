extends EnemyBehavior
class_name NavigateToSpottedTargetBehavior

# Navigates toward the player when visible, otherwise toward the last known position.
# Designed for use in the SPOTTED state of EnemyPatrolBase.

var _agent: NavigationAgent2D
var _patrol_enemy: EnemyPatrolBase


func _init(agent: NavigationAgent2D, enemy: EnemyPatrolBase) -> void:
	_agent = agent
	_patrol_enemy = enemy


func execute(enemy: EnemyBase, _delta: float) -> void:
	var target := _patrol_enemy.player_position() \
			if _patrol_enemy._can_see_player() \
			else _patrol_enemy._last_known_pos

	if target.distance_squared_to(_agent.target_position) > 64.0:
		_agent.target_position = target

	if _agent.is_navigation_finished():
		enemy.velocity = Vector2.ZERO
		return

	var next_pos := _agent.get_next_path_position()
	var dir := (next_pos - enemy.global_position).normalized()
	enemy._facing = dir
	enemy.velocity = dir * enemy.move_speed
