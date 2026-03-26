extends CharacterBody2D
class_name Grenade

var _camera: CameraController

var data: GrenadeData = null
var owner_node: Node = null
var shot_id: int = -1

var _fuse_timer: float = 0.0
var _bounce_count: int = 0
var _stuck: bool = false
var _exploded: bool = false

var _pre_explode_active: bool = false
var _flash_timer: float = 0.0
var _flash_visible: bool = true
var _squash_tween: Tween
var _radius_indicator: GrenadeRadius

var _settle_thresholds: Array[float] = []
var _settle_index: int = 0
var _spin_dir: float = 1.0

@onready var _sprite: Node2D = $Sprite2D
@onready var _sprite_scale: Vector2 = _sprite.scale


func init(grenade_data: GrenadeData, direction: Vector2, speed: float, thrower: Node, grenade_shot_id: int) -> void:
	data = grenade_data
	owner_node = thrower
	shot_id = grenade_shot_id
	velocity = direction * speed
	_spin_dir = signf(direction.x) if absf(direction.x) > 0.1 else 1.0


func _ready() -> void:
	assert(data != null, "Grenade: data not set — call init() before adding to tree")
	assert(_sprite != null, "Grenade: scene must have a Sprite2D child node")
	_camera = get_tree().get_first_node_in_group("camera") as CameraController
	assert(_camera != null, "Grenade: no CameraController in group 'camera'")
	_fuse_timer = data.fuse_time
	_build_settle_thresholds()
	if is_instance_valid(owner_node) and owner_node is PhysicsBody2D:
		add_collision_exception_with(owner_node)
	_radius_indicator = GrenadeRadius.new()
	add_child(_radius_indicator)
	_radius_indicator.setup(self)


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	_fuse_timer -= delta
	_tick_pre_explode(delta)

	if _fuse_timer <= 0.0:
		_explode()
		return

	if _stuck:
		return

	velocity *= exp(-data.velocity_decay * delta)

	if velocity.length() < data.stop_speed:
		_stuck = true
		velocity = Vector2.ZERO
		return

	_sprite.rotation += data.spin_rate * velocity.length() * _spin_dir * delta
	_radius_indicator.global_position = global_position
	_tick_settle_clinks()
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return

	var collider := collision.get_collider()

	if data.explode_on_impact:
		_explode()
		return

	if data.stick_to_walls and not collider.is_in_group("enemies"):
		_stuck = true
		velocity = Vector2.ZERO
		return

	if data.max_bounces > 0 and _bounce_count >= data.max_bounces:
		_explode()
		return

	velocity = velocity.bounce(collision.get_normal()) * data.bounce_friction
	_bounce_count += 1
	_settle_index = 0  # reset so settle clinks re-arm after each wall bounce
	_on_bounce(collision.get_position())



func _tick_pre_explode(delta: float) -> void:
	if _fuse_timer > data.pre_explode_start_time:
		return

	if not _pre_explode_active:
		_pre_explode_active = true
		_flash_timer = 0.0
		_radius_indicator.queue_redraw()

	var progress := 1.0 - (_fuse_timer / data.pre_explode_start_time)
	var flash_rate := lerpf(data.pre_explode_flash_rate_start, data.pre_explode_flash_rate_end, progress)
	_flash_timer += delta

	if _flash_timer >= 1.0 / flash_rate:
		_flash_timer = fmod(_flash_timer, 1.0 / flash_rate)
		_flash_visible = not _flash_visible
		_sprite.visible = _flash_visible
		_radius_indicator.queue_redraw()
		if data.pre_explode_sound:
			AudioPool.play(data.pre_explode_sound, global_position)


func _on_bounce(bounce_pos: Vector2, intensity: float = 1.0) -> void:
	if data.bounce_sound:
		AudioPool.play(data.bounce_sound, bounce_pos)
	if is_instance_valid(_squash_tween):
		_squash_tween.kill()
	var sx := 1.0 + 0.3 * intensity
	var sy := 1.0 - 0.3 * intensity
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _sprite_scale * Vector2(sx, sy), 0.04)
	_squash_tween.tween_property(_sprite, "scale", _sprite_scale, 0.1).set_ease(Tween.EASE_OUT)


func _build_settle_thresholds() -> void:
	_settle_thresholds.clear()
	var count := data.settle_clink_count
	if count <= 0:
		return
	# Space thresholds evenly between settle_speed and stop threshold (50),
	# excluding the endpoints (stop clink is handled separately).
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		_settle_thresholds.append(lerpf(data.settle_speed, data.stop_speed, t))
	_settle_thresholds.sort()
	_settle_thresholds.reverse()  # check highest first


func _tick_settle_clinks() -> void:
	var speed := velocity.length()
	while _settle_index < _settle_thresholds.size() and speed <= _settle_thresholds[_settle_index]:
		var intensity := _settle_thresholds[_settle_index] / data.settle_speed
		_on_bounce(global_position, intensity)
		velocity = velocity.normalized() * speed * 1.5
		_settle_index += 1


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_sprite.visible = true

	if data.explosion_sound:
		AudioPool.play(data.explosion_sound, global_position)
	if data.explosion_fx:
		data.explosion_fx.spawn(global_position)
	_camera.shake(Vector2.UP, data.explosion_shake_strength, 1.0, 0.8)

	await get_tree().create_timer(data.damage_delay, true, false, true).timeout

	_apply_explosion_damage()
	queue_free()


func _apply_explosion_damage() -> void:
	assert(data.explosion_outer_radius > data.explosion_inner_radius,
		"GrenadeData: explosion_outer_radius must be greater than explosion_inner_radius")

	var shape := CircleShape2D.new()
	shape.radius = data.explosion_outer_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.exclude = [self]

	var hits := get_world_2d().direct_space_state.intersect_shape(query)
	for hit in hits:
		var body: Node = hit.collider
		if not body.has_method("take_damage"):
			continue
		if body == owner_node and not data.self_damage:
			continue
		var surface_pos = _los_hit_pos(body as Node2D)
		if surface_pos == null:
			continue

		var dist := global_position.distance_to(body.global_position)
		var t := clampf(
			(dist - data.explosion_inner_radius) / (data.explosion_outer_radius - data.explosion_inner_radius),
			0.0, 1.0)
		var falloff_t := data.damage_falloff.sample(t) if data.damage_falloff else t

		var final_damage := lerpf(data.inner_damage, data.outer_damage, falloff_t)
		var final_knockback := lerpf(data.knockback_inner, data.knockback_outer, falloff_t)
		var knockback_dir: Vector2 = ((body as Node2D).global_position - global_position).normalized()

		if body == owner_node:
			final_damage = data.self_damage_override
			final_knockback = data.self_knockback_override

		_spawn_impact(_get_impact_data(body), surface_pos)
		body.take_damage(final_damage, knockback_dir * final_knockback, surface_pos)


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


## Returns the surface contact point if target has line-of-sight, or null if blocked.
func _los_hit_pos(target: Node2D) -> Variant:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self, target]
	query.collision_mask = data.los_mask
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return null  # blocked
	var to_target: Vector2 = target.global_position - global_position
	return global_position + to_target.normalized() * (to_target.length() - 1.0)


func _spawn_impact(impact_data: ImpactFXData, impact_pos: Vector2) -> void:
	if impact_data == null:
		return
	impact_data.spawn(impact_pos)

func _get_impact_data(body: Node) -> ImpactFXData:
	if body.get("impact_fx_data") is ImpactFXData:
		return body.impact_fx_data
	return null
