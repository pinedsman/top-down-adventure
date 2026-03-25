extends CharacterBody2D

const SPEED = 100.0

@export var laser_length: float = 100
@export var anim_data: PlayerAnimation
@export var weapons: Array[Weapon]
@export var max_health: float = 100.0
@export var pre_hurt_sound: AudioStream
@export var hurt_sound: AudioStream
@export var death_sound: AudioStream
@export var invulnerability_duration: float = 1.0
@export var hit_duration: float = 0.3
@export var knockback_force: float = 200.0
@export var hit_stop_duration: float = 0.1
@export var hit_impact_fx: ImpactFXData

signal weapon_changed(weapon: Weapon)
signal health_changed(current: float, maximum: float)

var weapon: Weapon:
	get: return weapons[_weapon_index] if weapons.size() > 0 else null

var _weapon_index: int = 0
var _aim_direction: Vector2 = Vector2.RIGHT
var _laser: Line2D
var _camera: CameraController
var _fire_held: bool = false
var crosshair: Node2D
var facingDirection: int
var _currentAnimEntry: AnimationEntry

var _health: float
var _is_dead: bool = false
var _flash_tween: Tween
var _invulnerable: bool = false
var _invulnerable_timer: float = 0.0
var _is_hit: bool = false
var _hit_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_shot_id: int = -1

func _ready() -> void:
	crosshair = get_tree().get_first_node_in_group("crosshair")
	assert(crosshair != null, "Player requires a node in the 'crosshair' group")
	_laser = $LaserSight
	_camera = $Camera2D
	_health = max_health
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputManager.is_gamepad)
	HitStop.ended.connect(_on_hit_stop_ended)
	_connect_weapon(weapon)
	weapon_changed.emit(weapon)
	health_changed.emit(_health, max_health)

func _physics_process(delta: float) -> void:
	_tick_hit_state(delta)
	_update_aim()
	_apply_aim_assist(delta)
	_update_crosshair()
	player_movement(delta)
	player_animation(delta)
	_tick_weapon(delta)
	_update_laser()

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_end"):  # End key
		take_damage(10.0, Vector2.from_angle(randf() * TAU))
		return

	if event.is_action("shoot"):
		var pressed = event.get_action_strength("shoot") > 0.5
		if pressed and not _fire_held and not _is_hit:
			_fire_held = true
			if weapon and weapon.fire_mode == Weapon.FireMode.SINGLE:
				weapon.fire(_get_current_muzzle(), _aim_direction)
		elif not pressed:
			_fire_held = false
	elif event.is_action_pressed("weapon_next"):
		_weapon_index = (_weapon_index + 1) % weapons.size()
		_fire_held = false
		_connect_weapon(weapon)
		weapon_changed.emit(weapon)
	elif event.is_action_pressed("weapon_prev"):
		_weapon_index = (_weapon_index - 1 + weapons.size()) % weapons.size()
		_fire_held = false
		_connect_weapon(weapon)
		weapon_changed.emit(weapon)

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO, impact_position: Vector2 = global_position, shot_id: int = -1) -> void:
	var same_shot := shot_id >= 0 and shot_id == _last_shot_id
	if _invulnerable and not same_shot:
		return
	_last_shot_id = shot_id
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, max_health)

	if same_shot:
		_knockback_velocity += knockback_direction
		return

	AudioPool.play(hurt_sound, global_position)
	_knockback_velocity = knockback_direction
	_is_hit = true
	_hit_timer = hit_duration
	_invulnerable = true
	_invulnerable_timer = invulnerability_duration

	var sprite := $AnimatedSprite2D as CanvasItem
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	sprite.modulate = Color(5.0, 5.0, 5.0)
	_flash_tween = create_tween()
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	_spawn_hit_impact(impact_position)
	_camera.shake(knockback_direction.normalized())
	_camera.zoom_punch()
	HitStop.request(hit_stop_duration)

func _tick_hit_state(delta: float) -> void:
	if _is_hit:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			_is_hit = false
			if _health <= 0.0:
				die()
				return
	if _invulnerable:
		_invulnerable_timer -= delta
		var sprite := $AnimatedSprite2D
		sprite.visible = fmod(_invulnerable_timer * 10.0, 1.0) >= 0.5
		if _invulnerable_timer <= 0.0:
			_invulnerable = false
			sprite.visible = true

func _update_aim() -> void:
	if InputManager.is_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.0:
			_aim_direction = stick.normalized()
	else:
		var mouse := get_global_mouse_position() - global_position
		if mouse.length() > 1.0:
			_aim_direction = mouse.normalized()

func _apply_aim_assist(delta: float) -> void:
	if not InputManager.is_gamepad or weapon == null or weapon.aim_assist_angle <= 0.0:
		return
	var threshold := deg_to_rad(weapon.aim_assist_angle)
	var best_dir := Vector2.ZERO
	var best_angle := threshold
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length_squared() > weapon.aim_assist_range * weapon.aim_assist_range:
			continue
		var angle := absf(_aim_direction.angle_to(to_enemy.normalized()))
		if angle < best_angle:
			best_angle = angle
			best_dir = to_enemy.normalized()
	if best_dir != Vector2.ZERO:
		var t := 1.0 - pow(1.0 - weapon.aim_assist_strength, delta * 60.0)
		_aim_direction = _aim_direction.lerp(best_dir, t).normalized()

func _on_input_mode_changed(is_gamepad: bool) -> void:
	if is_gamepad:
		crosshair.hide()
		_laser.show()
	else:
		crosshair.show()
		_laser.hide()

func _update_laser() -> void:
	var laser = _laser
	laser.clear_points()
	var parent := laser.get_parent() as Node2D
	var muzzle_pos: Vector2 = parent.global_position
	laser.add_point(parent.to_local(muzzle_pos))
	laser.add_point(parent.to_local(muzzle_pos + _aim_direction * laser_length))
	var mat = laser.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("laser_length", laser_length)

func _tick_weapon(delta: float) -> void:
	if weapon == null or _is_hit:
		return
	weapon.tick(delta)
	if _fire_held and weapon.fire_mode == Weapon.FireMode.AUTO:
		weapon.fire(_get_current_muzzle(), _aim_direction)

func player_movement(_delta: float) -> void:
	if _is_hit:
		velocity = _knockback_velocity
		_knockback_velocity = lerp(_knockback_velocity, Vector2.ZERO, 0.2)
	else:
		velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is Enemy and collider.contact_damage > 0.0:
			var knockback: Vector2 = (global_position - collider.global_position).normalized() * knockback_force
			take_damage(collider.contact_damage, knockback, collision.get_position())
			break

func _update_crosshair() -> void:
	crosshair.position = get_viewport().get_mouse_position()

func player_animation(_delta: float) -> void:
	if _is_dead:
		return
	var anim := $AnimatedSprite2D
	var state: String
	if _is_hit and anim_data.has_state("hit"):
		state = "hit"
	else:
		state = "walk" if velocity.length() > 0.01 else "idle"
	facingDirection = PlayerAnimation.direction_to_index(_aim_direction)

	_currentAnimEntry = anim_data.get_entry(state, facingDirection)
	if _currentAnimEntry:
		anim.flip_h = _currentAnimEntry.flip
		anim.play(_currentAnimEntry.animationIndex)
		$Muzzle.position = _currentAnimEntry.muzzle_offset
		$MuzzleBehind.position = _currentAnimEntry.muzzle_offset
		var target_muzzle = _get_current_muzzle()
		if _laser.get_parent() != target_muzzle:
			_laser.reparent(target_muzzle)
			_laser.position = Vector2.ZERO

func _spawn_hit_impact(impact_position: Vector2) -> void:
	if hit_impact_fx == null:
		return
	hit_impact_fx.spawn(impact_position, Node.PROCESS_MODE_ALWAYS)

func _connect_weapon(w: Weapon) -> void:
	if w == null:
		return
	if not w.fired.is_connected(_on_weapon_fired):
		w.fired.connect(_on_weapon_fired)

func _on_weapon_fired(direction: Vector2) -> void:
	if weapon and weapon.fire_shake_strength > 0.0:
		_camera.shake(-direction, weapon.fire_shake_strength)

func _on_hit_stop_ended() -> void:
	if not Input.is_action_pressed("shoot"):
		_fire_held = false

func die() -> void:
	_is_dead = true
	_invulnerable = false
	$AnimatedSprite2D.visible = true
	$AnimatedSprite2D.modulate = Color.WHITE
	set_physics_process(false)
	set_process_unhandled_input(false)
	$WallCollision.set_deferred("disabled", true)
	if death_sound:
		AudioPool.play(death_sound, global_position)
	if anim_data.has_state("death"):
		var entry := anim_data.get_entry("death", facingDirection)
		if entry:
			var anim := $AnimatedSprite2D
			anim.flip_h = entry.flip
			anim.play(entry.animationIndex)

func _get_current_muzzle() -> Marker2D:
	assert(_currentAnimEntry != null, "Player: no AnimationEntry for current state/direction — check anim_data is fully populated")
	return $MuzzleBehind if _currentAnimEntry.bullet_behind_player else $Muzzle
