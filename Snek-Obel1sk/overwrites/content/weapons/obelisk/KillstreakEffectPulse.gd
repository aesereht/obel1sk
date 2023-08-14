extends AnimatedSprite



func _ready() -> void:
	Style.init(self)
	play("default")


func _on_Pulse_animation_finished() -> void:
	queue_free()
