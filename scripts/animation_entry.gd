@tool
extends Resource
class_name AnimationEntry

@export var bullet_behind_player: bool = false
@export var animationIndex: String = ""
@export var flip: bool = false
@export var muzzle_offset: Vector2 = Vector2.ZERO:
	set(value):
		muzzle_offset = value
		if Engine.is_editor_hint():
			var player = _find_player()
			if player:
				player.get_node("Muzzle").position = muzzle_offset
				
@export_tool_button("Preview Animation") var preview_animation_button = _preview_animation

func _preview_animation() -> void:
	var player = _find_player()
	if player == null:
		push_error("Could not find Player node in scene")
		return
	var anim = player.get_node("AnimatedSprite2D")
	if anim:
		anim.play(animationIndex)
		anim.flip_h = flip
		player.get_node("Muzzle").position = muzzle_offset

func _find_player() -> Node:
	var tree = Engine.get_main_loop()
	if (tree and tree.edited_scene_root and tree.edited_scene_root.name == "Player"):
		return tree.edited_scene_root
	if tree and tree.edited_scene_root:
		return tree.edited_scene_root.find_child("Player", true, false)
	return null
