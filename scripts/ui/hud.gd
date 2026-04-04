extends CanvasLayer

@onready var weapon_display = $HFlowContainer/WeaponDisplay
@onready var hbox = $HBoxContainer
@onready var _interact_prompt: InteractPrompt = get_node_or_null("InteractPrompt")
@export var heart_ui_scene: PackedScene

var _current_weapon: Weapon
var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.weapon_changed.connect(_on_weapon_changed)
		player.ammo_changed.connect(_on_ammo_changed)
		player.health_changed.connect(_on_health_changed)
		player.interactable_focused.connect(_on_interactable_focused)
		_on_weapon_changed(player.weapon)
		_update_max_hp(player.max_health)

func _on_health_changed(health:float, maxHealth:float) -> void:
	_update_max_hp(maxHealth)
	_update_hp(health)

func _on_weapon_changed(weapon: Weapon) -> void:
	_current_weapon = weapon
	weapon_display.update_weapon(weapon)
	if weapon != null && weapon.ammo_type != null:
		$HFlowContainer/AmmoIcon.texture = weapon.ammo_type.icon 
	else:
		$HFlowContainer/AmmoIcon.texture = null
	if weapon != null:
		var initial_count: int = weapon.magazine_ammo() if Weapon.use_weapon_ammo else player.get_ammo(weapon.ammo_type)
		_on_ammo_changed(weapon.ammo_type, initial_count)
	else:
		_on_ammo_changed(null, 0)

func _on_ammo_changed(ammo_type: AmmoType, current_count: int) -> void:
	if _current_weapon == null:
		$HFlowContainer/AmmoText.text = ""
	elif Weapon.use_weapon_ammo:
		# current_count is magazine rounds; -1 means infinite — hide the counter
		$HFlowContainer/AmmoText.text = str(current_count) if current_count >= 0 else ""
	elif ammo_type != null && _current_weapon.ammo_type == ammo_type:
		$HFlowContainer/AmmoText.text = str(current_count)
	else:
		$HFlowContainer/AmmoText.text = ""

func _update_hp(health:int):
	var i=0
	for heart in hbox.get_children():
		heart.value = 2 if (i<health) else 0
		i+=1

func _on_interactable_focused(target: Interactable) -> void:
	if _interact_prompt == null:
		return
	if target == null:
		_interact_prompt.hide_prompt()
	else:
		_interact_prompt.show_prompt(target.get_prompt_text(), target)


func _update_max_hp(max_hp: int) -> void:
	while hbox.get_child_count() > max_hp:
		var heart = hbox.get_child(hbox.get_child_count() - 1)
		hbox.remove_child(heart)
		heart.queue_free()
	while hbox.get_child_count() < max_hp:
		hbox.add_child(heart_ui_scene.instantiate())
		
	
	
