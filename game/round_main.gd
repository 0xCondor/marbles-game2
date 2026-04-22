extends Node3D

# Round loop scene: runs continuous marble races on a WAITING → BUY_IN →
# RACING → SETTLE cycle. Each round generates a fresh seed, spawns marbles
# from mock buy-ins, records the race, writes the replay, calculates
# payouts, and tears down for the next round.

const MIN_MARBLES := 2
const MAX_MARBLES := 20

var _sm: RoundStateMachine
var _payout: PayoutCalculator

# Per-round state (created at BUY_IN, torn down at next BUY_IN).
var _round_id: int = 0
var _server_seed := PackedByteArray()
var _server_seed_hash := PackedByteArray()
var _client_seeds: Array = []
var _marbles: Array[RigidBody3D] = []
var _finish_line: FinishLine = null
var _recorder: TickRecorder = null
var _camera: LeaderCamera = null

func _ready() -> void:
	SceneHelpers.build_environment(self)
	add_child(RampTrack.new())

	_payout = PayoutCalculator.new()

	_sm = RoundStateMachine.new()
	_sm.buy_in_opened.connect(_on_buy_in_opened)
	_sm.race_started.connect(_on_race_started)
	_sm.race_settled.connect(_on_race_settled)
	add_child(_sm)

func _on_buy_in_opened() -> void:
	_teardown_race()

	_round_id = int(Time.get_unix_time_from_system())
	_server_seed = FairSeed.generate_server_seed()
	_server_seed_hash = FairSeed.hash_server_seed(_server_seed)
	print("COMMIT: round=#%d round_id=%d server_seed_hash=%s" % [
		_sm.get_round_number(), _round_id, FairSeed.to_hex(_server_seed_hash)])

	# Mock buy-ins: random number of players between MIN and MAX.
	var rng := RandomNumberGenerator.new()
	rng.seed = _round_id
	var count := rng.randi_range(MIN_MARBLES, MAX_MARBLES)
	_client_seeds.clear()
	for i in range(count):
		_client_seeds.append("")  # MVP: no per-player seed mixing
	print("BUY_IN: %d marbles registered" % count)

func _on_race_started() -> void:
	var slots := FairSeed.derive_spawn_slots(
		_server_seed, _round_id, _client_seeds, SpawnRail.SLOT_COUNT)
	_marbles = MarbleSpawner.spawn(self, slots)

	_finish_line = FinishLine.new()
	add_child(_finish_line)

	_recorder = TickRecorder.new()
	_recorder.set_round_context(
		_round_id, _server_seed, _server_seed_hash, _client_seeds, slots)
	_recorder.track(_marbles, _finish_line)
	add_child(_recorder)

	_camera = LeaderCamera.new()
	add_child(_camera)
	_camera.setup(_marbles)

	# Watch for race end: the recorder stops recording when the finish line
	# fires or MAX_TICKS is reached. We poll `recording` to detect this.
	set_process(true)

func _process(_delta: float) -> void:
	if _recorder != null and not _recorder.recording and _sm.state == RoundStateMachine.State.RACING:
		_on_recording_done()

func _on_recording_done() -> void:
	var results := {}
	if _finish_line:
		var placements := _finish_line.get_placements()
		var payout_result := _payout.calculate(_client_seeds.size(), placements)
		_payout.print_results(payout_result)
		results = payout_result
	_sm.notify_race_finished(results)

func _on_race_settled(_results: Dictionary) -> void:
	print("ROUND #%d settled. Next round starting soon..." % _sm.get_round_number())

func _teardown_race() -> void:
	for m in _marbles:
		if is_instance_valid(m):
			m.queue_free()
	_marbles.clear()
	if _finish_line and is_instance_valid(_finish_line):
		_finish_line.queue_free()
		_finish_line = null
	if _recorder and is_instance_valid(_recorder):
		_recorder.queue_free()
		_recorder = null
	if _camera and is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null
