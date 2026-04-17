class_name FinishLine
extends Area3D

signal marble_crossed(marble: RigidBody3D, tick: int)
signal race_finished(winner: RigidBody3D, tick: int)

var _winner: RigidBody3D = null
var _crossed: Dictionary = {}
var _placements: Array[RigidBody3D] = []

func _ready() -> void:
	# Ramp rotates -ANGLE_DEG about X, so its downhill end sits near world (0, -5, -14).
	# Slab is world-aligned so marbles falling off the deck still register.
	position = Vector3(0, -3.0, -13.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RampTrack.WIDTH + 2.0, 12.0, 0.4)
	shape.shape = box
	add_child(shape)

	_add_visual_banner()
	body_entered.connect(_on_body_entered)

func _add_visual_banner() -> void:
	var mesh_inst := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(RampTrack.WIDTH + 1.0, 3.0)
	mesh_inst.mesh = quad
	mesh_inst.rotation_degrees = Vector3(90, 0, 0)
	mesh_inst.position = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _on_body_entered(body: Node) -> void:
	if not body is RigidBody3D:
		return
	if _crossed.has(body):
		return
	var tick := Engine.get_physics_frames()
	_crossed[body] = tick
	_placements.append(body)
	marble_crossed.emit(body, tick)
	if _winner == null:
		_winner = body
		race_finished.emit(body, tick)
		print("WINNER: %s at tick %d" % [body.name, tick])

func get_winner() -> RigidBody3D:
	return _winner

func get_crossings() -> Dictionary:
	return _crossed

func get_placements() -> Array[RigidBody3D]:
	return _placements
