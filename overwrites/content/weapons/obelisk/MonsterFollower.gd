extends Node2D

export(String) var techId := ""
var targetMonster
var offset := Vector2.ZERO
var timeLimit := -1
var cur_timeLimit := 0.0

var nullMonsterTimer = 10.0 # number of seconds this can be without a monster bevore getting removed
var cur_nullMonsterTimer = 0.0

export var lerpMove = true

export var allowSceneDuplicates = true
export var allowMonsterDuplicates = true
export var stackMonsterDuplicates = true

var stacks = 1

var is_active := false
var obelisk

# order is important, only call init() after setting targetMonster
func init():
	Style.init(self)
	set_is_active(true)
	z_index = 100
	add_to_group("MonsterFollower")
	
	for f in get_tree().get_nodes_in_group("MonsterFollower"):
		if techId == f.techId and not allowSceneDuplicates and f != self:
			remove()
		
		if f.targetMonster == targetMonster and f != self:
			if techId == f.techId:
				if allowMonsterDuplicates and stackMonsterDuplicates:
					f.increment_stacks()
					remove()
				if not allowMonsterDuplicates:
					remove()
		
	

func _process(delta: float) -> void:
#	if not is_instance_valid(targetMonster) and is_active:
#		remove()
	if not is_active:
		return
	
	var monster_dist = 0
	if is_instance_valid(targetMonster):
		monster_dist = targetMonster.global_position.distance_to(global_position)
	
	
	# move to monster
	if monster_dist > 1:
		
		var monster_center := Vector2.ZERO
		var cen = targetMonster.get_node("Sprite")
		if cen == null:
			Logger.warn("MonsterFollower got a monster with no first-level Sprite node")
		else:
			monster_center = cen.position
		
		
		# this line got broken by making followers keep distance to each other, come back later
		if lerpMove:
			global_position = lerp(global_position, targetMonster.global_position + monster_center, 0.2)
		else:
			global_position = targetMonster.global_position + monster_center
		
	
	if timeLimit != -1:
		if cur_timeLimit >= timeLimit:
			remove()
		else:
			cur_timeLimit += delta
	
	var threshold = 30
	var sprite_size = Vector2.ZERO
	if is_instance_valid(targetMonster):
		sprite_size = targetMonster.getSpriteSize()
	threshold = max(threshold, max(sprite_size.x, sprite_size.y))
	
	modulate.a = 1.0 - max(monster_dist - threshold, 0) * 0.06
	
	if not is_instance_valid(targetMonster):
		if cur_nullMonsterTimer < nullMonsterTimer:
			cur_nullMonsterTimer += delta
		else:
			remove()
	
	if targetMonster.monsterFollowerImmunity:
		remove()
	

func increment_stacks():
	return

func set_offset(offset: Vector2):
	self.offset = offset
	global_position = targetMonster.global_position + offset

func set_monster(m):
	if m == null:
		targetMonster = null
		set_is_active(false)
		return
	
	if m.monsterFollowerImmunity:
		set_is_active(false)
		remove()
		return
	
	if targetMonster != m and targetMonster != null:
		targetMonster.disconnect("died", self, "remove")
	
	targetMonster = m
	
	if not m.is_connected("died", self, "remove"):
		m.connect("died", self, "remove")
	
func remove():
	set_monster(null)
	set_is_active(false)
	queue_free()

func set_is_active(value:bool):
	is_active = value
