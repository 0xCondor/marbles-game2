extends Node3D

# Casino web client: fetches replay from archive API, renders with full UI.

const DESKTOP_DEFAULT_API_BASE := "http://127.0.0.1:8080"

var _api_base: String = _default_api_base()

static func _default_api_base() -> String:
	if OS.has_feature("web"):
		var win := JavaScriptBridge.get_interface("window")
		if win != null:
			return String(win.location.origin)
		return ""
	return DESKTOP_DEFAULT_API_BASE

var _list_req: HTTPRequest
var _bin_req: HTTPRequest
var _player: PlaybackPlayer
var _hud: GameHUD
var _winner_overlay: WinnerOverlay
var _results_panel: RaceResultsPanel
var _history: RoundHistory
var _fairness_popup: FairnessPopup
var _loading: LoadingScreen
var _confetti: Confetti
var _camera: CinematicCamera
var _track: Track
var _replay: Dictionary

func _ready() -> void:
	_build_environment()

	_loading = LoadingScreen.new()
	add_child(_loading)
	_loading.set_progress(0.1, "Connecting to server...")

	_hud = GameHUD.new()
	add_child(_hud)
	_hud.update_state("LOADING")

	_results_panel = RaceResultsPanel.new()
	add_child(_results_panel)

	_winner_overlay = WinnerOverlay.new()
	add_child(_winner_overlay)

	_history = RoundHistory.new()
	add_child(_history)

	_fairness_popup = FairnessPopup.new()
	add_child(_fairness_popup)
	_history.round_clicked.connect(func(data: Dictionary): _fairness_popup.show_popup(data))

	_confetti = Confetti.new()
	add_child(_confetti)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--api-base="):
			_api_base = a.substr("--api-base=".length())

	_list_req = HTTPRequest.new()
	add_child(_list_req)
	_list_req.request_completed.connect(_on_list_response)

	_bin_req = HTTPRequest.new()
	add_child(_bin_req)
	_bin_req.request_completed.connect(_on_bin_response)

	_player = PlaybackPlayer.new()
	add_child(_player)
	_player.playback_finished.connect(_on_playback_finished)

	print("WEB_CLIENT: fetching round list from %s/rounds" % _api_base)
	var err := _list_req.request(_api_base + "/rounds")
	if err != OK:
		push_error("list request failed to start: %d" % err)

func _on_list_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("list fetch failed: result=%d code=%d" % [result, code])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("round_ids"):
		push_error("list response invalid")
		return
	var ids: Array = parsed["round_ids"]
	if ids.is_empty():
		push_error("no rounds in archive")
		return
	_loading.set_progress(0.4, "Loading replay...")
	var latest: String = String(ids[ids.size() - 1])
	print("WEB_CLIENT: latest round=%s, fetching replay" % latest)
	var err := _bin_req.request("%s/rounds/%s/replay.bin" % [_api_base, latest])
	if err != OK:
		push_error("replay request failed to start: %d" % err)

func _on_bin_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("replay fetch failed: result=%d code=%d" % [result, code])
		return
	_loading.set_progress(0.7, "Building scene...")
	_replay = ReplayReader.read_bytes(body)
	if _replay.is_empty():
		push_error("replay parse failed (%d bytes)" % body.size())
		return
	var track_id := int(_replay.get("track_id", TrackRegistry.RAMP))
	_track = TrackRegistry.instance(track_id)
	add_child(_track)

	_camera = CinematicCamera.new()
	_camera.track = _track
	add_child(_camera)
	_camera.set_mode(CinematicCamera.Mode.OVERVIEW)

	var header: Array = _replay["header"]
	_hud.update_state("PLAYING")
	_hud.update_marble_count(header.size(), 20)
	_hud.update_pot(float(header.size()) * 1.0)

	_loading.set_progress(1.0, "Starting race...")
	_loading.fade_out(0.5)

	print("WEB_CLIENT: playing %d frames for %d marbles (track=%s)" % [(_replay["frames"] as Array).size(), header.size(), TrackRegistry.name_of(track_id)])
	_player.load_replay(_replay)

	# Switch to follow mode after a short overview
	await get_tree().create_timer(1.5).timeout
	_camera.set_mode(CinematicCamera.Mode.FOLLOW)

func _on_playback_finished(last_tick: int, _first_marble_pos: Vector3) -> void:
	_hud.update_state("FINISHED")
	print("WEB_CLIENT: done at tick=%d" % last_tick)

	# Show winner from replay header/frames
	var header: Array = _replay["header"]
	if not header.is_empty():
		var winner_name: String = header[0]["name"]
		var winner_rgba: int = header[0].get("rgba", 0)
		var winner_color := Color(((winner_rgba >> 24) & 0xFF) / 255.0, ((winner_rgba >> 16) & 0xFF) / 255.0, ((winner_rgba >> 8) & 0xFF) / 255.0, 1.0) if winner_rgba != 0 else Color.WHITE
		var pot := float(header.size()) * 1.0
		var prize := pot * 0.95

		_confetti.shower(_first_marble_pos + Vector3(0, 2, 0))
		_winner_overlay.show_winner(winner_name, winner_color, "Won %.2f USDT" % prize)

		var result_data: Array = []
		var frames: Array = _replay["frames"]
		for i in range(header.size()):
			var rgba: int = header[i].get("rgba", 0)
			var c := Color(((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, 1.0) if rgba != 0 else Color.WHITE
			result_data.append({"name": header[i]["name"], "color": c, "time": float(last_tick) / 60.0 if i == 0 else 0.0, "payout": prize if i == 0 else 0.0})
		_results_panel.show_results(result_data)

		var round_id = _replay.get("round_id", 0)
		_history.add_round({
			"round_number": round_id,
			"winner_name": winner_name,
			"winner_color": winner_color,
			"seed_hash": FairSeed.to_hex(_replay.get("server_seed_hash", PackedByteArray())),
			"round_id": round_id,
			"server_seed": FairSeed.to_hex(_replay.get("server_seed", PackedByteArray())),
			"marble_count": header.size(),
			"verified": true,
		})

	await get_tree().create_timer(8.0).timeout
	get_tree().quit(0)

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.8
	light.light_color = Color(1.0, 0.97, 0.92)
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
	env.environment = e
	add_child(env)
