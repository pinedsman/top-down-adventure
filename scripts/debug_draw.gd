extends Node2D

var _entries: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		get_parent().remove_child(self)
		hud.add_child(self)


func add_line(start: Vector2, end: Vector2, color: Color = Color.GREEN, ttl: float = 2.0) -> void:
	_entries.append({"type": "line", "start": start, "end": end, "color": color, "ttl": ttl, "max_ttl": ttl})

func add_circle(pos: Vector2, radius: float, color: Color = Color.RED, ttl: float = 2.0) -> void:
	_entries.append({"type": "circle", "pos": pos, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})

func _draw() -> void:
	var ct = get_viewport().get_canvas_transform()
	for entry in _entries:
		var alpha = entry.ttl / entry.max_ttl
		var color = Color(entry.color.r, entry.color.g, entry.color.b, alpha)
		if entry.type == "line":
			draw_line(ct * entry.start, ct * entry.end, color, 1.0)
		elif entry.type == "circle":
			draw_arc(ct * entry.pos, entry.radius, 0, TAU, 16, color, 1.0)

func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	for entry in _entries:
		entry.ttl -= delta
	_entries = _entries.filter(func(e): return e.ttl > 0.0)
	queue_redraw()
