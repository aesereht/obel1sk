extends "res://content/weapons/obelisk/DamageManager.gd"

var is_active := false
var hitMonsters := []
var closeMonsters := []

var hm_delay = 0.1 # hit marker delay to not have them every frame
var cur_hm_delay = 0.0

var blockers = 0

var inactivityTimer = 5.0

var defaultVolume = 0.0

func init():
	.init()
	
	$AreaCore/Collider.shape.extents.x = Data.of("obelisk.beamWidth")
	$AreaRadiate/Collider.shape.radius = Data.of("obelisk.beamRadianceWidth")
	
	$EndSFX.connect("finished", self, "decrement_blockers")
	$Tween.connect("tween_all_completed", self, "decrement_blockers")
	
	defaultVolume = $SustainSFX.volume_db
	
	Style.init(self)

var beamWindup = 0.6
var cur_beamWindup = 0.0
func _process(delta: float) -> void:
	if is_active:
		if cur_beamWindup < beamWindup:
			cur_beamWindup += delta
			$Radiance.visible = false 
			$Core.visible = false
			$Hit.visible = false
			$Windup.modulate.a = cur_beamWindup / beamWindup
			return
	
	if hitMonsters.size() > 0 and is_active:
		reticle.hit_marker()
		$SustainSFX.volume_db = -80
		$SustainHitSFX.volume_db = defaultVolume
	else:
		$SustainSFX.volume_db = defaultVolume
		$SustainHitSFX.volume_db = -80
	
	for m in hitMonsters:
		if is_active:
			if m.currentHealth <= total_damage() * delta:
				emit_signal("killedMonster", m)
			m.hit(total_damage() * delta, Data.of("obelisk.stun") * delta)
			emit_signal("damagedMonster", min(total_damage() * delta, m.maxHealth))
	
	for m in closeMonsters:
		if is_active and not hitMonsters.has(m):
			var damage_dealt = total_damage() * delta * Data.of("obelisk.beamRadianceMult")
			var stun = Data.of("obelisk.stun") * delta * Data.of("obelisk.beamRadianceMult")
			if m.currentHealth <= damage_dealt:
				emit_signal("killedMonster", m)
			m.hit(damage_dealt, stun)
			emit_signal("damagedMonster", min(damage_dealt, m.maxHealth))
	
	# decrement blockers doesn't work atm so this is a workaround for discarded beams
	if not is_active:
		inactivityTimer -= delta
		if inactivityTimer <= 0.0:
			queue_free()


func set_is_active(value: bool):
	if not is_active and value:
		$StartSFX.play()
	if is_active and not value:
		$EndSFX.disconnect("finished", self, "decrement_blockers")
		$EndSFX.play()
	
	is_active = value
	if $SustainSFX.playing and not is_active:
		$SustainSFX.stop()
		$SustainHitSFX.stop()
	elif not $SustainSFX.playing and is_active and cur_beamWindup >= beamWindup:
		$SustainSFX.play(0.0)
		$SustainHitSFX.play(0.52)
	
	if is_active:
		$Radiance.visible = is_active and cur_beamWindup >= beamWindup
		$Core.visible = is_active and cur_beamWindup >= beamWindup
		$Hit.visible = is_active and cur_beamWindup >= beamWindup
		$Windup.visible = is_active
	else:
		$Tween.interpolate_property($Radiance, "modulate:a", 1.0, 0.0, 0.8,Tween.TRANS_ELASTIC)
		$Tween.interpolate_property($Core, "modulate:a", 1.0, 0.0, 0.4,Tween.TRANS_CIRC)
		$Tween.interpolate_property($Hit, "modulate:a", 1.0, 0.0, 0.4,Tween.TRANS_CIRC)
		$Tween.interpolate_property($Windup, "modulate:a", 1.0, 0.0, 0.4,Tween.TRANS_CIRC)
		$Tween.start()
	
	if is_active:
		inactivityTimer = 5.0

func setHitVFX(value:bool):
	if value:
		$Hit.animation = "hit"
	else:
		$Hit.animation = "default"

func remove():
	set_is_active(false)
	blockers += 1
	$EndSFX.play()

func decrement_blockers():
	blockers -= 1
	if blockers <= 0:
		queue_free()

func addToHitMonsters(m):
	if not hitMonsters.has(m):
		hitMonsters.append(m)
		if not m.is_connected("died", self, "removeFromHitMonsters"):
			m.connect("died", self, "removeFromHitMonsters", [m])

func removeFromHitMonsters(m):
	if hitMonsters.has(m):
		hitMonsters.erase(m)
		m.disconnect("died", self, "removeFromHitMonsters")

func addToCloseMonsters(m):
	if not closeMonsters.has(m):
		closeMonsters.append(m)
		if not m.is_connected("died", self, "removeFromCloseMonsters"):
			m.connect("died", self, "removeFromCloseMonsters", [m])

func removeFromCloseMonsters(m):
	if closeMonsters.has(m):
		closeMonsters.erase(m)
		m.disconnect("died", self, "removeFromCloseMonsters")



func _on_AreaCore_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addToHitMonsters(area)


func _on_AreaCore_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeFromHitMonsters(area)

func _on_AreaRadiate_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addToCloseMonsters(area)

func _on_AreaRadiate_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeFromCloseMonsters(area)



