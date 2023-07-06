extends Node2D


const NUKE_ECHO = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/DecayStunDoT.tscn")

var sustainFrames := 3

var hitMonsters := []
var blockers = 2

func _ready() -> void:
	$AnimatedSprite.connect("animation_finished", self, "decrement_blockers")
	$AnimatedSprite.play()
	Style.init(self)

func _physics_process(delta: float) -> void:
	if sustainFrames == 0:
		decrement_blockers()
	
	sustainFrames -= 1

func decrement_blockers():
	blockers -= 1
	if blockers <= 0:
		queue_free()

func _on_Area2D_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster") and not hitMonsters.has(area):
		if area.monsterFollowerImmunity:
			return
		hitMonsters.append(area)
		
		var dot = NUKE_ECHO.instance()
		Level.stage.add_child(dot)
		dot.set_monster(area)
		dot.set_offset(global_position - area.global_position) 
		dot.init()
