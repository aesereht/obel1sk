extends Node2D

const AMMO_SINGLE = preload("res://mods-unpacked/Snek-Obel1sk/overwrites/content/weapons/obelisk/AmmoDisplaySingle.tscn")

var maxAmmo = 12

export var radius = 0
export(float, 360) var starting_angle = 0
var origin = Vector2.ZERO
var ammo_displays := []

var flashing = false

func _ready() -> void:
	Data.listen(self, "obelisk.adStyle", true)

func init(newMaxAmmo) -> void:
	for c in $Singles.get_children():
		ammo_displays.erase(c)
		c.queue_free()
	maxAmmo = newMaxAmmo
	var index = 0
	# create nodes
	while index < maxAmmo:
		
		var new_node = AMMO_SINGLE.instance()
		$Singles.add_child(new_node)
		new_node.init(maxAmmo)
		new_node.ammo_index = index
		
		
		# set position of the new node
#		var new_x = origin.x + 1 * float(cos(2 * index * PI / maxAmmo))
#		var new_y = origin.y + radius * float(sin(2 * index * PI / maxAmmo))
#		new_node.position = Vector2(new_x, new_y)
		new_node.rotation_degrees = (float(index) / float(maxAmmo)) * 360 + starting_angle
		new_node.set_radius(radius)
		
		ammo_displays.append(new_node)
		index += 1

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"obelisk.adstyle":
			$Singles.visible = newValue == 0
			$Bar.visible = newValue == 1

func _process(delta: float) -> void:
	$Bar/Flashing.visible = flashing
	$Bar/Flashing.playing = flashing
	if flashing:
		$Bar/BaseFrame.modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		$Bar/BaseFrame.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_current_ammo(value: int):
	for a in ammo_displays:
		a.visible = a.ammo_index < value
	
	$Bar/Fill.rect_scale.y = (float(value) / float(maxAmmo)) * -1


func empty_ammo():
	set_current_ammo(0)

func fill_ammo():
	set_current_ammo(maxAmmo)
