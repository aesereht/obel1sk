extends AnimatedSprite



func _ready() -> void:
	Style.init(self)
	visible = true
	play("default")
	connect("animation_finished", self, "queue_free")
