extends Resource
class_name SwingData

@export var damage: float = 30.0
@export var knockback_force: float = 200.0
@export var arc_angle: float = 120.0    # total degrees of the arc cone
@export var arc_range: float = 80.0     # reach along swing direction
@export var arc_width: float = 0.0      # reach perpendicular; 0 = same as arc_range (circle)
@export var windup_time: float = 0.15   # before hitbox activates
@export var active_time: float = 0.2    # hitbox is live
@export var recovery_time: float = 0.15 # after hit, input blocked
@export_range(0.0, 1.0) var move_scale: float = 0.5       # multiplied against SPEED while swinging
@export_range(0.0, 1.0) var rotation_scale: float = 0.15  # aim turn speed factor while swinging
@export var swing_sound: AudioStream
@export var swipe_fx_scene: PackedScene
