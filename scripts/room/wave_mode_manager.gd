extends Node
class_name WaveModeManager

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal room_cleared
signal run_complete

@export var rooms: Array[RoomData] = []
@export var wave_sets: Array[WaveSetData] = []
@export var overlay: WaveOverlay

@export_group("Wave Rewards")
@export var reward_health_pickup: PickupData
@export var reward_health_amount: int = 20
@export var reward_weapon_pool: Array[WeaponData] = []

var _current_room_scene: Node = null
var _run_index: int = 0

@onready var _room_container: Node = $RoomContainer


func _ready() -> void:
	start_run()


func start_run() -> void:
	_run_index = 0
	_load_next()


func _load_next() -> void:
	if rooms.is_empty() or wave_sets.is_empty():
		run_complete.emit()
		return

	var room_data := _pick_room()
	var wave_set := _pick_wave_set()

	if not _validate_flags(room_data):
		return

	if is_instance_valid(_current_room_scene):
		_current_room_scene.queue_free()
		_current_room_scene = null

	var room_scene: Node = room_data.scene.instantiate()
	_room_container.add_child(room_scene)
	_current_room_scene = room_scene

	# Move the persistent player into the new room's ysort layer
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0] as Player
		var ysort: Node = null
		for node in get_tree().get_nodes_in_group("ysort"):
			if room_scene.is_ancestor_of(node):
				ysort = node
				break
		var spawn_position := player.global_position
		for node in get_tree().get_nodes_in_group("player_spawn"):
			if room_scene.is_ancestor_of(node):
				spawn_position = (node as Node2D).global_position
				break
		if ysort != null:
			player.enter_room(ysort, spawn_position)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera is CameraController:
		camera.refresh_limits(room_scene)

	var room_manager := RoomManager.new()
	room_scene.add_child(room_manager)
	room_manager.init(room_data, wave_set.waves, room_scene)
	_run_wave_sequence(room_manager)


func _pick_room() -> RoomData:
	return rooms[_run_index % rooms.size()]


func _pick_wave_set() -> WaveSetData:
	return wave_sets[_run_index % wave_sets.size()]


func _run_wave_sequence(room_manager: RoomManager) -> void:
	wave_started.emit(_run_index)
	if overlay:
		await overlay.fade_in()
		await overlay.show_wave_intro(_run_index + 1)

	for i in room_manager.wave_count():
		room_manager.run_wave(i)
		await room_manager.wave_cleared

	wave_cleared.emit(_run_index)
	if overlay:
		await overlay.show_wave_complete()

	var rewards := _spawn_wave_rewards()
	if not rewards.is_empty():
		await _wait_for_one_reward_pickup(rewards)

	if overlay:
		await overlay.fade_out()

	room_cleared.emit()
	room_manager.unlock_exit()
	_run_index += 1
	_load_next()


func _spawn_wave_rewards() -> Array:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return []

	# Collect reward spawn markers placed by designers inside the current room scene.
	var markers: Array[Node2D] = []
	if is_instance_valid(_current_room_scene):
		for node in get_tree().get_nodes_in_group("reward_spawn"):
			if _current_room_scene.is_ancestor_of(node) and node is Node2D:
				markers.append(node as Node2D)

	if markers.is_empty():
		push_warning("WaveModeManager: no 'reward_spawn' markers found in current room — skipping rewards.")
		return []

	# Sort markers left-to-right so designers can rely on predictable slot assignment
	# by placing the nodes at their desired positions.
	markers.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.x < b.global_position.x)

	var rewards: Array = []

	# Layout rules (up to 3 markers):
	#   1 marker  → health only
	#   2 markers → health [0], weapon [1]
	#   3+ markers → weapon [0], health [1], weapon [2]
	var count := mini(markers.size(), 3)

	if count == 1:
		if reward_health_pickup != null:
			var pickup := reward_health_pickup.spawn(markers[0].global_position, reward_health_amount)
			if pickup != null:
				rewards.append(pickup)

	elif count == 2:
		if reward_health_pickup != null:
			var pickup := reward_health_pickup.spawn(markers[0].global_position, reward_health_amount)
			if pickup != null:
				rewards.append(pickup)
		if not reward_weapon_pool.is_empty():
			var pool := reward_weapon_pool.duplicate()
			pool.shuffle()
			var dropped := DroppedWeapon.spawn(pool[0], pool[0].magazine_size,
				player.global_position, markers[1].global_position)
			if dropped != null:
				rewards.append(dropped)

	else:
		# 3 slots: weapon | health | weapon
		if not reward_weapon_pool.is_empty():
			var pool := reward_weapon_pool.duplicate()
			pool.shuffle()
			for i in mini(2, pool.size()):
				var pos: Vector2 = markers[0].global_position if i == 0 else markers[2].global_position
				var dropped := DroppedWeapon.spawn(pool[i], pool[i].magazine_size,
					player.global_position, pos)
				if dropped != null:
					rewards.append(dropped)
		if reward_health_pickup != null:
			var pickup := reward_health_pickup.spawn(markers[1].global_position, reward_health_amount)
			if pickup != null:
				rewards.append(pickup)

	return rewards


func _wait_for_one_reward_pickup(rewards: Array) -> void:
	# GDScript lambdas capture locals by value, so use an Array as a mutable reference.
	var done := [false]
	for node: Node in rewards:
		if not is_instance_valid(node):
			continue
		# Capture node by value so the lambda doesn't close over the loop variable.
		var picked: Node = node
		picked.tree_exiting.connect(func() -> void:
			if done[0]:
				return
			done[0] = true
			for other in rewards:
				# Skip the node that triggered this — it's already exiting the tree.
				# Use untyped iteration so the assignment doesn't blow up on freed instances.
				if other != picked and is_instance_valid(other):
					(other as Node).queue_free()
		, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame


func _validate_flags(room_data: RoomData) -> bool:
	for group: FlagGroup in room_data.incompatible_flags:
		var active := room_data.flags.filter(
			func(f: RoomFlag): return f.enabled and group.flags.has(f.flag_id))
		if active.size() > 1:
			push_error("WaveModeManager: incompatible flags active: %s" \
				% str(active.map(func(f: RoomFlag): return f.flag_id)))
			return false
	return true
