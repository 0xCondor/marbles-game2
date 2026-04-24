class_name FinishParticles
extends GPUParticles3D

# Burst of particles at the finish line when a marble crosses.
# Call burst() each time a marble finishes. One-shot explosion.

var _material: ParticleProcessMaterial

func _init() -> void:
	amount = 80
	lifetime = 1.2
	one_shot = true
	explosiveness = 0.95
	emitting = false

	_material = ParticleProcessMaterial.new()
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 180.0
	_material.initial_velocity_min = 3.0
	_material.initial_velocity_max = 8.0
	_material.gravity = Vector3(0, -6.0, 0)
	_material.scale_min = 0.04
	_material.scale_max = 0.1
	_material.damping_min = 1.0
	_material.damping_max = 3.0

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.3, 0.2, 0.0))
	color_ramp.gradient = gradient
	_material.color_ramp = color_ramp

	process_material = _material

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	draw_pass_1 = mesh

func burst(pos: Vector3, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	global_position = pos
	_material.color = color
	restart()
	emitting = true
