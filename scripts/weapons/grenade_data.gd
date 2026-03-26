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
@export_flags_2d_physics var los_mask: int = 1  # layers that block explosion line-of-sight
@export var explosion_fx: ImpactFXData
@export var explosion_sound: AudioStream
@export var explosion_shake_strength: float = 5.0

@export_group("Bounce")
@export var velocity_decay: float = 8.0  # speed loss per second (exponential)
@export var bounce_friction: float = 0.6  # speed multiplier per bounce
@export var spin_rate: float = 0.008     # radians per pixel/second of speed
@export var max_bounces: int = 0          # 0 = unlimited
@export var bounce_sound: AudioStream
@export var explode_on_impact: bool = false
@export var stick_to_walls: bool = false
@export var settle_clink_count: int = 2     # extra clinks as grenade decelerates to a stop
@export var settle_speed: float = 120.0     # speed at which settle clinks begin

@export_group("Radius Indicator")
@export var radius_inner_color: Color = Color(1.0, 0.4, 0.0, 0.6)
@export var radius_outer_color: Color = Color(1.0, 0.85, 0.2, 0.3)
@export var radius_inner_width: float = 1.5
@export var radius_outer_width: float = 1.0
@export var radius_flash_dim: float = 0.4  # alpha multiplier when sprite is hidden

@export_group("Pre-Explode")
@export var pre_explode_start_time: float = 1.0
@export var pre_explode_flash_rate_start: float = 2.0   # flashes/sec at start of window
@export var pre_explode_flash_rate_end: float = 12.0    # flashes/sec just before detonation
@export var pre_explode_sound: AudioStream
