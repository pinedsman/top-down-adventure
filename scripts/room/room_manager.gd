extends Node
class_name RoomManager

signal wave_cleared

var _room_data: RoomData
var _waves: Array[WaveData]
var _room_root: Node
var _living_enemies: Array[Node] = []
var _guard: CoroutineGuard


func init(room_data: RoomData, waves: Array[WaveData], room_root: Node) -> void:
	_room_data = room_data
	_waves = waves
	_room_root = room_root
	_guard = CoroutineGuard.new()
	_apply_flags()


func wave_count() -> int:
	return _waves.size()


func run_wave(index: int) -> void:
	_guard.start()
	await _spawn_wave(_waves[index])
	await _wait_for_wave_clear()
	wave_cleared.emit()


func unlock_exit() -> void:
	for node in get_tree().get_nodes_in_group("exit_door_blocker"):
		if _room_root.is_ancestor_of(node):
			node.queue_free()


func _apply_flags() -> void:
	for flag: RoomFlag in _room_data.flags:
		for node in get_tree().get_nodes_in_group(flag.flag_id):
			if not _room_root.is_ancestor_of(node):
				continue
			node.visible = flag.enabled
			node.process_mode = Node.PROCESS_MODE_INHERIT if flag.enabled \
					else Node.PROCESS_MODE_DISABLED


func _build_spawn_list(wave: WaveData) -> Array[PackedScene]:
	var list: Array[PackedScene] = []
	for entry: EnemyEntry in wave.guaranteed_spawns:
		list.append(entry.enemy_scene)

	var budget := wave.point_budget
	while budget > 0:
		var affordable: Array[EnemyEntry] = wave.spawn_pool.filter(
			func(e: EnemyEntry): return e.point_cost <= budget)
		if affordable.is_empty():
			break
		var total_weight := 0.0
		for e: EnemyEntry in affordable:
			total_weight += e.weight
		var roll := randf() * total_weight
		var cumulative := 0.0
		for e: EnemyEntry in affordable:
			cumulative += e.weight
			if roll <= cumulative:
				list.append(e.enemy_scene)
				budget -= e.point_cost
				break

	return list


func _spawn_wave(wave: WaveData) -> void:
	var list := _build_spawn_list(wave)
	var total := list.size()
	for i in total:
		_spawn_enemy(list[i])
		var progress := float(i) / float(maxi(total - 1, 1))
		var delay := wave.escalation_curve.sample(progress) if wave.escalation_curve \
				else lerpf(2.0, 0.3, progress)
		if not await _guard.wait(delay):
			return


func _spawn_enemy(scene: PackedScene) -> void:
	var spawn_points: Array[Node] = []
	for node in get_tree().get_nodes_in_group("spawn_points"):
		if _room_root.is_ancestor_of(node):
			spawn_points.append(node)

	if spawn_points.is_empty():
		push_warning("RoomManager: no spawn_points found in room")
		return

	var spawn_point := spawn_points[randi() % spawn_points.size()]

	var enemy: Node2D = scene.instantiate()
	var ysort_nodes := get_tree().get_nodes_in_group("ysort")
	var ysort: Node = ysort_nodes[0] if ysort_nodes.size() > 0 else _room_root
	ysort.add_child(enemy)
	enemy.global_position = (spawn_point as Node2D).global_position

	enemy.add_to_group("enemies")
	_living_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_removed)


func _on_enemy_removed() -> void:
	_living_enemies = _living_enemies.filter(func(e): return is_instance_valid(e))


func _wait_for_wave_clear() -> void:
	while true:
		_living_enemies = _living_enemies.filter(func(e): return is_instance_valid(e))
		if _living_enemies.is_empty():
			break
		await get_tree().physics_frame
