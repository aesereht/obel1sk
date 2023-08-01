extends DomeStation

func _ready():
	$Sprite.play("default")
	$WaveAlarm.visible = false

func enterStation():
	$Sprite.play("running")
	$Usable.updateFocus()

func exitStation():
	$Sprite.play("default")
	$Usable.updateFocus()

func waveAlertOn():
	$WaveAlarm.visible = true
	$WaveAlarm.frame = 0
	$WaveAlarm.playing = true

func waveAlertOff():
	$WaveAlarm.visible = false

func _on_Sprite_animation_finished():
	pass
