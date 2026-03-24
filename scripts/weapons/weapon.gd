extends Resource
class_name Weapon

enum FireMode { SINGLE, AUTO, BURST }

@export var fire_mode: FireMode = FireMode.SINGLE
@export var fire_rate: float = 0.2  # seconds between shots
@export var damage: float = 10.0
@export var bullet_speed: float = 400.0
@export var bullet_scene: PackedScene
@export var shoot_sound: AudioStream
@export var muzzle_flash_scene: PackedScene

var _cooldown: float = 0.0

func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func can_fire() -> bool:
	return _cooldown <= 0.0

func fire(muzzle: Marker2D, direction: Vector2, behind_player: bool = false) -> void:
	if not can_fire():
		return
	_cooldown = fire_rate
	_play_sound(muzzle)
	_spawn_muzzle_flash(muzzle, direction, behind_player)
	_spawn_bullet(muzzle, direction, behind_player)

func _spawn_muzzle_flash(muzzle: Marker2D, direction: Vector2, behind_player: bool) -> void:
	if muzzle_flash_scene == null:
		return
	var flash = muzzle_flash_scene.instantiate()
	muzzle.add_child(flash)
	flash.position = Vector2.ZERO
	flash.rotation = direction.angle()
	if behind_player:
		flash.z_as_relative = true
		flash.z_index = -1
	flash.flash()

func _play_sound(muzzle: Marker2D) -> void:
	if shoot_sound == null:
		return
	AudioPool.play(shoot_sound, muzzle.global_position)

func _spawn_bullet(muzzle: Marker2D, direction: Vector2, behind_player: bool) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	var ysort = muzzle.get_tree().current_scene.get_node("ySort")
	ysort.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.owner_node = muzzle.get_parent()
