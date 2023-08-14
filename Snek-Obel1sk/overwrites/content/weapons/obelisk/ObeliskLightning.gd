extends Node2D

const PARTICLES = preload("res://content/shared/destructibles/fake_explosion_particles.tscn")

var spacing = 20


func arc(from: Vector2, to:Vector2):
	var direction = to - from
	var distance = direction.length()
	
	var cur_distance = 0
	while cur_distance < distance:
		if cur_distance + spacing > distance:
			cur_distance = distance
		
		var spawn_pos = from + cur_distance * direction.normalized()
		spawn_pos.y += 5
		var new_particles = PARTICLES.instance()
		new_particles.min_particles_number = 13
		new_particles.max_particles_number = 25
		new_particles.min_particles_velocity = 10
		new_particles.max_particles_velocity = 30
		new_particles.min_particles_gravity = new_particles.min_particles_velocity
		new_particles.max_particles_gravity = new_particles.max_particles_velocity
		new_particles.global_position = spawn_pos
		new_particles.particles_explode = true
		new_particles.z_index = 101
		
		new_particles.particles_colors_with_weights = [
	[4, Color("#58ff64")],
	[2, Color("#58ff64")],
	[8, Color("#58ff64")],
	[8, Color("#58ff64")],
	[10, Color("#58ff64")]
]
		Style.init(new_particles)
		add_child(new_particles)
		
		cur_distance += spacing
		if randf() < 0.2:
			yield(get_tree(), "idle_frame")
