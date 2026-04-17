class_name LeaderCamera
extends Camera3D

const OFFSET := Vector3(0, 5.0, 8.0)
const SMOOTH_SPEED := 4.0

var _marbles: Array[RigidBody3D] = []
var _target_pos := Vector3.ZERO

func setup(marbles: Array[RigidBody3D]) -> void:
	_marbles = marbles
	current = true
	if not _marbles.is_empty():
		_target_pos = _find_leader_pos()
		global_position = _target_pos + OFFSET
		look_at(_target_pos)

func _process(delta: float) -> void:
	if _marbles.is_empty():
		return
	_target_pos = _find_leader_pos()
	var desired := _target_pos + OFFSET
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	look_at(_target_pos)

func _find_leader_pos() -> Vector3:
	var best: RigidBody3D = _marbles[0]
	var best_z := best.global_position.z
	for i in range(1, _marbles.size()):
		var m := _marbles[i]
		if m.global_position.z < best_z:
			best = m
			best_z = m.global_position.z
	return best.global_position
