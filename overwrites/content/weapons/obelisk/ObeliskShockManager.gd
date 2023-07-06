extends Node2D

# tracks all shocks and arcs
# a shock is a collider that binds itself to a monster and then arcs to all other monsters in a radius
# those arced-to monsters get fed back here and damaged by the manager
# arcs are vfx-representation of the chain of shocks

var arced = false

var cur_shockDuration := 0.0

var shockedMonsters := []
var shocks := []
var arcs := []

const SHOCK = preload("res://content/weapons/obelisk/ObeliskShock.tscn")
const ARC = preload("res://content/weapons/obelisk/ObeliskShockArc.tscn")

func init(originMonster, shotPos):
	shock_at_monster(originMonster, originMonster, shotPos)
	$ArcStatic.play()

func _process(delta: float) -> void:
	if GameWorld.paused or Data.of("obelisk.arcDuration") == 0.0:
		$ArcStatic.stream_paused = true
		return
	
	if cur_shockDuration < Data.of("obelisk.arcDuration"):
		# hit stuff only when we have at least two monsters between which the arc could exist
		if actual_shocked_monsters_size() > 1:
			$ArcStatic.stream_paused = false
			for sm in shockedMonsters:
				if is_instance_valid(sm):
					sm.hit((Data.of("obelisk.arcDamage") + actual_shocked_monsters_size() * Data.of("obelisk.arcDamagePerMonster")) * delta, Data.of("obelisk.arcStun"))
					if not arced:
						var obelisk = Level.dome.find_node("WeaponContainer").get_node("Obelisk")
						obelisk.cur_arcCooldown = 0.0
						arced = true
		else:
			$ArcStatic.stream_paused = true
		cur_shockDuration += delta
	else:
		# disappear
		for s in shocks:
			s.queue_free()
		for a in arcs:
			if is_instance_valid(a):
				a.remove()
		queue_free()

func shock_at_monster(originMonster, m, originOverride:=Vector2.ZERO):
	if actual_shocked_monsters_size() == 0 and originMonster != m:
		add_shocked_monster(originMonster)
		#print("first origin monster")
	if shockedMonsters.has(m):
		#print("shockedMonsters has " + str(m))
		return
	if not (is_instance_valid(originMonster) and is_instance_valid(m)):
		#print("invalid monsters")
		return
	var s = SHOCK.instance()
	s.global_position = m.global_position
	s.connect("arcedToMonster", self, "shock_at_monster")
	s.init(m)
	shocks.append(s)
	if originMonster != m:
		add_shocked_monster(m)
	
	# the 2d physics server gave errors with this line while flushing queries and recommended to use deferred calls
	Level.stage.call_deferred("add_child", s)
	
	arc_vfx(originOverride)
#	arc_vfx2() # doesn't work for now, the other implementation is good enough I think


func actual_shocked_monsters_size():
	var result = 0
	for m in shockedMonsters:
		if is_instance_valid(m):
			if not m.dead:
				result += 1
	return result

func actual_arcs_size():
	var result = 0
	for a in arcs:
		if is_instance_valid(a):
			if a.visible:
				result += 1
	return result

func arc_vfx(originOverride:=Vector2.ZERO):
	for a in arcs:
		if is_instance_valid(a):
			a.remove()
		arcs.erase(a)
	
	# upper limit for performance reasons
	var act_size = actual_shocked_monsters_size()
	var arcLimit = 7.2 - log(act_size)
	var arced_monsters = []
	shockedMonsters.shuffle()
	for m1 in shockedMonsters:
		if not monster_valid(m1):
			continue
		for m2 in shockedMonsters:
			if not monster_valid(m2):
				continue
			#if m1 != m2 and (m1.maxHealth > 10 and m2.maxHealth > 10):
			if actual_arcs_size() > arcLimit and arced_monsters.has(m1) and arced_monsters.has(m2):
				return
			if arced_monsters.has(m1) and arced_monsters.has(m2):
				continue
			
			arced_monsters.append(m1)
			arced_monsters.append(m2)
			
			var a = ARC.instance()
			Level.stage.add_child(a)
			
			var o = originOverride if originOverride != Vector2.ZERO else monster_center(m1)
			
			a.arc()
			a.setOriginMonster(m1)
			a.setTargetMonster(m2)
			a.init(o, monster_center(m2))
			arcs.append(a)
			#Style.init(a)

#func arc_vfx2():
#	$Arc.clear_points()
#	var index = 0
#	var points = PoolVector2Array()
#	while index < shockedMonsters.size():
#		var index_inner = index
#		while index_inner < shockedMonsters.size():
#			var last_m = shockedMonsters[index]
#			var cur_m = shockedMonsters[index_inner]
#			if monster_valid(last_m) and monster_valid(cur_m):
#				var p = arc(monster_center(last_m), monster_center(cur_m), true)
#				points.append_array(p)
#			index_inner += 1
#		index += 1
#	for point in points:
#		$Arc.add_point(point)
#
#	Style.init($Arc)
#
#
#var arcNoise = 0.03
#var midPointDistance = 15
#var midPointNoise = 0.3
#func arc(from:Vector2, to:Vector2, jitter := false) -> PoolVector2Array:
#	var points = PoolVector2Array()
#
#	if from == to:
#		return points
#
#	$Arc.clear_points()
#	if jitter:
#		$Arc.add_point(from * (1.0 + rand_range(-arcNoise, arcNoise)))
#	else:
#		$Arc.add_point(from)
#
#	var dist = from.distance_to(to)
#	var dir = (to - from).normalized()
#	var m = midPointDistance + rand_range(-midPointNoise, midPointNoise) * midPointDistance
#	var mid_points = floor(dist / m)
#
#	for i in range(1, mid_points):
#		var pt = from
#		pt += dir * i * m
#		pt.x += rand_range(-pt.x, pt.x) * arcNoise
#		pt.y += rand_range(-pt.y, pt.y) * arcNoise
#
#		$Arc.add_point(pt)
#
#	if jitter:
#		$Arc.add_point(to * (1.0 + rand_range(-arcNoise, arcNoise)))
#	else:
#		$Arc.add_point(to)
#
#	return points
	


func monster_valid(m):
	if is_instance_valid(m):
		if not m.dead:
			return true
	return false

func monster_center(m) -> Vector2:
	if not is_instance_valid(m):
		Logger.warn("Shock Manager received an invalid monster instance")
		return Vector2.ZERO
	var sprite = m.get_node("Sprite")
	if not is_instance_valid(sprite):
		Logger.warn("Shock Manager received a monster with no literal Sprite on first level of scene tree")
		return m.position
	return m.position + sprite.position
	

func add_shocked_monster(m):
	if not shockedMonsters.has(m) and monster_valid(m):
		shockedMonsters.append(m)
		if not m.is_connected("died", self, "removed_shocked_monster"):
			m.connect("died", self, "removed_shocked_monster", [m])

func removed_shocked_monster(m):
	if shockedMonsters.has(m) and monster_valid(m):
		shockedMonsters.erase(m)
		m.disconnect("died", self, "removed_shocked_monster")
