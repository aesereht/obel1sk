extends "res://content/gadgets/repellent/Repellent.gd"


func _ready():
	
	
	$Sprite.frames.add_animation("filling_domeobel1sk")
	var tex_path = "res://mods-unpacked/Snek-Obel1sk/overwrites/content/dome/domeobel1sk/dome/"
	for i in range(23):
		var path = str(tex_path, "repellantfill", i, ".png")
		$Sprite.frames.add_frame("filling_domeobel1sk", load(path), i)

	# yep this is gonna break with mp
	if Level.domeId() == "domeobel1sk":
		$Sprite.position.x += 10
	
	._ready()
	
