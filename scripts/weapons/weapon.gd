extends Resource
class_name Weapon

enum FireMode { SINGLE, AUTO, BURST }

@export var fire_mode: FireMode = FireMode.SINGLE
@export var fire_rate: float = 0.2  # seconds between shots
@export var damage: float = 10.0
@export var bullet_speed: float = 400.0
@export var knockback_force: float = 150.0
@export var bullet_range: float = 0.0  # world units; 0 = infinite
@export var bullet_range_fx: ImpactFXData
@export var hud_icon: Texture2D
@export var bullet_scene: PackedScene
@export var bullet_trail_scene: PackedScene
@export var shoot_sound: AudioStream
@export var muzzle_flash_scene: PackedScene
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0       # total cone width in degrees
@export var spread_randomness: float = 0.5  # 0 = evenly spaced, 1 = fully random
@export var rechamber_sound: AudioStream
@export var rechamber_sound_delay: float = 0.15
@export var burst_count: int = 3      # pellets per burst (BURST mode only)
@export var burst_delay: float = 0.08 # seconds between burst shots
@export var fire_shake_strength: float = 0.0  # 0 = no shake
@export var suppress_wall_impacts: bool = false
@export var aim_assist_angle: float = 0.0    # degrees, half-cone; 0 = disabled
@export var aim_assist_range: float = 150.0
@export var aim_assist_strength: float = 0.15
@export var grenade_data: GrenadeData        # if set, fire() throws a grenade instead of bullets
@export var ammo_type: AmmoType              # null = infinite ammo

signal fired(direction: Vector2)

var _cooldown: float = 0.0
var _shot_counter: int = 0
var _burst_remaining: int = 0
var owner_node: Node  # set by player on equip; used for ammo checks

func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func can_fire() -> bool:
	return _cooldown <= 0.0

func cancel_burst() -> void:
	_burst_remaining = 0

func fire(muzzle: Marker2D, direction: Vector2) -> void:
	if not can_fire():
		return
	_cooldown = fire_rate
	_fire_single(muzzle, direction)
	if fire_mode == FireMode.BURST and burst_count > 1:
		_burst_remaining = burst_count - 1
		_fire_burst(muzzle, direction)

func _fire_single(muzzle: Marker2D, direction: Vector2) -> void:
	_shot_counter += 1
	var shot_id := _shot_counter
	fired.emit(direction)
	_play_sound(muzzle)
	_spawn_muzzle_flash(muzzle, direction)
	if grenade_data:
		_spawn_grenade(muzzle, direction, shot_id)
	else:
		for pellet_dir in _get_spread_directions(direction):
			_spawn_bullet(muzzle, pellet_dir, shot_id)
		if rechamber_sound:
			_play_rechamber_sound(muzzle)

func _fire_burst(muzzle: Marker2D, direction: Vector2) -> void:
	while _burst_remaining > 0:
		await muzzle.get_tree().create_timer(burst_delay, true, false, true).timeout
		if not is_instance_valid(muzzle) or _burst_remaining <= 0:
			return
		if owner_node != null and not owner_node.has_ammo(self):
			_burst_remaining = 0
			return
		_burst_remaining -= 1
		_fire_single(muzzle, direction)

func _spawn_muzzle_flash(muzzle: Marker2D, direction: Vector2) -> void:
	if muzzle_flash_scene == null:
		return
	var flash = muzzle_flash_scene.instantiate()
	muzzle.add_child(flash)
	flash.position = Vector2.ZERO
	flash.rotation = direction.angle()
	flash.flash()

func _play_sound(muzzle: Marker2D) -> void:
	if shoot_sound == null:
		return
	AudioPool.play(shoot_sound, muzzle.global_position)

func _get_spread_directions(base_dir: Vector2) -> Array[Vector2]:
	if pellet_count <= 1:
		return [base_dir]
	var dirs: Array[Vector2] = []
	var half_spread := deg_to_rad(spread_angle * 0.5)
	var slot_width := deg_to_rad(spread_angle) / pellet_count
	for i in pellet_count:
		var t := float(i) / float(pellet_count - 1)
		var even_angle := lerpf(-half_spread, half_spread, t)
		var jitter := randf_range(-slot_width * 0.5, slot_width * 0.5) * spread_randomness
		dirs.append(Vector2.from_angle(base_dir.angle() + even_angle + jitter))
	return dirs

func _play_rechamber_sound(muzzle: Marker2D) -> void:
	await muzzle.get_tree().create_timer(rechamber_sound_delay, true, false, true).timeout
	if is_instance_valid(muzzle):
		AudioPool.play(rechamber_sound, muzzle.global_position)

func _spawn_grenade(muzzle: Marker2D, direction: Vector2, shot_id: int) -> void:
	assert(grenade_data.grenade_scene != null, "Weapon: grenade_data.grenade_scene not set")
	var grenade = grenade_data.grenade_scene.instantiate()
	var ysort = muzzle.get_tree().get_first_node_in_group("ysort")
	assert(ysort != null, "Weapon: no node in group 'ysort'")
	grenade.init(grenade_data, direction, bullet_speed, muzzle.get_parent(), shot_id)
	ysort.add_child(grenade)
	grenade.global_position = muzzle.global_position

func _spawn_bullet(muzzle: Marker2D, direction: Vector2, shot_id: int = -1) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	# Set properties that are read in _ready before adding to tree
	bullet.trail_scene = bullet_trail_scene
	var ysort = muzzle.get_tree().get_first_node_in_group("ysort")
	assert(ysort != null, "Weapon: no node in group 'ysort' — add the YSort node to the 'ysort' group")
	ysort.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.knockback_force = knockback_force
	bullet.travel_range = bullet_range
	bullet.range_fx = bullet_range_fx
	bullet.shot_id = shot_id
	bullet.suppress_wall_impacts = suppress_wall_impacts
	bullet.owner_node = muzzle.get_parent()
