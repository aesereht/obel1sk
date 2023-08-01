extends Node

const MOD_DOME_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/"
const GAME_DOME_PATH := "res://content/dome/"
const MOD_ICON_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/icons/"
const GAME_ICON_PATH := "res://content/icons/"
const MOD_PETS_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/pets/"
const GAME_PETS_PATH := "res://content/pets/"

var upgrade_icons := [
	"ammokill.png",
	"burst1.png",
	"burst2.png",
	"damage1.png",
	"damage2.png",
	"deathcandles.png",
	"default1.png",
	"default2.png",
	"nukes1.png",
	"nukes2.png",
	"slowdamage.png",
	"sniper1.png",
	"sniper2.png",
	"sniper3.png",
	"sniperautoaim.png",
	"speed1.png",
	"speed2.png",
	"spooling1.png",
	"storedamage.png",
	"stunarea.png",
]

var upgrade_icons_dome := [
	"health1.png",
	"adaptation.png",
	"adaptationduration.png",
	"ironrepair.png",
	"maxrestore.png",
]
var icons := [
	"loadout_domeobel1sk.png",
	"domeobel1sk.png",
	"obel1sk.png",
]

var vanilla_icons = [
	"healthmeter.png",
	"wavemeter.png",
	"resourcecounters.png",
	"wavecount.png"
]

var iconTextures := []

var petPositions := []

var otherOverwrites := []

func _init():
	for icon in icons:
		var overwrite = load(MOD_ICON_PATH+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+icon)
		
	for icon in upgrade_icons:
		var overwrite = load(MOD_ICON_PATH+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+"obel1sk"+icon)
		
	for icon in upgrade_icons_dome:
		var overwrite = load(MOD_ICON_PATH+"domeobel1sk"+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+"domeobel1sk"+icon)
	
	for icon in vanilla_icons:
		var overwrite = load(GAME_ICON_PATH+"dome"+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+"domeobel1sk"+icon)
	
	for i in range(6):
		var id = i + 1
		var a = str(MOD_PETS_PATH, "pet", id, "/PositionsDomeobel1sk.tscn")
		var overwrite = load(a)
		petPositions.append(overwrite)
		overwrite.take_over_path(str(GAME_PETS_PATH, "pet", id, "/PositionsDomeobel1sk.tscn"))
	
	var ow1 = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/domeobel1sk/Domeobel1sk.tscn")
	otherOverwrites.append(ow1)
	ow1.take_over_path(GAME_DOME_PATH + "domeobel1sk/Domeobel1sk.tscn")
	
	var ow2 = load("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/Obelisk.tscn")
	otherOverwrites.append(ow2)
	ow2.take_over_path("res://content/weapons/obel1sk/Obel1sk.tscn")
	
	var primaryWeapon = "obel1sk"
	#var ow3 = load(str("res://content/weapons/" + primaryWeapon + "/" + startCaptialized(primaryWeapon) + ".tscn"))
	var ow3 = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/Obelisk.tscn")
	ow3.take_over_path(str("res://content/weapons/" + primaryWeapon + "/" + primaryWeapon.capitalize() + ".tscn"))
	
	

# so what the fuck is this? well .capitalize() also screws with numbers (i.e. obel1sk becomes Obel 1 sk, not Obel1sk.)
# Data would have this function but by the time this gets _init() called, Data doesn't exist yet, so this is the copy-pasted function straight from Data

func startCaptialized(s:String):
	return s.substr(0, 1).to_upper() + s.substr(1, s.length() - 1)
