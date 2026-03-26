extends Weapon
class_name MeleeWeapon

enum SwingState { IDLE, WINDUP, ACTIVE, RECOVERY }

# Data pass-throughs for melee-specific fields
var swings: Array[SwingData]:  
	get: return (data as MeleeWeaponData).swings
var debug_draw_arc: bool:      
	get: return (data as MeleeWeaponData).debug_draw_arc
var los_mask: int:             
	get: return (data as MeleeWeaponData).los_mask

signal swing_started(swing_index: int)

var _state: SwingState = SwingState.IDLE
var _state_timer: float = 0.0
var _swing_index: int = 0
var _hit_set: Array = []
var _pending_swing: bool = false
var _swing_direction: Vector2 = Vector2.RIGHT
var _swing_muzzle: Marker2D = null
var _shooter: Node = null  # set on each fire(); used by tick helpers

var _arc_shape: CircleShape2D
var _arc_query: PhysicsShapeQueryParameters2D


func _init(weapon_data: WeaponData) -> void:
	super(weapon_data)
	_arc_shape = CircleShape2D.new()
	_arc_query = PhysicsShapeQueryParameters2D.new()
	_arc_query.shape = _arc_shape


# — Weapon overrides —

func tick(delta: float) -> void:
	super.tick(delta)
	if _state == SwingState.IDLE:
		return
	if _state == SwingState.ACTIVE and is_instance_valid(_swing_muzzle):
		_do_arc_query()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_advance_state()


func can_fire() -> bool:
	match _state:
		SwingState.IDLE:     return _cooldown <= 0.0
		SwingState.ACTIVE, \
		SwingState.RECOVERY: return true   # accept chain input
		_:                   return false  # WINDUP blocks input


func can_switch() -> bool:
	return _state == SwingState.IDLE or _state == SwingState.RECOVERY


func fire(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	_shooter = shooter
	match _state:
		SwingState.IDLE:
			if _cooldown > 0.0:
				return
			_swing_index = 0
			_start_swing(muzzle, direction)
		SwingState.ACTIVE, SwingState.RECOVERY:
			if _swing_index + 1 < swings.size():
				_pending_swing = true
				_swing_muzzle = muzzle
				_swing_direction = direction


func interrupt() -> void:
	_state = SwingState.IDLE
	_state_timer = 0.0
	_pending_swing = false
	_hit_set.clear()


func cancel_burst() -> void:
	interrupt()


# — State queries —

func is_swinging() -> bool:
	return _state != SwingState.IDLE


func swing_move_scale() -> float:
	if not is_swinging():
		return 1.0
	return _current_swing().move_scale


func swing_rotation_scale() -> float:
	if not is_swinging():
		return 1.0
	return _current_swing().rotation_scale


# — Internal —

func _start_swing(muzzle: Marker2D, direction: Vector2) -> void:
	_swing_muzzle = muzzle
	_swing_direction = direction
	_state = SwingState.WINDUP
	var swing := _current_swing()
	_state_timer = swing.windup_time
	_cooldown = swing.windup_time + swing.active_time + swing.recovery_time
	if swing.swing_sound and is_instance_valid(_shooter):
		AudioPool.play(swing.swing_sound, (_shooter as Node2D).global_position)
	fired.emit(direction)
	swing_started.emit(_swing_index)


func _advance_state() -> void:
	match _state:
		SwingState.WINDUP:
			_state = SwingState.ACTIVE
			_state_timer = _current_swing().active_time
			_hit_set.clear()
			_spawn_swipe_fx()
		SwingState.ACTIVE:
			if _pending_swing:
				_pending_swing = false
				_swing_index += 1
				_start_swing(_swing_muzzle, _swing_direction)
			else:
				_state = SwingState.RECOVERY
				_state_timer = _current_swing().recovery_time
		SwingState.RECOVERY:
			_state = SwingState.IDLE
			_swing_index = 0
			_cooldown = 0.0


func _do_arc_query() -> void:
	var swing := _current_swing()
	_arc_shape.radius = swing.arc_range
	_arc_query.transform = Transform2D(0.0, _swing_muzzle.global_position)
	var hits := _swing_muzzle.get_world_2d().direct_space_state.intersect_shape(_arc_query)
	var half_arc := deg_to_rad(swing.arc_angle * 0.5)
	for hit in hits:
		var body: Node = hit.collider
		if not body.has_method("take_damage"):
			continue
		if body == _shooter or _hit_set.has(body):
			continue
		var to_body: Vector2 = (body as Node2D).global_position - _swing_muzzle.global_position
		if absf(_swing_direction.angle_to(to_body.normalized())) > half_arc:
			continue
		if not _has_los(body as Node2D):
			continue
		_hit_set.append(body)
		var hit_pos: Vector2 = (body as Node2D).global_position
		body.take_damage(swing.damage, to_body.normalized() * swing.knockback_force, hit_pos)
		var impact_data = body.get("impact_fx_data")
		if impact_data is ImpactFXData:
			impact_data.spawn(hit_pos)


func _has_los(target: Node2D) -> bool:
	if los_mask == 0:
		return true
	var query := PhysicsRayQueryParameters2D.create(_swing_muzzle.global_position, target.global_position)
	query.exclude = [_shooter, target]
	query.collision_mask = los_mask
	return _swing_muzzle.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _spawn_swipe_fx() -> void:
	var swing := _current_swing()
	if swing.swipe_fx_scene == null or not is_instance_valid(_swing_muzzle):
		return
	var fx := swing.swipe_fx_scene.instantiate()
	var ysort := _swing_muzzle.get_tree().get_first_node_in_group("ysort")
	assert(ysort != null, "MeleeWeapon: no node in group 'ysort'")
	ysort.add_child(fx)
	if is_instance_valid(_shooter):
		fx.global_position = (_shooter as Node2D).global_position
	fx.rotation = _swing_direction.angle()
	fx.play()


func _current_swing() -> SwingData:
	return swings[clamp(_swing_index, 0, swings.size() - 1)]
