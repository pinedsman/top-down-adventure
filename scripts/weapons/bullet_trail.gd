extends Line2D
class_name BulletTrail

@export var max_points: int = 15
@export var detach_interval: float = 0.0  # seconds between point removals; 0 = every physics frame

var _target: Node2D = null
var _detached: bool = false
var _detach_timer: float = 0.0


func _ready() -> void:
	top_level = true


func follow(target: Node2D) -> void:
	_target = target


func detach(new_parent: Node, final_point: Vector2) -> void:
	add_point(final_point)
	_detached = true
	_target = null
	reparent(new_parent)


func _physics_process(delta: float) -> void:
	if not _detached:
		if is_instance_valid(_target):
			add_point(_target.global_position)
			while get_point_count() > max_points:
				remove_point(0)
	else:
		_detach_timer -= delta
		if _detach_timer > 0.0:
			return
		_detach_timer = detach_interval
		if get_point_count() > 0:
			remove_point(0)
		else:
			queue_free()
