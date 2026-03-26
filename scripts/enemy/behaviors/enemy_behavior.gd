extends RefCounted
class_name EnemyBehavior

## Base class for all per-frame enemy behaviors.
## Subclass this and override execute() to implement a new behavior.
## Set on EnemyBase via run_behavior() or _active_behavior directly.
func execute(_enemy: EnemyBase, _delta: float) -> void:
	pass
