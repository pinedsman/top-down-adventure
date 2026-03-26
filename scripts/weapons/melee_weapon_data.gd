extends WeaponData
class_name MeleeWeaponData

@export var swings: Array[SwingData] = []
@export_flags_2d_physics var los_mask: int = 0
@export var debug_draw_arc: bool = false


func create_instance() -> Weapon:
	return MeleeWeapon.new(self)
