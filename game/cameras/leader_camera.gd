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
		var bb := track.camera_bounds()
		var center := bb.get_center()
		global_position = center + Vector3(0, HEIGHT_ABOVE + 5.0, BEHIND_DISTANCE)
		look_at(_target_pos)

func _process(delta: float) -> void:
	if _marbles.is_empty():
		return
	_target_pos = _find_leader_pos()
	var leader := _find_leader()
	var vel := leader.linear_velocity.normalized() if leader.linear_velocity.length() > 0.5 else Vector3(0, 0, -1)
	var offset := -vel * BEHIND_DISTANCE + Vector3(0, HEIGHT_ABOVE, 0)
	var desired := _target_pos + offset
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	look_at(_target_pos)

func _find_leader() -> RigidBody3D:
	var best := _marbles[0]
	var best_y := best.global_position.y
	for i in range(1, _marbles.size()):
		if _marbles[i].global_position.y < best_y:
			best = _marbles[i]
			best_y = best.global_position.y
	return best

func _find_leader_pos() -> Vector3:
	return _find_leader().global_position
