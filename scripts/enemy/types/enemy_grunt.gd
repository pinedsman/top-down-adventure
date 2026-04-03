extends EnemyPatrolBase
class_name EnemyGrunt

@export_group("Combat")
@export var shoot_range: float = 130.0
@export var preferred_distance: float = 100.0  # orbit distance when repositioning
@export var shot_count: int = 3
@export var arc_angle: float = 45.0            # total spread in degrees
@export var wind_up: float = 0.3
@export var shot_interval: float = 0.25
@export var post_burst_wait_min: float = 0.4
@export var post_burst_wait_max: float = 0.9
@export var reposition_chance: float = 0.4   # 0–1 probability of repositioning after a burst
@export var reposition_angle_min: float = 70.0
@export var reposition_angle_max: float = 130.0
@export var reposition_wait_min: float = 0.2
@export var reposition_wait_max: float = 0.6


func _spotted_behavior() -> void:
	await _navigate_to_shoot_range()
	if not is_alive() or not _can_see_player():
		return

	face(player_position() - global_position)
	await rest(wind_up)
	if not is_alive():
		return

	await _fire_burst()

	await rest(randf_range(post_burst_wait_min, post_burst_wait_max))
	if not is_alive():
		return

	if not _can_see_player() or randf() < reposition_chance:
		await _reposition()
		await rest(randf_range(reposition_wait_min, reposition_wait_max))


func _fire_burst() -> void:
	for i in shot_count:
		if not is_alive():
			return
		# Grunt controls burst timing — bypass weapon cooldown so shot_interval is authoritative
		if _weapon_instances.size() > 0:
			_weapon_instances[0].reset_cooldown()
		var to_player := (player_position() - global_position).normalized()
		var spread := randf_range(-arc_angle * 0.5, arc_angle * 0.5)
		var dir := to_player.rotated(deg_to_rad(spread))
		shoot_weapon(0, global_position + dir * 500.0)
		if i < shot_count - 1:
			await rest(shot_interval)


# Approach the player until within shoot_range or LOS is lost.
func _navigate_to_shoot_range() -> void:
	await _navigate_interruptible(player_position(), 20.0,
		func() -> bool: return not _can_see_player() or global_position.distance_to(player_position()) <= shoot_range)


# Navigate to a point orbiting the player at a random side-angle.
func _reposition() -> void:
	var side := 1.0 if randf() > 0.5 else -1.0
	var angle := deg_to_rad(randf_range(reposition_angle_min, reposition_angle_max)) * side
	var to_player := (player_position() - global_position).normalized()
	var orbit_dir := to_player.rotated(angle)
	var target := player_position() - orbit_dir * preferred_distance
	await _navigate_interruptible(target, 2.0)
