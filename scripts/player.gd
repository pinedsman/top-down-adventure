extends CharacterBase

const SPEED = 100.0

@export var laser_length: float = 100
@export var invulnerability_duration: float = 1.0
@export var hit_duration: float = 0.3
@export var knockback_force: float = 200.0
@export_flags_2d_physics var aim_assist_mask: int = 0

signal weapon_changed(weapon: Weapon)
signal ammo_changed(ammo_type: AmmoType, current: int)

var weapon: Weapon:
	get: return weapons[_weapon_index] if weapons.size() > 0 else null

var _weapon_index: int = 0
var _aim_direction: Vector2 = Vector2.RIGHT
var _laser: Line2D
var _camera: CameraController
@export var fire_buffer_window: float = 0.15

var _fire_held: bool = false
var _fire_buffer: float = 0.0
var crosshair: Node2D
var _is_hit: bool = false
var _hit_timer: float = 0.0
var _invulnerable: bool = false
var _invulnerable_timer: float = 0.0
var _ammo: Dictionary = {}  # AmmoType -> int
var _aim_assist_area: Area2D
var _aim_assist_shape: CircleShape2D
var _aim_assist_enemies: Array[Node2D] = []


func _ready() -> void:
	super._ready()
	crosshair = get_tree().get_first_node_in_group("crosshair")
	assert(crosshair != null, "Player requires a node in the 'crosshair' group")
	_laser = $LaserSight
	_laser.hide()
	_camera = $Camera2D
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputManager.is_gamepad)
	HitStop.ended.connect(_on_hit_stop_ended)
	for w in weapons:
		if w.ammo_type != null and not _ammo.has(w.ammo_type):
			_ammo[w.ammo_type] = w.ammo_type.max_capacity
	_setup_aim_assist_area()
	_connect_weapon(weapon)
	weapon_changed.emit(weapon)
	health_changed.emit(_health, max_health)

func _connect_weapon(w: Weapon) -> void:
	super(w)
	_on_input_mode_changed(InputManager.is_gamepad)

func _physics_process(delta: float) -> void:
	_tick_hit_state(delta)
	_update_aim(delta)
	_apply_aim_assist(delta)
	_update_crosshair()
	player_movement(delta)
	player_animation(delta)
	_tick_weapon(delta)
	_update_laser()
	if weapon is MeleeWeapon and weapon.debug_draw_arc:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_end"):  # End key
		take_damage(10.0, Vector2.from_angle(randf() * TAU))
		return

	if event.is_action("shoot"):
		if _current_anim_entry == null:
			return
		var pressed = event.get_action_strength("shoot") > 0.5
		if pressed and not _fire_held and not _is_hit:
			_fire_held = true
			if weapon and weapon.fire_mode in [Weapon.FireMode.SINGLE, Weapon.FireMode.BURST]:
				if not has_ammo(weapon):
					pass
				elif weapon.can_fire():
					weapon.fire(_get_current_muzzle(), _aim_direction)
				else:
					_fire_buffer = fire_buffer_window
		elif not pressed:
			_fire_held = false
	elif event.is_action_pressed("weapon_next"):
		if weapon.can_switch():
			weapon.cancel_burst()
			_weapon_index = (_weapon_index + 1) % weapons.size()
			_fire_held = false
			_fire_buffer = 0.0
			_connect_weapon(weapon)
			_update_aim_assist_collider()
			weapon_changed.emit(weapon)
	elif event.is_action_pressed("weapon_prev"):
		if weapon.can_switch():
			weapon.cancel_burst()
			_weapon_index = (_weapon_index - 1 + weapons.size()) % weapons.size()
			_fire_held = false
			_fire_buffer = 0.0
			_connect_weapon(weapon)
			_update_aim_assist_collider()
			weapon_changed.emit(weapon)


# — CharacterBase overrides —

func _can_take_damage() -> bool:
	return not _invulnerable


func _on_take_damage(same_shot: bool, knockback_direction: Vector2, _impact_position: Vector2) -> void:
	if weapon:
		weapon.interrupt()
	if same_shot:
		return
	_is_hit = true
	_hit_timer = hit_duration
	_invulnerable = true
	_invulnerable_timer = invulnerability_duration
	_camera.shake(knockback_direction.normalized())
	_camera.zoom_punch()


func _on_die() -> void:
	_invulnerable = false
	var sprite := $AnimatedSprite2D
	sprite.visible = true
	sprite.modulate = Color.WHITE
	set_process_unhandled_input(false)
	$WallCollision.set_deferred("disabled", true)
	_laser.hide()
	crosshair.hide()
	if anim_data.has_state("death"):
		var entry := anim_data.get_entry("death", DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count))
		if entry:
			sprite.flip_h = entry.flip
			sprite.play(entry.animationIndex)


func _on_weapon_fired(direction: Vector2) -> void:
	if weapon and weapon.fire_shake_strength > 0.0:
		_camera.shake(-direction, weapon.fire_shake_strength)
	if weapon and weapon.ammo_type != null:
		_ammo[weapon.ammo_type] = maxi(_ammo.get(weapon.ammo_type, 0) - 1, 0)
		ammo_changed.emit(weapon.ammo_type, _ammo[weapon.ammo_type])


# — Hit state —

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


# — Aim —

func _update_aim(delta: float) -> void:
	var target: Vector2 = Vector2.ZERO
	if InputManager.is_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.0:
			target = stick.normalized()
	else:
		var mouse := get_global_mouse_position() - global_position
		if mouse.length() > 1.0:
			target = mouse.normalized()
	if target == Vector2.ZERO:
		return
	if weapon is MeleeWeapon and (weapon as MeleeWeapon).is_swinging():
		var t := 1.0 - pow(1.0 - (weapon as MeleeWeapon).swing_rotation_scale(), delta * 60.0)
		_aim_direction = _aim_direction.lerp(target, t).normalized()
	else:
		_aim_direction = target


func _setup_aim_assist_area() -> void:
	_aim_assist_shape = CircleShape2D.new()
	var col := CollisionShape2D.new()
	col.shape = _aim_assist_shape
	_aim_assist_area = Area2D.new()
	_aim_assist_area.collision_layer = 0
	_aim_assist_area.collision_mask = aim_assist_mask
	_aim_assist_area.add_child(col)
	add_child(_aim_assist_area)
	_aim_assist_area.body_entered.connect(_on_aim_assist_body_entered)
	_aim_assist_area.body_exited.connect(_on_aim_assist_body_exited)
	_update_aim_assist_collider()


func _update_aim_assist_collider() -> void:
	if _aim_assist_area == null:
		return
	var enabled := weapon != null and weapon.aim_assist_angle > 0.0
	_aim_assist_area.monitoring = enabled
	if enabled:
		_aim_assist_shape.radius = weapon.aim_assist_range
	if not enabled:
		_aim_assist_enemies.clear()


func _on_aim_assist_body_entered(body: Node2D) -> void:
	_aim_assist_enemies.append(body)


func _on_aim_assist_body_exited(body: Node2D) -> void:
	_aim_assist_enemies.erase(body)


func _apply_aim_assist(delta: float) -> void:
	if not InputManager.is_gamepad or weapon == null or weapon.aim_assist_angle <= 0.0:
		return
	var threshold := deg_to_rad(weapon.aim_assist_angle)
	var best_dir := Vector2.ZERO
	var best_angle := threshold
	for enemy: Node2D in _aim_assist_enemies:
		if not is_instance_valid(enemy) or enemy.get("_is_dead"):
			continue
		var to_enemy := enemy.global_position - global_position
		var angle := absf(_aim_direction.angle_to(to_enemy.normalized()))
		if angle < best_angle:
			best_angle = angle
			best_dir = to_enemy.normalized()
	if best_dir != Vector2.ZERO:
		var t := 1.0 - pow(1.0 - weapon.aim_assist_strength, delta * 60.0)
		_aim_direction = _aim_direction.lerp(best_dir, t).normalized()


func _on_input_mode_changed(is_gamepad: bool) -> void:
	if _is_dead:
		return
		
	if is_gamepad:
		crosshair.hide()
		update_laser_visibility()
	else:
		crosshair.show()
		_laser.hide()

func update_laser_visibility() -> void:
	if (weapon != null && weapon.show_laser):
		_laser.show()
	else:
		_laser.hide()

# — Laser —

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


# — Weapon —

func _tick_weapon(delta: float) -> void:
	_fire_buffer = maxf(_fire_buffer - delta, 0.0)
	if weapon == null or _is_hit:
		return
	weapon.tick(delta)
	if weapon.fire_mode == Weapon.FireMode.AUTO:
		if _fire_held and has_ammo(weapon):
			weapon.fire(_get_current_muzzle(), _aim_direction)
	elif _fire_buffer > 0.0 and weapon.can_fire() and has_ammo(weapon):
		_fire_buffer = 0.0
		weapon.fire(_get_current_muzzle(), _aim_direction)


func has_ammo(w: Weapon) -> bool:
	return w.ammo_type == null or _ammo.get(w.ammo_type, 0) > 0

func get_ammo(ammo_type: AmmoType) -> int:
	return _ammo.get(ammo_type, 0)

func add_ammo(ammo_type: AmmoType, amount: int) -> void:
	_ammo[ammo_type] = mini(_ammo.get(ammo_type, 0) + amount, ammo_type.max_capacity)
	ammo_changed.emit(ammo_type, _ammo[ammo_type])


func _on_hit_stop_ended() -> void:
	if not Input.is_action_pressed("shoot"):
		_fire_held = false


# — Movement —

func player_movement(_delta: float) -> void:
	if _is_hit:
		velocity = _knockback_velocity
		_knockback_velocity = lerp(_knockback_velocity, Vector2.ZERO, 0.2)
	else:
		var speed_scale := (weapon as MeleeWeapon).swing_move_scale() if weapon is MeleeWeapon else 1.0
		velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED * speed_scale
	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is EnemyBase and collider.contact_damage > 0.0:
			var knockback: Vector2 = (global_position - collider.global_position).normalized() * knockback_force
			take_damage(collider.contact_damage, knockback, collision.get_position())
			break


# — Animation —

func player_animation(_delta: float) -> void:
	if _is_dead:
		return
	var anim := $AnimatedSprite2D
	var state: String
	if _is_hit and anim_data.has_state("hit"):
		state = "hit"
	elif weapon is MeleeWeapon and weapon.is_swinging() and anim_data.has_state("swipe"):
		state = "swipe"
	else:
		state = "walk" if velocity.length() > 0.01 else "idle"
	_facing = _aim_direction

	_current_anim_entry = anim_data.get_entry(state, DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count))
	if _current_anim_entry:
		anim.flip_h = _current_anim_entry.flip
		anim.play(_current_anim_entry.animationIndex)
		$Muzzle.position = _current_anim_entry.muzzle_offset
		$MuzzleBehind.position = _current_anim_entry.muzzle_offset
		var target_muzzle = _get_current_muzzle()
		if _laser.get_parent() != target_muzzle:
			_laser.reparent(target_muzzle)
			_laser.position = Vector2.ZERO


func _update_crosshair() -> void:
	crosshair.position = get_viewport().get_mouse_position()


# — Debug draw —

func _draw() -> void:
	if not (weapon is MeleeWeapon and weapon.debug_draw_arc):
		return
	var melee := weapon as MeleeWeapon
	var swing := melee.swings[clamp(melee._swing_index, 0, melee.swings.size() - 1)] if melee.swings.size() > 0 else null
	if swing == null:
		return
	var dir := melee._swing_direction
	var half_arc := deg_to_rad(swing.arc_angle * 0.5)
	var r := swing.arc_range
	var start_angle := dir.angle() - half_arc
	var end_angle := dir.angle() + half_arc
	var active := melee._state == MeleeWeapon.SwingState.ACTIVE
	var col := Color(1, 0.3, 0, 0.7) if active else Color(1, 1, 0, 0.3)
	draw_arc(Vector2.ZERO, r, start_angle, end_angle, 32, col, 1.5)
	draw_line(Vector2.ZERO, Vector2.from_angle(start_angle) * r, col, 1.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(end_angle) * r, col, 1.0)


func _get_current_muzzle() -> Marker2D:
	assert(_current_anim_entry != null, "Player: no AnimationEntry for current state/direction — check anim_data is fully populated")
	return $MuzzleBehind if _current_anim_entry.bullet_behind_player else $Muzzle
