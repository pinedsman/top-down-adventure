extends Resource
class_name PickupData

@export var scene: PackedScene
@export var ammo_type: AmmoType
@export var heal_amount: float = 0.0  # > 0 makes this a health pickup; ammo_type ignored
@export var pickup_sound: AudioStream
@export var pickup_texture: Texture2D
@export var offset: Vector2 = Vector2.ZERO
@export var scale: Vector2 = Vector2.ONE

var _ysort: Node      # cached on first use

func spawn(position: Vector2, amount:int) -> void:
	assert(scene != null, "{PickupData}: scene is not set on resource '%s'" % resource_path)
	var pickup: Node2D = scene.instantiate()
	_get_ysort().add_child(pickup)
	pickup.set_pickup_data( self )
	pickup.amount = amount
	pickup.global_position = position
	pickup.rotation_degrees = randf_range(0,360)

func _get_ysort() -> Node:
	if not is_instance_valid(_ysort):
		_ysort = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("ysort")
		assert(_ysort != null, "Pickup: no node in group 'ysort'")
	return _ysort
