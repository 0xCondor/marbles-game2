class_name RoundStateMachine
extends Node

enum State { WAITING, BUY_IN, RACING, SETTLE }

signal state_changed(old_state: State, new_state: State)
signal buy_in_opened()
signal race_started()
signal race_settled(results: Dictionary)

const WAITING_DURATION := 5.0
const BUY_IN_DURATION := 15.0
const SETTLE_DURATION := 8.0

var state: State = State.WAITING
var _timer := 0.0
var _round_number := 0

func _ready() -> void:
	_enter_state(State.WAITING)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		match state:
			State.WAITING:
				_enter_state(State.BUY_IN)
			State.BUY_IN:
				_enter_state(State.RACING)
			State.SETTLE:
				_enter_state(State.WAITING)

func get_time_remaining() -> float:
	return max(0.0, _timer)

func notify_race_finished(results: Dictionary) -> void:
	if state != State.RACING:
		return
	race_settled.emit(results)
	_enter_state(State.SETTLE)

func _enter_state(new_state: State) -> void:
	var old := state
	state = new_state
	match new_state:
		State.WAITING:
			_timer = WAITING_DURATION
			print("ROUND SM: WAITING (%.0fs)" % WAITING_DURATION)
		State.BUY_IN:
			_round_number += 1
			_timer = BUY_IN_DURATION
			print("ROUND SM: BUY_IN round #%d (%.0fs)" % [_round_number, BUY_IN_DURATION])
			buy_in_opened.emit()
		State.RACING:
			_timer = -1.0  # no timer — race ends via notify_race_finished
			print("ROUND SM: RACING round #%d" % _round_number)
			race_started.emit()
		State.SETTLE:
			_timer = SETTLE_DURATION
			print("ROUND SM: SETTLE (%.0fs)" % SETTLE_DURATION)
	state_changed.emit(old, new_state)

func get_round_number() -> int:
	return _round_number

static func state_name(s: State) -> String:
	match s:
		State.WAITING: return "WAITING"
		State.BUY_IN: return "BUY_IN"
		State.RACING: return "RACING"
		State.SETTLE: return "SETTLE"
	return "UNKNOWN"
