extends Node
class_name WaveModeManager

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal room_cleared
signal run_complete

@export var rooms: Array[RoomData] = []
@export var wave_sets: Array[WaveSetData] = []
@export var overlay: WaveOverlay

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
		await overlay.fade_out()

	room_cleared.emit()
	room_manager.unlock_exit()
	_run_index += 1
	_load_next()


func _validate_flags(room_data: RoomData) -> bool:
	for group: FlagGroup in room_data.incompatible_flags:
		var active := room_data.flags.filter(
			func(f: RoomFlag): return f.enabled and group.flags.has(f.flag_id))
		if active.size() > 1:
			push_error("WaveModeManager: incompatible flags active: %s" \
				% str(active.map(func(f: RoomFlag): return f.flag_id)))
			return false
	return true
