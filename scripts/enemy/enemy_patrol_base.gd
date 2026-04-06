extends EnemyBase
class_name EnemyPatrolBase

@export_group("Patrol")
@export var waypoints: Array[Marker2D] = []
@export var patrol_loop: bool = true        # false = bounce back and forth
@export var patrol_wait_time: float = 0.5  # pause at each waypoint

@export_group("Detection")
@export var sight_range: float = 150.0          # unalerted detection radius
@export var alerted_sight_range: float = 250.0  # radius while SPOTTED or RETURNING
@export_flags_2d_physics var sight_mask: int = 1  # layers that block LOS
@export var return_distance: float = 300.0  # how far from path origin before returning

enum PatrolState { PATROL, SPOTTED, INVESTIGATING, RETURNING }

@export_group("Noise")
@export var noise_hearing_radius: float = 0.0  # 0 = use event radius; > 0 = cap enemy's personal range

var _patrol_state: PatrolState = PatrolState.PATROL
var _last_known_pos: Vector2 = Vector2.ZERO
var _damage_alert_pos: Vector2 = Vector2.ZERO  # set on hit while PATROL; cleared on transition
var _noise_alert_pos: Vector2 = Vector2.ZERO   # set on gunshot noise while PATROL; cleared on investigation
var _patrol_origin: Vector2   # position at _ready; fallback when no waypoints
var _wp_index: int = 0
var _bounce_dir: int = 1

# — Investigation debug state (read by EnemyDebugOverlay) —
var _dbg_investigate_pos: Vector2 = Vector2.ZERO
var _dbg_investigate_nav_target: Vector2 = Vector2.ZERO  # snapped navmesh point actually navigated to
var _dbg_investigate_stop_reason: String = ""  # "player" | "los" | "nav_done" | "timeout" | ""


func _ready() -> void:
	super._ready()
	_patrol_origin = global_position
	NoiseManager.noise_emitted.connect(_on_noise_emitted)


func _on_take_damage(same_shot: bool, knockback_direction: Vector2, impact_position: Vector2) -> void:
	super(same_shot, knockback_direction, impact_position)
	# Alert from damage only when unalerted and not already chasing.
	# knockback_direction points away from attacker, so attacker is at -knockback_direction.
	if same_shot or _patrol_state != PatrolState.PATROL:
		return
	var attack_dir := -knockback_direction.normalized() if knockback_direction != Vector2.ZERO \
			else Vector2.from_angle(randf() * TAU)
	_damage_alert_pos = global_position + attack_dir * alerted_sight_range


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _patrol_state != PatrolState.PATROL and _can_see_player():
		_last_known_pos = player_position()


# — Top-level behavior loop —

func _run_behavior() -> void:
	while is_alive():
		if _can_see_player():
			_patrol_state = PatrolState.SPOTTED
			_last_known_pos = player_position()
			_damage_alert_pos = Vector2.ZERO
			_noise_alert_pos = Vector2.ZERO
			await _run_spotted()
		elif _damage_alert_pos != Vector2.ZERO:
			_patrol_state = PatrolState.SPOTTED
			_last_known_pos = _damage_alert_pos
			_damage_alert_pos = Vector2.ZERO
			_noise_alert_pos = Vector2.ZERO
			await _run_spotted()
		elif _noise_alert_pos != Vector2.ZERO:
			var pos := _noise_alert_pos
			_noise_alert_pos = Vector2.ZERO
			await _run_investigate(pos)
		else:
			_patrol_state = PatrolState.PATROL
			await _run_patrol_step()


# — Patrol —

func _run_patrol_step() -> void:
	# No waypoints: treat starting position as an implicit single waypoint.
	var target := waypoints[_wp_index].global_position if waypoints.size() > 0 \
			else _patrol_origin
	await _navigate_interruptible(target)

	if _can_see_player():
		return   # outer loop switches to spotted

	if patrol_wait_time > 0.0:
		await rest(patrol_wait_time)
		if _can_see_player():
			return

	_advance_waypoint()


# — Spotted —

func _run_spotted() -> void:
	while is_alive():
		await _spotted_behavior()

		if not _can_see_player() and (_should_return() or _at_last_known_pos()):
			break   # lost player: either drifted too far, or reached last known position

	if is_alive():
		_patrol_state = PatrolState.RETURNING
		await _run_return_to_path()


func navigate_toward_spotted_target(duration: float) -> Signal:
	assert(_nav_agent != null,
		"EnemyPatrolBase: scene must have a NavigationAgent2D to use navigate_toward_spotted_target()")
	return run_behavior(NavigateToSpottedTargetBehavior.new(_nav_agent, self), duration)


func _spotted_behavior() -> void:
	# Override in subclasses for enemy-specific attack/chase sequence.
	await rest(1.0)


# — Return to path —

func _run_return_to_path() -> void:
	var target := waypoints[0].global_position if waypoints.size() > 0 else _patrol_origin
	_wp_index = 0
	_bounce_dir = 1
	# Navigate back, but resume spotted if player reappears
	await _navigate_interruptible(target)


# — Interruptible navigation —
# Loops frame-by-frame so patrol can react to spotting the player mid-traverse.

func _navigate_interruptible(target: Vector2, timeout: float = 20.0, stop_condition: Callable = Callable()) -> void:
	assert(_nav_agent != null,
		"EnemyPatrolBase: scene must have a NavigationAgent2D to use patrol")
	_active_behavior = NavigateToPointBehavior.new(_nav_agent, target)
	var end := Time.get_ticks_usec() / 1_000_000.0 + timeout
	# Wait one frame so the nav agent can process the new target before we check finished.
	await get_tree().physics_frame
	while is_alive():
		if Time.get_ticks_usec() / 1_000_000.0 >= end:
			break
		if _nav_agent.is_navigation_finished():
			break
		# When a stop_condition is provided it replaces the default LOS-break so callers
		# that chase the player (always visible) can supply their own exit criteria.
		if not stop_condition.is_null():
			if stop_condition.call():
				break
		elif _can_see_player():
			break
		if _damage_alert_pos != Vector2.ZERO:
			break
		if _noise_alert_pos != Vector2.ZERO:
			break
		await get_tree().physics_frame
	_active_behavior = null
	velocity = Vector2.ZERO


# — Noise investigation —

func _on_noise_emitted(noise_pos: Vector2, radius: float) -> void:
	# Only react when unalerted and not already investigating/spotted
	if _patrol_state != PatrolState.PATROL:
		return
	var effective_radius := noise_hearing_radius if noise_hearing_radius > 0.0 else radius
	if global_position.distance_squared_to(noise_pos) > effective_radius * effective_radius:
		return
	_noise_alert_pos = noise_pos


func _run_investigate(noise_pos: Vector2) -> void:
	_patrol_state = PatrolState.INVESTIGATING
	_dbg_investigate_pos = noise_pos
	_dbg_investigate_stop_reason = ""
	# Snap the navigation target to the navmesh so the agent always has a valid path.
	# noise_pos may be inside a wall (no navmesh coverage), which causes the agent to
	# report navigation_finished immediately without moving.
	# The LOS check still uses the original noise_pos so the enemy walks to the wall
	# and checks if it can see the shot origin from the closest reachable point.
	var nav_target := NavigationServer2D.map_get_closest_point(
			get_world_2d().navigation_map, noise_pos)
	_dbg_investigate_nav_target = nav_target
	# Force-set target_position directly so navigation_finished always resets to false,
	# even when nav_target happens to equal the previous patrol destination (in which case
	# NavigateToPointBehavior's != guard would skip the assignment and leave the agent in
	# its completed state).
	_nav_agent.target_position = nav_target
	# Approach until we have line-of-sight to the noise origin, or until we spot the player.
	await _navigate_interruptible(nav_target, 15.0,
		func() -> bool:
			if _can_see_player():
				_dbg_investigate_stop_reason = "player"
				return true
			if _can_see_point(noise_pos):
				_dbg_investigate_stop_reason = "los"
				return true
			return false)
	# Stop reason not set by stop_condition = nav_done or timeout.
	if _dbg_investigate_stop_reason.is_empty():
		_dbg_investigate_stop_reason = "nav_done" \
				if _nav_agent.is_navigation_finished() else "timeout"
	# Brief pause at the investigation point (skipped if player was spotted).
	if is_alive() and not _can_see_player():
		await rest(0.8)
	_dbg_investigate_pos = Vector2.ZERO
	_dbg_investigate_nav_target = Vector2.ZERO


func _can_see_point(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point)
	query.collision_mask = sight_mask
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()


# — Detection —

func _can_see_player() -> bool:
	var player := get_player()
	if player == null or player._is_dead:
		return false
	var range := sight_range if _patrol_state == PatrolState.PATROL else alerted_sight_range
	var to_player := player.global_position - global_position
	if to_player.length_squared() > range * range:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = sight_mask
	query.exclude = [self, player]
	return space.intersect_ray(query).is_empty()


func _at_last_known_pos(threshold: float = 24.0) -> bool:
	return _last_known_pos != Vector2.ZERO \
			and global_position.distance_to(_last_known_pos) <= threshold


func _get_debug_label() -> String:
	var s = PatrolState.keys()[_patrol_state]
	if _noise_alert_pos != Vector2.ZERO:
		s += " [noise]"
	if _dbg_investigate_stop_reason != "":
		s += " [stop:%s]" % _dbg_investigate_stop_reason
	return s


func _should_return() -> bool:
	var ref := waypoints[0].global_position if waypoints.size() > 0 else _patrol_origin
	return false #global_position.distance_to(ref) > return_distance


# — Waypoint bookkeeping —

func _advance_waypoint() -> void:
	if waypoints.size() <= 1:
		return
	if patrol_loop:
		_wp_index = (_wp_index + 1) % waypoints.size()
	else:
		_wp_index += _bounce_dir
		if _wp_index >= waypoints.size():
			_wp_index = waypoints.size() - 2
			_bounce_dir = -1
		elif _wp_index < 0:
			_wp_index = 1
			_bounce_dir = 1
