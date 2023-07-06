extends Node

const MYMODNAME_LOG = "Snek-Obel1sk"
const MYMODNAME_MOD_DIR = "Snek-Obel1sk/"

var dir = ""
var ext_dir = ""
var trans_dir = ""

func _init(modLoader = ModLoader):
	ModLoaderLog.info("Init", MYMODNAME_LOG)
	dir = ModLoaderMod.get_unpacked_dir() + MYMODNAME_MOD_DIR
	ext_dir = dir + "extensions/"
	trans_dir = dir + "translations/"
	
	# Add extensions
	ModLoaderMod.install_script_extension(ext_dir + "game/GameWorld.gd")
	#ModLoaderMod.install_script_extension(ext_dir + "systems/data/Data.gd")
	
	ModLoaderMod.add_translation(trans_dir + "obel1sk_text.en.translation")

func _ready():
	ModLoaderLog.info("Done", MYMODNAME_LOG)
	add_to_group("mod_init")

func modInit():
	Data.registerDome("domeobel1sk")
	




