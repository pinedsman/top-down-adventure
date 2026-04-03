extends EnemyPatrolBase
class_name EnemyGrunt

@export_group("Combat")
@export var shoot_range: float = 130.0
@export var preferred_distance: float = 100.0  # orbit distance when repositioning
@export var shot_count: int = 3
@export var arc_angle: float = 45.0            # total spread in degrees
@export var wind_up: float = 0.3
@export var shot_interval: float = 0.25
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

	for i in shot_count:
		if not is_alive():
			return
		var to_player := (player_position() - global_position).normalized()
		var spread := randf_range(-arc_angle * 0.5, arc_angle * 0.5)
		var dir := to_player.rotated(deg_to_rad(spread))
		shoot_weapon(0, global_position + dir * 500.0)
		if i < shot_count - 1:
			await rest(shot_interval)

	await _reposition()
	await rest(randf_range(reposition_wait_min, reposition_wait_max))


# Drives the nav agent directly each frame, stopping when within shoot_range.
func _navigate_to_shoot_range() -> void:
	assert(_nav_agent != null,
		"EnemyGrunt: scene must have a NavigationAgent2D")
	await get_tree().physics_frame
	while is_alive() and _can_see_player():
		if global_position.distance_to(player_position()) <= shoot_range:
			break
		_nav_agent.target_position = player_position()
		var next_pos := _nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		_facing = dir
		velocity = dir * move_speed
		await get_tree().physics_frame
	velocity = Vector2.ZERO


# Navigate to a point orbiting the player at a random side-angle.
func _reposition() -> void:
	var side := 1.0 if randf() > 0.5 else -1.0
	var angle := deg_to_rad(randf_range(reposition_angle_min, reposition_angle_max)) * side
	var to_player := (player_position() - global_position).normalized()
	var orbit_dir := to_player.rotated(angle)
	var target := player_position() - orbit_dir * preferred_distance
	await _navigate_interruptible(target, 2.0)
