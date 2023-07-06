extends Node2D



func init():
	Data.listen(self, "obelisk.markCurrent", true)
	Data.listen(self, "obelisk.markMax", true)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"obelisk.markcurrent": 
			set_mark_count()
		"obelisk.markmax":
			set_mark_count()


func set_mark_count():
	$Label.text = str(Data.of("obelisk.markCurrent"), "/", Data.of("obelisk.markMax"))
