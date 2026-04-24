class_name MarbleTrail
extends GPUParticles3D

# Subtle speed-dependent trail behind a marble. Emits more particles at
# higher speeds, giving a visual sense of velocity. Attaches as a child
# of the marble's RigidBody3D.

const BASE_EMISSION_RATE := 30.0
const MAX_EMISSION_RATE := 120.0
const SPEED_THRESHOLD := 2.0

var _material: ParticleProcessMaterial

func _init() -> void:
	amount = 64
	lifetime = 0.6
	explosiveness = 0.0
	randomness = 0.2
	visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	_material = ParticleProcessMaterial.new()
	_material.direction = Vector3(0, 0.3, 0)
	_material.spread = 30.0
	_material.initial_velocity_min = 0.2
	_material.initial_velocity_max = 0.8
	_material.gravity = Vector3(0, -1.0, 0)
	_material.scale_min = 0.03
	_material.scale_max = 0.06
	_material.color = Color(1.0, 1.0, 1.0, 0.4)

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.5))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	color_ramp.gradient = gradient
	_material.color_ramp = color_ramp

	process_material = _material

	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	draw_pass_1 = mesh

func set_trail_color(color: Color) -> void:
	_material.color = Color(color.r, color.g, color.b, 0.5)

func _process(_delta: float) -> void:
	var parent := get_parent()
	if parent is RigidBody3D:
		var speed := (parent as RigidBody3D).linear_velocity.length()
		emitting = speed > SPEED_THRESHOLD
		if emitting:
			var t := clampf((speed - SPEED_THRESHOLD) / 10.0, 0.0, 1.0)
			amount_ratio = lerpf(BASE_EMISSION_RATE / MAX_EMISSION_RATE, 1.0, t)
