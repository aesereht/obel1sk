extends "res://content/weapons/obelisk/MonsterFollower.gd"


var stunDecay = 0.1
var curStun = 1.0
var minStun = 0.1
var fullStunDuration = 0.5

var cur_fullStunDuration = 0.0

var baseAmount = 0

func _ready() -> void:
	$Sprite.play()
	baseAmount = $Particles2D.amount

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	if is_instance_valid(targetMonster):
		var damage = (logWithBase(stacks, Data.of("obelisk.nukeEchoDps")) * Data.of("obelisk.nukeEchoDps")) + Data.of("obelisk.nukeEchoDps") + stacks
		damage *= delta
		targetMonster.hit(damage, max(targetMonster.fullStunAt * curStun, targetMonster.fullStunAt * minStun * stacks))
	
	if cur_fullStunDuration < fullStunDuration:
		cur_fullStunDuration += delta
	else:
		curStun = max(curStun - stunDecay * delta, 0)
	
	if is_instance_valid(targetMonster):
		$Particles2D.process_material.emission_sphere_radius = targetMonster.getSpriteSize().x / 4
	


func increment_stacks():
	stacks += 1
	curStun = 1.0
	$Sprite.speed_scale = stacks
	$Particles2D.amount = baseAmount * (stacks + stacks)

func logWithBase(value, base):
	return log(value) / log(base)
