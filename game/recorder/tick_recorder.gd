class_name TickRecorder
extends Node

const EVENT_FINISH_CROSS := 1 << 0
const TAIL_TICKS := 60  # ~1s slowdown footage after winner crosses
const TICK_RATE_HZ := 60

# Flat per-marble state layout: [pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w]
const FLOATS_PER_MARBLE := 7

var marbles: Array[RigidBody3D] = []
var finish_line: FinishLine = null

var header: Array = []  # [{id, name, client_seed, slot}] per marble
# Flat, GC-friendly frame storage. One PackedFloat32Array holds
# every marble state for every tick back-to-back; no per-tick allocations.
var _ticks: PackedInt32Array = PackedInt32Array()
var _flags: PackedByteArray = PackedByteArray()
var _states: PackedFloat32Array = PackedFloat32Array()
var recording: bool = true

var _round_id: int = 0
var _server_seed: PackedByteArray = PackedByteArray()
var _server_seed_hash: PackedByteArray = PackedByteArray()
var _client_seeds: Array = []
var _slots: Array = []
var _slot_count: int = 0

var _marble_count: int = 0
var _floats_per_frame: int = 0
var _pending_flags: int = 0
var _stop_tick: int = -1

func set_round_context(
	round_id: int,
	server_seed: PackedByteArray,
	server_seed_hash: PackedByteArray,
	client_seeds: Array,
	slots: Array,
) -> void:
	_round_id = round_id
	_server_seed = server_seed
	_server_seed_hash = server_seed_hash
	_client_seeds = client_seeds
	_slots = slots
	_slot_count = SpawnRail.SLOT_COUNT

func track(marble_list: Array[RigidBody3D], line: FinishLine) -> void:
	marbles = marble_list
	finish_line = line
	_marble_count = marbles.size()
	_floats_per_frame = _marble_count * FLOATS_PER_MARBLE
	header.clear()
	for i in range(_marble_count):
		var m := marbles[i]
		header.append({
			"id": m.get_instance_id(),
			"name": m.name,
			"client_seed": String(_client_seeds[i]) if i < _client_seeds.size() else "",
			"slot": int(_slots[i]) if i < _slots.size() else 0,
		})
	# Reserve generously — a typical race is 5-15s at 60Hz. Growing is fine
	# if we underestimate (Packed*Array doubles on resize).
	var expected_frames := 20 * TICK_RATE_HZ
	_ticks.resize(0)
	_flags.resize(0)
	_states.resize(0)
	_ticks.resize(expected_frames)
	_flags.resize(expected_frames)
	_states.resize(expected_frames * _floats_per_frame)
	# Shrink back to 0; the above just primes the backing capacity so the
	# first N appends don't repeatedly reallocate during physics.
	_ticks.resize(0)
	_flags.resize(0)
	_states.resize(0)
	if finish_line:
		finish_line.marble_crossed.connect(_on_marble_crossed)
		finish_line.race_finished.connect(_on_race_finished)

func _physics_process(_delta: float) -> void:
	if not recording:
		return
	var tick := Engine.get_physics_frames()
	_ticks.append(tick)
	_flags.append(_pending_flags & 0xFF)
	# Extend the flat state buffer by one frame's worth of floats, then fill in
	# place. This avoids allocating an Array + N Dictionaries per tick.
	var base := _states.size()
	_states.resize(base + _floats_per_frame)
	var off := base
	for i in range(_marble_count):
		var m := marbles[i]
		var p := m.global_position
		var q := m.global_basis.get_rotation_quaternion()
		_states[off] = p.x
		_states[off + 1] = p.y
		_states[off + 2] = p.z
		_states[off + 3] = q.x
		_states[off + 4] = q.y
		_states[off + 5] = q.z
		_states[off + 6] = q.w
		off += FLOATS_PER_MARBLE
	_pending_flags = 0
	if _stop_tick >= 0 and tick >= _stop_tick:
		_finalize()

func _on_marble_crossed(_marble: RigidBody3D, _tick: int) -> void:
	_pending_flags |= EVENT_FINISH_CROSS

func _on_race_finished(_winner: RigidBody3D, tick: int) -> void:
	_stop_tick = tick + TAIL_TICKS

func _finalize() -> void:
	recording = false
	var frame_count := _ticks.size()
	print("RECORDER: captured %d frames, %d marbles/frame" % [frame_count, _marble_count])
	print("REVEAL: server_seed=%s" % FairSeed.to_hex(_server_seed))

	var path := "user://replays/%d.bin" % _round_id
	var err := ReplayWriter.write(path, {
		"round_id": _round_id,
		"tick_rate_hz": TICK_RATE_HZ,
		"server_seed": _server_seed,
		"server_seed_hash": _server_seed_hash,
		"slot_count": _slot_count,
		"header": header,
		"frame_count": frame_count,
		"marble_count": _marble_count,
		"ticks": _ticks,
		"flags": _flags,
		"states": _states,
	})
	if err != OK:
		push_error("replay write failed: %d" % err)
		return
	var size := FileAccess.get_file_as_bytes(path).size()
	print("WRITER: wrote %s (%d bytes)" % [path, size])

	_roundtrip_check(path)

func _roundtrip_check(path: String) -> void:
	var replay := ReplayReader.read(path)
	if replay.is_empty():
		push_error("replay read failed")
		return
	var read_frames: Array = replay["frames"]
	var read_header: Array = replay["header"]
	var frame_count := _ticks.size()
	var ok := read_frames.size() == frame_count and read_header.size() == header.size()
	if ok and frame_count > 0:
		var read_last: Dictionary = read_frames[read_frames.size() - 1]
		var last_off := (frame_count - 1) * _floats_per_frame
		var orig_last_pos := Vector3(_states[last_off], _states[last_off + 1], _states[last_off + 2])
		ok = orig_last_pos.is_equal_approx(read_last["states"][0]["pos"] as Vector3)
		ok = ok and int(_ticks[frame_count - 1]) == int(read_last["tick"])
		ok = ok and (replay["server_seed"] as PackedByteArray) == _server_seed
		ok = ok and int(read_header[0]["slot"]) == int(header[0]["slot"])
	print("ROUNDTRIP: %s (%d frames, %d marbles)" % ["OK" if ok else "MISMATCH", read_frames.size(), read_header.size()])
