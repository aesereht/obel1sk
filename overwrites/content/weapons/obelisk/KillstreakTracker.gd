extends Node2D

signal triggerKillstreak
signal endKillstreak

enum States {Gaining, Active}
var cur_state = States.Gaining

var progress := 0.0
var activeDuration := 15.0
var inactiveDecay := 0.05
var decayDelay := 2.0
var cur_decayDelay := 0.0
var lockProgressGain = false
var activeDrain = 0.2

var maxStage = 50

func init():
	Data.listen(self, "obelisk.killstreakInactiveEffects", true)
	
	Style.init(self)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"obelisk.killstreakinactiveeffects":
			$GHF.visible = newValue

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	$Label.text = ""
	match cur_state:
		States.Gaining:
			var delay = decayDelay
			if Data.of("obelisk.killstreakChargeWithDamage"):
				delay *= Data.of("obelisk.killstreakChargeWithDamageDelayMult")
			$Label.text += str("\n",delay)
			if cur_decayDelay < delay:
				cur_decayDelay += delta
			else:
				var d = inactiveDecay
				if Data.of("obelisk.killstreakChargeWithDamage"):
					d *= Data.of("obelisk.killstreakChargeWithDamageDecayMult")
				progress -= Goal() * d * delta
				progress = max(progress, 0)
				$Label.text += str("\n",d)
		States.Active:
			if progress > 0.0:
				progress -= (Goal() / Data.of("obelisk.killstreakActiveDuration")) * delta
				progress = max(progress, 0)
			else:
				set_state(States.Gaining)
				emit_signal("endKillstreak")
	
	var frame = clamp(floor((maxStage) * (progress / Goal())), 0, maxStage)
	$Fill.frame = int(frame)
	$Fill.visible = progress > 0.0
	
	if Data.of("obelisk.killstreakInactiveEffects"):
		$GHF/GHFabove.visible = progress >= Goal() * Data.of("obelisk.killstreakGHFthreshold") and not active()
		$GHF/GHFbelow.visible = progress < Goal() * Data.of("obelisk.killstreakGHFthreshold") and not active()
		
		$GHF.position.y = lerp(-24, 25, 1.0 - Data.of("obelisk.killstreakGHFthreshold"))
	
	
	if active():
		if not $Sustain.playing:
			$Sustain.play()
	else:
		$Sustain.stop()
	
	
	
func set_state(new_state):
	cur_state = new_state
	lockProgressGain = cur_state == States.Active

func add_monster_weight(m):
	if not lockProgressGain:
		set_progress(progress + monster_weight(m))

func add_damage_weight(damage:float):
	if not lockProgressGain:
		set_progress(progress + damage)

func set_progress(value:float):
	progress = min(value, Goal())
	cur_decayDelay = 0.0
	if progress >= Goal():
		set_state(States.Active)
		emit_signal("triggerKillstreak")

func monster_weight(m):
	var health = m.maxHealth
	var tier = Data.of(str(m.techId, ".tier"))
	var groupsize = Data.ofOr(str(m.techId, ".groupsize"), 1)
	var weight = (((health + 100) * 0.25) * tier * tier) / groupsize
	return min(weight, 0.5 * Data.of("obelisk.killstreakGoal"))

func active():
	return cur_state == States.Active

func Goal():
	var wave_mod = 1.0 + 0.02 * Data.of("monsters.cycle")
	return Data.of("obelisk.killstreakGoal") * GameWorld.waveStrengthModifier * 0.675 * wave_mod

func set_visible(value:bool):
	if Data.of("obelisk.killstreaks"):
		visible = value
	else:
		visible = false
