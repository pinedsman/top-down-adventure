extends EnemyBehavior
class_name MoveToPointBehavior

var target: Vector2 = Vector2.ZERO
var arrival_threshold: float = 8.0

func execute(enemy: EnemyBase, _delta: float) -> void:
	var to_target := target - enemy.global_position
	if to_target.length() <= arrival_threshold:
		enemy.velocity = Vector2.ZERO
		return
	var dir := to_target.normalized()
	enemy._facing = dir
	enemy.velocity = dir * enemy.move_speed
