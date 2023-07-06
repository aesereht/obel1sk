extends Node2D

const SHOT = preload("res://content/weapons/obelisk/ObeliskShot.tscn")
const BEAM = preload("res://content/weapons/obelisk/ObeliskBeam.tscn")
# stats
var maxAmmo := 1
# minQuickReload: range [0,1]
# maxQuickReload: part of the reload range that is available for quick load
# Data.of("obelisk.maxQuickReloadWindow"): maximum amount of seconds the quickload can be there if the span of min - max is too large
#var maxReticleSpeed := 0.0 # start at 2.0, maximum of around 6.0 (becomes uncontrollable otherwise
var cur_shootingSpread = 0.0
var beamAmmoTickDelay := 0.05


# internal behavior tracking / controls
var is_active := false
var can_shoot := true
var can_reload := false
var is_reloading := false
var cur_reloadTime := 0.0
var cur_shootDelay := 0.0
var cur_burstDelay := 0.0
var cur_beamAmmoTickDelay := 0.0
var cur_ammo := 0
var shoot_button_down_from_shot := false
var reload_button_down_from_reload := false
var shoot_button_down_from_reload := false
var can_increment_quick_reload_attempts := true
var quick_reload_attempts := 0
var cur_burstCount = 0
var last_fire := 0.0
var last_spec := 0.0


var restDamageMultBuildup := 1.75
var cur_restDamageMult := 0.0

var anticipation_deadzone := 1.2 # window before reload bar slider starts moving in s
var cur_anticipation_deadzone := 0.0

var min_shoot_delay = 0.025 #hard-coded lower bound
var shoot_delay_reduction_decay := 0.17
var cur_shoot_delay_reduction := 0.0
var isShootingM := false # movement-based determination
var isShootingA := false # action-based determination

var cur_batteryDelay := 0.0
var cur_batterySingleProgress := 0.0
var markDetonationDelay := 0.25
var cur_markDetonationDelay := 0.0
var can_detonate = true
var arcCooldown = 0.0
var cur_arcCooldown = 0.0
var timeSinceLastShot = 0.0
var timeSinceWaveEnded = 0.0
var baseFullAutoVolume:float

var arcUpSustain = 0.4
var cur_arcUpSustain = 0.0

var special_slow = 1.0
var special_slow_coyote_time = 0.075
var cur_special_slow_coyote_time = 0.0
var ammoRatioOnReloadStart = 0.0

var beam = null
var noSpreadRemainingDuration := 0.0

var remainingAutoAimDuration := 0.0
var storedDamage := 0
var reloadFromEmpty := false

var arcStunMonsters := []

enum AttackTypes{
	Shot,
	Beam
}
export (AttackTypes) var attack_type = AttackTypes.Shot
enum ShotTypes {
	Explosion,
	Mark
}
enum SpecialTypes {
	Reload,
	DetonateMarks,
	SlowReticle
}
var marks := []
var markedMonsters := []

# mouse stuff
enum ControlModes{
	Keyboard,
	MouseDrag,
	MousePing
}
export (ControlModes) var control_mode = ControlModes.Keyboard
var reticle_target : ReticleTarget = null
const RETICLE_TARGET = preload("res://content/weapons/obelisk/ReticleTarget.tscn")
const LIGHTNING_UP = preload("res://content/weapons/obelisk/LightningUp.tscn")
const ARC = preload("res://content/weapons/obelisk/ObeliskShockArc.tscn")
const KILLSTREAK = preload("res://content/weapons/obelisk/KillstreakEffect.tscn")
const RAD_AREA = preload("res://content/weapons/obelisk/RadiationApplyArea.tscn")
const DEATH_CANDLE = preload("res://content/weapons/obelisk/DeathCandle.tscn")

var killstreak_effects := []


# other weapons use a cupola path but this doesn't need anything in its init func so we give it an underscore
func init(_unusedCupolaPath):
	$Reticle.position = $ReticleSpawn.position
	$Reticle.init()
	$MarkCounter.init()
	$KillstreakTracker.init()
	$KillstreakTracker.connect("triggerKillstreak", self, "triggerKillstreak")
	$KillstreakTracker.connect("endKillstreak", self, "endActiveKillstreak")
	$MercilessTracker.init()
	
	$Arc.init(Vector2.ZERO, Vector2.ZERO)
	
	Data.listen(self, "obelisk.maxAmmo", true)
	Data.listen(self, "obelisk.reloadTime", true)
	Data.listen(self, "obelisk.minQuickReload", true)
	Data.listen(self, "obelisk.maxQuickReload", true)
	Data.listen(self, "obelisk.maxQuickReloadWindow", true)
	Data.listen(self, "obelisk.attackType", true)
	Data.listen(self, "obelisk.arcCooldown", true)
	Data.listen(self, "monsters.wavepresent", true)
	Data.listen(self, "obelisk.shotType", true)
	Data.listen(self, "obelisk.markCurrent", true)
	Data.listen(self, "obelisk.killstreaks", true)
	Data.listen(self, "obelisk.chStyle", true)
	Data.listen(self, "obelisk.mercilessMax", true)
	Data.listen(self, "obelisk.shootDelay", true)
	Data.listen(self, "obelisk.autoAimDuration", true)
	Data.listen(self, "dome.health")
	Data.listen(self, "obelisk.storedDamageMax", true)
	Data.listen(self, "obelisk.damage", true)
	
	maxAmmo = int(Data.of("obelisk.maxAmmo"))
	attack_type = int(Data.of("obelisk.attackType"))
	arcCooldown = Data.of("obelisk.arcCooldown")
	
	
	$AmmoDisplay.init(maxAmmo)
	ammo_counter_visible(false)
	merciless_tracker_visible(false)
	set_cur_ammo(maxAmmo)
	
	# check if this range exceeds the maximum allowed length (in s) and clamp to that
	init_quick_reload()
	$QuickReload.set_visible(false)
	$BeamOutline.visible = canBeamOutlineBeVisible()
	
	
	baseFullAutoVolume = $FullAutoSound.volume_db
	cur_shootDelay = shootDelay()
	
	$AutoAim.playing = true
	
	Style.init(self)



func move(dir:Vector2, allowMove:bool = true):
	if not allowMove or GameWorld.paused or not is_active:
		$Reticle.move(Vector2.ZERO, 0.0)
		return
	
	
	var speed_mod = 1.0
	
	if is_reloading and (not Data.of("obelisk.killstreakActiveFullSpeed") or not $KillstreakTracker.active()) and not Data.of("obelisk.rechargeAmmo"):
		speed_mod *= Data.of("obelisk.speedWhileReloading")
	if Data.of("obelisk.killstreaks") and Data.of("obelisk.killstreakInactiveEffects"):
		if not $KillstreakTracker.active() and $KillstreakTracker.progress >= $KillstreakTracker.Goal() * Data.of("obelisk.killstreakGHFthreshold"):
			speed_mod *= Data.of("obelisk.killstreakInactiveSpeed")
	
	$Reticle.killstreakActive = $KillstreakTracker.active()
	
	if cur_ammo <= 0 and not is_reloading: speed_mod *= Data.of("obelisk.speedWhileNoAmmo")
	# shootingSpread * 0.1 is like a small grace thingy to make the transition from shooting to not shooting a bit smoother
	match attack_type:
		AttackTypes.Shot:
			if (($Reticle.cur_spread > $Reticle.maxSpread() + cur_shootingSpread * 0.1) and cur_ammo > 0) or isShootingA:
				if not Data.of("obelisk.killstreakActiveFullSpeed") and not $KillstreakTracker.active():
					speed_mod *= Data.of("obelisk.speedWhileShooting")
				isShootingM = true
			else:
				isShootingM = false
			
		AttackTypes.Beam:
			if (is_beam_active()):
				if not Data.of("obelisk.killstreakActiveFullSpeed") and not $KillstreakTracker.active():
					var t = clamp((beam.cur_beamWindup * beam.cur_beamWindup) / beam.beamWindup, 0, 1)
					speed_mod *= Data.of("obelisk.speedWhileShooting") * t
			dir.y = 0
	
	speed_mod *= special_slow
	
	speed_mod *= mercilessMult("speed")
	
	$Reticle.move(dir, speed_mod)
	if is_instance_valid(beam):
		var target = sky_target($Reticle.global_position, false)
		
		if not $BeamTargetPointer.is_colliding() or Data.of("obelisk.piercingBeam"):
			beam.global_position = $Reticle.global_position
			beam.setHitVFX(false)
		else:
			var col_pos = $BeamTargetPointer.get_collision_point()
			var col_dir =  col_pos - target
			var dist_to_collider = col_pos.distance_to($BeamTargetPointer.get_collider().global_position)
			col_pos += col_dir.normalized() * dist_to_collider * 0.35
			beam.global_position = col_pos
			beam.setHitVFX(true)
		
		beam.look_at(target)
		beam.rotate(PI * 0.5)

func action(fireStrength:float, specialStrength:float, allowShoot:bool):
	if not allowShoot or GameWorld.paused or not is_active:
		return
	
	var fire = fireStrength
	var spec = specialStrength
	# only assume the player is doing something if the trigger is going down
	# otherwise the positive inputs from releasing the trigger when fullauto/auto-reload will trip the quick reload instantly
	if fire < last_fire:
		fire = 0.0
	if spec < last_spec or (int(Data.of("obelisk.ammoUsage")) == 0 and Data.of("obelisk.shotType") != 1):
		spec = 0.0
	
	isShootingA = fire > 0.0 or timeSinceLastShot < 0.1
	
	if not shoot_button_down_from_reload:
		match attack_type:
			AttackTypes.Shot:
				match int(Data.of("obelisk.shotType")):
					ShotTypes.Explosion:
						if not int(Data.of("obelisk.specialType")) == SpecialTypes.SlowReticle:
							actionF_shot(fire, spec)
						elif not is_reloading:
							actionF_shot(fire, spec)
					ShotTypes.Mark:
						actionF_shot(fire, spec)
			AttackTypes.Beam:
				actionF_beam(fire, spec)
	
	if fire == 0.0:
		shoot_button_down_from_shot = false
		shoot_button_down_from_reload = false
	
	if fire > 0.0 and not Data.of("obelisk.allowReload") and cur_ammo == 0 and not shoot_button_down_from_shot and not Data.of("obelisk.fullAuto") and timeSinceLastShot > 0.1:
		$Reticle.denial()
	
	match int(Data.of("obelisk.specialType")):
		SpecialTypes.Reload:
			actionS_reload(fire, spec)
		SpecialTypes.DetonateMarks:
			actionS_detonate(fire, spec)
		SpecialTypes.SlowReticle:
			actionS_reload(fire, spec, true)
			actionS_slow(fire, spec)
	
	# quit reloading if the player wants to fire from a non-full magazine with recharging ammo
	if fire > 0.0 and Data.of("obelisk.rechargeAmmo") and is_reloading and not reloadFromEmpty:
		reloadFillAmmo(false, true)
	
	last_fire = fireStrength
	last_spec = specialStrength




func actionF_shot(fire, spec):
	if fire > 0.0 and can_shoot and cur_ammo > 0 and not shoot_button_down_from_reload and timeSinceWaveEnded > 1.0 and ((not is_reloading and not Data.of("obelisk.rechargeAmmo")) or Data.of("obelisk.rechargeAmmo")):
		if not Data.of("obelisk.fullAuto"):
			if not shoot_button_down_from_shot:
				shoot()
				shoot_button_down_from_shot = true
		else:
			shoot()
			shoot_button_down_from_shot = true



func actionF_beam(fire, spec):
	if fire > 0.0 and can_shoot and cur_ammo > 0 and not is_reloading and not shoot_button_down_from_reload:
		if not is_instance_valid(beam):
			var b = BEAM.instance()
			b.global_position = $Reticle.global_position
			b.init()
			b.connect("damagedMonster", self, "handleMonsterDamaged")
			b.connect("killedMonster", self, "handleMonsterDied")
			beam = b
			Level.stage.add_child(b)
		beam.set_is_active(true)
		shoot_button_down_from_shot = true
		cur_batteryDelay = 0.0
		arc_to_shot($Reticle.position)
		growShootingSpread()
	else:
		if is_beam_active():
			beam.disconnect("damagedMonster", self, "handleMonsterDamaged")
			beam.disconnect("killedMonster", self, "handleMonsterDied")
			beam.set_is_active(false)
			beam.remove()
			beam = null
	

func actionS_reload(fire, spec, secondaryAction:=false):
	if fire == 0.0:
		shoot_button_down_from_reload = false
	
	var spec_quick = spec > 0.0 and not reload_button_down_from_reload and not secondaryAction
	var fire_quick = fire > 0.0 and not shoot_button_down_from_shot and not shoot_button_down_from_reload
	if (spec_quick or fire_quick) and Data.of("obelisk.maxQuickReloadWindow") > 0.0 and Data.of("obelisk.allowReload"):
		if quick_reload_attempts <= 0 and cur_reloadTime > anticipationDeadzone():
			var _min = $QuickReload.get_progress_pos_min()
			var _max = $QuickReload.get_progress_pos_max()
			var p = get_reload_progress()
			if p >= _min * 0.95 and p <= _max * 1.15: # factors are coyote time
				if fire_quick:
					# beam can quick reload and start shooting with the same continuous input
					shoot_button_down_from_reload = Data.of("obelisk.chStyle") != 4
				reloadFillAmmoQuick()
			elif cur_reloadTime > anticipationDeadzone():
				$QuickReload.set_visible(false)
				if is_reloading and not $QuickReloadFail.playing:
					$QuickReloadFail.play()
			
		elif cur_reloadTime > anticipationDeadzone():
			$QuickReload.set_visible(false)
		
		if can_increment_quick_reload_attempts and cur_reloadTime > anticipationDeadzone():
			quick_reload_attempts += 1
			can_increment_quick_reload_attempts = false
	
	
	if spec > 0.0 and can_reload and not is_reloading and Data.of("obelisk.allowReload") and Data.of("obelisk.allowManualReloadStart"):
		reloadStart()
		reload_button_down_from_reload = true
	
	if spec == 0.0:
		reload_button_down_from_reload = false
		can_increment_quick_reload_attempts = true
	
	
	
	
	if fire > 0.0 and not Data.of("obelisk.autoReload") and cur_ammo <= 0 and not shoot_button_down_from_shot and not is_reloading and Data.of("obelisk.allowReload")and Data.of("obelisk.allowManualReloadStart"):
		reloadStart()
	
	
	if fire > 0.0 and not shoot_button_down_from_shot and not shoot_button_down_from_reload and last_fire != fire and Data.of("obelisk.allowReload") and timeSinceLastShot > 0.1:
		if cur_reloadTime > 0.0 and quick_reload_attempts > 2:
			$Reticle.denial()
		elif cur_shootDelay > 0.0 and cur_shootDelay < shootDelay() and not Data.of("obelisk.fullAuto"):
			$Reticle.denial()
	
	if not Data.of("obelisk.fullAuto") and fire == 0.0:
		shoot_button_down_from_shot = false

func actionS_detonate(fire, spec):
	if spec > 0.0:
		if can_detonate:
			if marks.size() > 0:
				can_detonate = false
				reload_button_down_from_reload = true
				$DetonateMarks.play()
			var mark_count = marks.size()
			var inf_safety = 0
			while marks.size() > 0 and inf_safety < 40:
				var m = marks.front()
				if not is_instance_valid(m):
					continue
				var mon = m.targetMonster
				removeFromMarkedMonsters(mon)
				marks.erase(m)
				m.remove()
				shoot(true, m.position, mark_count)
				inf_safety += 1
			Data.apply("obelisk.markCurrent", 0)
			
		elif not reload_button_down_from_reload:
			$Reticle.denial()
	if spec == 0.0:
		reload_button_down_from_reload = false

func actionS_slow(fire, spec):
	if spec > 0.0:
		special_slow = Data.of("obelisk.speedWhileSpecialSlow")
		$Reticle.special_slow = true
	else:
		special_slow = 1.0
		$Reticle.special_slow = false

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"obelisk.maxammo": 
			maxAmmo = newValue
			$AmmoDisplay.init(maxAmmo)
			set_cur_ammo(maxAmmo)
		"obelisk.reloadtime": 
			init_quick_reload()
			if anticipationDeadzone() > 0.5 * reloadTime():
				anticipation_deadzone = reloadTime() * 0.5
			else:
				anticipation_deadzone = 1.2
		"obelisk.minquickreload": 
			init_quick_reload()
		"obelisk.maxquickreload": 
			init_quick_reload()
		"obelisk.maxquickreloadwindow": 
			init_quick_reload()
		"obelisk.attacktype":
			attack_type = newValue
			$BeamTargetPointer.enabled = attack_type == AttackTypes.Beam
		"obelisk.arccooldown":
			arcCooldown = newValue
			cur_arcCooldown = arcCooldown
		"obelisk.shottype":
			$MarkCounter.visible = newValue == 1
		"monsters.wavepresent":
			if oldValue != newValue:
				# refill ammo when wave ends and starts
				reloadFillAmmoQuick(false)
				if not newValue:
					timeSinceWaveEnded = 0.0
					$MercilessTracker.set_bonus(Data.of("obelisk.mercilessBase"), false)
					for d in $DeathCandleArea.get_children():
						d.lifetime = 0
			if not newValue and not $TweenReturnReticle.is_active() and not is_active:
				return_reticle()
		"obelisk.markcurrent":
			if newValue != null and oldValue != null:
				if newValue > oldValue:
					var diff = newValue - oldValue
					set_cur_ammo(cur_ammo - diff)
		"obelisk.killstreaks":
			$KillstreakTracker.visible = newValue
		"obelisk.chstyle":
			if int(newValue) == 4: # beam
				$ReticleSpawn.position.y = 20
			else:
				$ReticleSpawn.position.y = -86
			$TweenReturnReticle.seek($TweenReturnReticle.get_runtime())
			$Reticle.position = $ReticleSpawn.position
		"obelisk.mercilessmax":
			$MercilessTracker.set_bonus(Data.of("obelisk.mercilessBase"))
		"obelisk.shootdelay":
			cur_shootDelay = newValue
		"obelisk.autoaimduration":
			$AutoAim.visible = newValue > 0
		"dome.health":
			var diff = clamp(oldValue - newValue, 0, Data.of("dome.maxhealth"))
			diff = ceil(diff)
			setStoredDamage(storedDamage + diff)
		"obelisk.storeddamagemax":
			$StoredDamage.visible = newValue > 0
			setStoredDamage(0)
		"obelisk.damage":
			setStoredDamage(storedDamage) # update visuals
	
	merciless_tracker_visible(is_active)
	bonus_damage_visible(is_active)



func _process(delta: float) -> void:
	$ReloadStaticSound.stream_paused = GameWorld.paused
	if GameWorld.paused:
		if $TweenReload.is_active():
			$TweenReload.seek((cur_reloadTime / reloadTime()) * reloadTime())
		return
	
	var decay_threshold = 0.05
	if Data.of("obelisk.chStyle") == 5:
		decay_threshold = Data.of("obelisk.shootDelay") + 0.025
	if $Reticle.shooting_spread != 0 and (timeSinceLastShot > decay_threshold):
		var decay = Data.of("obelisk.shootingSpreadDecay")
		var growth = Data.of("obelisk.shootingSpreadGrowth")
		
		if abs(cur_shootingSpread) <= growth * growth and int(Data.of("obelisk.chStyle")) == 1:
			if decay > 0:
				decay = sqrt(sqrt(decay))
		var decayed = cur_shootingSpread
		if Data.of("obelisk.shootingSpreadGrowth") >= 0:
			decayed = max(0, $Reticle.shooting_spread - decay)
		else:
			decayed = min(0, $Reticle.shooting_spread + decay)
		$Reticle.shooting_spread = decayed
		cur_shootingSpread = decayed
	
	if int(Data.of("obelisk.burstCount")) == 1:
		if cur_shootDelay < shootDelay():
			cur_shootDelay += delta
		else:
			if not $ReadyLightning.playing and not can_shoot and not is_reloading:
				if $ReadyLightning.streams.front().get_length() < shootDelay():
					$ReadyLightning.play()
			set_can_shoot(true)
	else:
		if cur_burstCount == 0:
			if cur_shootDelay < shootDelay():
				cur_shootDelay += delta
			else:
				if not $ReadyLightning.playing and not can_shoot and not is_reloading:
					if $ReadyLightning.streams.front().get_length() < shootDelay():
						$ReadyLightning.play()
				set_can_shoot(true)
		else:
			if cur_burstDelay < Data.of("obelisk.burstDelay"):
				cur_burstDelay += delta
			else:
				if cur_burstCount > 0 and cur_burstCount < int(Data.of("obelisk.burstCount")):
					
					shoot()
					
					#cur_burstDelay = 0.0
				elif cur_burstCount >= int(Data.of("obelisk.burstCount")):
					if cur_shootDelay < shootDelay():
						cur_shootDelay += delta
					else:
						if not $ReadyLightning.playing and not can_shoot and not is_reloading:
							if $ReadyLightning.streams.front().get_length() < shootDelay():
								$ReadyLightning.play()
						set_can_shoot(true)
					#cur_burstCount = 0
					#cur_burstDelay = 0.0
			
		
	if is_reloading:
		if cur_anticipation_deadzone < anticipationDeadzone():
			cur_anticipation_deadzone += delta
		else:
			var progress = get_reload_progress()
			$QuickReload.show_progress(progress)
			$Reticle.apply_shoot_delay(1.0) # make it full size
			$ReloadStaticSound.pitch_scale = 1.0 + (progress)
			$ReloadStaticSound.volume_db = -2 - (progress) * 10
			
	else: # vfx until the next shot is ready if the amount of time between shots is large enough
		var sd = shootDelay()
		if sd > 0.5:
			$Reticle.apply_shoot_delay(cur_shootDelay / sd)
		else:
			$Reticle.apply_shoot_delay(1.0)
	
	var what = not isShootingA
	if isShootingA and reloadFromEmpty:
		what = true
	if what and Data.of("obelisk.rechargeAmmo"):
		var delay = Data.of("obelisk.batteryDelay")
		if $KillstreakTracker.active():
			delay *= Data.of("obelisk.killstreakActiveReloadMultiplier")
		if $MercilessTracker.aboveThreshold():
			delay *= Data.of("obelisk.mercilessThresholdReloadMultiplier")
		if cur_batteryDelay < delay:
			cur_batteryDelay += delta
		else:
			var charge = max((1.0 / reloadTime()) * maxAmmo * delta, 0.01)
			if $KillstreakTracker.active():
				charge *= 1.0 / Data.of("obelisk.killstreakActiveReloadMultiplier")
			if $MercilessTracker.aboveThreshold():
				charge *= 1.0 / Data.of("obelisk.mercilessThresholdReloadMultiplier")
			#print(str("charge add ", charge))
			cur_batterySingleProgress += charge
			if cur_batterySingleProgress >= 1.0:
				var last_a = cur_ammo
				set_cur_ammo(cur_ammo + max(round(charge), 1))
				#print(cur_ammo + round(charge))
				cur_batterySingleProgress = 1.0 - cur_batterySingleProgress
				if last_a != cur_ammo and Data.of("obelisk.adStyle") == 0:
					$AmmoRecharge.pitch_scale = 0.6 if reloadFromEmpty else 1.0
					$AmmoRecharge.play(0.0)
		
		if cur_ammo < Data.of("obelisk.maxAmmo") and not is_reloading and cur_batteryDelay >= delay:
			ammoRatioOnReloadStart = float(cur_ammo) / float(Data.of("obelisk.maxAmmo"))
			init_quick_reload()
			reloadStart()
			cur_batterySingleProgress = 0.0
	
	if not Data.of("obelisk.rechargeAmmo"):
		if cur_reloadTime < reloadTime() and cur_reloadTime > 0.0:
			cur_reloadTime += delta
		if cur_reloadTime >= reloadTime():
			reloadFillAmmo()
	else:
		if cur_reloadTime < reloadTime(true) and cur_reloadTime > 0.0:
			cur_reloadTime += delta
		if cur_ammo >= Data.of("obelisk.maxAmmo") and is_reloading:
			reloadFillAmmo(true, true)
	
	if attack_type == AttackTypes.Beam and is_beam_active():
		if cur_beamAmmoTickDelay < beamAmmoTickDelay:
			cur_beamAmmoTickDelay += delta
		elif beam.cur_beamWindup >= beam.beamWindup:
			cur_beamAmmoTickDelay = 0.0
			set_cur_ammo(cur_ammo - int(Data.of("obelisk.ammoUsage")))
			if Data.of("obelisk.autoReload") and cur_ammo <= 0 and Data.of("obelisk.allowReload") and Data.of("obelisk.enterAutoReloadOnLastAmmo"):
				reloadStart()
	
	$BeamTargetPointer.global_position = sky_target($Reticle.global_position, false)
	$BeamTargetPointer.cast_to = $Reticle.global_position - $BeamTargetPointer.global_position
	var hit_sth = true if $BeamTargetPointer.get_collider() != null else false
	$Reticle.hoverOverride = hit_sth
	#print(cur_restDamageMult)
	if not is_reloading and ($Reticle.input == Vector2.ZERO or spreadDeactivated()) and is_active:
		if Data.of("obelisk.maxRestDamageMult") > 0.0 and cur_ammo > 0:
			build_up_rest_damage_mult(delta)
			cur_special_slow_coyote_time = 0.0
	else:
		if Data.of("obelisk.specialType") == 2 and special_slow == Data.of("obelisk.speedWhileSpecialSlow") and cur_ammo > 0:
			build_up_rest_damage_mult(delta, 0.3)
			cur_special_slow_coyote_time = 0.0
		else:
			if cur_special_slow_coyote_time < special_slow_coyote_time:
				cur_special_slow_coyote_time += delta
			elif not is_reloading:
				var reduction = cur_restDamageMult * 0.5 * Data.of("obelisk.restDamageDecayMult")
				setCurRestDamageMult(cur_restDamageMult -reduction)
				if Data.of("obelisk.maxRestDamageMult") != 0:
					if Data.of("obelisk.maxRestDamageMult") < 0.05 and cur_ammo > 0:
						setCurRestDamageMult(0.0)
					setCurRestDamageMult(cur_restDamageMult)
	
	if cur_markDetonationDelay < markDetonationDelay:
		cur_markDetonationDelay += delta
	else:
		cur_markDetonationDelay = 0.0
		can_detonate = true
	
	if cur_arcCooldown < arcCooldown:
		cur_arcCooldown += delta
	
	
	if $Arc.visible:
		if cur_arcUpSustain < arcUpSustain:
			cur_arcUpSustain += delta
		else:
			$Arc.visible = false
			cur_arcUpSustain = 0.0
	
	
	if Data.of("obelisk.chStyle") == 5 and not Data.of("obelisk.attackType") == 1:
		var shooting = isShootingA and not is_reloading
		$FullAutoSound.volume_db = baseFullAutoVolume - 6 + (6 * int(shooting))
		$FullAutoSound.pitch_scale = lerp($FullAutoSound.pitch_scale, (0.9 + 0.5 * int(shooting)), 0.1)
		if is_reloading: $FullAutoSound.volume_db -= 10
	
	timeSinceLastShot += delta
	timeSinceWaveEnded += delta
	
	#$Label.text = str("burst ", cur_burstDelay, "\n", cur_burstCount, "\nshoot", cur_shootDelay)
	
	if not is_shooting() and Data.of("obelisk.maxShootDelayReduction") > 0.0:
		cur_shoot_delay_reduction -= (shoot_delay_reduction_decay / Data.of("obelisk.maxShootDelayReduction")) * delta
		cur_shoot_delay_reduction = max(cur_shoot_delay_reduction, 0)
	
	if $KillstreakTracker.active() and Data.of("obelisk.killstreakActiveEffects"):
		for ke in killstreak_effects:
			if is_instance_valid(ke):
				if ke.cur_reticleArcDelay >= ke.reticleArcDelay:
					var arc = ARC.instance()
					Level.stage.add_child(arc)
					arc.visual = true
					arc.lifetime = 0.6
					arc.init(ke.global_position, $Reticle.global_position)
					ke.cur_reticleArcDelay = 0.0
					ke.reticle_arc_sfx()
				else:
					ke.cur_reticleArcDelay += delta
	
	if Data.of("obelisk.chStyle") == 4:
		$BeamOutline.visible = canBeamOutlineBeVisible()
		$BeamOutline.clear_points()
		var width = Data.of("obelisk.beamWidth") / 2.0
		var r1 = Vector2($Reticle.position.x + width, $Reticle.position.y)
		var r2 = Vector2($Reticle.position.x - width, $Reticle.position.y)
		var s = sky_target($Reticle.position, false)
		var s1 = Vector2(s.x + width, s.y)
		var s2 = Vector2(s.x - width, s.y)
		$BeamOutline.add_point(r2)
		$BeamOutline.add_point(s2)
		$BeamOutline.add_point(s1)
		$BeamOutline.add_point(r1)
	
	$Reticle.spreadDeactivated = spreadDeactivated()
	$AmmoDisplay.flashing = reloadFromEmpty or cur_ammo == 0
	
	$ArcStunArea/Shape.global_position = ($ReticleSpawn.global_position + $Reticle.global_position) / 2
	$ArcStunArea/Shape.shape.height = $ReticleSpawn.global_position.distance_to($Reticle.global_position)
	$ArcStunArea/Shape.shape.radius = $Reticle.cur_spread
	var arcStunDir = $ReticleSpawn.global_position - $Reticle.global_position
	$ArcStunArea/Shape.rotation = (atan2(-arcStunDir.y, -arcStunDir.x)) + PI * 0.5
	if timeSinceLastShot < 0.5:
		for m in arcStunMonsters:
			if is_instance_valid(m):
				m.hit(0, Data.of("obelisk.StunAlongArc"))
	
	noSpreadRemainingDuration = max(noSpreadRemainingDuration - delta, 0)
	remainingAutoAimDuration = max(remainingAutoAimDuration - delta, 0)
	if remainingAutoAimDuration > 0:
		$AutoAim.animation = "active"
	else:
		$AutoAim.animation = "inactive"
	
	if (reloadFromEmpty or (Data.of("obelisk.chStyle") == 4 and cur_ammo == 0)) and not $Overheat.playing:
		$Overheat.play()
		print("start")
	elif cur_ammo == Data.of("obelisk.maxAmmo"):
		$Overheat.stop()

func build_up_rest_damage_mult(delta, builup_fac:=1.0):
	cur_restDamageMult += (delta * restDamageMultBuildup * (cur_restDamageMult + 0.125)) * builup_fac
	setCurRestDamageMult(clamp(cur_restDamageMult, 0, Data.of("obelisk.maxRestDamageMult")))

func spreadDeactivated():
	if Data.of("obelisk.killstreakActiveNoSpread") and $KillstreakTracker.active():
		return true
	
	if noSpreadRemainingDuration > 0.0:
		return true
	
	if $MercilessTracker.aboveThreshold() and Data.of("obelisk.mercilessThresholdNoSpread"):
		return true
	
	return false

func get_reload_progress():
	var p = max(0, cur_reloadTime - anticipationDeadzone()) / reloadTime(Data.of("obelisk.rechargeAmmo"))
	p *= 1.0 + anticipationDeadzone() / reloadTime(Data.of("obelisk.rechargeAmmo"))
	return p

func anticipationDeadzone():
	if Data.of("obelisk.rechargeAmmo"):
		return 0
	return anticipation_deadzone

func start():
	$TweenReturnReticle.remove_all()
	set_is_active(true)
	ammo_counter_visible(true)
	merciless_tracker_visible(true)
	$Reticle.visible = true
	
	# there's a bug somewhere that the reticle can be controlled with keyboard controls until the first ping comes and I can't figure out where it is, so for now this is a hack around that problem
	if control_mode == ControlModes.MousePing:
		ping_reticle_target($ReticleSpawn.position)
	
	$StartSound.play()
	if Data.of("obelisk.chStyle") == 5 and not Data.of("obelisk.attackType") == 1:
		$FullAutoSound.play()
	
	if is_reloading:
		$QuickReload.set_visible(true)


func stop():
	if is_instance_valid(beam):
		beam.remove()
	
	if not Data.of("monsters.wavepresent"):
		return_reticle()
	
	set_is_active(false)
	ammo_counter_visible(false)
	
	merciless_tracker_visible(false)
	
	$StopSound.play()
	if Data.of("obelisk.chStyle") == 5:
		$FullAutoSound.stop()

func merciless_tracker_visible(value:bool):
	$MercilessTracker.visible = value and Data.of("obelisk.mercilessMax") > 0

func ammo_counter_visible(value: bool):
	$AmmoDisplay.visible = (value and int(Data.of("obelisk.ammoUsage")) > 0) or Data.of("obelisk.shotType") == 1

func bonus_damage_visible(value:bool):
	if not Data.of("obelisk.maxRestDamageMult") > 1.0 or not Data.of("obelisk.fullRestDamageAdd") > 0:
		$BonusDamageDisplay.visible = false
	else:
		$BonusDamageDisplay.visible = value

func return_reticle():
	$TweenReturnReticle.remove_all()
	var dist = ($ReticleSpawn.global_position - $Reticle.global_position).length()
	
	var anim_time = 0.01 * dist
	
	$TweenReturnReticle.interpolate_property($Reticle, "position", $Reticle.position, $ReticleSpawn.position, anim_time, Tween.TRANS_BACK)
	$TweenReturnReticle.interpolate_method($Reticle, "apply_spread", $Reticle.cur_spread, 0, anim_time, Tween.TRANS_BACK)
	$TweenReturnReticle.start()
	
	if not $TweenReturnReticle.is_connected("tween_all_completed", $Reticle, "set_visible"):
		$TweenReturnReticle.connect("tween_all_completed", $Reticle, "set_visible", [false])

func init_quick_reload():
	var _min = Data.of("obelisk.minQuickReload")
	var _max = Data.of("obelisk.maxQuickReload")
	#print(str((_max - _min) * reloadTime, " ", reloadTime))
	if (_max - _min) * reloadTime(Data.of("obelisk.rechargeAmmo")) > Data.of("obelisk.maxQuickReloadWindow"):
		var max_span = _min + (Data.of("obelisk.maxQuickReloadWindow") / reloadTime(Data.of("obelisk.rechargeAmmo")))
		_max = max_span
		#maxQuickReload = _max
	$QuickReload.init(_min, _max)
	$QuickReload.set_visible(false)

func set_can_shoot(value:bool):
	if not can_shoot and value and Data.of("obelisk.chStyle") != 5 and not is_reloading:
		if ((Data.of("obelisk.fullAuto") and not isShootingA) or not Data.of("obelisk.fullAuto")) and is_active and shootDelay() > 0.2:
			$Reticle.showShotReady()
	can_shoot = value

func set_is_active(value:bool):
	is_active = value
	
	if control_mode == ControlModes.MouseDrag:
		if is_active:
			var tar = RETICLE_TARGET.instance()
			tar.init(false)
			add_child(tar)
			reticle_target = tar
			$Reticle.cur_reticle_target = tar
			$Reticle.follow_reticle_target = true
		else:
			$Reticle.follow_reticle_target = false
			$Reticle.cur_reticle_target = null
			reticle_target.queue_free()
			reticle_target = null
	
	$Reticle.is_active = is_active or (timeSinceLastShot < 2.0 and not is_reloading)
	$QuickReload.set_visible(false)
	$KillstreakTracker.set_visible(is_active)
	$StoredDamage.visible = is_active and Data.of("obelisk.storedDamageMax") > 0
	bonus_damage_visible(is_active)

func is_beam_active():
	if reloadFromEmpty:
		return false
	if is_instance_valid(beam):
		return beam.is_active
	return false

func shoot(
	use_mark_overrides:=false,
	mark_pos:=Vector2.ZERO,
	mark_count:=0
	):
	if GameWorld.paused or not is_active:
		return
	var shot_type_override=int(Data.of("obelisk.shotType"))
	var pos_override:=shot_pos()
	var single_target_override=Data.of("obelisk.singleTarget")
	var ammo_usage_override=int(Data.of("obelisk.ammoUsage"))
	var radius_override=Data.of("obelisk.radius")
	
	if int(Data.of("obelisk.chStyle")) == 1 and timeSinceLastShot < 0.2: # sniper inaccuracy
		pos_override=shot_pos(50)
	
	if remainingAutoAimDuration > 0.0 and $Reticle.detectedMonsters.size() > 0:
		var m = $Reticle.detectedMonsters.front()
		if is_instance_valid(m):
			pos_override = m.getCenter()
	
	# hard-coded values for what the explosions triggered by a mark do
	# since the mark doesn't deal damage, that doesn't need an override
	if use_mark_overrides:
		pos_override = mark_pos
		
		shot_type_override = 0
		single_target_override = false
		ammo_usage_override = 0
		radius_override = Data.of("obelisk.markDetonationRadius")
	
	set_can_shoot(false)
	set_cur_ammo(cur_ammo - ammo_usage_override)
	
	if Data.of("obelisk.autoReload") and cur_ammo <= 0 and Data.of("obelisk.allowReload") and Data.of("obelisk.enterAutoReloadOnLastAmmo"):
		reloadStart()
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var allow_arc = cur_arcCooldown >= arcCooldown
	
	
	var newShot = SHOT.instance()

	newShot.global_position = pos_override
	newShot.connect("shotDown", self, "arc_from_shot", [pos_override])
	newShot.connect("damagedMonster", self, "handleMonsterDamaged")
	newShot.connect("killedMonster", self, "handleMonsterDied")
	newShot.init()
	newShot.shot_type = shot_type_override
	newShot.singleTarget = single_target_override
	newShot.set_radius(radius_override)
	newShot.allowArc = allow_arc
	
	
	Level.stage.add_child(newShot)
	$Reticle.light_up_crosshair()
	
	
	cur_arcUpSustain = 0.0
	if not Data.of("obelisk.arcDirectlyToShot"):
		arc_to_shot(pos_override)
	
	if Data.of("obelisk.fullAuto") and attack_type == AttackTypes.Shot:
		var incr = Data.of("obelisk.shootDelayReductionIncrease") / Data.of("obelisk.burstCount")
		cur_shoot_delay_reduction += incr
		cur_shoot_delay_reduction = clamp(cur_shoot_delay_reduction, 0, Data.of("obelisk.maxShootDelayReduction"))
	
	growShootingSpread()
	
	setCurRestDamageMult(0.0)
	cur_batteryDelay = 0.0
	timeSinceLastShot = 0.0
	
	if Data.of("obelisk.rechargeAmmo") and is_reloading:
		reloadFillAmmo(true, true)
	
	$Reticle.speed_add = Data.of("obelisk.reticleSpeedAddOnShoot")
	$Reticle.speed_add_duration = Data.of("obelisk.reticleSpeedAddOnShootDuration")
	$Reticle.cur_speed_add_duration = 0.0
	
	cur_shootDelay = 0.0
	cur_burstCount += 1
	cur_burstDelay = 0.0
	if cur_burstCount >= Data.of("obelisk.burstCount"):
		cur_burstCount = 0
	#print(str("burst cnt is now ", cur_burstCount))

func setCurRestDamageMult(value:float):
	cur_restDamageMult = value
	var progress = 0.0
	if Data.of("obelisk.maxRestDamageMult") != 0:
		progress = cur_restDamageMult / Data.of("obelisk.maxRestDamageMult")
	$BonusDamageDisplay.set_progress(progress)

func growShootingSpread():
	var _max = Data.of("obelisk.shootingSpreadMax")
	var growth = Data.of("obelisk.shootingSpreadGrowth")
	var positive = Data.of("obelisk.shootingSpreadMax") >= 0 or Data.of("obelisk.shootingSpreadGrowth") >= 0
	var _sign = 1 if positive else -1
	if positive:
		cur_shootingSpread = min(cur_shootingSpread + growth, _max)
	else:
		cur_shootingSpread = max(cur_shootingSpread + growth, _max)
	
	# grow faster at start for normal
	if int(Data.of("obelisk.chStyle")) != 1:
		if cur_shootingSpread < _max * 0.5:
			if positive:
				cur_shootingSpread = min(cur_shootingSpread + growth * growth * _sign, _max)
			else:
				cur_shootingSpread = max(cur_shootingSpread + growth * growth * _sign, _max)
		else:
			if positive:
				cur_shootingSpread = min(cur_shootingSpread + growth, _max)
			else:
				cur_shootingSpread = max(cur_shootingSpread + growth, _max)
	# cubic growth for sniper
	if int(Data.of("obelisk.chStyle")) == 1:
		cur_shootingSpread = min(cur_shootingSpread * cur_shootingSpread * cur_shootingSpread, _max)
	
	if spreadDeactivated():
		cur_shootingSpread = 0
	
	
	$Reticle.shooting_spread = cur_shootingSpread

func shot_pos(min_inaccuracy := 0) -> Vector2:
	var rand_pos = Vector2.ZERO
	if $Reticle.cur_spread > Data.of("obelisk.guaranteedCenterShotThreshold"):
		rand_pos = Vector2(rand_range(min(min_inaccuracy, $Reticle.cur_spread), $Reticle.cur_spread), 0).rotated(rand_range(0, 6.28))
	return $Reticle.global_position + rand_pos

func arc_to_shot(shotPosition:Vector2, from:=$ArcOrigin.position):
	$Arc.visible = true
	var target = sky_target(shotPosition, true)
	
	$Arc.width = arc_width()
	$Arc.from = from
	
	if Data.of("obelisk.arcDirectlyToShot"):
		$Arc.arcNoiseX = min((0.4 * from.distance_to(shotPosition)) / 465*2, 0.11)
		$Arc.arcNoiseY = min((0.05 * from.distance_to(shotPosition)) / 1000, 0.008)
		$Arc.width = arc_width() * 0.5
	else:
		$Arc.arcNoiseX = 0.4 * min((465*2 / (abs($Reticle.global_position.x)+1)), 25)
		$Arc.arcNoiseY = 0.05 * (shotPosition.y / 1000)
	
	if Data.of("obelisk.arcDirectlyToShot"):
		target = shotPosition
	
	$Arc.to = target
	$Arc.arc(true)
	
	if Data.of("obelisk.explosionDelay") > 0:
		$LightningUpSound.play()

func arc_from_shot(shotPosition:Vector2):
	var arc = ARC.instance()
	arc.global_position = Vector2.ZERO
	arc.to = Vector2.ZERO
	Level.stage.add_child(arc)
	var from = sky_target(shotPosition, false)
	if Data.of("obelisk.arcDirectlyToShot"):
		from = $ReticleSpawn.global_position
	arc.visual = true
	arc.width = arc_width() / Data.of("obelisk.burstCount")
	arc.init(from, shotPosition)
	arc.arc(true)
	randomize()
	arc.lifetime = 0.5 + rand_range(-0.15, 0.15)
	
	for i in range(Data.of("obelisk.shotsAlongArc")):
		var ratio = float(i + 1.0) / float(Data.of("obelisk.shotsAlongArc") + 1.0)
		var origin = Vector2.ZERO
		var target = shotPosition
		if Data.of("obelisk.arcDirectlyToShot"):
			origin = $ReticleSpawn.position
		else:
			origin = sky_target(shotPosition, false)
		
		var dir = (target - origin).normalized()
		var length = origin.distance_to(target)
		var posOnArc = origin + dir * ratio * length
		
		printt(ratio, origin, target, dir, length, posOnArc)
		
		var n = preload("res://content/weapons/obelisk/DeathCandle.tscn").instance()
		$DeathCandleArea.add_child(n)
		n.position = posOnArc
		n.init()

# obelisk param is if the arc is on the side of the obelisk or the shot
func sky_target(shotPosition:Vector2, obelisk:bool):
	if obelisk:
		var x = $ArcOrigin.global_position.x + shotPosition.x * Data.of("obelisk.lightningXRatio")
		var y = Data.of("obelisk.lightningYTarget")
		return Vector2(x, y)
	else: # shot side
		var x = Data.of("obelisk.lightningXRatio")
		var y = Data.of("obelisk.lightningYTarget")
		return (Vector2(shotPosition.x * (1.0 - x), shotPosition.y + y))

func arc_width():
	match int(Data.of("obelisk.attackType")):
		0: #shot
			#return max(Data.of("obelisk.radius") * Data.of("obelisk.radius") / 125, 2)
			# Welcome, wary traveler. You may look at the above line and think to yourself, "what beautiful dynamic code" but beware for it is the pandora's box of this godless script
			# if you were to uncomment that line, you would kill this game.
			# something stirrs within that code that causes the fps to die off in droves when the radius gets too high
			# radius 60 permanently drops the game down to 53 fps. radius 90 goes to 45 fps. I did not dare to venture further down
			# tldr; do not involve the radius in the calculation of the arc width or I will come to your house and eat your spine
			# I spent 3.5 hours hunting this shit down
			return 3.5
		1: # beam
			return Data.of("obelisk.beamWidth")

func set_is_reloading(value:bool):
	is_reloading = value
	
	if is_reloading:
		$ReloadStaticSound.play(0.0)
	else:
		$ReloadStaticSound.stop()
	
	cur_burstDelay = 0.0
	cur_burstCount = 0
	
	$Reticle.set_reload(is_reloading)

func reloadStart():
	if cur_ammo <= 0:
		reloadFromEmpty = true
	quick_reload_attempts = 0
	set_is_reloading(true)
	cur_reloadTime = 0.01 # starts counting up
	if not Data.of("obelisk.rechargeAmmo"): $AmmoDisplay.empty_ammo()
	$QuickReload.set_visible(true)
	$QuickReload.show_progress(0.0)
	if not Data.of("obelisk.rechargeAmmo"): reticle_reload_anim()
	$ReloadStartSound.play()
	if attack_type == AttackTypes.Beam:
		if is_instance_valid(beam):
			beam.set_is_active(false)
	cur_shoot_delay_reduction = 0.0

func reloadFillAmmo(play_sfx:=true, dontFillAmmo:=false):
	reloadFromEmpty = false
	set_can_shoot(true)
	set_is_reloading(false)
	if not dontFillAmmo:
		set_cur_ammo(maxAmmo)
	cur_reloadTime = 0.0
	$AmmoDisplay.set_current_ammo(cur_ammo)
	$QuickReload.show_progress(0.0)
	$QuickReload.set_visible(false)
	if play_sfx:
		$ReloadFinishSound.play()
	cur_anticipation_deadzone = 0.0
	cur_batteryDelay = 0.0

func reloadTime(includeCurrentAmmo:=false):
	var time = Data.of("obelisk.reloadTime") * Data.of("obelisk.reloadTimeMult")
	
	if Data.of("obelisk.rechargeAmmo") and includeCurrentAmmo:
		var f = 1.0 - ammoRatioOnReloadStart
		time *= f
	
	if $KillstreakTracker.active():
		time *= Data.of("obelisk.killstreakActiveReloadMultiplier")
	
	if $MercilessTracker.aboveThreshold():
		time *= Data.of("obelisk.mercilessThresholdReloadMultiplier")
	
	if reloadFromEmpty:
		time *= Data.of("obelisk.emptyReloadTimeMult")
	
	time -= Data.of("obelisk.reloadTimeReduction")
	
	return max(time, anticipationDeadzone() + 0.1)

func shootDelay():
	var delay = Data.of("obelisk.shootDelay")
	
	delay -= cur_shoot_delay_reduction
	
	if $KillstreakTracker.active():
		delay *= Data.of("obelisk.killstreakActiveShootDelayMultiplier")
		
	if $MercilessTracker.aboveThreshold():
		delay *= Data.of("obelisk.mercilessThresholdShootDelayMultiplier")
	
	delay -= Data.of("obelisk.shootDelayReduction")
	
	return max(delay, min_shoot_delay)

func reloadFillAmmoQuick(play_sfx:=true, dontFillAmmo:=false):
	$TweenReload.seek($TweenReload.get_runtime())
	if play_sfx:
		$QuickReloadSuccess.play()
	reloadFillAmmo(false, dontFillAmmo)

func set_cur_ammo(value: int):
	cur_ammo = min(value, maxAmmo)
	$AmmoDisplay.set_current_ammo(cur_ammo)
	can_reload = cur_ammo < maxAmmo

func setStoredDamage(value: int):
	storedDamage = clamp(value, 0, Data.of("obelisk.storedDamageMax"))
	#$Label.text = str("stored damage: ", storedDamage)
	#$Label.visible = storedDamage > 0
	$StoredDamage.setValue(storedDamage)

func reticle_reload_anim():
	$TweenReload.remove_all()
	$TweenReload.interpolate_method($Reticle, "apply_spread", $Reticle.cur_spread, 0, 0.2, Tween.TRANS_BACK)
	$TweenReload.interpolate_property($Reticle.container, "rotation_degrees", 0, 360*(round(reloadTime()) + 1), reloadTime(), Tween.TRANS_CUBIC)
	$TweenReload.start()


## obv bad WIP code
#func _input(event: InputEvent) -> void:
#	if event.is_action_pressed("battle_mouse1"):
#		if event is InputEventMouseButton and control_mode == ControlModes.MousePing:
#			ping_reticle_target(get_global_mouse_position())

func ping_reticle_target(target_pos:Vector2):
	if is_instance_valid(reticle_target):
		reticle_target.decrement_blockers()
	var tar = RETICLE_TARGET.instance()
	tar.init(true)
	tar.global_position = target_pos
	add_child(tar)
	reticle_target = tar
	$Reticle.cur_reticle_target = tar
	$Reticle.follow_reticle_target = true

func getFireName():
	return "level.station.battle.navbar.shoot"

func getSpecialName():
	match int(Data.of("obelisk.specialType")):
		SpecialTypes.Reload:
			if int(Data.of("obelisk.ammoUsage")) == 0:
				return ""
			else:
				if not Data.of("obelisk.allowManualReloadStart"):
					return ""
				return "level.station.battle.navbar.reload" 
		SpecialTypes.DetonateMarks:
			return "level.station.battle.navbar.detonate"
		SpecialTypes.SlowReticle:
			return "level.station.battle.navbar.slowreticle"
	return ""

func is_shooting():
	return isShootingA or isShootingM

func addToMarkedMonsters(m):
	if not markedMonsters.has(m):
		markedMonsters.append(m)
		if not m.is_connected("died", self, "removeFromMarkedMonsters"):
			m.connect("died", self, "removeFromMarkedMonsters", [m])

func removeFromMarkedMonsters(m):
	if markedMonsters.has(m):
		markedMonsters.erase(m)
		m.disconnect("died", self, "removeFromMarkedMonsters")


func handleMonsterDied(m):
	if Data.of("obelisk.killstreaks") and not Data.of("obelisk.killstreakChargeWithDamage"):
		$KillstreakTracker.add_monster_weight(m)
	
	if Data.of("obelisk.spreadLossOnKill"):
		noSpreadRemainingDuration = Data.of("obelisk.spreadLossOnKillDuration")
	
	# ammo refill on kill
	if Data.of("obelisk.ammoRefillOnKill") > 0:
		set_cur_ammo(cur_ammo + max(Data.of("obelisk.ammoRefillOnKill") * maxAmmo, 1))
	if is_reloading and Data.of("obelisk.ammoRefillOnKill") > 0.0:
		reloadFillAmmoQuick(false, true)
		set_cur_ammo(cur_ammo+1)
	
	if not Data.of("obelisk.mercilessGainOnDamage"):
		$MercilessTracker.add_monster_weight(m)
	
	if Data.of("obelisk.spreadRadiationOnDeath") and m.maxHealth > 10:
		var ra = RAD_AREA.instance()
		Level.stage.add_child(ra)
		ra.global_position = m.getCenter()
	
	if Data.of("obelisk.deathCandles") and m.techId != "tick" and m.techId != "bigtick":
		var candle = DEATH_CANDLE.instance()
		candle.global_position = m.getCenter()
		candle.lifetime = clamp(float(m.maxHealth) / 10.0, Data.of("obelisk.deathCandleMinDuration"), Data.of("obelisk.deathCandleMaxDuration"))
		candle.init()
		$DeathCandleArea.add_child(candle)
	
	remainingAutoAimDuration = Data.of("obelisk.autoAimDuration")

func handleMonsterDamaged(damage:float):
	if Data.of("obelisk.killstreaks") and Data.of("obelisk.killstreakChargeWithDamage"):
		$KillstreakTracker.add_damage_weight(damage)
	
	if Data.of("obelisk.mercilessGainOnDamage"):
		$MercilessTracker.add_damage_weight(damage)
	
	cur_shootingSpread = max(cur_shootingSpread - Data.of("obelisk.spreadDecreaseOnHit"), 0)
	$Reticle.shooting_spread = cur_shootingSpread

func triggerKillstreak():
	var pos = $Reticle.global_position
	var ks = KILLSTREAK.instance()
	ks.init()
	Level.stage.add_child(ks)
	ks.global_position.x = pos.x
	# prevent the effect from being in the ground
	ks.global_position.y = min(pos.y, -10 - Data.of("obelisk.killstreakEffectRadius") / 2.0)
	killstreak_effects.append(ks)

func endActiveKillstreak():
	var i = 0
	while i < killstreak_effects.size():
		var ks = killstreak_effects[i]
		if not is_instance_valid(ks):
			killstreak_effects.remove(i)
			i -= 1
		else:
			ks.end()
		
		i += 1


func mercilessMult(bonusType:=""):
	var b = float($MercilessTracker.bonus) / 100.0
	var result = b
	match bonusType:
		"":
			pass
		"damage":
			result *= Data.of("obelisk.mercilessDamageEfficiency")
			result -= 1.0
		"speed":
			result *= Data.of("obelisk.mercilessSpeedEfficiency")
	return result + 1.0


func canBeamOutlineBeVisible() -> bool:
	if Data.of("obelisk.chStyle") != 4: # beam
		return false
	return Data.of("obelisk.radiusOutline") and is_active# and not is_beam_active()


func _on_ArcStunArea_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addToArcStunMonsters(area)

func _on_ArcStunArea_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeFromArcStunMonsters(area)

func addToArcStunMonsters(m):
	if not arcStunMonsters.has(m):
		arcStunMonsters.append(m)
		if not m.is_connected("died", self, "removeFromArcStunMonsters"):
			m.connect("died", self, "removeFromArcStunMonsters", [m])

func removeFromArcStunMonsters(m):
	if arcStunMonsters.has(m):
		arcStunMonsters.erase(m)
		m.disconnect("died", self, "removeFromArcStunMonsters")

