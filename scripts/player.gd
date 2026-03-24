extends CharacterBody2D

const SPEED = 100.0

@export var laser_length: float = 100
@export var anim_data: PlayerAnimation
@export var weapon: Weapon

var _aim_direction: Vector2 = Vector2.RIGHT
var _fire_held: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _is_gamepad: bool = false
var crosshair: Node2D
var facingDirection: int
var _currentAnimEntry: AnimationEntry

func _ready() -> void:
	crosshair = get_tree().get_first_node_in_group("crosshair")
	assert(crosshair != null, "Player requires a node in the 'crosshair' group")
	on_input_changed()
	_setup_camera_limits()

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
	_update_laser()
	_update_crosshair()
	player_movement(delta)
	player_animation(delta)
	_tick_weapon(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("shoot"):
		var pressed = event.get_action_strength("shoot") > 0.5
		if pressed and not _fire_held:
			_fire_held = true
			if weapon and weapon.fire_mode == Weapon.FireMode.SINGLE:
				weapon.fire(_get_current_muzzle(), _aim_direction, _currentAnimEntry.bullet_behind_player)
		elif not pressed:
			_fire_held = false

func _update_aim() -> void:
	var stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var last_is_gamepad = _is_gamepad
	var mouse_pos = get_global_mouse_position()

	if stick.length() > 0.2:
		_is_gamepad = true
		_aim_direction = stick.normalized()
	elif mouse_pos != _last_mouse_pos:
		_is_gamepad = false
		var mouse = mouse_pos - global_position
		if mouse.length() > 1.0:
			_aim_direction = mouse.normalized()

	if _is_gamepad != last_is_gamepad:
		on_input_changed()

	_last_mouse_pos = mouse_pos

func on_input_changed() -> void:
	if (_is_gamepad):
		crosshair.hide()
		$LaserSight.show()
	else:
		crosshair.show()
		$LaserSight.hide()

func _update_laser() -> void:
	var laser = $LaserSight
	laser.clear_points()
	var start = to_local($Muzzle.global_position)
	var end = to_local($Muzzle.global_position + _aim_direction * laser_length)
	
	laser.add_point(start)
	laser.add_point(end)
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
	facingDirection = get_index_for_normalized_vector(_aim_direction)

	_currentAnimEntry = anim_data.get_entry(state, facingDirection)
	if _currentAnimEntry:
		anim.flip_h = _currentAnimEntry.flip
		anim.play(_currentAnimEntry.animationIndex)
		$Muzzle.position = _currentAnimEntry.muzzle_offset
		$MuzzleBehind.position = _currentAnimEntry.muzzle_offset

func _get_current_muzzle() -> Marker2D:
	return $MuzzleBehind if _currentAnimEntry.bullet_behind_player else $Muzzle

func get_index_for_normalized_vector(in_vector: Vector2) -> int:
	var angle_deg = fmod(rad_to_deg(atan2(in_vector.x, -in_vector.y)) + 360.0, 360.0)
	var per_slice = 360.0 / 8
	for i in range(7):
		if angle_deg >= per_slice * (i + 0.5) and angle_deg < per_slice * (i + 1.5):
			return i + 1
	return 0
