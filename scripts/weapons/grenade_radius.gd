extends Node2D
class_name GrenadeRadius

var _grenade: Grenade = null


func setup(grenade: Grenade) -> void:
	_grenade = grenade
	top_level = true


func _draw() -> void:
	if not is_instance_valid(_grenade) or not _grenade._pre_explode_active:
		return
	var data := _grenade.data
	var dim := data.radius_flash_dim if not _grenade._flash_visible else 1.0
	var inner_col := Color(data.radius_inner_color, data.radius_inner_color.a * dim)
	var outer_col := Color(data.radius_outer_color, data.radius_outer_color.a * dim)
	draw_arc(Vector2.ZERO, data.explosion_inner_radius, 0.0, TAU, 40, inner_col, data.radius_inner_width, true)
	draw_arc(Vector2.ZERO, data.explosion_outer_radius, 0.0, TAU, 60, outer_col, data.radius_outer_width, true)
