extends Node2D


signal arcedToMonster(origin, m)

var originMonster
var originPos
var arcedMonsters := []
var radius := 0.0

const HOLD_PHYSICS_FRAMES := 2
const SHOCK_REGISTER_FRAMES := 2 # number of frames after starting to arc that the shock accepts new monsters to track
var cur_holdFrames := 0
var cur_registerFrames := 0
var blockers := 3

var arcedCount= 0
var arcedMax= 3

var frameDamageDelay := 10 # number of frames that have to pass before the damage gets sent out
var emittedDamage := false
var framesSinceStart = 0

func set_origin_monster(om):
	originMonster = om
	originPos = om.global_position

func init(om):
	set_origin_monster(om)
	set_physics_process(true)
	decrement_blockers()
	
	radius = Data.of("obel1sk.arcRange")
	$Area2D/CollisionShape2D.shape.radius = radius
	
	Style.init(self)

func _physics_process(delta: float) -> void:
	if GameWorld.paused:
		return
	if cur_holdFrames >= HOLD_PHYSICS_FRAMES:
		decrement_blockers()
	else:
		cur_holdFrames += 1
	
	if blockers <= 0:
		if cur_registerFrames <= SHOCK_REGISTER_FRAMES:
			cur_registerFrames += 1
	
	framesSinceStart += 1

func _process(delta: float) -> void:
	if framesSinceStart > frameDamageDelay and not emittedDamage:
		if is_instance_valid(originMonster):
			originMonster.hit(Data.of("obel1sk.arcInitialDamage"),0)
		emittedDamage = true

func decrement_blockers():
	blockers -= 1
	if blockers <= 0:
		arc()

func arc():
	# only arc and communicate results to manager
	# manager handles damage
	if arcedCount < arcedMax:
		for m in arcedMonsters:
			if not m == originMonster:
				emit_signal("arcedToMonster", originMonster, m)
		arcedCount += 1

func _on_Area2D_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		if (not area == originMonster) and cur_registerFrames < SHOCK_REGISTER_FRAMES:
			# small monsters get instantly fried
			# this is mostly for performance reasons because spawning a bunch of arcs over a swarm of ticks, only to kill them within the next 2 frames is really taxing on performance without much gameplay or immersion payoff
			var damage = Data.of("obel1sk.arcDamage") * Data.of("obel1sk.arcDuration") * 0.1
			if area.maxHealth <= damage or area.currentHealth <= damage:
				area.hit(damage, Data.of("obel1sk.arcStun"))
			else:
				arcedMonsters.append(area)
				decrement_blockers()
