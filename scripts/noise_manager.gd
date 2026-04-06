extends Node
## Singleton that broadcasts gunshot noise events to interested listeners.
## Autoloaded as "NoiseManager".

signal noise_emitted(position: Vector2, radius: float)


func emit_noise(position: Vector2, radius: float) -> void:
	noise_emitted.emit(position, radius) 
