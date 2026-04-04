extends Resource
class_name WeaponData

enum FireMode { SINGLE, AUTO, BURST }

@export var fire_mode: FireMode = FireMode.SINGLE
@export var fire_rate: float = 0.2          # seconds between shots
@export var damage: float = 10.0
@export var bullet_speed: float = 400.0
@export var knockback_force: float = 150.0
@export var bullet_range: float = 0.0       # world units; 0 = infinite
@export var bullet_range_fx: ImpactFXData
@export var hud_icon: Texture2D
@export var bullet_scene: PackedScene
@export var bullet_trail_scene: PackedScene
@export var shoot_sound: AudioStream
@export var pickup_sound: AudioStream
@export var dryfire_sound: AudioStream
@export var swap_sound: AudioStream
@export var muzzle_flash_scene: PackedScene
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0       # total cone width in degrees
@export var spread_randomness: float = 0.5  # 0 = evenly spaced, 1 = fully random
@export var rechamber_sound: AudioStream
@export var rechamber_sound_delay: float = 0.15
@export var burst_count: int = 3            # shots per burst (BURST mode only)
@export var burst_delay: float = 0.08       # seconds between burst shots
@export var fire_shake_strength: float = 0.0
@export var suppress_wall_impacts: bool = false
@export var aim_assist_angle: float = 0.0   # degrees half-cone; 0 = disabled
@export var aim_assist_range: float = 150.0
@export var aim_assist_strength: float = 0.15
@export var grenade_data: GrenadeData       # if set, fire() throws a grenade
@export var weapon_name: String = ""
@export var drop_sprite: Texture2D
@export var ammo_type: AmmoType             # null = infinite ammo (shared-pool mode)
@export var magazine_size: int = 0          # weapon-ammo mode: rounds per instance; 0 = infinite
@export var show_laser: bool = true
@export_flags_2d_physics var bullet_collision_mask: int = 0xFFFFFFFF
## When true this weapon tracks its own magazine. When false the player's shared ammo pool is used.
@export var use_weapon_ammo: bool = true

@export_group("Custom Ability")
## If set, firing runs ability.execute() instead of spawning bullets/grenades.
@export var ability: WeaponAbility

## While this weapon is active (charging), prevent all other weapons from firing.
@export var blocks_other_weapons: bool = false
## While this weapon is active (charging), prevent the player from dashing.
@export var blocks_dash: bool = false

@export_group("Charge")
## Seconds to reach full charge. 0 = instant fire (no charge mechanic).
@export var charge_time: float = 0.0
## Fire at whatever charge level was reached when the button is released.
@export var fire_on_partial_charge: bool = false
enum ChargeMode {
	HOLD_TO_CHARGE_FIRE_ON_RELEASE, ## Hold button to charge; releasing fires (or cancels if not full).
	HOLD_TO_CHARGE_AUTOFIRE,        ## Hold button to charge; fires automatically when full.
	AUTO_CHARGE,                    ## Charges on its own; fires automatically when full. Button ignored.
}
@export var charge_mode: ChargeMode = ChargeMode.HOLD_TO_CHARGE_FIRE_ON_RELEASE
## Spawned as a child of the muzzle while charging; freed on fire or cancel.
@export var charge_fx_scene: PackedScene
## Looping sound played while charging; stopped on fire or cancel.
@export var charge_loop_sound: AudioStream
## If true, taking damage while charging cancels the charge.
@export var damage_cancels_charge: bool = false
## Movement speed multiplier while charging. 1.0 = no slow, 0.0 = fully stopped.
@export_range(0.0, 1.0) var charge_move_speed_scale: float = 1.0
## Aim turn speed multiplier while charging. 1.0 = instant/normal, lower = sluggish turning.
@export_range(0.0, 1.0) var charge_turn_speed_scale: float = 1.0


func create_instance() -> Weapon:
	return Weapon.new(self)
