extends AnimatedSprite

var blockers := 2

func _ready() -> void:
	visible = false
	z_index = 300
	connect("animation_finished", self, "decrement_blockers")
	$SFX.connect("finished", self, "decrement_blockers")

func init():
	Style.init(self)
	visible = true
	play("default")
	$SFX.play()


func decrement_blockers():
	blockers -= 1
	if blockers <= 0:
		queue_free()
