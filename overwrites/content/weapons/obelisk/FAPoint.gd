extends Position2D


var dir
var defaultPosition = Vector2.ZERO

func _ready() -> void:
	dir = position.normalized()
	

func set_normal():
	pass

func set_hover():
	pass

func set_reload():
	pass
