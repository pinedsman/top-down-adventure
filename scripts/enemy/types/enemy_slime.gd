extends EnemyPatrolBase
class_name EnemySlime

@export_group("Chase")
@export var approach_min: float = 2.0
@export var approach_max: float = 3.0
@export var wait_min: float = 1.0
@export var wait_max: float = 2.0


func _spotted_behavior() -> void:
	await navigate_toward_spotted_target(randf_range(approach_min, approach_max))
	await rest(randf_range(wait_min, wait_max))
