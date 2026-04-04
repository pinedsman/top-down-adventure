extends Interactable
class_name Pickup

@export var preset_pickup_data: PickupData
@export var amount: int = 20

var data: PickupData


func _ready() -> void:
	super._ready()
	if preset_pickup_data != null:
		set_pickup_data(preset_pickup_data)


func set_pickup_data(new_data: PickupData) -> void:
	data = new_data
	$Sprite2D.texture = new_data.pickup_texture
	$Sprite2D.scale = new_data.scale
	$Sprite2D.position = new_data.offset


func interact(player: Player) -> void:
	if data == null:
		return
	var consumed := false
	if data.ammo_type != null:
		consumed = player.add_ammo(data.ammo_type, amount) > 0
	if consumed:
		if data.pickup_sound != null:
			AudioPool.play(data.pickup_sound, global_position)
		queue_free()


func get_prompt_text(player: Player) -> String:
	if data == null:
		return ""
	var label := data.display_name
	var amountText := "x%d" % [amount] if player.get_ammo(data.ammo_type) < data.ammo_type.max_capacity else "Full"
	return "%s %s" % [label, amountText]
