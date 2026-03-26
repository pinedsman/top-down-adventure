extends Node2D
class_name Pickup

@export var preset_pickup_data: PickupData
@export var amount: int = 20

var data: PickupData

func _ready() -> void:
	self.body_entered.connect(_on_player_entered)
	if (preset_pickup_data != null):
		set_pickup_data(preset_pickup_data)

func set_pickup_data(newData:PickupData):
	data = newData
	$Sprite2D.texture = data.ammo_type.icon

func _on_player_entered(body: Node2D) -> void:
	if (body is Player):
		var player = body as Player
		player.add_ammo(data.ammo_type, amount)
		AudioPool.play(data.pickup_sound, global_position)
		queue_free()
