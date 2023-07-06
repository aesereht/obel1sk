extends "res://content/weapons/obelisk/DamageManager.gd"

signal shotDown

var cur_explosionDelay = 0.0

enum ShotTypes {
	Explosion,
	Mark
}

var blockers = 2

# these vars need to be here because mark detonationss need to be able to override Data
var explosionDelay = 0.0
var radius = 0
var stun = 0.0
var singleTarget := true
var shot_type = ShotTypes.Explosion


const EXPLOSION_GROUND = preload("res://content/shared/explosions/Explosion98.tscn")
const EXPLOSION_AIR = preload("res://content/shared/explosions/Explosion97.tscn")
const EXPLOSION_STUN = preload("res://content/shared/explosions/Explosion96.tscn")
const EXPLOSION_SINGLE = preload("res://content/shared/explosions/Explosion95.tscn")
const EXPLOSION_MARK = preload("res://content/shared/explosions/Explosion94.tscn")
const LIGHTNING_DOWN = preload("res://content/weapons/obelisk/LightningDown.tscn")
const MARK = preload("res://content/weapons/obelisk/Mark.tscn")
const EXPLOSION_SNIPER = preload("res://content/shared/explosions/Explosion93.tscn")

const SHOCK_MANAGER = preload("res://content/weapons/obelisk/ObeliskShockManager.tscn")
const NUKE_ECHO = preload("res://content/weapons/obelisk/DecayStunDoT.tscn")

var hitMonsters := []
var physics_passed := false
const EXPLOSION_HOLD_FRAMES := 3
var cur_hold_frames := 0
var has_exploded = false
var first_frame = true
var allowArc = true

var anticipationBaseScale = 1.0

func init():
	.init()
	stun = Data.of("obelisk.stun")
	set_radius(Data.of("obelisk.radius"))
	explosionDelay = Data.of("obelisk.explosionDelay")
	singleTarget = Data.of("obelisk.singleTarget")
	shot_type = int(Data.of("obelisk.shotType"))
	
	$Anticipation.visible = explosionDelay > 0.0
	$AnticipationOutline.visible = Data.of("obelisk.anticipationOutline")
	anticipationBaseScale = (float(Data.of("obelisk.radius")) * 2) / 55.0
	$AnticipationOutline.scale = Vector2(anticipationBaseScale, anticipationBaseScale)
	$AnticipationOutline.playing = true
	
	
	Style.init(self)

func set_radius(value: float):
	radius = value
	$HitArea/CollisionShape2D.shape.radius = value
	


func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	if not has_exploded:
		# don't explode on the first frame because monsters need to be registered first
		if cur_explosionDelay >= explosionDelay and not first_frame and physics_passed:
			if cur_hold_frames >= EXPLOSION_HOLD_FRAMES:
				explode()
			
		else:
			cur_explosionDelay += delta
	
	# scale anticipationOutline based on explosionDelay progress to explosion
	# doesn't look good imo so it's commented out
#	if explosionDelay > 0.0:
#		var s = cur_explosionDelay / explosionDelay
#		$AnticipationOutline.scale = Vector2(s * anticipationBaseScale, s * anticipationBaseScale)
	
	first_frame = false

func _physics_process(delta: float) -> void:
	if not physics_passed:
		if cur_hold_frames >= EXPLOSION_HOLD_FRAMES:
			physics_passed = true
			set_physics_process(false)
		else:
			cur_hold_frames += 1


func explode():
	$Anticipation.visible = false
	$AnticipationOutline.visible = false
	has_exploded = true
	vfx_explosion()
	
	var stun_rad = Data.of("obelisk.stunRadius") * radius
	var expl_stun
	if stun_rad > radius:
		expl_stun = EXPLOSION_STUN.instance()
		expl_stun.damage = 0
		#expl_stun.get_node("Area2D").set_collision_mask_bit(7, false)
		expl_stun.global_position = global_position
		Level.stage.add_child(expl_stun)
		expl_stun.connect("remove", self, "decrement_blockers")
		blockers += 1
		expl_stun.stun_override = 300
		expl_stun.connect("stun_override_hit", self, "decay_stun_dot")
		#expl_stun.connect("explosion_disabled", $HitArea, "set_collision_mask_bit", [7, false])
		Style.init(expl_stun)
		var s2 = stun_rad
		s2 /= 256.0 / 2.0 # magic number based half the size of the explosion texture
		expl_stun.scale = Vector2(s2,s2)
	
	# if we hit sth, put explosion in front of enemies
	# this is useful for subtle visual hints in the trailing non-hitting frames of the explosion
	if hitMonsters.size() > 0:
		if Data.of("obelisk.arcRange") > 0.0 and allowArc:
			var firstMonster = hitMonsters[0]
			var sm = SHOCK_MANAGER.instance()
			Level.stage.add_child(sm)
			sm.init(firstMonster, (position + firstMonster.position) / 2.0)
		
		
		if expl_stun != null:
			expl_stun.get_node("Sprite").z_index = 200
	else:
		
		if expl_stun != null:
			expl_stun.get_node("Sprite").z_index = -1
	
	if hitMonsters.size() > 0:
		reticle.hit_marker()
	
	emit_signal("shotDown")
	
	if hitMonsters.size() > 0 and singleTarget:
		var smallest_monster = hitMonsters[0]
		var smallest_dist = global_position.distance_to(hitMonsters[0].global_position)
		for m in hitMonsters:
			if global_position.distance_to(m.global_position) < smallest_dist:
				smallest_monster = m
		hitMonsters = [smallest_monster]
	
	match shot_type:
		ShotTypes.Explosion:
			for m in hitMonsters:
				if m.currentHealth <= total_damage():
					emit_signal("killedMonster", m)
				m.hit(total_damage(), stun)
				emit_signal("damagedMonster", min(total_damage(), m.maxHealth))
				if stun_rad <= radius:
					decay_stun_dot(m)
		ShotTypes.Mark:
			for m in hitMonsters:
				if Data.of("obelisk.markCurrent") < Data.of("obelisk.markMax") and obelisk.cur_ammo > 0 and not m.monsterFollowerImmunity:
					if not obelisk.markedMonsters.has(m):
						obelisk.addToMarkedMonsters(m)
						var mark = MARK.instance()
						Level.stage.add_child(mark)
						obelisk.marks.append(mark)
						mark.set_monster(m)
						mark.set_offset(global_position - m.global_position) 
						$HitArea.set_collision_mask_bit(7, false)
						
						mark.init()
						Data.apply("obelisk.markCurrent", int(Data.of("obelisk.markCurrent")) + 1)
				else:
					break
	
	# shake harder the closer to the dome the shot lands
	var t = Data.of("obelisk.shootDelay")
	InputSystem.getCamera().shake((900 - abs(global_position.length())) * 0.07, t * 0.5)
	
	var audio_player
	if Data.of("obelisk.shotType") == 1 and hitMonsters.size() > 0: # mark hit something
		if shot_type == 0: # triggered explosion of mark
			$ShotDefault.play() 
			$ShotDefault.connect("finished", self, "decrement_blockers")
			audio_player = $ShotDefault
		else: # initial marking
			$ShotMarkMonster.play()
			$ShotMarkMonster.connect("finished", self, "decrement_blockers")
			audio_player = $ShotMarkMonster
	elif Data.of("obelisk.chStyle") == 1:
			$ShotSniper.play()
			$ShotSniper.connect("finished", self, "decrement_blockers")
			audio_player = $ShotSniper
			if obelisk.cur_ammo == 0:
				blockers += 1
				$ShotSniper.volume_db -= 3
				$LastShotSniper.play()
				$LastShotSniper.connect("finished", self, "decrement_blockers")
			elif obelisk.cur_ammo > 0 and obelisk.cur_ammo <= obelisk.maxAmmo * 0.25:
				$ShotSniper.pitch_scale = 0.5
				$ShotSniper.volume_db -= 3
	elif Data.of("obelisk.chStyle") == 5: # fullauto plays no shot sfx bc it has static
		decrement_blockers()
	elif obelisk.cur_ammo == 0:
		$LastShot.play()
		$LastShot.connect("finished", self, "decrement_blockers")
		audio_player = $LastShot
	else:
		if Data.of("obelisk.chStyle") == 2:
			$ShotNuke.play()
			$ShotNuke.connect("finished", self, "decrement_blockers")
			audio_player = $ShotNuke
		elif Data.of("obelisk.damage") <=20:
			$ShotStarter.play()
			$ShotStarter.connect("finished", self, "decrement_blockers")
			audio_player = $ShotStarter
		else:
			$ShotDefault.play() 
			$ShotDefault.connect("finished", self, "decrement_blockers")
			audio_player = $ShotDefault
	
	if (obelisk.cur_ammo > 0 and obelisk.cur_ammo <= obelisk.maxAmmo * 0.25) or (obelisk.cur_ammo == 1 and obelisk.maxAmmo > 2):
		if audio_player is AudioStreamPlayer:
			audio_player.pitch_scale = 0.5

func decay_stun_dot(area):
	if Data.of("obelisk.nukeEchoDps") > 0.0 and not area.monsterFollowerImmunity:
		var dot = NUKE_ECHO.instance()
		Level.stage.add_child(dot)
		dot.set_monster(area)
		dot.set_offset(global_position - area.global_position) 
		dot.init()

func vfx_explosion():
	var expl
	var s = radius # divisors are magic numbers based on half the visual size of the explosion texture
	var ground_threshold = -35
	if shot_type == 1: # mark
		expl = EXPLOSION_MARK.instance()
	elif Data.of("obelisk.chStyle") == 1: #sniper
		expl = EXPLOSION_SNIPER.instance()
		if position.y >= ground_threshold:
			expl.get_node("Sprite").animation = "ground"
		else:
			expl.get_node("Sprite").animation = "air"
	elif singleTarget:
		expl = EXPLOSION_SINGLE.instance()
	else:
		if position.y >= ground_threshold:
			expl = EXPLOSION_GROUND.instance()
			if radius <= 24/2:
				expl.get_node("Sprite").animation = "24"
				expl.get_node("Sprite").position = Vector2(-1, -13)
			elif radius <= 96/2:
				expl.get_node("Sprite").animation = "96"
				expl.get_node("Sprite").position = Vector2(2, -49)
			else:
				expl.get_node("Sprite").animation = "256"
				expl.get_node("Sprite").position = Vector2(-3, -60)
		else:
			expl = EXPLOSION_AIR.instance()
			if radius <= 24/2:
				expl.get_node("Sprite").animation = "24"
			elif radius <= 96/2:
				expl.get_node("Sprite").animation = "96"
			else:
				expl.get_node("Sprite").animation = "256"
	if not Data.of("obelisk.chStyle") == 1:
		var sprite = expl.get_node("Sprite")
		var sprite_size = sprite.get_sprite_frames().get_frame(sprite.animation, 0).get_size()
		s /= sprite_size.x / 2
		expl.scale = Vector2(s,s)
	
	expl.damage = 0
	expl.get_node("Area2D").set_collision_mask_bit(7, false)
	Style.init(expl)
	Level.stage.add_child(expl)
	expl.global_position = global_position
	if Data.of("obelisk.chStyle") == 1 and position.y >= ground_threshold:
		expl.global_position.y += -13
	
	expl.connect("remove", self, "decrement_blockers")
	expl.connect("explosion_disabled", $HitArea, "set_collision_mask_bit", [7, false])
	
	# if we hit sth, put explosion in front of enemies
	# this is useful for subtle visual hints in the trailing non-hitting frames of the explosion
	if hitMonsters.size() > 0:
		expl.get_node("Sprite").z_index = 200
	else:
		expl.get_node("Sprite").z_index = -1


func set_shot_type(value:int):
	shot_type = value

func decrement_blockers():
	blockers -= 1
	if blockers <= 0:
		queue_free()

func _on_HitArea_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addToHitMonsters(area)

func _on_HitArea_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeFromHitMonsters(area)

func addToHitMonsters(m):
	if not hitMonsters.has(m):
		hitMonsters.append(m)
		if not m.is_connected("died", self, "removeFromHitMonsters"):
			m.connect("died", self, "removeFromHitMonsters", [m])

func removeFromHitMonsters(m):
	if hitMonsters.has(m):
		if not m.alive() and m.maxHealth > 10:
			reticle.kill_marker_next_frame = true
		hitMonsters.erase(m)
		m.disconnect("died", self, "removeFromHitMonsters")
