class_name LeaderCamera
extends Camera3D

const SMOOTH_SPEED := 4.0
const HEIGHT_ABOVE := 6.0
const BEHIND_DISTANCE := 10.0

var track: Track
var _marbles: Array[RigidBody3D] = []
var _target_pos := Vector3.ZERO

func setup(marbles: Array[RigidBody3D]) -> void:
	_marbles = marbles
	current = true
	if not _marbles.is_empty() and track != null:
		_target_pos = _find_leader_pos()
		var bb := track.track_bounds()
		var center := bb.get_center()
		global_position = center + Vector3(0, HEIGHT_ABOVE + 5.0, BEHIND_DISTANCE)
		look_at(_target_pos)

func _process(delta: float) -> void:
	if _marbles.is_empty():
		return
	_target_pos = _find_leader_pos()
	var offset := Vector3(0, HEIGHT_ABOVE, BEHIND_DISTANCE)
	if track != null:
		var last_meta := track.segment_meta(track.segment_count() - 1)
		var forward: Vector3 = last_meta["forward"]
		offset = -forward * BEHIND_DISTANCE + Vector3(0, HEIGHT_ABOVE, 0)
	var desired := _target_pos + offset
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	look_at(_target_pos)

func _find_leader_pos() -> Vector3:
	var best: RigidBody3D = _marbles[0]
	var best_progress := _marble_progress(best)
	for i in range(1, _marbles.size()):
		var m := _marbles[i]
		var p := _marble_progress(m)
		if p > best_progress:
			best = m
			best_progress = p
	return best.global_position

func _marble_progress(m: RigidBody3D) -> float:
	if track == null:
		return -m.global_position.z
	var pos := m.global_position
	var best_dist := INF
	var best_progress := 0.0
	var cumulative := 0.0
	for i in range(track.segment_count()):
		var meta := track.segment_meta(i)
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
