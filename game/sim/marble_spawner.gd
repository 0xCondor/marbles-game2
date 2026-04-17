class_name MarbleSpawner
extends RefCounted

const RADIUS := 0.3

# Deterministic-by-slot spawn. `slots[i]` is the spawn slot for marble i.
# `colors[i]` (optional, same length as slots) overrides the default HSV-by-index color.
#
# Perf: mesh, collision shape, and physics material are built once and shared
# across all marbles. Godot ref-counts Resource, so sharing is safe and lets the
# renderer/physics backend amortize setup + batch better. Individual albedo
# materials are still per-marble since each marble has a unique color.
static func spawn(parent: Node, slots: Array, colors: Array = []) -> Array[RigidBody3D]:
	var marbles: Array[RigidBody3D] = []
	var shared_mesh := SphereMesh.new()
	shared_mesh.radius = RADIUS
	shared_mesh.height = RADIUS * 2.0
	var shared_shape := SphereShape3D.new()
	shared_shape.radius = RADIUS
	var shared_phys_mat := PhysicsMaterials.marble()
	for i in range(slots.size()):
		var color: Color = colors[i] if i < colors.size() else Color.from_hsv(float(i) / max(slots.size(), 1), 0.8, 0.95)
		var marble := _make_marble(i, int(slots[i]), color, shared_mesh, shared_shape, shared_phys_mat)
		parent.add_child(marble)
		marbles.append(marble)
	return marbles

static func _make_marble(
	drop_order: int,
	slot: int,
	color: Color,
	shared_mesh: SphereMesh,
	shared_shape: SphereShape3D,
	shared_phys_mat: PhysicsMaterial,
) -> RigidBody3D:
	var marble := RigidBody3D.new()
	marble.name = "Marble_%02d" % drop_order
	marble.mass = 1.0
	# CCD was a precaution during M1 but marbles on a 20° ramp never approach
	# the tunneling threshold (would need >18 m/s through a 0.5m slab at 60Hz).
	# Leaving it off saves a non-trivial Jolt sweep per substep.
	marble.continuous_cd = false

	marble.set_meta("color", color)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = shared_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	marble.add_child(mesh_inst)

	var shape := CollisionShape3D.new()
	shape.shape = shared_shape
	marble.add_child(shape)

	marble.physics_material_override = shared_phys_mat
	marble.position = SpawnRail.slot_position(slot, drop_order)
	return marble
