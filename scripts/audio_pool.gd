extends Node

## Single round-robin pool of AudioStreamPlayer2D nodes shared across all streams.
##
## Pool size is set once at startup (default 8). Each acquired player has its
## stream swapped to whatever is needed, so no per-asset allocation is required.
##
## Usage:
##   AudioPool.play(stream, position)
##
## To resize the pool before any sounds play (e.g. from a GameManager _ready):
##   AudioPool.pool_size = 12

@export var pool_size: int = 8

var _players: Array[AudioStreamPlayer2D] = []
var _index: int = 0


func _ready() -> void:
	for i in pool_size:
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		_players.append(p)


func play(stream: AudioStream, position: Vector2, ignore_pause: bool = false) -> void:
	assert(stream != null, "AudioPool.play: stream is null")
	var player := _players[_index]
	_index = (_index + 1) % _players.size()
	player.process_mode = Node.PROCESS_MODE_ALWAYS if ignore_pause else Node.PROCESS_MODE_INHERIT
	player.stream = stream
	player.global_position = position
	player.play()
