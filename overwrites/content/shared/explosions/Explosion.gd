extends Node2D

var removable := 2
export(float) var damage := 50.0
export(float) var stun_override := -1.0
signal remove
signal explosion_disabled
signal stun_override_hit(area)

func _ready():
	$Sprite.frame = 0
	$Sprite.playing = true
	$Sound.play()
	Style.init(self)
	$Area2D/Collision.disabled = true
	
	InputSystem.getCamera().shake(10 + damage, 0.35)

func _process(delta):
	if removable <= 0:
		emit_signal("remove")
		queue_free()

func _on_Sprite_animation_finished():
	removable -= 1
	$Sprite.visible = false

func _on_Sound_finished():
	removable -= 1

func _on_Area2D_area_entered(area):
	if stun_override > 0.0:
		area.hit(damage, stun_override)
		emit_signal("stun_override_hit", area)
	else:
		area.hit(damage, damage * 0.1)

func _on_Sprite_frame_changed():
	if $Sprite.frame == 1:
		$Area2D/Collision.disabled = false
	elif $Sprite.frame == 4:
		$Area2D/Collision.disabled = true
		emit_signal("explosion_disabled")
