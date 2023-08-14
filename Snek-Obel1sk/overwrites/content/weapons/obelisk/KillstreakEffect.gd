extends Node2D


var hitMonsters := []

var radius = 30

var cur_pulseDelay := 0.0

var reticleArcDelay := 1.0
var cur_reticleArcDelay := reticleArcDelay * 0.75

var blockers = 1
var ended = false

const PULSE = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/KillstreakEffectPulse.tscn")

func init():
	radius = Data.of("obel1sk.killstreakEffectRadius")
	$HitArea/CollisionShape2D.shape.radius = radius
	$Static.scale /= 166/2/radius
	$Static.play("static")
	$StartSFX.play()
	$ArcSFX.connect("finished", self, "decrement_blockers")
	$PulseSFX.connect("finished", self, "decrement_blockers")
	
	cur_pulseDelay = Data.of("obel1sk.killstreakEffectPulseDelay") * 0.85
	
	Style.init(self)

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	if cur_pulseDelay == 0.0 and not ended:
		pulse()
	
	cur_pulseDelay += delta
	if cur_pulseDelay >= Data.of("obel1sk.killstreakEffectPulseDelay"):
		cur_pulseDelay = 0.0
	
	for m in hitMonsters:
		m.hit(Data.of("obel1sk.killstreakEffectStaticDamage") * delta, 0.4)

func pulse():
	for m in hitMonsters:
		m.hit(Data.of("obel1sk.killstreakEffectPulseDamage"), 50.0)
	$PulseSFX.play()
	blockers += 1
	
	var p = PULSE.instance()
	p.global_position = global_position
	Level.stage.add_child(p)
	p.scale /= 166/2/radius

func hide_pulse():
	$Pulse.visible = false

func decrement_blockers():
	blockers -= 1
	
	if blockers <= 0:
		queue_free()

func end():
	ended = true
	$Static.play("vanish")
	blockers += 1
	$Static.connect("animation_finished", self, "decrement_blockers")
	$EndSFX.play()
	blockers += 1
	$EndSFX.connect("finished", self, "decrement_blockers")
	
	$HitArea.monitoring = false
	decrement_blockers()

func reticle_arc_sfx():
	$ArcSFX.play()
	blockers += 1

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
		hitMonsters.erase(m)
		m.disconnect("died", self, "removeFromHitMonsters")
