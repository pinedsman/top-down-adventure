extends RefCounted
class_name Weapon

# Runtime instance wrapping a WeaponData config resource.
# One Weapon is created per character per weapon slot — never shared.

static var _ysort_cache: Node = null

var data: WeaponData

var _cooldown: float = 0.0
var _shot_counter: int = 0
var _burst_remaining: int = 0
# -1 = infinite (magazine_size == 0), >= 0 = current rounds remaining
var _magazine: int = -1

# Charge state
var _charge: float = 0.0
var _is_charging: bool = false
var _charge_muzzle: Marker2D = null
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_shooter: Node = null
var _charge_fx: Node = null
var _charge_audio: AudioStreamPlayer2D = null

signal fired(direction: Vector2)


func _init(weapon_data: WeaponData) -> void:
	data = weapon_data
	_magazine = weapon_data.magazine_size if weapon_data.magazine_size > 0 else -1


# — Data pass-throughs (keeps call sites unchanged) —
var fire_mode: WeaponData.FireMode:
	get: return data.fire_mode
var ammo_type: AmmoType:
	get: return data.ammo_type
var hud_icon: Texture2D:
	get: return data.hud_icon
var show_laser: bool:
	get: return data.show_laser
var fire_shake_strength: float:
	get: return data.fire_shake_strength
var aim_assist_angle: float:
	get: return data.aim_assist_angle
var aim_assist_range: float:
	get: return data.aim_assist_range
var aim_assist_strength: float:
	get: return data.aim_assist_strength
var grenade_data: GrenadeData:
	get: return data.grenade_data
var burst_count: int:
	get: return data.burst_count


# — Core API —

func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _is_charging and data.charge_time > 0.0:
		_charge = minf(_charge + delta / data.charge_time, 1.0)
		if _charge >= 1.0 and data.charge_mode != WeaponData.ChargeMode.HOLD_TO_CHARGE_FIRE_ON_RELEASE:
			_execute_charge_fire()


func can_fire() -> bool:
	return _cooldown <= 0.0

## Returns false if the weapon's ability blocks firing for this shooter.
## Always true for non-ability weapons.
func can_activate(shooter: Node) -> bool:
	if data.ability == null:
		return true
	return data.ability.can_execute(shooter, self)

## Call when can_activate() returned false to let the ability give feedback.
func notify_fire_prevented(shooter: Node) -> void:
	if data.ability != null:
		data.ability.on_fire_prevented(shooter, self)


func reset_cooldown() -> void:
	_cooldown = 0.0


# — Magazine API (weapon-ammo mode) —

func magazine_ammo() -> int:
	return _magazine  # -1 = infinite

func has_magazine_ammo() -> bool:
	return _magazine != 0  # -1 (infinite) or > 0 both have ammo

func spend_magazine_ammo() -> void:
	if _magazine > 0:
		_magazine -= 1

func refill_magazine() -> void:
	_magazine = data.magazine_size if data.magazine_size > 0 else -1


# — Charge API —

func is_charge_weapon() -> bool:
	return data.charge_time > 0.0

func is_charging() -> bool:
	return _is_charging

## Returns 0.0–1.0 charge progress. Always 1.0 for non-charge weapons.
func charge_progress() -> float:
	return _charge if is_charge_weapon() else 1.0

func start_charge(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	if _is_charging or not can_fire():
		return
	_is_charging = true
	_charge = 0.0
	_charge_muzzle = muzzle
	_charge_direction = direction
	_charge_shooter = shooter
	_spawn_charge_fx(muzzle)

## Call on button release. No-op in AUTO_CHARGE mode — tick() handles firing.
## In hold-to-charge modes: fires or cancels depending on charge level and fire_on_partial_charge.
func release_charge(direction: Vector2) -> void:
	if not _is_charging or data.charge_mode == WeaponData.ChargeMode.AUTO_CHARGE:
		return
	_charge_direction = direction
	if data.fire_on_partial_charge or _charge >= 1.0:
		_execute_charge_fire()
	else:
		cancel_charge()

func cancel_charge() -> void:
	if _is_charging and data.ability != null and _charge_shooter != null:
		data.ability.on_charge_cancelled(_charge_shooter, self)
	_is_charging = false
	_charge = 0.0
	_charge_muzzle = null
	_charge_shooter = null
	_destroy_charge_fx()

func _execute_charge_fire() -> void:
	if _charge_muzzle == null or _charge_shooter == null:
		cancel_charge()
		return
	if not can_activate(_charge_shooter):
		cancel_charge()
		return
	var charge := _charge
	var muzzle := _charge_muzzle
	var direction := _charge_direction
	var shooter := _charge_shooter
	cancel_charge()
	_cooldown = data.fire_rate
	_shot_counter += 1
	var shot_id := _shot_counter
	fired.emit(direction)
	_play_sound(muzzle)
	_spawn_muzzle_flash(muzzle, direction)
	_fire_with_charge(muzzle, direction, shot_id, shooter, charge)

func _spawn_charge_fx(muzzle: Marker2D) -> void:
	if data.charge_fx_scene != null:
		_charge_fx = data.charge_fx_scene.instantiate()
		muzzle.add_child(_charge_fx)
	if data.charge_loop_sound != null:
		_charge_audio = AudioStreamPlayer2D.new()
		_charge_audio.stream = data.charge_loop_sound
		_charge_audio.autoplay = true
		muzzle.add_child(_charge_audio)

func _destroy_charge_fx() -> void:
	if is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null
	if is_instance_valid(_charge_audio):
		_charge_audio.queue_free()
	_charge_audio = null


func cancel_burst() -> void:
	_burst_remaining = 0


func interrupt() -> void:
	pass  # overridden by MeleeWeapon


func can_switch() -> bool:
	return true  # overridden by MeleeWeapon

func is_blocking() -> bool:
	return data.blocks_other_weapons and _is_charging

func is_blocking_dash() -> bool:
	return data.blocks_dash and _is_charging


func fire(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	if not can_fire() or not can_activate(shooter):
		return
	_cooldown = data.fire_rate
	_fire_single(muzzle, direction, shooter)
	if data.fire_mode == WeaponData.FireMode.BURST and data.burst_count > 1:
		_burst_remaining = data.burst_count - 1
		_fire_burst(muzzle, direction, shooter)


func _fire_single(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	_shot_counter += 1
	var shot_id := _shot_counter
	fired.emit(direction)
	_play_sound(muzzle)
	_spawn_muzzle_flash(muzzle, direction)
	_fire_with_charge(muzzle, direction, shot_id, shooter, 1.0)


## Routes to ability, grenade, or bullet. charge scales bullet damage.
func _fire_with_charge(muzzle: Marker2D, direction: Vector2, shot_id: int, shooter: Node, charge: float) -> void:
	if data.ability != null:
		data.ability.execute(shooter, self, charge)
	elif data.grenade_data:
		_spawn_grenade(muzzle, direction, shot_id, shooter)
	else:
		for pellet_dir in _get_spread_directions(direction):
			_spawn_bullet(muzzle, pellet_dir, shot_id, shooter, charge)
		if data.rechamber_sound:
			_play_rechamber_sound(muzzle)


func _fire_burst(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	while _burst_remaining > 0:
		await muzzle.get_tree().create_timer(data.burst_delay, true, false, true).timeout
		if not is_instance_valid(muzzle) or _burst_remaining <= 0:
			return
		if not shooter.has_ammo(self):
			_burst_remaining = 0
			return
		_burst_remaining -= 1
		_fire_single(muzzle, direction, shooter)


# — Spawn helpers —

func _spawn_muzzle_flash(muzzle: Marker2D, direction: Vector2) -> void:
	if data.muzzle_flash_scene == null:
		return
	var flash := data.muzzle_flash_scene.instantiate()
	muzzle.add_child(flash)
	flash.position = Vector2.ZERO
	flash.rotation = direction.angle()
	flash.flash()


func _play_sound(muzzle: Marker2D) -> void:
	if data.shoot_sound == null:
		return
	AudioPool.play(data.shoot_sound, muzzle.global_position)


func _play_rechamber_sound(muzzle: Marker2D) -> void:
	await muzzle.get_tree().create_timer(data.rechamber_sound_delay, true, false, true).timeout
	if is_instance_valid(muzzle):
		AudioPool.play(data.rechamber_sound, muzzle.global_position)


func _get_spread_directions(base_dir: Vector2) -> Array[Vector2]:
	if data.pellet_count <= 1:
		return [base_dir]
	var dirs: Array[Vector2] = []
	var half_spread := deg_to_rad(data.spread_angle * 0.5)
	var slot_width := deg_to_rad(data.spread_angle) / data.pellet_count
	for i in data.pellet_count:
		var t := float(i) / float(data.pellet_count - 1)
		var even_angle := lerpf(-half_spread, half_spread, t)
		var jitter := randf_range(-slot_width * 0.5, slot_width * 0.5) * data.spread_randomness
		dirs.append(Vector2.from_angle(base_dir.angle() + even_angle + jitter))
	return dirs


func _spawn_bullet(muzzle: Marker2D, direction: Vector2, shot_id: int, shooter: Node, charge: float = 1.0) -> void:
	if data.bullet_scene == null:
		return
	var bullet := data.bullet_scene.instantiate()
	bullet.trail_scene = data.bullet_trail_scene
	_get_ysort().add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = data.damage * charge
	bullet.speed = data.bullet_speed
	bullet.knockback_force = data.knockback_force
	bullet.travel_range = data.bullet_range
	bullet.range_fx = data.bullet_range_fx
	bullet.shot_id = shot_id
	bullet.suppress_wall_impacts = data.suppress_wall_impacts
	bullet.hit_mask = data.bullet_collision_mask
	bullet.owner_node = shooter


func _spawn_grenade(muzzle: Marker2D, direction: Vector2, shot_id: int, shooter: Node) -> void:
	assert(data.grenade_data.grenade_scene != null, "Weapon: grenade_data.grenade_scene not set")
	var grenade := data.grenade_data.grenade_scene.instantiate()
	grenade.init(data.grenade_data, direction, data.bullet_speed, shooter, shot_id)
	_get_ysort().add_child(grenade)
	grenade.global_position = muzzle.global_position


func _get_ysort() -> Node:
	if not is_instance_valid(_ysort_cache):
		_ysort_cache = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("ysort")
		assert(_ysort_cache != null, "Weapon: no node in group 'ysort'")
	return _ysort_cache
