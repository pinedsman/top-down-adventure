extends CanvasLayer

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(player.weapon)

func _on_weapon_changed(weapon: Weapon) -> void:
	$WeaponDisplay.update_weapon(weapon)
