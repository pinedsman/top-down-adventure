extends CharacterBody2D
class_name Grenade

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

@onready var _sprite: Node2D = $Sprite2D


func init(grenade_data: GrenadeData, direction: Vector2, speed: float, thrower: Node, grenade_shot_id: int) -> void:
	data = grenade_data
	owner_node = thrower
	shot_id = grenade_shot_id
	velocity = direction * speed


func _ready() -> void:
	assert(data != null, "Grenade: data not set — call init() before adding to tree")
	assert(_sprite != null, "Grenade: scene must have a Sprite2D child node")
	_fuse_timer = data.fuse_time


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

	# what's a better way to decay velocity?
	velocity *= 0.9

	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider == owner_node:
		return

	if data.explode_on_impact:
		_explode()
		return

	if data.stick_to_walls and not (collider is Enemy):
		_stuck = true
		velocity = Vector2.ZERO
		return

	if data.max_bounces > 0 and _bounce_count >= data.max_bounces:
		_explode()
		return

	velocity = velocity.bounce(collision.get_normal()) * data.bounce_friction
	_bounce_count += 1
	_on_bounce(collision.get_position())


func _tick_pre_explode(delta: float) -> void:
	if _fuse_timer > data.pre_explode_start_time:
		return

	if not _pre_explode_active:
		_pre_explode_active = true
		_flash_timer = 0.0

	var progress := 1.0 - (_fuse_timer / data.pre_explode_start_time)
	var flash_rate := lerpf(data.pre_explode_flash_rate_start, data.pre_explode_flash_rate_end, progress)
	_flash_timer += delta

	if _flash_timer >= 1.0 / flash_rate:
		_flash_timer = fmod(_flash_timer, 1.0 / flash_rate)
		_flash_visible = not _flash_visible
		_sprite.visible = _flash_visible
		if data.pre_explode_sound:
			AudioPool.play(data.pre_explode_sound, global_position)


func _on_bounce(bounce_pos: Vector2) -> void:
	if data.bounce_sound:
		AudioPool.play(data.bounce_sound, bounce_pos)
	if is_instance_valid(_squash_tween):
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.04)
	_squash_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_sprite.visible = true

	if data.explosion_sound:
		AudioPool.play(data.explosion_sound, global_position)
	if data.explosion_fx:
		data.explosion_fx.spawn(global_position)

	await get_tree().create_timer(data.damage_delay).timeout

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

		var impact_pos = body.global_position
		_spawn_impact(_get_impact_data(body), impact_pos)
		body.take_damage(final_damage, knockback_dir * final_knockback, body.global_position)


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


func _spawn_impact(impact_data: ImpactFXData, impact_pos: Vector2) -> void:
	if impact_data == null:
		return
	impact_data.spawn(impact_pos)

func _get_impact_data(body: Node) -> ImpactFXData:
	if body.get("impact_fx_data") is ImpactFXData:
		return body.impact_fx_data
	return null
