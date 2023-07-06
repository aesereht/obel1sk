extends CollisionShape2D

var lifetime := 10.0

func init():
	$Glow.playing = true
	$Skull.playing = true
	
	Style.init(self)


func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
