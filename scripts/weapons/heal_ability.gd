extends WeaponAbility
class_name HealAbility

@export var heal_amount: float = 1.0
@export var player_at_full_health_sound: AudioStream

func can_execute(shooter: Node, _weapon: Weapon) -> bool:
	var character := shooter as CharacterBase
	return character != null and character._health < character.max_health


func on_fire_prevented(shooter: Node, _weapon: Weapon) -> void:
	var character := shooter as CharacterBase
	if character == null:
		return
	if player_at_full_health_sound != null:
		AudioPool.play(player_at_full_health_sound, character.global_position)


func execute(shooter: Node, _weapon: Weapon, _charge: float) -> void:
	var character := shooter as CharacterBase
	if character == null:
		return
	character.heal(heal_amount)

func on_charge_cancelled(_shooter: Node, _weapon: Weapon) -> void:
	var character := _shooter as Player
	var ammo := character.get_ammo(_weapon.data.ammo_type)
	character.take_ammo(_weapon.data.ammo_type, 1) 
