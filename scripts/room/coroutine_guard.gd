extends RefCounted
class_name CoroutineGuard

var _version: int = 0


func start() -> void:
	_version += 1


func cancel() -> void:
	_version += 1


func snapshot() -> int:
	return _version


func is_valid(version: int) -> bool:
	return _version == version


func wait(duration: float) -> bool:
	var my_version := _version
	await Engine.get_main_loop().create_timer(duration).timeout
	return my_version == _version
