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
@export var ammo_type: AmmoType             # null = infinite ammo
@export var show_laser: bool = true


func create_instance() -> Weapon:
	return Weapon.new(self)
