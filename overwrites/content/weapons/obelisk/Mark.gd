extends "res://content/weapons/obelisk/MonsterFollower.gd"


func _ready() -> void:
	$Sprite.play()

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	if is_instance_valid(targetMonster):
		targetMonster.hit(0, targetMonster.fullStunAt * Data.of("obelisk.slowMark"))
