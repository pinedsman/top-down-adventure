extends Resource
class_name WeaponAbility

## Base class for custom weapon abilities.
## Subclass this and override execute() to implement behaviour.
## charge: 0.0–1.0 where 1.0 = fully charged. Non-charge weapons always pass 1.0.

## Return false to block firing entirely (e.g. heal at full health).
## Called before starting a charge and before executing — safe to override.
func can_execute(_shooter: Node, _weapon: Weapon) -> bool:
	return true

## Called when can_execute() returned false and the fire was prevented.
func on_fire_prevented(_shooter: Node, _weapon: Weapon) -> void:
	pass

## Called when the charge is cancelled (damage, weapon switch, etc.) before firing.
func on_charge_cancelled(_shooter: Node, _weapon: Weapon) -> void:
	pass

func execute(_shooter: Node, _weapon: Weapon, _charge: float) -> void:
	pass
