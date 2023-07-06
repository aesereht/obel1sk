extends Node2D


export var acceleration = 1.9
export var friction = 9.0
var motion = Vector2.ZERO
var input = Vector2.ZERO
var last_input = Vector2.ZERO
var speed_mod := 1.0
var speed_add := 0.0
var speed_add_duration := 0.0
var cur_speed_add_duration := 0.0

onready var container = _containerDefault
onready var segments = _segmentsDefaut
#onready var dirs = _dirsDefault
var last_spread: = 0.0 # used to determine the direction of the spread; expand or shrink
var cur_spread: = 0.0
var monsterDetectionHighlightsCrosshairs: = true
var shooting_spread = 0.0
var last_shooting_spread = 0.0

var hoveredMonsters := [] # used by slowdownOverMonsters. circular collider in the center of the crosshairs with size up to detectionRadius (limited by spread)
var detectedMonsters := [] # the entire spread area (dynamic)
var cur_bridgeTime := 0.0

var follow_reticle_target := false
var cur_reticle_target : ReticleTarget = null
var is_active := false
var near_target_slowdown_increase = 0.1
var cur_near_target_slowdown = 0

var hit_marker_next_frame := false
var kill_marker_next_frame := false
var hitMarkerStayTime := 0.35
var cur_hitMarkerStayTime := 0.0
const HIT_MARKER = preload("res://content/weapons/obelisk/HitMarker.tscn")
const KILL_MARKER = preload("res://content/weapons/obelisk/KillMarker.tscn")
const SHOT_READY = preload("res://content/weapons/obelisk/ShotReady.tscn")

var killstreakActive := false
var special_slow := false
var hoverOverride := false

var spreadDeactivated := false

enum Styles {Default, Sniper, Nukes, FullAuto, Beam, FullAutoCircle}

var cur_chStyle = 0
onready var _containerDefault = $DefaultContainer
onready var _segmentsDefaut = [$DefaultContainer/ReticleR, $DefaultContainer/ReticleD, $DefaultContainer/ReticleL, $DefaultContainer/ReticleU]
onready var _containerSniper = $SniperContainer
onready var _segmentsSniper = [
	$SniperContainer/ReticleTR,
	$SniperContainer/ReticleR,
	$SniperContainer/ReticleBR,
	$SniperContainer/ReticleBL,
	$SniperContainer/ReticleL,
	$SniperContainer/ReticleTL]
onready var _containerNukes = $NukeContainer
onready var _segmentsNukes = [
	$NukeContainer/ReticleTR,
	$NukeContainer/ReticleBR,
	$NukeContainer/ReticleBL,
	$NukeContainer/ReticleTL,
	$NukeContainer/ReticleR,
	$NukeContainer/ReticleL
]
onready var _containerFullAuto = $FullAutoContainer
onready var _segmentsFullAuto = [$FullAutoContainer/ReticleR, $FullAutoContainer/ReticleD, $FullAutoContainer/ReticleL, $FullAutoContainer/ReticleU]
onready var _containerBeam = $BeamContainer
onready var _segmentsBeam = [$BeamContainer/ReticleSegment, $BeamContainer/ReticleSegment2]
onready var _containerFACircle = $FAPoints
onready var _segmentsFACircle = [
	$FAPoints/Position2D,
	$FAPoints/Position2D2,
	$FAPoints/Position2D3,
	$FAPoints/Position2D4,
	$FAPoints/Position2D5,
	$FAPoints/Position2D6,
	$FAPoints/Position2D7,
	$FAPoints/Position2D8,
	$FAPoints/Position2D9,
	$FAPoints/Position2D10,
	$FAPoints/Position2D11,
	$FAPoints/Position2D12,
	$FAPoints/Position2D13,
	$FAPoints/Position2D14,
	$FAPoints/Position2D15,
	$FAPoints/Position2D16,
	$FAPoints/Position2D17,
	$FAPoints/Position2D18,
	$FAPoints/Position2D19,
	$FAPoints/Position2D20,
	$FAPoints/Position2D21,
	$FAPoints/Position2D22,
	$FAPoints/Position2D23,
	$FAPoints/Position2D24
]

var reloading = false

func init():
	Data.listen(self, "obelisk.chStyle", true)

	set_style(int(Data.of("obelisk.chStyle")))
	$Outline.visible = canOutlineBeVisible()
	
	$HitMarker.visible = false
	$Denial.connect("animation_finished", self, "hide_denial")
	hide_denial()
	
	Style.init(self)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		# ONLY LOWERCASE HERE
		"obelisk.chstyle":
			set_style(newValue)


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if follow_reticle_target:
		if is_instance_valid(cur_reticle_target):
			var target_pos = cur_reticle_target.global_position
			var dist_to_target = target_pos.distance_to(global_position)
			input = (target_pos - global_position).normalized() * delta * dist_to_target
	else:
		# clamp reticle to edges of screen
		var x1 = 465*2 # max extents at 1.0 zoom
		var y1 = 455*2
		var zoom = InputSystem.getCamera().zoom
		var pos = InputSystem.getCamera().position
		if input.x < 0:
			if global_position.x <= -((x1 * zoom.x) + pos.x):
				input.x = 0
		elif input.x > 0:
			if global_position.x >= ((x1 * zoom.x) + pos.x):
				input.x = 0
		if input.y < 0: # up
			# no idea why this works for both battle an mining cams but here we are
			# -200 is the default camera pos y offset
			if global_position.y <= -((y1 * zoom.y) + pos.y + (800 * zoom.y * zoom.y)):
				input.y = 0
		elif input.y > 0: # down
			if global_position.y >= 0:
				input.y = 0
	
	# when quickly changing directions, only counter friction in the opposite direction
	if last_input.x != 0 and input.x == 0:
		var counter = Vector2(last_input.x, 0)
		apply_friction(friction * 0.7, counter)
	elif last_input.y != 0 and input.y == 0:
		var counter = Vector2(0, last_input.y)
		apply_friction(friction * 0.7, counter)
	if input == Vector2.ZERO:
		# if we don't get any input, decelerate without directional bias
		apply_friction(friction)
	else:
		apply_movement(input.normalized() * acceleration, speed_mod)
	
	
	if hoveredMonsters.size() > 0 or cur_bridgeTime > 0.0:
		motion *= Data.of("obelisk.slowdownOverMonsters")
	
	position += motion
	var s = ((maxSpread() - minSpread()) * motion.length()) / Data.of("obelisk.maxReticleSpeed") + minSpread()
	
	if Data.of("obelisk.specialType") == 2 and special_slow:
		s = max(s*0.7, minSpread())
	
	if spreadDeactivated:
		s = minSpread()
	
	apply_spread(s)
	
	last_input = input

func minSpread():
	if spreadDeactivated or Data.of("obelisk.chStyle") == 4:
		return Data.of("obelisk.minReticleSpread")
	
	# if the base spread is below center shot threshold and the add would push it over threshold, instead just go up to threshold
	if Data.of("obelisk.minReticleSpread") <= Data.of("obelisk.guaranteedCenterShotThreshold") and Data.of("obelisk.minReticleSpread") + Data.of("obelisk.reticleSpreadAdd") > Data.of("obelisk.guaranteedCenterShotThreshold"):
		return Data.of("obelisk.guaranteedCenterShotThreshold")
	
	return Data.of("obelisk.minReticleSpread") + Data.of("obelisk.reticleSpreadAdd")

func maxSpread():
	if spreadDeactivated or Data.of("obelisk.chStyle") == 4:
		return Data.of("obelisk.maxReticleSpread")
	return Data.of("obelisk.maxReticleSpread") + Data.of("obelisk.reticleSpreadAdd")

func move(dir:Vector2, speed_mod: float):
	input = dir
	self.speed_mod = speed_mod

func _process(delta: float) -> void:
	if GameWorld.paused or not is_active:
		return
	if cur_bridgeTime < Data.of("obelisk.monsterSlowdownBridgeTime") and cur_bridgeTime > 0.0:
		cur_bridgeTime += delta
	elif cur_bridgeTime >= Data.of("obelisk.monsterSlowdownBridgeTime") and hoveredMonsters.size() == 0:
		cur_bridgeTime = 0.0
	
	if Data.of("obelisk.chStyle") != 5: # if not circle
		if reloading and not Data.of("obelisk.rechargeAmmo"):
			for ch in container.get_children():
				ch.set_reload()
		elif (detectedMonsters.size() > 0 and monsterDetectionHighlightsCrosshairs) or hoverOverride:
			for ch in container.get_children():
				ch.set_hover()
		else:
			for ch in container.get_children():
				ch.set_normal()
	else:
		if reloading and not Data.of("obelisk.rechargeAmmo"):
			$FullAutoCircle.texture = load("res://content/weapons/obelisk/img/crosshairsFACircle_reload.png")
		elif (detectedMonsters.size() > 0 and monsterDetectionHighlightsCrosshairs) or hoverOverride:
			$FullAutoCircle.texture = load("res://content/weapons/obelisk/img/crosshairsFACircle_hover.png")
		else:
			$FullAutoCircle.texture = load("res://content/weapons/obelisk/img/crosshairsFACircle_no.png")
	
	$MonsterDetection/CollisionShape2D.shape.radius = min(cur_spread, Data.of("obelisk.detectionRadius"))
	
	if $HitMarker.visible:
		if cur_hitMarkerStayTime <= hitMarkerStayTime:
			cur_hitMarkerStayTime += delta
		else:
			$HitMarker.visible = false
			hit_marker_next_frame = false
			cur_hitMarkerStayTime = 0.0
	
	
	if kill_marker_next_frame:
		kill_marker()
		kill_marker_next_frame = false
	
	$Outline.visible = canOutlineBeVisible()
	if cur_spread - Data.of("obelisk.shootingSpreadMax") < Data.of("obelisk.guaranteedCenterShotThreshold"):
		var outline_s = (Data.of("obelisk.guaranteedCenterShotThreshold") + Data.of("obelisk.radius")) / 160
		$Outline.clear_points()
		for p in $OutlinePoints.get_children():
			$Outline.add_point(p.position * 0.7 * outline_s)
		$Outline.add_point($OutlinePoints.get_children().front().position * 0.7 * outline_s)
		
	else:
		$Outline.visible = false
	
	if Data.of("obelisk.chStyle") == 5:
		$FullAutoCircle.clear_points()
		for p in $FAPoints.get_children():
			$FullAutoCircle.add_point(p.position)
		$FullAutoCircle.add_point(segments.front().position)
	
	if speed_add_duration > 0.0:
		cur_speed_add_duration += delta
		if cur_speed_add_duration > speed_add_duration:
			speed_add = 0

func apply_friction(amount, direction:= Vector2.ZERO):
	if direction == Vector2.ZERO:
		if motion.length() > amount:
			motion -= motion.normalized() * amount
		else:
			motion = Vector2.ZERO
	else:
		if motion.length() > direction.length():
			motion -= direction * amount
		else:
			motion = Vector2.ZERO

func apply_movement(acceleration_vec, speed_mod):
	motion += acceleration_vec
	
	var limit = Data.of("obelisk.maxReticleSpeed")
	if killstreakActive:
		limit += Data.of("obelisk.killstreakActiveReticleSpeedAdd")
	
	limit += speed_add
	
	if speed_add > 0:
		# if we have some additional speed, only apply the speed mod if it's positive so that they don't cancel out and the additional speed is still noticeable
		if speed_mod > 1.0:
			limit *= speed_mod
	else:
		limit *= speed_mod
	
	# controller input can be less than 1.0
	if input.length() < 1.0:
		limit *= input.length()
	
	motion = motion.clamped(limit)

func apply_spread(spread: float, useLerp: bool = true):
	var expand = last_spread < spread
	var lerp_strength = Data.of("obelisk.spreadUpSpeed") if expand else  Data.of("obelisk.spreadDownSpeed")
	spread += shooting_spread
	
	# with negative growth the spread could tend towards 0 or even go into the negatives, so to visually not make the reticle retreat to a single point, this clamps it
	if spread < abs(Data.of("obelisk.guaranteedCenterShotThreshold")) and Data.of("obelisk.shootingSpreadGrowth") < 0:
		spread = Data.of("obelisk.guaranteedCenterShotThreshold")
	
	for i in range(segments.size()):
		# if started shooting, immediately expand the crosshairs to max size
		if (last_shooting_spread == 0 and shooting_spread > 0):
			var s = segments[i]
			s.position = s.defaultPosition + s.dir * spread
		# else, use lerp to make the movement smooth
		else:
			if useLerp:
				var s = segments[i]
				var spread_lerp = lerp(s.position, spread * s.dir, lerp_strength)
				s.position = s.defaultPosition + spread_lerp
				cur_spread = spread_lerp.length()
			else:
				var s = segments[i]
				s.position = s.dir * minSpread()
			
	$SpreadArea/CollisionShape2D.shape.radius = cur_spread
	last_spread = spread
	last_shooting_spread = shooting_spread
	
	var circ_scale = 0
	if Data.of("obelisk.chStyle") == 5:
		circ_scale = spread / 160
	$FAPoints.scale = Vector2(circ_scale, circ_scale)

func apply_shoot_delay(progress: float):
	var segment_count = segments.size()
	var seg_index = 1
	for cs in segments:
		if float(seg_index) / float(segment_count) < progress or progress >= 1.0:
			cs.scale = Vector2(1.0, 1.0)
			cs.modulate.a = 1.0
		else:
			cs.scale = Vector2(0.5, 0.5)
			cs.modulate.a = 0.25
		seg_index += 1

func _on_SpreadArea_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addDetectedMonsters(area)

func _on_SpreadArea_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeDetectedMonsters(area)


func addDetectedMonsters(m):
	if not detectedMonsters.has(m):
		detectedMonsters.append(m)
		if not m.is_connected("died", self, "removeDetectedMonsters"):
			m.connect("died", self, "removeDetectedMonsters", [m])

func removeDetectedMonsters(m):
	if detectedMonsters.has(m):
		detectedMonsters.erase(m)
		m.disconnect("died", self, "removeDetectedMonsters")

func addHoveredMonsters(m):
	if not hoveredMonsters.has(m):
		hoveredMonsters.append(m)
		if not m.is_connected("died", self, "removeHoveredMonsters"):
			m.connect("died", self, "removeHoveredMonsters", [m])

func removeHoveredMonsters(m):
	if hoveredMonsters.has(m):
		hoveredMonsters.erase(m)
		m.disconnect("died", self, "removeHoveredMonsters")
		if hoveredMonsters.size() == 0:
			cur_bridgeTime = 0.01


func _on_MonsterDetection_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addHoveredMonsters(area)


func _on_MonsterDetection_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeHoveredMonsters(area)


func hit_marker():
	$HitMarker.visible = true
	cur_hitMarkerStayTime = 0.0

func kill_marker():
	pass

func light_up_crosshair():
	$TweenLight.seek($TweenLight.get_runtime())
	$TweenLight.remove_all()
	$TweenLight.interpolate_property(container, "modulate", Color(15.0, 15.0, 15.0, 1.0), Color(1.0, 1.0, 1.0, 1.0), 0.5, Tween.TRANS_LINEAR)
	$TweenLight.start()

func showShotReady():
	var hm = SHOT_READY.instance()
	add_child(hm)
	hm.z_index = 350

func canOutlineBeVisible() -> bool:
	if Data.of("obelisk.singleTarget"):
		return false
	if Data.of("obelisk.chStyle") == 4: # beam
		return false
	if Data.of("obelisk.chStyle") == 5: # full auto
		return false
	return Data.of("obelisk.radiusOutline") and is_active

func set_style(style: int):
	cur_chStyle = style
	match cur_chStyle:
		Styles.Default:
			container = _containerDefault
			segments = _segmentsDefaut
		Styles.Sniper:
			container = _containerSniper
			segments = _segmentsSniper
		Styles.Nukes:
			container = _containerNukes
			segments = _segmentsNukes
		Styles.FullAuto:
			container = _containerFullAuto
			segments = _segmentsFullAuto
		Styles.Beam:
			container = _containerBeam
			segments = _segmentsBeam
		Styles.FullAutoCircle:
			container = _containerFACircle
			segments = _segmentsFACircle
	
	$DefaultContainer.visible = style == Styles.Default
	$SniperContainer.visible = style == Styles.Sniper
	$NukeContainer.visible = style == Styles.Nukes
	$FullAutoContainer.visible = style == Styles.FullAuto
	$BeamContainer.visible = style == Styles.Beam
	$FullAutoCircle.visible = style == Styles.FullAutoCircle

func set_visible(value:bool):
	visible = value


func set_reload(value:bool):
	reloading = value

func denial():
	if not $Denial.visible and not $DenialSound.playing:
		$Denial.visible = true
		$Denial.frame = 0
		$Denial.play("default")
		$DenialSound.play(0.0)

func hide_denial():
	$Denial.visible = false
