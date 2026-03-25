extends Area2D
class_name Bullet

@export var speed: float = 400.0
@export var impact_fx_data: ImpactFXData

static var debug: bool = false

var direction: Vector2 = Vector2.RIGHT:
	set(value):
		direction = value
		rotation = value.angle()
var damage: float = 10.0
var knockback_force: float = 0.0
var shot_id: int = -1
var suppress_wall_impacts: bool = false
var range: float = 0.0  # 0 = infinite
var range_fx: ImpactFXData = null
var owner_node: Node = null:
	set(value):
		owner_node = value
		var exclude := [self, value]
		_cast_query.exclude = exclude
		_rest_query.exclude = exclude
		_hit_query.exclude = exclude

var _distance_travelled: float = 0.0
var _shape: CircleShape2D
var _cast_query: PhysicsShapeQueryParameters2D
var _rest_query: PhysicsShapeQueryParameters2D
var _hit_query: PhysicsShapeQueryParameters2D

func _ready() -> void:
	_shape = CircleShape2D.new()
	_shape.radius = ($CollisionShape2D.shape as CircleShape2D).radius

	_cast_query = PhysicsShapeQueryParameters2D.new()
	_cast_query.shape = _shape
	_cast_query.exclude = [self]

	_rest_query = PhysicsShapeQueryParameters2D.new()
	_rest_query.shape = _shape
	_rest_query.exclude = [self]

	_hit_query = PhysicsShapeQueryParameters2D.new()
	_hit_query.shape = _shape
	_hit_query.exclude = [self]

func _physics_process(delta: float) -> void:
	var space = get_world_2d().direct_space_state
	var motion := direction * speed * delta

	var range_reached := false
	if range > 0.0:
		var remaining := range - _distance_travelled
		if motion.length() >= remaining:
			motion = direction * remaining
			range_reached = true

	_cast_query.transform = Transform2D(0.0, global_position)
	_cast_query.motion = motion
	var result = space.cast_motion(_cast_query)

	if debug: DebugDraw.add_circle(global_position, _shape.radius, Color.BLUE)

	if result[0] < 1.0:
		var impact_transform := Transform2D(0.0, global_position + motion * result[1])
		_rest_query.transform = impact_transform
		var rest_info = space.get_rest_info(_rest_query)

		var impact_pos: Vector2
		var impact_normal: Vector2
		if rest_info.size() > 0:
			impact_pos = rest_info["point"]
			impact_normal = rest_info["normal"]
		else:
			impact_pos = global_position + motion * result[0] + direction * _shape.radius
			impact_normal = -direction

		_hit_query.transform = impact_transform
		var hits = space.intersect_shape(_hit_query)
		if debug: DebugDraw.add_circle(impact_pos, _shape.radius, Color.BLUE)
		if hits.size() > 0:
			_on_impact(impact_pos, impact_normal, hits[0].collider)
		return

	global_position += motion
	_distance_travelled += motion.length()

	if range_reached:
		if range_fx:
			_spawn_impact(range_fx, global_position)
		queue_free()

func _on_impact(impact_pos: Vector2, impact_normal: Vector2, body: Node) -> void:
	if body == owner_node:
		return
	var same_shot: bool = shot_id >= 0 and body.get("_last_shot_id") == shot_id
	if body.has_method("take_damage"):
		body.take_damage(damage, direction * knockback_force, impact_pos, shot_id)
	if debug: DebugDraw.add_circle(impact_pos, 2, Color.GREEN)
	if not same_shot:
		_spawn_impact(_get_impact_data(body, impact_pos, impact_normal), impact_pos)
	queue_free()

func _spawn_impact(data: ImpactFXData, impact_pos: Vector2) -> void:
	if data == null:
		return
	data.spawn(impact_pos)

func _get_impact_data(body: Node, impact_pos: Vector2, impact_normal: Vector2) -> ImpactFXData:
	if debug: DebugDraw.add_circle(impact_pos, 1, Color.RED)
	if body is TileMapLayer:
		if suppress_wall_impacts:
			return null
		var probe_pos = impact_pos - impact_normal * 8.0
		var tile_pos = body.local_to_map(body.to_local(probe_pos))
		var tile_data = body.get_cell_tile_data(tile_pos)
		if tile_data:
			var data = tile_data.get_custom_data("impact_fx_data")
			if data is ImpactFXData:
				return data
	elif body.get("impact_fx_data") is ImpactFXData:
		return body.impact_fx_data
	return impact_fx_data


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
