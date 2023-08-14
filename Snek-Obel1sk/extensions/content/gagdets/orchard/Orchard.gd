extends "res://content/gadgets/orchard/Orchard.gd"


const MYMODNAME_LOG = "Snek-Obel1sk"
const MYMODNAME_MOD_DIR = "Snek-Obel1sk/"

func _ready():
	ModLoaderLog.info("Init", MYMODNAME_LOG)
	var dir = ModLoaderMod.get_unpacked_dir() + MYMODNAME_MOD_DIR
	var ovr_dir = dir + "overwrites/"
	var tex_path = ovr_dir + "content/gadgets/orchard/domeobel1sk/"
	
	var anims = ["empty", "fruit", "growing", "overcharged"]
	for a in anims:
		
		var frame_count = 0
		match a:
			"empty":
				frame_count = 1
			"fruit":
				frame_count = 8
			"growing":
				frame_count = 7
			"overcharged":
				frame_count = 7
		
		$Sprite.frames.add_animation(str(a, "_domeobel1sk"))
		
		for i in range(frame_count):
			var path = str(tex_path, str("obel1sk_", a, "_domeobel1sk"), i, ".png")
			$Sprite.frames.add_frame(str(a, "_domeobel1sk"), load(path), i)
	
	
	$Sprite/Fruit.frames.add_animation("shine_domeobel1sk")
	for i in range(5):
		var path = str(tex_path, "obel1sk_fruit", i, ".png")
		$Sprite/Fruit.frames.add_frame("shine_domeobel1sk", load(path), i)
	
	if Level.domeId() == "domeobel1sk":
		position.y -= 13
	
	._ready()
