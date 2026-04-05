extends CharacterBase
class_name EnemyBase

@export var contact_damage: float = 10.0
@export_range(0.0, 1.0) var knockback_scale: float = 1.0
@export var impact_fx_data: ImpactFXData  # read by bullet.gd for hit FX
@export var move_speed: float = 80.0
@export var show_debug: bool = false

var _active_behavior: EnemyBehavior
var _player_cache: CharacterBase
var _muzzle: Marker2D
var _nav_agent: NavigationAgent2D
var _is_spawning: bool = false


func _ready() -> void:
	super._ready()
	_muzzle = get_node_or_null("Muzzle") as Marker2D
	_nav_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if show_debug:
		var overlay := EnemyDebugOverlay.new()
		add_child(overlay)
		overlay.setup(self)
	_run_behavior()


func _physics_process(delta: float) -> void:
	if _is_spawning:
		return
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

func _can_take_damage() -> bool:
	return not _is_spawning


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
	queue_free()


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
	if _is_spawning:
		return
	assert(index >= 0 and index < _weapon_instances.size(),
		"EnemyBase: weapon index %d out of range (have %d weapons)" % [index, _weapon_instances.size()])
	assert(_muzzle != null,
		"EnemyBase: scene must have a Marker2D named 'Muzzle' to use shoot_weapon()")
	var direction := (target_pos - _muzzle.global_position).normalized()
	_weapon_instances[index].fire(_muzzle, direction, self)


func is_alive() -> bool:
	return not _is_dead


func _get_debug_label() -> String:
	return ""


func get_player() -> CharacterBase:
	if not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as CharacterBase
	return _player_cache


func player_position() -> Vector2:
	var p := get_player()
	return p.global_position if p != null else global_position


# — Internal —

func _tick_all_weapons(delta: float) -> void:
	for w: Weapon in _weapon_instances:
		w.tick(delta)


func begin_spawn() -> void:
	_is_spawning = true
	$CollisionShape2D.set_deferred("disabled", true)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("spawn"):
		sprite.play("spawn")
		sprite.animation_finished.connect(_end_spawn, CONNECT_ONE_SHOT)
	else:
		_end_spawn()


func _end_spawn() -> void:
	_is_spawning = false
	$CollisionShape2D.set_deferred("disabled", false)


func _update_facing_animation() -> void:
	if anim_data == null or _is_dead or _is_spawning:
		return
	var state := "walk" if (velocity.length_squared() > 1.0 && velocity.normalized().dot(_facing) > 0.0 ) else "idle"
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
