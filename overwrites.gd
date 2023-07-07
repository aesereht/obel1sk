extends Node

const MOD_DOME_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/"
const GAME_DOME_PATH := "res://content/dome/"
const MOD_ICON_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/icons/"
const GAME_ICON_PATH := "res://content/icons/"
const MOD_PETS_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/pets/"
const GAME_PETS_PATH := "res://content/pets/"

var icons := [
	"loadout_domeobel1sk.png",
]

var iconTextures := []

func _init():
	for icon in icons:
		var overwrite = load(MOD_ICON_PATH+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+icon)
	
	var ow1 = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/domeobel1sk/Domeobel1sk.tscn")
	ow1.take_over_path(GAME_DOME_PATH + "domeobel1sk/Domeobel1sk.tscn")
	
	var ow2 = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/Obelisk.tscn")
	ow2.take_over_path("res://content/weapons/obel1sk/Obel1sk.tscn")
	
	var primaryWeapon = "obel1sk"
	var ow3 = load(str("res://content/weapons/" + primaryWeapon + "/" + startCaptialized(primaryWeapon) + ".tscn"))
	ow3.take_over_path(str("res://content/weapons/" + primaryWeapon + "/" + primaryWeapon.capitalize() + ".tscn"))
	
	for i in range(6):
		var id = i + 1
		#var overwrite = load(str(MOD_PETS_PATH, "pet", id, "/PositionsDomeobel1sk.tscn"))
		#overwrite.take_over_path(str(GAME_PETS_PATH, "pet", id, "/PositionsDomeobel1sk.tscn"))

# so what the fuck is this? well .capitalize() also screws with numbers (i.e. obel1sk becomes Obel 1 sk, not Obel1sk.) Data would have this function but by the time this gets _init() called, Data doesn't exist yet, so this is the copy-pasted function straight from Data

func startCaptialized(s:String):
	return s.substr(0, 1).to_upper() + s.substr(1, s.length() - 1)
