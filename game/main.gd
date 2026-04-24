extends Node3D

const MARBLE_COUNT := 20

var _status_path: String = ""
var _round_id: int = 0
var _server_seed: PackedByteArray = PackedByteArray()
var _server_seed_hash: PackedByteArray = PackedByteArray()
var _replay_path: String = ""
var _interactive := false

var _track: Track
var _marbles: Array[RigidBody3D] = []
var _finish_line: FinishLine
var _recorder: TickRecorder
var _colors: Array = []
var _client_seeds: Array = []

# UI (interactive mode only)
var _hud: GameHUD
var _countdown: CountdownDisplay
var _winner_overlay: WinnerOverlay
var _results_panel: RaceResultsPanel
var _history: RoundHistory
var _fairness_popup: FairnessPopup
var _camera: CinematicCamera
var _audio: AudioManager
var _finish_particles: FinishParticles
var _confetti: Confetti

func _ready() -> void:
	_build_environment()

	var spec := _load_spec_from_cli()
	var round_id: int
	var server_seed: PackedByteArray
	var client_seeds: Array
	var client_count: int
	var track_id: int
	if spec.is_empty():
		_interactive = true
		round_id = int(Time.get_unix_time_from_system())
		server_seed = FairSeed.generate_server_seed()
		client_seeds = []
		client_count = MARBLE_COUNT
		for i in range(client_count):
			client_seeds.append("")
		track_id = TrackRegistry.RAMP
	else:
		round_id = int(spec["round_id"])
		server_seed = FairSeed.from_hex(String(spec["server_seed_hex"]))
		client_seeds = spec["client_seeds"]
		client_count = client_seeds.size()
		_status_path = String(spec.get("status_path", ""))
		_replay_path = String(spec.get("replay_path", ""))
		track_id = int(spec.get("track_id", TrackRegistry.RAMP))

	_round_id = round_id
	_server_seed = server_seed
	_server_seed_hash = FairSeed.hash_server_seed(server_seed)
	_client_seeds = client_seeds

	_track = TrackRegistry.instance(track_id)
	add_child(_track)
	var rail := SpawnRail.new(_track)

	print("COMMIT: round_id=%d server_seed_hash=%s" % [round_id, FairSeed.to_hex(_server_seed_hash)])

	var slots := FairSeed.derive_spawn_slots(server_seed, round_id, client_seeds, SpawnRail.SLOT_COUNT)
	_colors = FairSeed.derive_marble_colors(server_seed, round_id, client_seeds)
	_marbles = MarbleSpawner.spawn(self, rail, slots, _colors)

	# Attach trail particles to each marble
	for i in range(_marbles.size()):
		var trail := MarbleTrail.new()
		trail.set_trail_color(_colors[i] if i < _colors.size() else Color.WHITE)
		_marbles[i].add_child(trail)

	_finish_line = FinishLine.new()
	_finish_line.track = _track
	add_child(_finish_line)
	_finish_line.marble_crossed.connect(_on_marble_crossed)
	_finish_line.race_finished.connect(_on_race_finished)

	_recorder = TickRecorder.new()
	_recorder.set_round_context(round_id, server_seed, _server_seed_hash, client_seeds, slots, _colors, track_id)
	if not _replay_path.is_empty():
		_recorder.override_output_path(_replay_path)

	var stream_addr := String(spec.get("live_stream_addr", "")) if not spec.is_empty() else ""
	if not stream_addr.is_empty():
		var colon := stream_addr.find(":")
		if colon > 0:
			var host := stream_addr.substr(0, colon)
			var port := int(stream_addr.substr(colon + 1))
			var streamer := TickStreamer.new()
			if streamer.connect_to(host, port, round_id):
				_recorder.set_streamer(streamer)
				print("STREAM: connected to %s:%d" % [host, port])
			else:
				print("STREAM: connect to %s:%d failed, continuing without live stream" % [host, port])
	_recorder.track(_marbles, _finish_line)
	add_child(_recorder)
	if not _status_path.is_empty():
		_recorder.finalized.connect(_on_finalized.bind(_finish_line))

	if _interactive:
		_setup_interactive(track_id)
	else:
		var cam := FixedCamera.new()
		cam.track = _track
		add_child(cam)

func _setup_interactive(_track_id: int) -> void:
	_audio = AudioManager.new()
	add_child(_audio)

	_camera = CinematicCamera.new()
	_camera.track = _track
	add_child(_camera)
	_camera.setup(_marbles)
	_camera.set_mode(CinematicCamera.Mode.OVERVIEW)

	var finish_pos := _finish_line.global_position
	_camera.set_finish_position(finish_pos)

	_finish_particles = FinishParticles.new()
	add_child(_finish_particles)

	_confetti = Confetti.new()
	add_child(_confetti)

	_hud = GameHUD.new()
	add_child(_hud)
	_hud.update_state("RACING")
	_hud.update_marble_count(_marbles.size(), MARBLE_COUNT)
	_hud.update_pot(float(_marbles.size()) * 1.0)

	_results_panel = RaceResultsPanel.new()
	add_child(_results_panel)

	_winner_overlay = WinnerOverlay.new()
	add_child(_winner_overlay)

	_history = RoundHistory.new()
	add_child(_history)

	_fairness_popup = FairnessPopup.new()
	add_child(_fairness_popup)
	_history.round_clicked.connect(func(data: Dictionary): _fairness_popup.show_popup(data))

	_countdown = CountdownDisplay.new()
	add_child(_countdown)

	# Freeze marbles during countdown
	for m in _marbles:
		m.freeze = true
	_camera.set_mode(CinematicCamera.Mode.OVERVIEW)
	_hud.update_state("COUNTDOWN")
	_audio.play_sfx("countdown_tick")

	_countdown.countdown_finished.connect(_on_countdown_done)
	_countdown.start_countdown(3)

func _on_countdown_done() -> void:
	for m in _marbles:
		m.freeze = false
	_camera.set_mode(CinematicCamera.Mode.FOLLOW)
	_hud.update_state("RACING")
	_audio.play_sfx("race_start")

var _race_timer := 0.0
var _race_active := false

func _process(delta: float) -> void:
	if _interactive and _camera != null and _camera.mode == CinematicCamera.Mode.FOLLOW:
		_race_active = true
	if _race_active:
		_race_timer += delta
		if _hud:
			_hud.update_timer(_race_timer)

func _on_marble_crossed(marble: RigidBody3D, _tick: int) -> void:
	if _interactive and _finish_particles:
		_finish_particles.burst(marble.global_position, marble.get_meta("color", Color.WHITE) if marble.has_meta("color") else Color(1.0, 0.85, 0.3))
		_audio.play_sfx("marble_cross")

func _on_race_finished(winner: RigidBody3D, _tick: int) -> void:
	if not _interactive:
		return
	_race_active = false
	_hud.update_state("FINISHED")
	_audio.play_sfx("winner_fanfare")

	_camera.set_winner(winner)
	_camera.set_mode(CinematicCamera.Mode.WINNER)

	_confetti.shower(winner.global_position)

	var winner_color := winner.get_meta("color", Color.WHITE) if winner.has_meta("color") else Color.WHITE
	var pot := float(_marbles.size()) * 1.0
	var house_edge := 0.05
	var prize := pot * (1.0 - house_edge)
	_winner_overlay.show_winner(winner.name, winner_color, "Won %.2f USDT" % prize)

	# Build results
	var placements := _finish_line.get_placements()
	var crossings := _finish_line.get_crossings()
	var result_data: Array = []
	for i in range(placements.size()):
		var m: RigidBody3D = placements[i]
		var tick_val: int = crossings[m]
		var color := m.get_meta("color", Color.WHITE) if m.has_meta("color") else Color.WHITE
		var entry := {"name": m.name, "color": color, "time": float(tick_val) / 60.0}
		if i == 0:
			entry["payout"] = prize
		result_data.append(entry)
	# Add DNF
	var finished_set := {}
	for m in placements:
		finished_set[m] = true
	for m in _marbles:
		if not finished_set.has(m):
			var color := m.get_meta("color", Color.WHITE) if m.has_meta("color") else Color.GRAY
			result_data.append({"name": m.name, "color": color, "time": 0.0})

	await get_tree().create_timer(2.0).timeout
	_results_panel.show_results(result_data)

	_history.add_round({
		"round_number": _round_id,
		"winner_name": winner.name,
		"winner_color": winner_color,
		"seed_hash": FairSeed.to_hex(_server_seed_hash),
		"round_id": _round_id,
		"server_seed": FairSeed.to_hex(_server_seed),
		"marble_count": _marbles.size(),
		"verified": true,
	})

func _load_spec_from_cli() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var spec_path := ""
	for a in args:
		if a.begins_with("--round-spec="):
			spec_path = a.substr("--round-spec=".length())
			break
	if spec_path.is_empty():
		return {}
	var f := FileAccess.open(spec_path, FileAccess.READ)
	if f == null:
		push_error("could not open round-spec %s (err=%d)" % [spec_path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("round-spec %s is not a JSON object" % spec_path)
		return {}
	return parsed

func _on_finalized(_path: String, finish: FinishLine) -> void:
	var winner := finish.get_winner()
	var winner_idx := -1
	var finish_tick := -1
	if winner != null:
		winner_idx = int(String(winner.name).trim_prefix("Marble_"))
		finish_tick = int(finish.get_crossings().get(winner, -1))
	var status := {
		"round_id": _round_id,
		"ok": winner != null,
		"winner_marble_index": winner_idx,
		"finish_tick": finish_tick,
		"replay_path": _replay_path,
		"server_seed_hash_hex": FairSeed.to_hex(_server_seed_hash),
		"tick_rate_hz": TickRecorder.TICK_RATE_HZ,
	}
	var f := FileAccess.open(_status_path, FileAccess.WRITE)
	if f == null:
		push_error("could not write status %s (err=%d)" % [_status_path, FileAccess.get_open_error()])
	else:
		f.store_string(JSON.stringify(status))
		f.close()
	get_tree().quit(0)

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.8
	light.light_color = Color(1.0, 0.97, 0.92)
	light.shadow_bias = 0.02
	add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.82)
	sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.88)
	sky_mat.ground_bottom_color = Color(0.18, 0.2, 0.25)
	sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.68)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAP_ACES
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.75, 0.85)
	e.fog_density = 0.003
	e.ssao_enabled = true
	e.ssao_radius = 2.0
	e.ssao_intensity = 1.5
	env.environment = e
	add_child(env)
