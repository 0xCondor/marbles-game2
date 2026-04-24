class_name CinematicCamera
extends Camera3D

# Multi-mode cinematic camera for casino presentation. Modes:
#   OVERVIEW  — frames the whole track (pre-race, buy-in)
#   FOLLOW    — tracks the leading marble with smooth interpolation
#   FINISH    — close-up on the finish line as marbles approach
#   WINNER    — orbits the winning marble with slow-motion feel
#
# The race orchestrator sets the mode; transitions are smooth via lerp/slerp.

enum Mode { OVERVIEW, FOLLOW, FINISH, WINNER }

const SMOOTH_SPEED := 3.5
const FOLLOW_HEIGHT := 7.0
const FOLLOW_BEHIND := 12.0
const FINISH_HEIGHT := 4.0
const FINISH_DISTANCE := 8.0
const WINNER_ORBIT_SPEED := 0.4
const WINNER_RADIUS := 5.0
const WINNER_HEIGHT := 3.0

var track: Track
var mode: Mode = Mode.OVERVIEW
var _marbles: Array[RigidBody3D] = []
var _winner: RigidBody3D = null
var _orbit_angle := 0.0
var _finish_pos := Vector3.ZERO

func setup(marbles: Array[RigidBody3D]) -> void:
	_marbles = marbles
	current = true
	if track != null:
		_snap_to_overview()

func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if new_mode == Mode.WINNER and _winner != null:
		_orbit_angle = 0.0

func set_winner(marble: RigidBody3D) -> void:
	_winner = marble

func set_finish_position(pos: Vector3) -> void:
	_finish_pos = pos

func _ready() -> void:
	fov = 55.0

func _process(delta: float) -> void:
	match mode:
		Mode.OVERVIEW:
			_update_overview(delta)
		Mode.FOLLOW:
			_update_follow(delta)
		Mode.FINISH:
			_update_finish(delta)
		Mode.WINNER:
			_update_winner(delta)

func _snap_to_overview() -> void:
	if track == null:
		return
	var bb := track.track_bounds()
	var center := bb.get_center()
	var extent := max(bb.size.x, bb.size.z) * 0.6
	global_position = center + Vector3(extent * 0.5, extent * 0.7, extent * 0.8)
	look_at(center)

func _update_overview(delta: float) -> void:
	if track == null:
		return
	var bb := track.track_bounds()
	var center := bb.get_center()
	var extent := max(bb.size.x, bb.size.z) * 0.6
	var desired := center + Vector3(extent * 0.5, extent * 0.7, extent * 0.8)
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	var look_target := center
	var current_forward := -global_basis.z
	var desired_forward := (look_target - global_position).normalized()
	var blended := current_forward.lerp(desired_forward, SMOOTH_SPEED * delta).normalized()
	look_at(global_position + blended)

func _update_follow(delta: float) -> void:
	if _marbles.is_empty():
		return
	var leader := _find_leader()
	var leader_pos := leader.global_position

	var offset := Vector3(0, FOLLOW_HEIGHT, FOLLOW_BEHIND)
	if track != null:
		var seg_idx := _nearest_segment(leader_pos)
		var meta := track.segment_meta(seg_idx)
		var forward: Vector3 = meta["forward"]
		offset = -forward * FOLLOW_BEHIND + Vector3(0, FOLLOW_HEIGHT, 0)

	var desired := leader_pos + offset
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	look_at(leader_pos)

func _update_finish(delta: float) -> void:
	if _finish_pos == Vector3.ZERO:
		_update_follow(delta)
		return
	var offset := Vector3(FINISH_DISTANCE * 0.7, FINISH_HEIGHT, FINISH_DISTANCE * 0.7)
	var desired := _finish_pos + offset
	global_position = global_position.lerp(desired, SMOOTH_SPEED * 1.5 * delta)
	var look_target := _finish_pos
	if not _marbles.is_empty():
		var leader := _find_leader()
		look_target = look_target.lerp(leader.global_position, 0.4)
	look_at(look_target)

func _update_winner(delta: float) -> void:
	if _winner == null:
		_update_overview(delta)
		return
	_orbit_angle += WINNER_ORBIT_SPEED * delta
	var target_pos := _winner.global_position
	var orbit_pos := target_pos + Vector3(
		cos(_orbit_angle) * WINNER_RADIUS,
		WINNER_HEIGHT,
		sin(_orbit_angle) * WINNER_RADIUS
	)
	global_position = global_position.lerp(orbit_pos, SMOOTH_SPEED * 2.0 * delta)
	look_at(target_pos)

func _find_leader() -> RigidBody3D:
	var best := _marbles[0]
	var best_progress := _marble_progress(best)
	for i in range(1, _marbles.size()):
		var p := _marble_progress(_marbles[i])
		if p > best_progress:
			best = _marbles[i]
			best_progress = p
	return best

func _marble_progress(m: RigidBody3D) -> float:
	if track == null:
		return -m.global_position.z
	return LeaderCamera._static_marble_progress(track, m.global_position)

func _nearest_segment(pos: Vector3) -> int:
	if track == null:
		return 0
	var best_idx := 0
	var best_dist := INF
	for i in range(track.segment_count()):
		var meta := track.segment_meta(i)
		var dist := pos.distance_to(meta["center"])
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

static func _static_marble_progress(t: Track, pos: Vector3) -> float:
	var best_progress := 0.0
	var best_dist := INF
	var cumulative := 0.0
	for i in range(t.segment_count()):
		var meta := t.segment_meta(i)
		var center: Vector3 = meta["center"]
		var forward: Vector3 = meta["forward"]
		var length: float = meta["length"]
		var local_forward := forward.dot(pos - center)
		var clamped := clampf(local_forward, -length * 0.5, length * 0.5)
		var projected := center + forward * clamped
		var dist := pos.distance_to(projected)
		if dist < best_dist:
			best_dist = dist
			best_progress = cumulative + clamped + length * 0.5
		cumulative += length
	return best_progress
