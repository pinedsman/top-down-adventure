extends Resource
class_name GrenadeData

@export var grenade_scene: PackedScene

@export_group("Fuse")
@export var fuse_time: float = 3.0

@export_group("Explosion")
@export var damage_delay: float = 0.02  # seconds after fx before damage applies
@export var explosion_inner_radius: float = 30.0
@export var explosion_outer_radius: float = 80.0
@export var inner_damage: float = 50.0
@export var outer_damage: float = 10.0
@export var knockback_inner: float = 300.0
@export var knockback_outer: float = 50.0
@export var damage_falloff: Curve        # null = linear
@export var self_damage: bool = true
@export var self_damage_override: float = 10.0
@export var self_knockback_override: float = 150.0
@export var explosion_fx: ImpactFXData
@export var explosion_sound: AudioStream

@export_group("Bounce")
@export var bounce_friction: float = 0.6  # speed multiplier per bounce
@export var max_bounces: int = 0          # 0 = unlimited
@export var bounce_sound: AudioStream
@export var explode_on_impact: bool = false
@export var stick_to_walls: bool = false

@export_group("Pre-Explode")
@export var pre_explode_start_time: float = 1.0
@export var pre_explode_flash_rate_start: float = 2.0   # flashes/sec at start of window
@export var pre_explode_flash_rate_end: float = 12.0    # flashes/sec just before detonation
@export var pre_explode_sound: AudioStream
