extends CharacterBase
class_name Player

const SPEED = 100.0

@export var laser_length: float = 100
@export var invulnerability_duration: float = 1.0
@export var hit_duration: float = 0.3
@export var knockback_force: float = 200.0
@export_flags_2d_physics var aim_assist_mask: int = 0
@export var dash_data: DashData
@export var weapon_slots: Array[WeaponSlotData] = []

signal weapon_changed(weapon: Weapon)
signal ammo_changed(ammo_type: AmmoType, current: int)

var weapon: Weapon:
	get: return _weapon_instances[_weapon_index] if _weapon_instances.size() > 0 else null

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
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_direction: Vector2 = Vector2.ZERO
var _saved_collision_layer: int = 0
var _slot_instances: Array[Weapon] = []
var _cached_active_melee: MeleeWeapon = null
var _aim_assist_area: Area2D
var _aim_assist_shape: CircleShape2D
var _aim_assist_enemies: Array[Node2D] = []

@onready var dash_particle = $DashParticle

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
	for w: Weapon in _weapon_instances:
		if w.ammo_type != null and not _ammo.has(w.ammo_type):
			_ammo[w.ammo_type] = w.ammo_type.max_capacity
	for slot: WeaponSlotData in weapon_slots:
		assert(slot.weapon_data != null,
			"Player: WeaponSlotData '%s' has null weapon_data — assign a WeaponData resource" % slot.resource_path)
		var instance := slot.weapon_data.create_instance()
		_slot_instances.append(instance)
		instance.fired.connect(func(dir: Vector2) -> void:
			if instance.fire_shake_strength > 0.0:
				_camera.shake(-dir, instance.fire_shake_strength))
	_setup_aim_assist_area()
	_connect_weapon(weapon)
	weapon_changed.emit(weapon)
	health_changed.emit(_health, max_health)

func _connect_weapon(w: Weapon) -> void:
	super(w)
	_on_input_mode_changed(InputManager.is_gamepad)

func _physics_process(delta: float) -> void:
	_cached_active_melee = _active_melee_slot()
	_tick_hit_state(delta)
	_tick_dash(delta)
	if not _is_dashing:
		_update_aim(delta)
		_apply_aim_assist(delta)
		_update_crosshair()
		_update_laser()
	player_movement(delta)
	player_animation(delta)
	_tick_weapon(delta)
	if _cached_active_melee != null and _cached_active_melee.debug_draw_arc:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_end"):  # End key
		take_damage(10.0, Vector2.from_angle(randf() * TAU))
		return
	if OS.is_debug_build() and event.is_action_pressed("ui_home"):  # Home key
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.has_method("die"):
				enemy.die()
		return

	if event.is_action("shoot"):
		if _current_anim_entry == null:
			return
		var pressed = event.get_action_strength("shoot") > 0.5
		if pressed and not _fire_held and not _is_hit and not _is_dashing and not _slot_blocking_fire():
			_fire_held = true
			if weapon and weapon.fire_mode in [WeaponData.FireMode.SINGLE, WeaponData.FireMode.BURST]:
				if has_ammo(weapon):
					if weapon.can_fire():
						weapon.fire(_get_current_muzzle(), _aim_direction, self)
					else:
						_fire_buffer = fire_buffer_window
		elif pressed and _is_dashing and not _is_hit:
			if weapon and weapon.fire_mode in [WeaponData.FireMode.SINGLE, WeaponData.FireMode.BURST]:
				if _dash_timer <= fire_buffer_window:
					_fire_buffer = fire_buffer_window
		elif not pressed:
			_fire_held = false
	elif event.is_action_pressed("dash"):
		if not _is_dashing and _dash_cooldown_timer <= 0.0 and dash_data != null and not _is_hit:
			_start_dash()
	elif event.is_action_pressed("weapon_next"):
		if weapon != null and weapon.can_switch() and _weapon_instances.size() > 1:
			weapon.cancel_burst()
			_weapon_index = (_weapon_index + 1) % _weapon_instances.size()
			_fire_held = false
			_fire_buffer = 0.0
			_connect_weapon(weapon)
			_update_aim_assist_collider()
			weapon_changed.emit(weapon)
	elif event.is_action_pressed("weapon_prev"):
		if weapon != null and weapon.can_switch() and _weapon_instances.size() > 1:
			weapon.cancel_burst()
			_weapon_index = (_weapon_index - 1 + _weapon_instances.size()) % _weapon_instances.size()
			_fire_held = false
			_fire_buffer = 0.0
			_connect_weapon(weapon)
			_update_aim_assist_collider()
			weapon_changed.emit(weapon)
	else:
		for i in _slot_instances.size():
			var slot := weapon_slots[i]
			if slot.input_action.is_empty():
				continue
			if event.is_action_pressed(slot.input_action):
				if not _is_hit and not _is_dashing and _current_anim_entry != null:
					_slot_instances[i].fire(_get_current_muzzle(), _aim_direction, self)
				break


# — CharacterBase overrides —

func _can_take_damage() -> bool:
	if _invulnerable:
		return false
	if _is_dashing and dash_data != null and dash_data.invincible_during_dash:
		return false
	return true


func _on_take_damage(same_shot: bool, knockback_direction: Vector2, _impact_position: Vector2) -> void:
	if weapon:
		weapon.interrupt()
	for instance in _slot_instances:
		instance.interrupt()
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
	var _swinging_melee := _active_melee_slot()
	if _swinging_melee != null:
		var t := 1.0 - pow(1.0 - _swinging_melee.swing_rotation_scale(), delta * 60.0)
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


# — Dash —

func _start_dash() -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dash_dir := move_input.normalized() if move_input.length() > 0.01 else _aim_direction
	_is_dashing = true
	_dash_direction = dash_dir
	dash_particle.emitting = true
	_facing = dash_dir
	
	#HACK to match direction index since we are directly accessing the PNG
	var dash_indexes: Array[int] = [ 3, 4, 5, 5, 0, 1, 1, 2 ]
	var i := DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count)
	
	AudioPool.play(dash_data.dash_sound,global_position)
	
	dash_particle.material.set_shader_parameter("particles_anim_row", dash_indexes[i])
	_dash_timer = dash_data.dash_duration
	_dash_velocity = dash_dir * dash_data.dash_speed
	_fire_held = false
	_fire_buffer = 0.0
	if dash_data.invincible_during_dash:
		_saved_collision_layer = collision_layer
		collision_layer = 0
	_laser.hide()
	if InputManager.is_gamepad:
		crosshair.hide()


func _tick_dash(delta: float) -> void:
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if not _is_dashing:
		return
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_end_dash()
		return
	_apply_dash_steering()


func _apply_dash_steering() -> void:
	var progress := 1.0 - (_dash_timer / dash_data.dash_duration)
	var control_scale := dash_data.control_curve.sample(progress) \
			if dash_data.control_curve else progress

	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fwd := _dash_direction
	var lat := fwd.orthogonal()

	var steer := Vector2.ZERO
	if move_input.length() > 0.01:
		steer += lat * move_input.dot(lat) * dash_data.lateral_control
		var med := move_input.dot(fwd)
		if med < 0.0:
			steer += fwd * med * dash_data.medial_control

	_dash_velocity = (fwd + steer * control_scale) * dash_data.dash_speed


func _end_dash() -> void:
	_is_dashing = false
	dash_particle.emitting = false
	_dash_cooldown_timer = dash_data.dash_cooldown
	if dash_data.invincible_during_dash:
		set_deferred("collision_layer", _saved_collision_layer)
	_on_input_mode_changed(InputManager.is_gamepad)
	if Input.is_action_pressed("shoot"):
		_fire_held = true


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
	for instance in _slot_instances:
		if not _is_hit:
			instance.tick(delta)
	if weapon == null or _is_hit or _is_dashing or _slot_blocking_fire():
		return
	weapon.tick(delta)
	if weapon.fire_mode == WeaponData.FireMode.AUTO:
		if _fire_held and has_ammo(weapon):
			weapon.fire(_get_current_muzzle(), _aim_direction, self)
	elif _fire_buffer > 0.0 and weapon.can_fire() and has_ammo(weapon):
		_fire_buffer = 0.0
		weapon.fire(_get_current_muzzle(), _aim_direction, self)


func has_ammo(w: Weapon) -> bool:
	return w.ammo_type == null or _ammo.get(w.ammo_type, 0) > 0

func get_ammo(ammo_type: AmmoType) -> int:
	return _ammo.get(ammo_type, 0)

func add_ammo(ammo_type: AmmoType, amount: int) -> int:
	var old_count = _ammo[ammo_type]
	_ammo[ammo_type] = mini(_ammo.get(ammo_type, 0) + amount, ammo_type.max_capacity)
	var delta = _ammo[ammo_type] - old_count
	if ( delta > 0 ):
		ammo_changed.emit(ammo_type, _ammo[ammo_type])
	return delta


func _on_hit_stop_ended() -> void:
	if not Input.is_action_pressed("shoot"):
		_fire_held = false


# — Movement —

func player_movement(_delta: float) -> void:
	if _is_dashing:
		velocity = _dash_velocity
		move_and_slide()
		return
	if _is_hit:
		velocity = _knockback_velocity
		_knockback_velocity = lerp(_knockback_velocity, Vector2.ZERO, 0.2)
	else:
		var speed_scale := _cached_active_melee.swing_move_scale() if _cached_active_melee != null else 1.0
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
	if _is_dashing and anim_data.has_state("dash"):
		state = "dash"
	elif _is_hit and anim_data.has_state("hit"):
		state = "hit"
	elif _cached_active_melee != null and anim_data.has_state("swipe"):
		state = "swipe"
	else:
		state = "walk" if velocity.length() > 0.01 else "idle"
	if not _is_dashing:
		_facing = _aim_direction

	_current_anim_entry = anim_data.get_entry(state, DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count))
	if _current_anim_entry:
		anim.flip_h = _current_anim_entry.flip
		var anim_speed := -1.0 if state == "walk" and velocity.normalized().dot(_facing) < 0.0 else 1.0
		anim.play(_current_anim_entry.animationIndex, anim_speed)
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
	var melee := _cached_active_melee
	if melee == null or not melee.debug_draw_arc:
		return
	var swing := melee.swings[clamp(melee._swing_index, 0, melee.swings.size() - 1)] if melee.swings.size() > 0 else null
	if swing == null:
		return
	var dir := melee._swing_direction
	var base_angle := dir.angle()
	var half_arc := deg_to_rad(swing.arc_angle * 0.5)
	var range_x: float = swing.arc_range
	var range_y: float = swing.arc_width if swing.arc_width > 0.0 else swing.arc_range
	var active := melee._state == MeleeWeapon.SwingState.ACTIVE
	var col := Color(1, 0.3, 0, 0.7) if active else Color(1, 1, 0, 0.3)
	# Draw arc-clipped ellipse: for each polar angle, find the ellipse surface point
	var points: PackedVector2Array = [Vector2.ZERO]
	var steps := 32
	for i in steps + 1:
		var theta := lerpf(-half_arc, half_arc, float(i) / float(steps))
		var cx := cos(theta)
		var cy := sin(theta)
		var r := 1.0 / sqrt((cx / range_x) * (cx / range_x) + (cy / range_y) * (cy / range_y))
		points.append(Vector2(cx, cy).rotated(base_angle) * r)
	points.append(Vector2.ZERO)
	draw_polyline(points, col, 1.5)


func _active_melee_slot() -> MeleeWeapon:
	for instance in _slot_instances:
		if instance is MeleeWeapon and (instance as MeleeWeapon).is_swinging():
			return instance as MeleeWeapon
	return null


func _slot_blocking_fire() -> bool:
	return _cached_active_melee != null


func _get_current_muzzle() -> Marker2D:
	assert(_current_anim_entry != null, "Player: no AnimationEntry for current state/direction — check anim_data is fully populated")
	return $MuzzleBehind if _current_anim_entry.bullet_behind_player else $Muzzle


# — Room transitions —

func enter_room(ysort: Node, spawn_position: Vector2) -> void:
	reparent(ysort, true)
	global_position = spawn_position


# — State persistence (used by WaveModeManager) —

func save_to_state() -> PlayerState:
	var state := PlayerState.new()
	state.health = _health
	state.weapons = weapons.duplicate()
	state.weapon_index = _weapon_index
	state.ammo = _ammo.duplicate()
	return state


func restore_from_state(state: PlayerState) -> void:
	weapons = state.weapons.duplicate()
	_weapon_instances.clear()
	for wd: WeaponData in weapons:
		_weapon_instances.append(wd.create_instance())
	_weapon_index = clampi(state.weapon_index, 0, maxi(_weapon_instances.size() - 1, 0))
	_ammo = state.ammo.duplicate()
	_health = state.health
	health_changed.emit(_health, max_health)
	_connect_weapon(weapon)
	weapon_changed.emit(weapon)
