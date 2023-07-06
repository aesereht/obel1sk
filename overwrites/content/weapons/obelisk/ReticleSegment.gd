extends Sprite


export(Texture) var textureNormal
export(Texture) var textureHover
export(Texture) var textureReload
export(Vector2) var dir = Vector2.ZERO
export var rotateToDir := true
export var flipToDir := false

var defaultPosition = Vector2.ZERO

func _ready() -> void:
	if rotateToDir:
		rotate(atan2(-dir.y, -dir.x))
	if flipToDir:
		flip_h = dir.x > 0.0
		flip_v = dir.y > 0.0
	
	defaultPosition = position

func set_hover():
	texture = textureHover

func set_normal():
	texture = textureNormal

func set_reload():
	texture = textureReload
