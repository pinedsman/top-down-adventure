extends RefCounted
class_name Weapon

# Runtime instance wrapping a WeaponData config resource.
# One Weapon is created per character per weapon slot — never shared.

var data: WeaponData

var _cooldown: float = 0.0
var _shot_counter: int = 0
var _burst_remaining: int = 0

signal fired(direction: Vector2)


func _init(weapon_data: WeaponData) -> void:
	data = weapon_data


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


func can_fire() -> bool:
	return _cooldown <= 0.0


func cancel_burst() -> void:
	_burst_remaining = 0


func interrupt() -> void:
	pass  # overridden by MeleeWeapon


func can_switch() -> bool:
	return true  # overridden by MeleeWeapon


func fire(muzzle: Marker2D, direction: Vector2, shooter: Node) -> void:
	if not can_fire():
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
	if data.grenade_data:
		_spawn_grenade(muzzle, direction, shot_id, shooter)
	else:
		for pellet_dir in _get_spread_directions(direction):
			_spawn_bullet(muzzle, pellet_dir, shot_id, shooter)
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


func _spawn_bullet(muzzle: Marker2D, direction: Vector2, shot_id: int, shooter: Node) -> void:
	if data.bullet_scene == null:
		return
	var bullet := data.bullet_scene.instantiate()
	bullet.trail_scene = data.bullet_trail_scene
	_get_ysort(muzzle).add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = data.damage
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
	_get_ysort(muzzle).add_child(grenade)
	grenade.global_position = muzzle.global_position


func _get_ysort(muzzle: Marker2D) -> Node:
	var ysort := muzzle.get_tree().get_first_node_in_group("ysort")
	assert(ysort != null, "Weapon: no node in group 'ysort'")
	return ysort
