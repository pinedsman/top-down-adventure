extends Control

func update_weapon(weapon: Weapon) -> void:
	if weapon == null:
		return
	$WeaponIcon.texture = weapon.hud_icon
