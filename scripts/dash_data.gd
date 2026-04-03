extends Resource
class_name DashData

@export var dash_sound: AudioStream
@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.6
@export var invincible_during_dash: bool = true

@export_group("Steering")
# Fractions of dash_speed — e.g. 0.3 = can steer up to 30% of dash speed laterally
@export var lateral_control: float = 0.3
@export var medial_control: float = 0.15   # only allows pushing against the dash (shortening)
# X = dash progress (0 = just started, 1 = about to end), Y = control multiplier
# Default nil = linear (full ramp from 0 to 1)
@export var control_curve: Curve
