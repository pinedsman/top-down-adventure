extends Node2D
class_name SpreadArc

# TODO: Artist — assign a ShaderMaterial in the inspector (see assets/spread_arc.gdshader).
# fill_color is used directly when no shader is assigned, and is also synced to the
# shader's fill_color uniform when one is set.

@export var arc_radius: float = 40.0
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var arc_steps: int = 16   # polygon resolution; increase for smoother arcs

var _spread_angle: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_sync_shader_params()


func update(aim_direction: Vector2, spread_angle_deg: float) -> void:
	_aim_direction = aim_direction
	_spread_angle = spread_angle_deg
	_sync_shader_params()
	queue_redraw()


func _sync_shader_params() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("arc_radius", arc_radius)
		(material as ShaderMaterial).set_shader_parameter("fill_color", fill_color)


func _draw() -> void:
	var base_angle := _aim_direction.angle()

	if _spread_angle <= 0.0:
		draw_line(Vector2.ZERO, _aim_direction * arc_radius, fill_color, 1.0)
		return

	var half := deg_to_rad(_spread_angle * 0.5)

	# Filled wedge: centre vertex + arc edge vertices
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(arc_steps + 1):
		var t := float(i) / float(arc_steps)
		var angle := lerpf(base_angle - half, base_angle + half, t)
		points.append(Vector2.from_angle(angle) * arc_radius)

	draw_polygon(points, PackedColorArray([fill_color]))
