extends Camera2D
class_name CameraController

@export var shake_strength: float = 5.0
@export var shake_damping: float = 0.55
@export var shake_randomness: float = 0.3
@export var shake_step_time: float = 0.06
@export var zoom_amount: float = 1.15
@export var zoom_in_duration: float = 0.05
@export var zoom_out_duration: float = 0.25

var _shake_tween: Tween
var _zoom_tween: Tween


func _ready() -> void:
	_setup_limits()


func shake(impact_direction: Vector2) -> void:
	if shake_strength <= 0.0:
		return
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()
	_shake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var dir := impact_direction * -1.0 if impact_direction.length_squared() > 0.0 else Vector2.RIGHT
	var amplitude := shake_strength
	var flip := 1.0
	while amplitude >= 0.5:
		var noise := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * shake_randomness
		var offset := dir * amplitude * flip + noise
		_shake_tween.tween_property(self, "offset", offset, shake_step_time).set_trans(Tween.TRANS_SINE)
		amplitude *= shake_damping
		flip = -flip
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, shake_step_time).set_trans(Tween.TRANS_SINE)


func zoom_punch() -> void:
	if zoom_amount <= 1.0:
		return
	if is_instance_valid(_zoom_tween):
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * zoom_amount, zoom_in_duration).set_trans(Tween.TRANS_SINE)
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE, zoom_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_limits() -> void:
	var ground = get_tree().get_first_node_in_group("ground_tilemap")
	if ground == null:
		return
	var rect: Rect2i = ground.get_used_rect()
	var tile_size: Vector2i = ground.tile_set.tile_size
	limit_left   = rect.position.x * tile_size.x
	limit_top    = rect.position.y * tile_size.y
	limit_right  = (rect.position.x + rect.size.x) * tile_size.x
	limit_bottom = (rect.position.y + rect.size.y) * tile_size.y
