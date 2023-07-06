extends Node2D
class_name ReticleTarget

var is_ping := false

var remaining_blockers := 3

func init(as_ping:bool):
	is_ping = as_ping
	Style.init($AmmoSingle)
	if is_ping:
		ping()


func ping():
	pass
	# vfx and sfx
	decrement_blockers()
	decrement_blockers()

func _physics_process(delta: float) -> void:
	if not is_ping:
		global_position = get_global_mouse_position()

func decrement_blockers(value:=1):
	remaining_blockers -= value
	if remaining_blockers <= 0:
		queue_free()
