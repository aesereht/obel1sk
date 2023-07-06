extends Node2D

var origin = Vector2.ZERO

var fade_time = 0.0
var ammo_index := 0

func _ready() -> void:
	origin = position

func set_radius(value: float):
	$Sprite.position.y = value * -0.5

func init(maxAmmo):
	fade_time = Data.of("obel1sk.shootDelay") * 0.18
	
#	if maxAmmo > 1:
#		$Sprite.position.y += $Sprite.texture.get_size().y / 2
	
	if maxAmmo > 25:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo25.png")
	elif maxAmmo >= 15:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo15.png")
	elif maxAmmo >= 9:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo9.png")
	elif maxAmmo >= 5:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo5.png")
	elif maxAmmo >= 3:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo3.png")
	elif maxAmmo >= 2:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo2.png")
	else:
		$Sprite.texture = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/img/ammo1.png")
	
	Style.init(self)
	visible = true
