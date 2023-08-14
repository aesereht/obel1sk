extends Node2D



func init():
	Data.listen(self, "obel1sk.markCurrent", true)
	Data.listen(self, "obel1sk.markMax", true)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"obel1sk.markcurrent": 
			set_mark_count()
		"obel1sk.markmax":
			set_mark_count()


func set_mark_count():
	$Label.text = str(Data.of("obel1sk.markCurrent"), "/", Data.of("obel1sk.markMax"))
