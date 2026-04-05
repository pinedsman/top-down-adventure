extends Area2D
class_name Interactable

# Base class for world objects the player can interact with (press the interact key).
# Subclasses override interact() and get_prompt_text().
# The player scans this group each frame; this node does NOT need monitoring enabled.

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 8  # layer 4 "interactable"
	monitoring = false
	monitorable = true


# Called when the player successfully interacts with this object.
func interact(player: Player) -> void:
	pass


# Text shown next to the input glyph in the interact prompt.
func get_prompt_text(player: Player) -> String:
	return ""
