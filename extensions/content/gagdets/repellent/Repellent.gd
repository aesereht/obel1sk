extends "res://content/gadgets/repellent/Repellent.gd"


const MYMODNAME_LOG = "Snek-Obel1sk"
const MYMODNAME_MOD_DIR = "Snek-Obel1sk/"

func _ready():
	ModLoaderLog.info("Init", MYMODNAME_LOG)
	var dir = ModLoaderMod.get_unpacked_dir() + MYMODNAME_MOD_DIR
	var ovr_dir = dir + "overwrites/"
	
	$Sprite.frames.add_animation("filling_domeobel1sk")
	var tex_path = ovr_dir + "content/dome/domeobel1sk/dome/"
	for i in range(23):
		var path = str(tex_path, "repellantfill", i, ".png")
		$Sprite.frames.add_frame("filling_domeobel1sk", load(path), i)
	
	
	._ready()
	
