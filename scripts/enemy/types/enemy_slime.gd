extends EnemyBase

func _run_behavior() -> void:
	while is_alive():
		await rest(randf_range(2.0, 3.0))
		await navigate_toward_player(randf_range(2.0, 3.0))
