extends Node2D

var origin = Vector2.ZERO

var fade_time = 0.0
var ammo_index := 0

const MYMODNAME_MOD_DIR = "Snek-Obel1sk/"

func _ready() -> void:
	origin = position

func set_radius(value: float):
	$Sprite.position.y = value * -0.5

func init(maxAmmo):
	fade_time = Data.of("obel1sk.shootDelay") * 0.18
	
#	if maxAmmo > 1:
#		$Sprite.position.y += $Sprite.texture.get_size().y / 2
	
	
	var dir = ModLoaderMod.get_unpacked_dir() + MYMODNAME_MOD_DIR
	var ovr_dir = dir + "overwrites/"
	var img_dir = ovr_dir + "content/weapons/obelisk/img/"
	
	if maxAmmo > 25:
		$Sprite.texture = load(img_dir + "obel1sk_ammo25.png")
	elif maxAmmo >= 15:
		$Sprite.texture = load(img_dir + "obel1sk_ammo15.png")
	elif maxAmmo >= 9:
		$Sprite.texture = load(img_dir + "obel1sk_ammo9.png")
	elif maxAmmo >= 5:
		$Sprite.texture = load(img_dir + "obel1sk_ammo5.png")
	elif maxAmmo >= 3:
		$Sprite.texture = load(img_dir + "obel1sk_ammo3.png")
	elif maxAmmo >= 2:
		$Sprite.texture = load(img_dir + "obel1sk_ammo2.png")
	else:
		$Sprite.texture = load(img_dir + "obel1sk_ammo1.png")
	
	Style.init(self)
	visible = true
