class_name Confetti
extends GPUParticles3D

# Winner confetti shower — multicolored particles falling from above.
# Triggered once on winner announcement, lasts a few seconds.

var _material: ParticleProcessMaterial

func _init() -> void:
	amount = 200
	lifetime = 3.0
	one_shot = true
	explosiveness = 0.3
	emitting = false
	visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))

	_material = ParticleProcessMaterial.new()
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(8, 0.5, 8)
	_material.direction = Vector3(0, -1, 0)
	_material.spread = 25.0
	_material.initial_velocity_min = 1.0
	_material.initial_velocity_max = 3.0
	_material.gravity = Vector3(0, -4.0, 0)
	_material.angular_velocity_min = -180.0
	_material.angular_velocity_max = 180.0
	_material.scale_min = 0.03
	_material.scale_max = 0.08
	_material.damping_min = 0.5
	_material.damping_max = 1.5

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	color_ramp.gradient = gradient
	_material.color_ramp = color_ramp

	# Multicolor via hue variation
	_material.color = Color(1.0, 0.85, 0.3)
	_material.hue_variation_min = -0.5
	_material.hue_variation_max = 0.5

	process_material = _material

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.02, 0.06)
	draw_pass_1 = mesh

func shower(center: Vector3) -> void:
	global_position = center + Vector3(0, 12, 0)
	restart()
	emitting = true
