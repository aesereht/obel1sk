extends Node2D

signal damagedMonster
signal killedMonster

var reticle = null
var obelisk = null

var damageMults = []
var damageAdds = []

func init():
	damageMults.append(Data.of("obelisk.damageMult"))
	
	reticle = Level.dome.find_node("WeaponContainer").get_node("Obelisk/Reticle")
	obelisk = Level.dome.find_node("WeaponContainer").get_node("Obelisk")
	var tracker = obelisk.get_node("KillstreakTracker")
	var merc = obelisk.get_node("MercilessTracker")
	var mark_count = obelisk.marks.size()
	
	if Data.of("obelisk.maxRestDamageMult") > 0.0:
		damageMults.append(obelisk.cur_restDamageMult)
	
	if obelisk.cur_restDamageMult == Data.of("obelisk.maxRestDamageMult"):
		damageAdds.append(Data.of("obelisk.fullRestDamageAdd"))
	
	if obelisk.storedDamage > 0:
		var bonus = min(obelisk.storedDamage, Data.of("obelisk.damage"))
		obelisk.setStoredDamage(obelisk.storedDamage - bonus)
		damageAdds.append(bonus)
	
	if mark_count > 0:
		damageMults.append(Data.of("obelisk.markBonusDamagePerMonster") * (mark_count - 1) + 1.0)
	
	if Data.of("obelisk.killstreaks"):
		if not tracker.active() and tracker.progress < tracker.Goal() * Data.of("obelisk.killstreakGHFthreshold"):
			damageMults.append(Data.of("obelisk.killstreakInactiveDamage"))
		if tracker.active() and Data.of("obelisk.chStyle") == 4:
			damageMults.append(1.0 / Data.of("obelisk.killstreakActiveShootDelayMultiplier"))
	
	if merc.aboveThreshold() and Data.of("obelisk.chStyle") == 4:
		damageMults.append(1.0 / Data.of("obelisk.mercilessThresholdShootDelayMultiplier"))
	
	if Data.of("obelisk.ammoUsage") > 0 and obelisk.cur_ammo == 0:
		damageMults.append(Data.of("obelisk.lastShotDamageMult"))
		print("more damage")
	
	# is capped at 0 by default so no if statement needed
	var merciless = obelisk.mercilessMult("damage")
	damageMults.append(merciless)

# the obelisk has a default multiplier of 1.0 so all further multipliers should have default value 0.0 if they are not supposed to increase damage
func total_mult() -> float:
	var totalMult = 0.0
	for v in damageMults:
		totalMult += v
	return totalMult

func total_add() -> float:
	var totalAdd = Data.of("obelisk.damage")
	for a in damageAdds:
		totalAdd += a
	return totalAdd

func total_damage():
	return total_add() * total_mult()
