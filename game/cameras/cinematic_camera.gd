class_name CinematicCamera
extends Camera3D

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
var _bounds: AABB

func setup(marbles: Array[RigidBody3D]) -> void:
	_marbles = marbles
	current = true
	if track != null:
		_bounds = track.camera_bounds()
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
	var center := _bounds.get_center()
	var extent := max(_bounds.size.x, _bounds.size.z) * 0.6
	global_position = center + Vector3(extent * 0.5, extent * 0.7, extent * 0.8)
	look_at(center)

func _update_overview(delta: float) -> void:
	if track == null:
		return
	var center := _bounds.get_center()
	var extent := max(_bounds.size.x, _bounds.size.z) * 0.6
	var desired := center + Vector3(extent * 0.5, extent * 0.7, extent * 0.8)
	global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
	look_at(global_position + (center - global_position).normalized())

func _update_follow(delta: float) -> void:
	if _marbles.is_empty():
		return
	var leader := _find_leader()
	var leader_pos := leader.global_position
	var vel := leader.linear_velocity.normalized() if leader.linear_velocity.length() > 0.5 else Vector3(0, 0, -1)
	var behind := -vel * FOLLOW_BEHIND
	behind.y = FOLLOW_HEIGHT
	var desired := leader_pos + behind
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
	var best_y := best.global_position.y
	for i in range(1, _marbles.size()):
		if _marbles[i].global_position.y < best_y:
			best = _marbles[i]
			best_y = best.global_position.y
	return best
