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
		var patrol := _enemy as EnemyPatrolBase
		_draw_patrol_info(patrol, font, font_size)
		_draw_investigate_info(patrol, font, font_size)


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


func _draw_investigate_info(enemy: EnemyPatrolBase, font: Font, font_size: int) -> void:
	if enemy._dbg_investigate_pos == Vector2.ZERO:
		return
	var target_local := enemy._dbg_investigate_pos - global_position

	# LOS check to noise target: green = can see it, red = blocked.
	var can_see := enemy._can_see_point(enemy._dbg_investigate_pos)
	var los_color := Color(0.2, 1.0, 0.2, 0.8) if can_see else Color(1.0, 0.2, 0.2, 0.8)
	draw_dashed_line(Vector2.ZERO, target_local, los_color, 1.0, 6.0)

	# Noise origin dot (where the shot came from).
	draw_circle(target_local, 5.0, Color(1.0, 0.4, 1.0, 0.9))
	var los_label := "LOS:yes" if can_see else "LOS:no"
	draw_string(font, target_local + Vector2(7.0, 4.0), "NOISE  " + los_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.4, 1.0, 0.9))

	# Nav target dot (snapped navmesh point — may differ from noise origin).
	if enemy._dbg_investigate_nav_target != Vector2.ZERO:
		var nav_local := enemy._dbg_investigate_nav_target - global_position
		draw_circle(nav_local, 4.0, Color(1.0, 0.8, 0.0, 0.9))
		draw_line(target_local, nav_local, Color(1.0, 0.8, 0.0, 0.5), 1.0)
		draw_string(font, nav_local + Vector2(7.0, 4.0), "NAV_TARGET",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.8, 0.0, 0.9))

	# Nav agent path.
	if enemy._nav_agent != null:
		var path := enemy._nav_agent.get_current_navigation_path()
		for i in range(1, path.size()):
			var a := path[i - 1] - global_position
			var b := path[i] - global_position
			draw_line(a, b, Color(1.0, 0.4, 1.0, 0.4), 1.0)
		# Nav finished indicator — bright if finished, dim if still navigating.
		var nav_done := enemy._nav_agent.is_navigation_finished()
		var nav_col := Color(1.0, 0.1, 0.1, 0.9) if nav_done else Color(0.2, 1.0, 0.2, 0.5)
		var nav_label := "NAV:done" if nav_done else "NAV:active"
		draw_string(font, target_local + Vector2(7.0, 14.0), nav_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, nav_col)


func _next_waypoint_index(enemy: EnemyPatrolBase, i: int) -> int:
	if enemy.waypoints.size() < 2:
		return -1
	if enemy.patrol_loop:
		return (i + 1) % enemy.waypoints.size()
	# Bounce: only draw forward edges (reverse edges are implied)
	return i + 1 if i < enemy.waypoints.size() - 1 else -1
