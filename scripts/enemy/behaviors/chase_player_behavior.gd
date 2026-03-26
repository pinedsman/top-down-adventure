extends EnemyBehavior
class_name ChasePlayerBehavior

func execute(enemy: EnemyBase, _delta: float) -> void:
	var player := enemy.get_player()
	if player == null:
		enemy.velocity = Vector2.ZERO
		return
	var dir := (player.global_position - enemy.global_position).normalized()
	enemy._facing = dir
	enemy.velocity = dir * enemy.move_speed
