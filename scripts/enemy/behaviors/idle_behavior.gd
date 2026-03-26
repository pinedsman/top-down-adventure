extends EnemyBehavior
class_name IdleBehavior

func execute(enemy: EnemyBase, _delta: float) -> void:
	enemy.velocity = Vector2.ZERO
