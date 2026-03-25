extends CanvasLayer

@onready var weapon_display = $WeaponDisplay
@onready var hbox = $HBoxContainer
@export var heart_ui_scene: PackedScene

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.weapon_changed.connect(_on_weapon_changed)
		player.health_changed.connect(_on_health_changed)
		_on_weapon_changed(player.weapon)
		_update_max_hp(player.max_health)

func _on_health_changed(health:float, maxHealth:float) -> void:
	_update_max_hp(maxHealth)
	_update_hp(health)

func _on_weapon_changed(weapon: Weapon) -> void:
	weapon_display.update_weapon(weapon)

func _update_hp(health:int):
	var i=0
	for heart in hbox.get_children():
		heart.value = 2 if (i<health) else 0
		i+=1

func _update_max_hp(max_hp: int) -> void:
	while hbox.get_child_count() > max_hp:
		var heart = hbox.get_child(hbox.get_child_count() - 1)
		hbox.remove_child(heart)
		heart.queue_free()
	while hbox.get_child_count() < max_hp:
		hbox.add_child(heart_ui_scene.instantiate())
		
	
	
