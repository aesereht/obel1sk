extends AnimatedSprite


func showProgress(value:float):
	if value >= 1.0:
		frame = 5
	else:
		var f = clamp(floor((5) * value), 0, 5)
		frame = int(f)
