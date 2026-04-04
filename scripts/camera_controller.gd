extends Camera2D
class_name CameraController

@export var shake_strength: float = 5.0
@export var shake_damping: float = 0.55
@export var shake_randomness: float = 0.3
@export var shake_step_time: float = 0.06
@export var zoom_amount: float = 1.15
@export var zoom_in_duration: float = 0.05
@export var zoom_out_duration: float = 0.25

## Fraction of the player→aim-target vector the camera moves at look_scalar = 1.
## 0.5 = halfway point, 1.0 = full aim-target position.
const LOOKAHEAD_FRACTION: float = 0.25

@export_group("Look-ahead")
## Max world-unit look-ahead for gamepad at full stick deflection.
## Also used as the fallback when the current weapon has infinite bullet range.
@export var gamepad_lookahead_max: float = 120.0
## 0 = camera stays on player, 1 = camera moves to halfway point between player and aim target.
## Designed to be driven by a settings menu at runtime.
@export_range(0.0, 1.0) var look_scalar: float = 1.0
@export var gamepad_look_smooth_speed: float = 6.0

var _shake_tween: Tween
var _zoom_tween: Tween
var _current_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("camera")
	_setup_limits()


func refresh_limits(room_root: Node = null) -> void:
	_setup_limits(room_root)


func shake(impact_direction: Vector2, strength_override: float = -1.0, randomness_override: float = -1.0, damping_override: float = -1.0) -> void:
	var amplitude := strength_override if strength_override >= 0.0 else shake_strength
	if amplitude <= 0.0:
		return
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()
	_shake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var dir := impact_direction * -1.0 if impact_direction.length_squared() > 0.0 else Vector2.RIGHT
	var flip := 1.0
	var randomness := shake_randomness if (randomness_override==-1) else randomness_override
	var damping := shake_damping if (damping_override==-1) else damping_override
	while amplitude >= 0.5:
		var noise := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * randomness
		var shake_offset := dir * amplitude * flip + noise
		_shake_tween.tween_property(self, "offset", shake_offset, shake_step_time).set_trans(Tween.TRANS_SINE)
		amplitude *= damping
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


func _process(delta: float) -> void:
	var player := get_parent() as Player
	if player == null:
		return

	if InputManager.is_gamepad:
		var target_offset := Vector2.ZERO
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		var stick_len := stick.length()
		if stick_len > 0.01:
			var w := player.weapon
			var bullet_range := w.data.bullet_range if w != null and w.data.bullet_range > 0.0 else gamepad_lookahead_max
			var look_dist := minf(bullet_range, gamepad_lookahead_max)
			target_offset = stick.normalized() * (look_dist * LOOKAHEAD_FRACTION) * stick_len
		_current_offset = _current_offset.lerp(target_offset, 1.0 - exp(-gamepad_look_smooth_speed * delta))
	else:
		var mouse_world := get_viewport().get_canvas_transform().affine_inverse() \
				* get_viewport().get_mouse_position()
		_current_offset = (mouse_world - player.global_position) * LOOKAHEAD_FRACTION

	position = _current_offset * look_scalar


func _setup_limits(room_root: Node = null) -> void:
	# Manual bounds: place an Area2D in the "camera_bounds" group with a
	# CollisionShape2D child using a RectangleShape2D.
	var bounds_node: Node = null
	if room_root != null:
		for node in get_tree().get_nodes_in_group("camera_bounds"):
			if node == room_root or room_root.is_ancestor_of(node):
				bounds_node = node
				break
	else:
		bounds_node = get_tree().get_first_node_in_group("camera_bounds")
	if bounds_node is Area2D:
		var col := bounds_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null and col.shape is RectangleShape2D:
			var center := col.global_position
			var half := (col.shape as RectangleShape2D).size * 0.5
			var rect := Rect2(center - half, (col.shape as RectangleShape2D).size)
			limit_left   = int(rect.position.x)
			limit_top    = int(rect.position.y)
			limit_right  = int(rect.end.x)
			limit_bottom = int(rect.end.y)
			return

	# Fallback: derive bounds from the ground tilemap.
	var ground = get_tree().get_first_node_in_group("ground_tilemap")
	if ground == null:
		return
	var rect: Rect2i = ground.get_used_rect()
	var tile_size: Vector2i = ground.tile_set.tile_size
	limit_left   = rect.position.x * tile_size.x
	limit_top    = rect.position.y * tile_size.y
	limit_right  = (rect.position.x + rect.size.x) * tile_size.x
	limit_bottom = (rect.position.y + rect.size.y) * tile_size.y
