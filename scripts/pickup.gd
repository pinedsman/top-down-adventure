extends Area2D
class_name Pickup

@export var preset_pickup_data: PickupData
@export var amount: int = 20

var data: PickupData

func _ready() -> void:
	body_entered.connect(_on_player_entered)
	if (preset_pickup_data != null):
		set_pickup_data(preset_pickup_data)

func set_pickup_data(newData:PickupData):
	data = newData
	$Sprite2D.texture = newData.pickup_texture
	$Sprite2D.scale = newData.scale
	$Sprite2D.position = newData.offset

func _on_player_entered(body: Node2D) -> void:
	if (body is Player):
		var player = body as Player
		var delta = player.add_ammo(data.ammo_type, amount)
		if ( delta > 0 ):
			AudioPool.play(data.pickup_sound, global_position)
			queue_free()
