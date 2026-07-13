class_name ParticleBurst
extends Node

enum BurstType { CLEAN, MISTAKE, SCRUB, JUNK, EXPLOSION }

@export var layer_path: NodePath = ^"../WorldLayer"


func spawn(type: BurstType, world_pos: Vector2) -> void:
	var parent := get_node(layer_path) as Node2D
	if parent == null:
		return

	var particles := CPUParticles2D.new()
	parent.add_child(particles)
	particles.global_position = world_pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.finished.connect(particles.queue_free)

	match type:
		BurstType.CLEAN:
			_setup(particles, 10, 0.45, Color(0.7, 0.95, 0.75), 60.0, 140.0, 2.0, 5.0)
		BurstType.MISTAKE:
			_setup(particles, 8, 0.35, Color(0.95, 0.35, 0.3), 50.0, 110.0, 2.0, 4.0)
		BurstType.SCRUB:
			_setup(particles, 3, 0.25, Color(0.85, 0.8, 0.65), 20.0, 50.0, 1.0, 2.5)
		BurstType.JUNK:
			_setup(particles, 14, 0.55, Color(1.0, 0.55, 0.15), 80.0, 160.0, 3.0, 6.0)
		BurstType.EXPLOSION:
			_setup(particles, 24, 0.7, Color(0.9, 0.2, 0.15), 120.0, 220.0, 4.0, 8.0)

	particles.emitting = true


func _setup(
	particles: CPUParticles2D,
	count: int,
	lifetime: float,
	color: Color,
	vel_min: float,
	vel_max: float,
	scale_min: float,
	scale_max: float
) -> void:
	particles.amount = count
	particles.lifetime = lifetime
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = vel_min
	particles.initial_velocity_max = vel_max
	particles.gravity = Vector2(0, 180)
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color = color
