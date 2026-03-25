extends Node

## Centralised hit-stop manager.
##
## Any system can call HitStop.request(duration) to freeze the simulation.
## Concurrent requests are merged: the tree stays paused until the longest
## request expires.  A new request while one is already running simply
## extends the end time if it would outlast the current one.
##
##   HitStop.request(0.1)
##   HitStop.ended.connect(_on_hit_stop_ended)

signal ended

var _end_time: float = -1.0
var _running: bool = false


func request(duration: float) -> void:
	var new_end := Time.get_ticks_usec() / 1_000_000.0 + duration
	_end_time = maxf(_end_time, new_end)
	if not _running:
		_run()


func _run() -> void:
	_running = true
	get_tree().paused = true
	while true:
		var remaining := _end_time - Time.get_ticks_usec() / 1_000_000.0
		if remaining <= 0.0:
			break
		await get_tree().create_timer(remaining, true, false, true).timeout
	get_tree().paused = false
	_running = false
	ended.emit()
