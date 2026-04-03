extends Resource
class_name PlayerState

var health: float = 0.0
var weapons: Array[WeaponData] = []
var weapon_index: int = 0
var ammo: Dictionary = {}   # AmmoType → int
