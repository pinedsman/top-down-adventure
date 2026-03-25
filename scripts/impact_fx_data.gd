extends Resource
class_name ImpactFXData

@export var scene: PackedScene
@export var animation_name: String = "impact"
@export var sound: AudioStream
@export var offset: Vector2 = Vector2.ZERO
@export var scale: Vector2 = Vector2.ONE


func spawn(position: Vector2, process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT) -> void:
	assert(scene != null, "ImpactFXData: scene is not set on resource '%s'" % resource_path)
	var fx: Node2D = scene.instantiate()
	fx.process_mode = process_mode
	Engine.get_main_loop().current_scene.add_child(fx)
	fx.global_position = position
	fx.play_impact(self)
