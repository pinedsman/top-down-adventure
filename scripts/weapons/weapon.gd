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
@export var shoot_sound: AudioStream
@export var muzzle_flash_scene: PackedScene
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0       # total cone width in degrees
@export var spread_randomness: float = 0.5  # 0 = evenly spaced, 1 = fully random
@export var rechamber_sound: AudioStream
@export var rechamber_sound_delay: float = 0.15
@export var fire_shake_strength: float = 0.0  # 0 = no shake
@export var suppress_wall_impacts: bool = false
@export var aim_assist_angle: float = 0.0    # degrees, half-cone; 0 = disabled
@export var aim_assist_range: float = 150.0
@export var aim_assist_strength: float = 0.15

signal fired(direction: Vector2)

var _cooldown: float = 0.0
var _shot_counter: int = 0

func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func can_fire() -> bool:
	return _cooldown <= 0.0

func fire(muzzle: Marker2D, direction: Vector2) -> void:
	if not can_fire():
		return
	_cooldown = fire_rate
	_shot_counter += 1
	var shot_id := _shot_counter
	fired.emit(direction)
	_play_sound(muzzle)
	_spawn_muzzle_flash(muzzle, direction)
	for pellet_dir in _get_spread_directions(direction):
		_spawn_bullet(muzzle, pellet_dir, shot_id)
	if rechamber_sound:
		_play_rechamber_sound(muzzle)

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
	await muzzle.get_tree().create_timer(rechamber_sound_delay).timeout
	if is_instance_valid(muzzle):
		AudioPool.play(rechamber_sound, muzzle.global_position)

func _spawn_bullet(muzzle: Marker2D, direction: Vector2, shot_id: int = -1) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	var ysort = muzzle.get_tree().get_first_node_in_group("ysort")
	assert(ysort != null, "Weapon: no node in group 'ysort' — add the YSort node to the 'ysort' group")
	ysort.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.knockback_force = knockback_force
	bullet.range = bullet_range
	bullet.range_fx = bullet_range_fx
	bullet.shot_id = shot_id
	bullet.suppress_wall_impacts = suppress_wall_impacts
	bullet.owner_node = muzzle.get_parent()
