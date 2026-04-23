class_name RampTrack
extends Track

const WIDTH := 6.0
const DECK_THICKNESS := 0.5
const WALL_HEIGHT := 3.0
const GROUND_MARGIN := 30.0

const SEGMENTS := [
	{"length": 18.0, "yaw_deg":   0.0, "tilt_deg": 14.0},
	{"length": 18.0, "yaw_deg":  18.0, "tilt_deg": 14.0},
	{"length": 18.0, "yaw_deg": -18.0, "tilt_deg": 14.0},
	{"length": 18.0, "yaw_deg": -18.0, "tilt_deg": 14.0},
	{"length": 18.0, "yaw_deg":  18.0, "tilt_deg": 14.0},
]

var _meta: Array = []
var _deck_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D

func _ready() -> void:
	_ensure_meta()
	_deck_mat = StandardMaterial3D.new()
	_deck_mat.albedo_color = Color(0.55, 0.58, 0.65)
	_deck_mat.roughness = 0.85
	_deck_mat.metallic = 0.05
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.35, 0.38, 0.45)
	_wall_mat.roughness = 0.7
	_wall_mat.metallic = 0.1
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_color = Color(0.22, 0.24, 0.28)
	_ground_mat.roughness = 0.95
	for m: Dictionary in _meta:
		add_child(_make_box_body("Deck", Vector3(WIDTH, DECK_THICKNESS, float(m["length"])), m["center"], m["basis"], _deck_mat))
		add_child(_make_wall(m, +1))
		add_child(_make_wall(m, -1))
	add_child(_make_ground())

func _make_wall(meta: Dictionary, side: int) -> StaticBody3D:
	var right: Vector3 = meta["right"]
	var up: Vector3 = meta["up"]
	var center: Vector3 = meta["center"]
	var length: float = meta["length"]
	var wall_center := center + right * (WIDTH * 0.5 * side) + up * (WALL_HEIGHT * 0.5)
	return _make_box_body("Wall", Vector3(0.2, WALL_HEIGHT, length), wall_center, meta["basis"], _wall_mat)

func _make_box_body(node_name: String, size: Vector3, pos: Vector3, basis: Basis, mat: StandardMaterial3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = Transform3D(basis, pos)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	if mat:
		mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	body.physics_material_override = PhysicsMaterials.track()
	return body

func _make_ground() -> StaticBody3D:
	var bb := track_bounds()
	var ground_size := max(bb.size.x, bb.size.z) + GROUND_MARGIN * 2.0
	var ground_y := bb.position.y - 8.0
	var ground_center := Vector3(bb.get_center().x, ground_y, bb.get_center().z)
	return _make_box_body("Ground", Vector3(ground_size, 0.5, ground_size), ground_center, Basis.IDENTITY, _ground_mat)

# ─── Track overrides ───────────────────────────────────────────────────

func get_width() -> float:
	return WIDTH

func segment_count() -> int:
	_ensure_meta()
	return _meta.size()

func segment_meta(i: int) -> Dictionary:
	_ensure_meta()
	return _meta[i]

func segment_surface_point(i: int, forward_offset: float) -> Vector3:
	_ensure_meta()
	var m: Dictionary = _meta[i]
	var center: Vector3 = m["center"]
	var forward: Vector3 = m["forward"]
	var up: Vector3 = m["up"]
	return center + forward * forward_offset + up * (DECK_THICKNESS * 0.5)

func track_bounds() -> AABB:
	_ensure_meta()
	var bb := AABB()
	var first := true
	for m: Dictionary in _meta:
		var center: Vector3 = m["center"]
		var right: Vector3 = m["right"]
		var up: Vector3 = m["up"]
		var forward: Vector3 = m["forward"]
		var half_len: float = float(m["length"]) * 0.5
		for sx in [-1, 1]:
			for sy in [0, 1]:
				for sz in [-1, 1]:
					var corner := center
					corner += right * (WIDTH * 0.5 * float(sx))
					corner += up * (WALL_HEIGHT * float(sy))
					corner += forward * (half_len * float(sz))
					if first:
						bb = AABB(corner, Vector3.ZERO)
						first = false
					else:
						bb = bb.expand(corner)
	return bb

func _ensure_meta() -> void:
	if not _meta.is_empty():
		return
	var cursor := Vector3.ZERO
	for s: Dictionary in SEGMENTS:
		var yaw_rad := deg_to_rad(float(s["yaw_deg"]))
		var tilt_rad := deg_to_rad(-float(s["tilt_deg"]))
		var yaw_basis := Basis(Vector3.UP, yaw_rad)
		var tilt_basis := Basis(Vector3(1, 0, 0), tilt_rad)
		var basis := yaw_basis * tilt_basis
		var forward: Vector3 = basis * Vector3(0, 0, -1)
		var right: Vector3 = basis * Vector3(1, 0, 0)
		var up: Vector3 = basis * Vector3(0, 1, 0)
		var length := float(s["length"])
		var center := cursor + forward * (length * 0.5)
		_meta.append({
			"center": center,
			"basis": basis,
			"forward": forward,
			"right": right,
			"up": up,
			"length": length,
		})
		cursor += forward * length
