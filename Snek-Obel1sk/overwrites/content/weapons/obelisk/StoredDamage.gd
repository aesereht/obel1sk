extends Node2D


func setValue(value:int):
	var displayedDamage = 0
	for c in get_children():
		if c is AnimatedSprite:
			var diff = value - displayedDamage
			if diff >= Data.of("obel1sk.damage"):
				displayedDamage += Data.of("obel1sk.damage")
				c.showProgress(1.0)
				continue
			elif diff > 0 and diff < Data.of("obel1sk.damage"):
				c.showProgress(float(diff) / float(Data.of("obel1sk.damage")))
				displayedDamage += diff
				continue
			
			else:
				c.showProgress(0.0)
