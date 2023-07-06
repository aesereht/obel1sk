extends Node2D


var cur_loss_delay = 0.0

var bonus = 0
var maxStage = 0

func init():
	maxStage = $Bar.frames.get_frame_count("default")
	$Threshold.visible = false
	$Threshold.playing = true

func _process(delta: float) -> void:
	$Label.text = str("bonus ", bonus, "\ndelay ", cur_loss_delay)
	if GameWorld.paused:
		return
	
	if Data.of("obelisk.mercilessFullLossDelay") > 0.0:
		cur_loss_delay -= delta
		if cur_loss_delay <= 0:# Data.of("obelisk.mercilessFullLossDelay"):
			cur_loss_delay = 0.0
			set_bonus(Data.of("obelisk.mercilessBase"), false)
	
	if Data.of("obelisk.mercilessLossRate") > 0.0:
		set_bonus(bonus - Data.of("obelisk.mercilessLossRate") * delta, false)
	
	
	if Data.of("obelisk.mercilessFullLossDelay") != 0:
		var d = (float(cur_loss_delay) / float(Data.of("obelisk.mercilessFullLossDelay")))
		fill_bar(d)
	elif Data.of("obelisk.mercilessLossRate") > 0.0:
		var d = float(bonus) / float(Data.of("obelisk.mercilessMax"))
		fill_bar(d)
	else:
		fill_bar(0)
	

func show_value(value):
	value = int(value)
	if value > 9999:
		value = 9999
	if value < Data.of("obelisk.mercilessBase"):
		value = Data.of("obelisk.mercilessBase")
	
	var s = String(value)
	while s.length() < 4:
		s = s.indent("0")
	
	$Numbers/One.frame = int(s[3])
	$Numbers/Ten.frame = int(s[2])
	$Numbers/Hundred.frame = int(s[1])
	$Numbers/Thousand.frame = int(s[0])

func fill_bar(progress):
	var frame = clamp(floor((maxStage) * progress), 0, maxStage)
	$Bar.frame = int(frame)

func add_monster_weight(m):
	set_bonus(bonus + monster_weight(m))

func add_damage_weight(damage:float):
	set_bonus(bonus + damage)

func set_bonus(value:float, resetLossDelay:=true):
	bonus = clamp(value, Data.of("obelisk.mercilessBase"), Data.of("obelisk.mercilessMax"))
	show_value(bonus)
	
	if resetLossDelay: cur_loss_delay = Data.of("obelisk.mercilessFullLossDelay")
	
	$Threshold.visible = aboveThreshold() and Data.of("obelisk.mercilessThreshold") > 0.0

func monster_weight(m):
#	var health = m.maxHealth
#	var tier = Data.of(str(m.techId, ".tier"))
	var groupsize = Data.ofOr(str(m.techId, ".groupsize"), 1)
#	var weight = (((health + 100) * 0.25) * tier * tier) / groupsize
#	print(weight)
#	return weight
	return ceil(Data.of("obelisk.mercilessGain") / groupsize)

func aboveThreshold():
	return bonus > Data.of("obelisk.mercilessThreshold")
