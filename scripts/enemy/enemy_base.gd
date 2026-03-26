extends CharacterBase
class_name EnemyBase

@export var contact_damage: float = 10.0
@export_range(0.0, 1.0) var knockback_scale: float = 1.0
@export var impact_fx_data: ImpactFXData  # read by bullet.gd for hit FX
@export var move_speed: float = 80.0

var _active_behavior: EnemyBehavior
var _player_cache: CharacterBase
var _muzzle: Marker2D
var _nav_agent: NavigationAgent2D


func _ready() -> void:
	super._ready()
	_muzzle = get_node_or_null("Muzzle") as Marker2D
	_nav_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	for w in weapons:
		w.owner_node = self
	_run_behavior()


func _physics_process(delta: float) -> void:
	if _knockback_velocity != Vector2.ZERO:
		velocity = _knockback_velocity
		_knockback_velocity = lerp(_knockback_velocity, Vector2.ZERO, 0.2)
		if _knockback_velocity.length() < 1.0:
			_knockback_velocity = Vector2.ZERO
	elif _active_behavior != null:
		_active_behavior.execute(self, delta)
	_tick_all_weapons(delta)
	_update_facing_animation()
	move_and_slide()


# — CharacterBase overrides —

func _get_knockback_scale() -> float:
	return knockback_scale


func _on_take_damage(same_shot: bool, knockback_direction: Vector2, _impact_position: Vector2) -> void:
	if same_shot:
		return
	if knockback_direction != Vector2.ZERO:
		_facing = -knockback_direction.normalized()


func _on_die() -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	var sprite := $AnimatedSprite2D
	if anim_data != null and anim_data.has_state("death"):
		var entry := anim_data.get_entry("death", DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count))
		if entry:
			sprite.flip_h = entry.flip
			sprite.play(entry.animationIndex)
			sprite.animation_finished.connect(queue_free)
			return
	# Fallback for enemies without DirectionalAnimData configured
	var dir_index := DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count)
	var dir_names := ["up", "up", "right", "down", "down", "down", "left", "up"]
	sprite.play("death_" + dir_names[dir_index])
	sprite.animation_finished.connect(queue_free)


# — Behavior API —

func _run_behavior() -> void:
	pass  # override in subclasses to define behavior sequences


func navigate_toward_player(duration: float) -> Signal:
	assert(_nav_agent != null,
		"EnemyBase: scene must have a NavigationAgent2D node to use navigate_toward_player()")
	return run_behavior(NavigateToPlayerBehavior.new(_nav_agent), duration)


func run_behavior(b: EnemyBehavior, duration: float) -> Signal:
	_active_behavior = b
	return get_tree().create_timer(duration, true, false, true).timeout


func rest(duration: float) -> Signal:
	_active_behavior = null
	velocity = Vector2.ZERO
	return get_tree().create_timer(duration, true, false, true).timeout


func face(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing = direction.normalized()


func shoot_weapon(index: int, target_pos: Vector2) -> void:
	assert(index >= 0 and index < weapons.size(),
		"EnemyBase: weapon index %d out of range (have %d weapons)" % [index, weapons.size()])
	assert(_muzzle != null,
		"EnemyBase: scene must have a Marker2D named 'Muzzle' to use shoot_weapon()")
	var direction := (target_pos - _muzzle.global_position).normalized()
	weapons[index].fire(_muzzle, direction)


func is_alive() -> bool:
	return not _is_dead


func get_player() -> CharacterBase:
	if not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as CharacterBase
	return _player_cache


func player_position() -> Vector2:
	var p := get_player()
	return p.global_position if p != null else global_position


# — Internal —

func _tick_all_weapons(delta: float) -> void:
	for w: Weapon in weapons:
		w.tick(delta)


func _update_facing_animation() -> void:
	if anim_data == null or _is_dead:
		return
	var state := "walk" if velocity.length() > 0.01 else "idle"
	if not anim_data.has_state(state):
		return
	var dir_index := DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count)
	var entry := anim_data.get_entry(state, dir_index)
	if entry == null or entry == _current_anim_entry:
		return
	_current_anim_entry = entry
	var sprite := $AnimatedSprite2D
	sprite.flip_h = entry.flip
	sprite.play(entry.animationIndex)
