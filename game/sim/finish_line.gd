class_name FinishLine
extends Area3D

signal marble_crossed(marble: RigidBody3D, tick: int)
signal race_finished(winner: RigidBody3D, tick: int)

# Set by the caller before add_child. The finish slab geometry is derived from
# the last segment of this track.
var track: Track

var _winner: RigidBody3D = null
var _crossed: Dictionary = {}
var _placements: Array[RigidBody3D] = []

func _ready() -> void:
	# Park the slab just past the last segment's downhill edge. The slab is
	# oriented to match the last segment's frame so its "crossing plane" is
	# perpendicular to the segment's forward direction — otherwise a curving
	# track ending with a yaw would have marbles missing an axis-aligned slab.
	var last := track.segment_count() - 1
	var meta := track.segment_meta(last)
	var up: Vector3 = meta["up"]
	var length: float = meta["length"]

	# Surface point at the downhill edge, plus a small forward offset so the slab
	# sits just past the edge and catches balls that fall off.
	var edge := track.segment_surface_point(last, length * 0.5 + 0.5)
	position = edge + up * 2.0
	basis = meta["basis"]

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Wide and tall in the segment's cross-track / vertical axes, thin along its forward axis.
	box.size = Vector3(track.get_width() + 4.0, 12.0, 0.4)
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
