extends Interactable
class_name DroppedWeapon

const DEBOUNCE_TIME: float = 0.5
const DROP_SCENE: String = "res://scenes/dropped_weapon.tscn"

@export var weapon_data: WeaponData

# Preserved ammo count from the weapon instance that was dropped.
# -1 = infinite / not applicable. Restored onto the new Weapon instance on pickup.
@export var saved_magazine: int = -1

var _pickup_debounce: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	if weapon_data != null and weapon_data.drop_sprite != null:
		_sprite.texture = weapon_data.drop_sprite
		if saved_magazine < 0:
			saved_magazine = weapon_data.magazine_size


func _process(delta: float) -> void:
	if _pickup_debounce > 0.0:
		_pickup_debounce -= delta


# — Interactable overrides —

func interact(player: Player) -> void:
	if _pickup_debounce > 0.0:
		return
	if weapon_data != null and weapon_data.pickup_sound != null:
		AudioPool.play(weapon_data.pickup_sound, global_position)
	player.pick_up_weapon(self)


func get_prompt_text() -> String:
	if weapon_data == null:
		return ""
	return weapon_data.weapon_name


# — Static factory —

# Spawns a DroppedWeapon at player_position and tweens it to rest_position.
# magazine: current ammo on the weapon being dropped (-1 = infinite).
static func spawn(data: WeaponData, magazine: int, player_position: Vector2, rest_position: Vector2) -> void:
	var scene: PackedScene = load(DROP_SCENE)
	assert(scene != null, "DroppedWeapon: could not load scene at " + DROP_SCENE)

	var instance: DroppedWeapon = scene.instantiate()
	instance.weapon_data = data
	instance.saved_magazine = magazine
	instance._pickup_debounce = DEBOUNCE_TIME

	var ysort = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("ysort")
	assert(ysort != null, "DroppedWeapon: no node in group 'ysort'")
	ysort.add_child(instance)
	instance.global_position = player_position

	# Animate to rest position
	var tween := instance.create_tween()
	tween.tween_property(instance, "global_position", rest_position, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
