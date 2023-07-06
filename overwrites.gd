extends Node

const MOD_DOME_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/"
const GAME_DOME_PATH := "res://content/dome/"
const MOD_ICON_PATH := "res://mods-unpacked/Snek-Obel1sk/overwrites/content/icons/"
const GAME_ICON_PATH := "res://content/icons/"

var icons := [
	"loadout_domeobel1sk.png",
]

var iconTextures := []

func _init():
	for icon in icons:
		var overwrite = load(MOD_ICON_PATH+icon)
		iconTextures.append(overwrite)
		overwrite.take_over_path(GAME_ICON_PATH+icon)
	
	var overwrite = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/domeobel1sk/Domeobel1sk.tscn")
	overwrite.take_over_path(GAME_DOME_PATH + "domeobel1sk/Domeobel1sk.tscn")
