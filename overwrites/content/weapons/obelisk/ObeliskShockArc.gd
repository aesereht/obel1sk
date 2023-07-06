extends Line2D


signal removed

var arcNoiseX = 0.03
var arcNoiseY = 0.03
var midPointDistance = 15
var midPointNoise = 0.3
var jitterInverval = 0.1
var cur_jitterInverval = 0.0

var from
var to
var startTo # starting value of to, NOT set in init
var originMonster
var targetMonster
var omHasSet = false
var tmHasSet = false
var lifetime = -1.0
var cur_lifetime = 0.0

var remove = false

export var visual = false # overriding parameter that doesn't check for monsters dying or anything
export var subArc = false
var subArcs := []

# set origin and target monsters before calling init
# arc will vanish if those are not set
func init(from: Vector2, to: Vector2):
	self.from = from
	self.to = to
	randomize()
	
	
	if originMonster == targetMonster and (originMonster != null and targetMonster != null):
		visible = false
		remove()
	elif from == to and not visual:
		visible = false
		remove()
	visible = true
	
	Style.init(self)

func arc(jitter := false, bindToMonsters := false):
	if from == to:
		return
	
	if originMonster == null or targetMonster == null:
		bindToMonsters = false
	if bindToMonsters:
		from = monster_center(originMonster)
		to = monster_center(targetMonster)
	
	clear_points()
#	for a in subArcs:
#		if is_instance_valid(a):
#			a.remove()
	if jitter:
		var x = from.x * (1.0 + rand_range(-arcNoiseX, arcNoiseX))
		var y = from.y * (1.0 + rand_range(-arcNoiseY, arcNoiseY))
		add_point(Vector2(x,y))
	else:
		add_point(from)
	
	var dist = from.distance_to(to)
	var dir = (to - from).normalized()
	var m = midPointDistance + rand_range(-midPointNoise, midPointNoise) * midPointDistance
	var mid_points = floor(dist / m)
	for i in range(1, mid_points):
		var pt = from
		pt += dir * i * m
		pt.x += rand_range(-pt.x, pt.x) * arcNoiseX
		pt.y += rand_range(-pt.y, pt.y) * arcNoiseY
		
		add_point(pt)
	
	# populate sub arcs on the first pass, and just readjust them on subsequent arc calls instead of instancing new ones
	if subArcs.size() == 0:
		for i in range(1, mid_points):
			var arc_scene = load("res://content/weapons/obelisk/ObeliskShockArc.tscn")
			var arc = arc_scene.instance()
			add_child(arc)
			arc.subArc = false
			arc.visual = true
			arc.init(points[i], points[i])
			arc.startTo = points[i]
			arc.connect("removed", self, "remove_sub_arc", [arc])
			subArcs.append(arc)
	
	if visible and subArcs.size() > 0:
		randomize()
		for p in points:
			var a = subArcs[randi() % subArcs.size()]#for a in subArcs:
			var rand = Vector2(rand_range(-5, 5), rand_range(-7, 3))
			a.from = p#Vector2(100, -100)
			a.to = a.from + Vector2(rand.x + sign(rand.x) * width, rand.y * width + sign(rand.y) * width)
			a.width = max(width * 0.1, 1)
			a.arcNoiseX = arcNoiseX * 0.2
			a.arcNoiseY = arcNoiseY * 0.2
			a.init(a.from, a.to)
	
#		if subArc:
#			var arc_scene = load("res://content/weapons/obelisk/ObeliskShockArc.tscn")
#			var arc = arc_scene.instance()
#			add_child(arc)
#
#			var f = pt
#			var t = pt
#			t += Vector2(rand_range(-5, 5) * 2 * width, rand_range(-5, 5) * 2 * width)
#			#var sub_dist = f.distance_to(t)
#			arc.subArc = false
#			arc.visual = true
#			arc.init(f, t)
#
#			arc.width = width * 0.25
#			arc.midPointDistance = 5
#			arc.arc()
#			arc.connect("removed", self, "remove_sub_arc", [arc])
#			subArcs.append(arc)
	
	if jitter:
		var x = to.x*1.0 + rand_range(-arcNoiseX, arcNoiseX)
		var y = to.y*1.0 + rand_range(-arcNoiseY, arcNoiseY)
		add_point(Vector2(x,y))
	else:
		add_point(to)

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	if cur_jitterInverval >= jitterInverval:
		cur_jitterInverval = 0.0
		if visual:
			arc(true)
			for a in subArcs:
				if is_instance_valid(a):
					a.arc(true)
		else:
			arc(true, true)
			for a in subArcs:
				if is_instance_valid(a):
					a.arc(true, true)
	else:
		cur_jitterInverval += delta
	
	if not visual:
		var oDead = false
		var tDead = false
		if not is_instance_valid(originMonster):
			oDead = true
		elif originMonster.dead:
			oDead = true
		if not is_instance_valid(targetMonster):
			tDead = true
		elif targetMonster.dead:
			tDead = true
		
		if oDead or tDead:
			remove()
	
	if (from == Vector2.ZERO or to == Vector2.ZERO) and not visual:
		remove()
	
	
	cur_lifetime += delta
	if cur_lifetime > lifetime:
		if lifetime != -1:
			remove()

func remove():
	emit_signal("removed")
	#print("remove")
	queue_free()
	

func setOriginMonster(m):
	originMonster = m

func setTargetMonster(m):
	targetMonster = m


func monster_center(m) -> Vector2:
	if not is_instance_valid(m):
		return Vector2.ZERO
	var sprite = m.get_node("Sprite")
	if not is_instance_valid(sprite):
		Logger.warn("Shock Arc received a monster with no literal Sprite on first level of scene tree")
		return m.position
	return m.position + sprite.position

func remove_sub_arc(a):
	if subArcs.has(a):
		subArcs.erase(a)
		a.disconnect("removed", self, "remove_sub_arc")
