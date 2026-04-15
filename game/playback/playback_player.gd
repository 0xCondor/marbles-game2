class_name PlaybackPlayer
extends Node3D

const MARBLE_RADIUS := 0.3
const FLOATS_PER_MARBLE := 7  # pos (3) + quat (4)

var _header: Array = []
var _tick_rate: float = 60.0
var _marbles: Array[Node3D] = []
var _elapsed_ticks: float = 0.0
var _finished := false

# Flat state storage: all frames' positions + rotations back-to-back. Built
# once at load, indexed directly during interpolation (no dict lookups on
# the per-frame hot path).
var _frame_count: int = 0
var _marble_count: int = 0
var _floats_per_frame: int = 0
var _states: PackedFloat32Array = PackedFloat32Array()
var _last_tick: int = 0

signal playback_finished(last_tick: int, first_marble_pos: Vector3)

func load_replay(replay: Dictionary) -> void:
	_header = replay["header"]
	var frames: Array = replay["frames"]
	_tick_rate = float(replay["tick_rate_hz"])
	_frame_count = frames.size()
	_marble_count = _header.size()
	_floats_per_frame = _marble_count * FLOATS_PER_MARBLE
	_flatten_frames(frames)
	if _frame_count > 0:
		_last_tick = int(frames[_frame_count - 1]["tick"])
	_build_marbles()
	# Snap to the first recorded frame so the scene is valid before playback starts.
	if _frame_count > 0:
		_apply_frame_state(0)

func _flatten_frames(frames: Array) -> void:
	_states.resize(_frame_count * _floats_per_frame)
	for i in range(_frame_count):
		var states: Array = frames[i]["states"]
		var off := i * _floats_per_frame
		for j in range(_marble_count):
			var s: Dictionary = states[j]
			var p: Vector3 = s["pos"]
			var q: Quaternion = s["rot"]
			_states[off] = p.x
			_states[off + 1] = p.y
			_states[off + 2] = p.z
			_states[off + 3] = q.x
			_states[off + 4] = q.y
			_states[off + 5] = q.z
			_states[off + 6] = q.w
			off += FLOATS_PER_MARBLE

func _build_marbles() -> void:
	_marbles.clear()
	# Share a single sphere mesh across all visual marbles — the renderer is
	# free to batch draw calls when the mesh resource is identical.
	var shared_mesh := SphereMesh.new()
	shared_mesh.radius = MARBLE_RADIUS
	shared_mesh.height = MARBLE_RADIUS * 2.0
	for m in _header:
		var node := MeshInstance3D.new()
		node.name = m["name"]
		node.mesh = shared_mesh
		var mat := StandardMaterial3D.new()
		var rgba: int = m["rgba"]
		if rgba == 0:
			# Deterministic fallback color by header index so M1/M2 look roughly alike.
			mat.albedo_color = Color.from_hsv(float(_marbles.size()) / max(_header.size(), 1), 0.8, 0.95)
		else:
			mat.albedo_color = Color(((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, (rgba & 0xFF) / 255.0)
		node.material_override = mat
		add_child(node)
		_marbles.append(node)

func _process(delta: float) -> void:
	if _finished or _frame_count == 0:
		return
	_elapsed_ticks += delta * _tick_rate
	var idx_f: float = min(_elapsed_ticks, float(_frame_count - 1))
	var i := int(idx_f)
	var t := idx_f - float(i)
	if i + 1 < _frame_count:
		_apply_interpolated(i, i + 1, t)
	else:
		_apply_frame_state(i)
		_finished = true
		var last_off := (_frame_count - 1) * _floats_per_frame
		playback_finished.emit(_last_tick, Vector3(_states[last_off], _states[last_off + 1], _states[last_off + 2]))

func _apply_frame_state(frame_idx: int) -> void:
	var base := frame_idx * _floats_per_frame
	for j in range(_marble_count):
		var off := base + j * FLOATS_PER_MARBLE
		_marbles[j].global_position = Vector3(_states[off], _states[off + 1], _states[off + 2])
		_marbles[j].global_basis = Basis(Quaternion(_states[off + 3], _states[off + 4], _states[off + 5], _states[off + 6]))

func _apply_interpolated(frame_a: int, frame_b: int, t: float) -> void:
	var base_a := frame_a * _floats_per_frame
	var base_b := frame_b * _floats_per_frame
	for j in range(_marble_count):
		var oa := base_a + j * FLOATS_PER_MARBLE
		var ob := base_b + j * FLOATS_PER_MARBLE
		var pa := Vector3(_states[oa], _states[oa + 1], _states[oa + 2])
		var pb := Vector3(_states[ob], _states[ob + 1], _states[ob + 2])
		var qa := Quaternion(_states[oa + 3], _states[oa + 4], _states[oa + 5], _states[oa + 6])
		var qb := Quaternion(_states[ob + 3], _states[ob + 4], _states[ob + 5], _states[ob + 6])
		_marbles[j].global_position = pa.lerp(pb, t)
		_marbles[j].global_basis = Basis(qa.slerp(qb, t))
