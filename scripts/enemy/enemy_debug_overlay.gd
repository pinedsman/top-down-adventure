extends Node2D
class_name EnemyDebugOverlay

var _enemy: EnemyBase


func setup(enemy: EnemyBase) -> void:
	_enemy = enemy


func _ready() -> void:
	top_level = true


func _process(_delta: float) -> void:
	if not is_instance_valid(_enemy):
		queue_free()
		return
	global_position = _enemy.global_position
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_enemy):
		return

	var font := ThemeDB.fallback_font
	var font_size := 10

	# State label centred above the enemy
	var label := _enemy._get_debug_label()
	if label != "":
		var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(-label_w * 0.5, -38.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	if _enemy is EnemyPatrolBase:
		_draw_patrol_info(_enemy as EnemyPatrolBase, font, font_size)


func _draw_patrol_info(enemy: EnemyPatrolBase, font: Font, font_size: int) -> void:
	# Unalerted range (cyan), alerted range (orange) — both always visible for comparison
	draw_arc(Vector2.ZERO, enemy.sight_range, 0.0, TAU, 64,
			Color(0.3, 0.9, 1.0, 0.5), 1.0, false)
	if enemy.alerted_sight_range != enemy.sight_range:
		draw_arc(Vector2.ZERO, enemy.alerted_sight_range, 0.0, TAU, 64,
				Color(1.0, 0.6, 0.2, 0.5), 1.0, false)

	# Last known player position
	if enemy._last_known_pos != Vector2.ZERO:
		var lkp := enemy._last_known_pos - global_position
		draw_circle(lkp, 4.0, Color(1.0, 0.2, 0.2, 0.8))
		draw_line(Vector2.ZERO, lkp, Color(1.0, 0.2, 0.2, 0.4), 1.0)
		draw_string(font, lkp + Vector2(6.0, 4.0), "LKP",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.2, 0.2, 0.8))

	if enemy.waypoints.is_empty():
		# Mark the implicit origin
		var origin_local := enemy._patrol_origin - global_position
		draw_circle(origin_local, 4.0, Color(1.0, 1.0, 0.0, 0.5))
		return

	# Draw waypoint nodes and connecting path
	for i in enemy.waypoints.size():
		var wp: Marker2D = enemy.waypoints[i]
		if not is_instance_valid(wp):
			continue
		var p := wp.global_position - global_position
		var is_current := i == enemy._wp_index
		var col := Color.YELLOW if is_current else Color(1.0, 1.0, 0.0, 0.45)

		draw_circle(p, 4.0 if is_current else 3.0, col)
		draw_string(font, p + Vector2(6.0, 4.0), str(i),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

		# Line to next waypoint
		var next_i := _next_waypoint_index(enemy, i)
		if next_i >= 0:
			var np: Marker2D = enemy.waypoints[next_i]
			if is_instance_valid(np):
				draw_line(p, np.global_position - global_position,
						Color(1.0, 1.0, 0.0, 0.3), 1.0)

	# Arrow from enemy to current target waypoint
	var cur_wp: Marker2D = enemy.waypoints[enemy._wp_index]
	if is_instance_valid(cur_wp):
		draw_dashed_line(Vector2.ZERO, cur_wp.global_position - global_position,
				Color.CYAN, 1.0, 6.0)


func _next_waypoint_index(enemy: EnemyPatrolBase, i: int) -> int:
	if enemy.waypoints.size() < 2:
		return -1
	if enemy.patrol_loop:
		return (i + 1) % enemy.waypoints.size()
	# Bounce: only draw forward edges (reverse edges are implied)
	return i + 1 if i < enemy.waypoints.size() - 1 else -1
