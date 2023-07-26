extends "res://content/monster/scarab/Scarab.gd"


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func subProcess(delta):
	set("monsterFollowerImmunity", phase == Phase.PROTECTED)
	.subProcess(delta)
	
	
