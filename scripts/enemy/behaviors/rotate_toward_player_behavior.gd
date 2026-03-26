extends EnemyBehavior
class_name RotateTowardPlayerBehavior

@export var rotation_speed: float = 3.0  # radians per second

func execute(enemy: EnemyBase, delta: float) -> void:
	var player := enemy.get_player()
	if player == null:
		return
	var target_dir := (player.global_position - enemy.global_position).normalized()
	var angle_diff := enemy._facing.angle_to(target_dir)
	enemy._facing = enemy._facing.rotated(
		clampf(angle_diff, -rotation_speed * delta, rotation_speed * delta)
	).normalized()
	enemy.velocity = Vector2.ZERO
