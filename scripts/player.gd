extends CharacterBody2D

const SPEED = 100.0

@export var laser_length: float = 100
@export var anim_data: PlayerAnimation
@export var weapons: Array[Weapon]

var weapon: Weapon:
	get: return weapons[_weapon_index] if weapons.size() > 0 else null

var _weapon_index: int = 0
var _aim_direction: Vector2 = Vector2.RIGHT
var _laser: Line2D
var _fire_held: bool = false
var crosshair: Node2D
var facingDirection: int
var _currentAnimEntry: AnimationEntry

func _ready() -> void:
	crosshair = get_tree().get_first_node_in_group("crosshair")
	assert(crosshair != null, "Player requires a node in the 'crosshair' group")
	_laser = $LaserSight
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputManager.is_gamepad)
	_setup_camera_limits()
	weapon_changed.emit(weapon)

func _setup_camera_limits() -> void:
	var ground = get_tree().get_first_node_in_group("ground_tilemap")
	if ground == null:
		return
	var rect = ground.get_used_rect()
	var tile_size: Vector2i = ground.tile_set.tile_size
	var cam = $Camera2D
	cam.limit_left = rect.position.x * tile_size.x
	cam.limit_top = rect.position.y * tile_size.y
	cam.limit_right = (rect.position.x + rect.size.x) * tile_size.x
	cam.limit_bottom = (rect.position.y + rect.size.y) * tile_size.y
	
func _physics_process(delta: float) -> void:
	_update_aim()
	_update_crosshair()
	player_movement(delta)
	player_animation(delta)
	_tick_weapon(delta)
	_update_laser()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("shoot"):
		var pressed = event.get_action_strength("shoot") > 0.5
		if pressed and not _fire_held:
			_fire_held = true
			if weapon and weapon.fire_mode == Weapon.FireMode.SINGLE:
				weapon.fire(_get_current_muzzle(), _aim_direction, _currentAnimEntry.bullet_behind_player)
		elif not pressed:
			_fire_held = false
	elif event.is_action_pressed("weapon_next"):
		_weapon_index = (_weapon_index + 1) % weapons.size()
		_fire_held = false
		weapon_changed.emit(weapon)
	elif event.is_action_pressed("weapon_prev"):
		_weapon_index = (_weapon_index - 1 + weapons.size()) % weapons.size()
		_fire_held = false
		weapon_changed.emit(weapon)

signal weapon_changed(weapon: Weapon)

func _update_aim() -> void:
	if InputManager.is_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.0:
			_aim_direction = stick.normalized()
	else:
		var mouse := get_global_mouse_position() - global_position
		if mouse.length() > 1.0:
			_aim_direction = mouse.normalized()

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
	if weapon == null:
		return
	weapon.tick(delta)
	if _fire_held and weapon.fire_mode == Weapon.FireMode.AUTO:
		weapon.fire(_get_current_muzzle(), _aim_direction, _currentAnimEntry.bullet_behind_player)

func player_movement(_delta: float) -> void:
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	move_and_slide()
	
func _update_crosshair() -> void:
	crosshair.position = get_viewport().get_mouse_position()

func player_animation(_delta: float) -> void:
	var anim = $AnimatedSprite2D
	var state = "walk" if velocity.length() > 0.01 else "idle"
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

func _get_current_muzzle() -> Marker2D:
	assert(_currentAnimEntry != null, "Player: no AnimationEntry for current state/direction — check anim_data is fully populated")
	return $MuzzleBehind if _currentAnimEntry.bullet_behind_player else $Muzzle
