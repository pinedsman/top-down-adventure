extends CanvasLayer
class_name WaveOverlay

# All visuals are driven by named animations in the AnimationPlayer.
# Artists: edit those animations freely — do not rename them.
#   "fade_in"       — reveal the scene from black
#   "fade_out"      — cover the scene to black
#   "wave_intro"    — display the wave number splash (reads _label.text)
#   "wave_complete" — display the wave complete splash

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _label: Label = $WaveLabel


func fade_in() -> void:
	_anim.play("fade_in")
	await _anim.animation_finished


func fade_out() -> void:
	_anim.play("fade_out")
	await _anim.animation_finished


func show_wave_intro(wave_number: int) -> void:
	_label.text = "Wave %d" % wave_number
	_anim.play("wave_intro")
	await _anim.animation_finished


func show_wave_complete() -> void:
	_label.text = "Wave Complete"
	_anim.play("wave_complete")
	await _anim.animation_finished
