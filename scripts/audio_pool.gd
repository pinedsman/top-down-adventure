extends Node

## Pool of AudioStreamPlayer2D nodes partitioned into two independent buckets:
## a normal bucket and a priority bucket.
##
## Normal sounds (gunshots, footsteps, death sounds…) round-robin through the
## normal bucket.  Priority sounds (explosions, cinematics…) round-robin through
## their own reserved slots and can never be stomped by normal-bucket churn.
##
## Usage:
##   AudioPool.play(stream, position)           # normal priority
##   AudioPool.play_priority(stream, position)  # high priority — reserved slots
##
## To resize the pool before any sounds play (e.g. from a GameManager _ready):
##   AudioPool.pool_size = 12
##   AudioPool.priority_pool_size = 3

@export var pool_size: int = 8
## Slots reserved exclusively for play_priority() calls.
## Must be < pool_size.  If 0, play_priority() falls through to the normal bucket.
@export var priority_pool_size: int = 2

var _players: Array[AudioStreamPlayer2D] = []
var _normal_index: int = 0
var _priority_index: int = 0


func _ready() -> void:
	for i in pool_size:
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		_players.append(p)


## Play a normal-priority sound.  Never occupies a priority-reserved slot.
func play(stream: AudioStream, position: Vector2, ignore_pause: bool = false) -> void:
	assert(stream != null, "AudioPool.play: stream is null")
	var count := _normal_count()
	if count <= 0:
		return  # entire pool is reserved; drop the sound gracefully
	var player := _players[_normal_index]
	_normal_index = (_normal_index + 1) % count
	_configure(player, stream, position, ignore_pause)


## Play a high-priority sound using reserved slots that normal sounds cannot touch.
## Falls back to the normal bucket if priority_pool_size is 0.
func play_priority(stream: AudioStream, position: Vector2, ignore_pause: bool = false) -> void:
	assert(stream != null, "AudioPool.play_priority: stream is null")
	if priority_pool_size <= 0:
		play(stream, position, ignore_pause)
		return
	var offset := _normal_count()
	var player := _players[offset + _priority_index]
	_priority_index = (_priority_index + 1) % priority_pool_size
	_configure(player, stream, position, ignore_pause)


func _normal_count() -> int:
	return maxi(pool_size - priority_pool_size, 0)


func _configure(player: AudioStreamPlayer2D, stream: AudioStream, position: Vector2, ignore_pause: bool) -> void:
	player.process_mode = Node.PROCESS_MODE_ALWAYS if ignore_pause else Node.PROCESS_MODE_INHERIT
	player.stream = stream
	player.global_position = position
	player.play()
