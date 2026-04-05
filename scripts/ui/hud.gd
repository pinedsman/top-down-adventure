extends CanvasLayer

@onready var ammo_text = $BottomContainer/AmmoText
@onready var health_text = $BottomContainer/HealthBottomContainer/VBoxContainer/HealthMainContainer/HealthText
@onready var weapon_display = $BottomContainer/WeaponDisplay
@onready var hbox = $HBoxContainer
@onready var _interact_prompt: InteractPrompt = get_node_or_null("InteractPrompt")
@onready var _charge_bar: ChargeBar = get_node_or_null("ChargeBar")
@export var heart_ui_scene: PackedScene

var _current_weapon: Weapon
var player: Player
var _heal_weapon: Weapon

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		_heal_weapon = player.get_slot_weapon("heal")
		player.weapon_changed.connect(_on_weapon_changed)
		player.ammo_changed.connect(_on_ammo_changed)
		player.weapon_magazine_changed.connect(_on_magazine_changed)
		player.health_changed.connect(_on_health_changed)
		player.interactable_focused.connect(_on_interactable_focused)
		_on_weapon_changed(player.weapon)
		_update_max_hp(player.max_health)
		_on_ammo_changed(_heal_weapon.data.ammo_type, player.get_ammo(_heal_weapon.data.ammo_type))


func _process(_delta: float) -> void:
	if _charge_bar == null or player == null:
		return
	var cw := player.get_charging_weapon()
	if cw != null:
		_charge_bar.show_bar(player)
		_charge_bar.set_progress(cw.charge_progress())
	else:
		_charge_bar.hide_bar()

func _on_health_changed(health:float, maxHealth:float) -> void:
	_update_max_hp(maxHealth)
	_update_hp(health)

func _on_weapon_changed(weapon: Weapon) -> void:
	if (weapon not in player._weapon_instances):
		return
	
	_current_weapon = weapon
	weapon_display.update_weapon(weapon)
	
	if weapon != null:
		if _current_weapon.data.use_weapon_ammo:
			_on_magazine_changed(weapon, weapon.magazine_ammo())
		else: 
			_on_ammo_changed(weapon.ammo_type, player.get_ammo(weapon.ammo_type))
	else:
		_on_ammo_changed(null, 0)

func _on_magazine_changed(weapon: Weapon, current_count: int) -> void:
	if weapon == _current_weapon and not _current_weapon == null: 
		ammo_text.text = str(current_count)

func _on_ammo_changed(ammo_type: AmmoType, current_count: int) -> void:
	if ammo_type == _heal_weapon.data.ammo_type:
		health_text.text = str(player.get_ammo(ammo_type))
		return
		
	if _current_weapon == null:
		ammo_text.text = ""
	elif _current_weapon.data.use_weapon_ammo:
		return
	elif ammo_type != null && _current_weapon.ammo_type == ammo_type:
		ammo_text.text = str(current_count)
	else:
		ammo_text.text = ""

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
		_interact_prompt.show_prompt(target.get_prompt_text(player), target)


func _update_max_hp(max_hp: int) -> void:
	while hbox.get_child_count() > max_hp:
		var heart = hbox.get_child(hbox.get_child_count() - 1)
		hbox.remove_child(heart)
		heart.queue_free()
	while hbox.get_child_count() < max_hp:
		hbox.add_child(heart_ui_scene.instantiate())
		
	
	
