extends Node3D

# Live casino client: subscribes to active round via WebSocket,
# renders frame-by-frame with full casino UI.

const DESKTOP_DEFAULT_API_BASE := "http://127.0.0.1:8087"
const LIVE_POLL_INTERVAL_SEC := 0.5
const LIVE_POLL_TIMEOUT_SEC := 30.0

var _api_base: String = _default_api_base()

static func _default_api_base() -> String:
	if OS.has_feature("web"):
		var win := JavaScriptBridge.get_interface("window")
		if win != null:
			return String(win.location.origin)
		return ""
	return DESKTOP_DEFAULT_API_BASE

var _list_req: HTTPRequest
var _player: PlaybackPlayer
var _client: LiveStreamClient
var _poll_deadline_ms: int = 0

var _hud: GameHUD
var _winner_overlay: WinnerOverlay
var _results_panel: RaceResultsPanel
var _history: RoundHistory
var _fairness_popup: FairnessPopup
var _betting_panel: BettingPanel
var _loading: LoadingScreen
var _countdown: CountdownDisplay
var _confetti: Confetti
var _camera: CinematicCamera
var _audio: AudioManager
var _track: Track
var _header_data: Dictionary
var _race_timer := 0.0
var _racing := false

func _ready() -> void:
	_build_environment()

	_audio = AudioManager.new()
	add_child(_audio)

	_loading = LoadingScreen.new()
	add_child(_loading)
	_loading.set_progress(0.1, "Looking for live race...")

	_hud = GameHUD.new()
	add_child(_hud)
	_hud.update_state("CONNECTING")

	_results_panel = RaceResultsPanel.new()
	add_child(_results_panel)

	_winner_overlay = WinnerOverlay.new()
	add_child(_winner_overlay)

	_history = RoundHistory.new()
	add_child(_history)

	_fairness_popup = FairnessPopup.new()
	add_child(_fairness_popup)
	_history.round_clicked.connect(func(data: Dictionary): _fairness_popup.show_popup(data))

	_betting_panel = BettingPanel.new()
	add_child(_betting_panel)
	_betting_panel.bet_placed.connect(_on_bet_placed)

	_countdown = CountdownDisplay.new()
	add_child(_countdown)

	_confetti = Confetti.new()
	add_child(_confetti)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--api-base="):
			_api_base = a.substr("--api-base=".length())

	_list_req = HTTPRequest.new()
	add_child(_list_req)
	_list_req.request_completed.connect(_on_list_response)

	_player = PlaybackPlayer.new()
	add_child(_player)
	_player.playback_finished.connect(_on_playback_finished)

	_poll_deadline_ms = Time.get_ticks_msec() + int(LIVE_POLL_TIMEOUT_SEC * 1000.0)
	_request_live_list()

func _process(delta: float) -> void:
	if _racing:
		_race_timer += delta
		_hud.update_timer(_race_timer)

func _request_live_list() -> void:
	var err := _list_req.request(_api_base + "/live")
	if err != OK:
		push_error("live list request failed: %d" % err)

func _on_list_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("live list fetch failed: result=%d code=%d" % [result, code])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("round_ids"):
		return
	var ids: Array = parsed["round_ids"]
	if ids.is_empty():
		if Time.get_ticks_msec() > _poll_deadline_ms:
			push_error("no active rounds after %d s" % int(LIVE_POLL_TIMEOUT_SEC))
			_hud.update_state("NO RACE")
			_loading.set_progress(1.0, "Waiting for next race...")
			_loading.fade_out(1.0)
			return
		_loading.set_progress(0.2, "Waiting for race...")
		await get_tree().create_timer(LIVE_POLL_INTERVAL_SEC).timeout
		_request_live_list()
		return
	var newest := String(ids[0])
	for id in ids:
		if int(id) > int(newest):
			newest = String(id)
	_loading.set_progress(0.5, "Joining race...")
	_subscribe(newest)

func _subscribe(round_id: String) -> void:
	var ws_base := _api_base
	if ws_base.begins_with("https://"):
		ws_base = "wss://" + ws_base.substr("https://".length())
	elif ws_base.begins_with("http://"):
		ws_base = "ws://" + ws_base.substr("http://".length())
	var url := "%s/live/%s" % [ws_base, round_id]

	_client = LiveStreamClient.new()
	add_child(_client)
	_client.header_received.connect(_on_header)
	_client.tick_received.connect(_on_tick)
	_client.done_received.connect(_on_done)
	_client.connection_failed.connect(_on_ws_failed)
	_client.closed.connect(_on_ws_closed)
	var err := _client.connect_to_url(url)
	if err != OK:
		push_error("ws connect failed: %d" % err)

func _on_header(header: Dictionary) -> void:
	_header_data = header
	var marbles: int = (header["header"] as Array).size()
	var track_id := int(header.get("track_id", TrackRegistry.RAMP))
	_track = TrackRegistry.instance(track_id)
	add_child(_track)

	_camera = CinematicCamera.new()
	_camera.track = _track
	add_child(_camera)
	_camera.set_mode(CinematicCamera.Mode.OVERVIEW)

	_hud.update_state("LIVE")
	_hud.update_marble_count(marbles, 20)
	_hud.update_pot(float(marbles) * 1.0)

	# Show betting panel with marble colors
	var marble_colors: Array = []
	for m in header["header"]:
		var rgba: int = m.get("rgba", 0)
		if rgba != 0:
			marble_colors.append(Color(((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, 1.0))
		else:
			marble_colors.append(Color.WHITE)
	_betting_panel.show_panel(marble_colors)

	_loading.set_progress(1.0, "Race starting!")
	_loading.fade_out(0.3)

	_player.begin_stream(header)

	# Short countdown then switch to follow
	_audio.play_sfx("countdown_tick")
	_countdown.countdown_finished.connect(func():
		_racing = true
		_camera.set_mode(CinematicCamera.Mode.FOLLOW)
		_betting_panel.lock_bets()
		_hud.update_state("RACING")
		_audio.play_sfx("race_start")
	)
	_countdown.start_countdown(3)

var _tick_count: int = 0

func _on_tick(frame: Dictionary) -> void:
	_player.append_frame(frame)
	_tick_count += 1

func _on_done() -> void:
	_racing = false
	_player.end_stream()

func _on_bet_placed(marble_index: int, amount: float) -> void:
	print("BET: marble #%d for %.2f" % [marble_index, amount])
	_audio.play_sfx("bet_placed")

func _on_ws_failed(reason: String) -> void:
	push_error("live ws failed: %s" % reason)
	_hud.update_state("DISCONNECTED")

func _on_ws_closed() -> void:
	_player.end_stream()

func _on_playback_finished(last_tick: int, _first_marble_pos: Vector3) -> void:
	_racing = false
	_hud.update_state("FINISHED")
	_audio.play_sfx("winner_fanfare")

	if not _header_data.is_empty():
		var header: Array = _header_data["header"]
		if not header.is_empty():
			var winner_name: String = header[0]["name"]
			var rgba: int = header[0].get("rgba", 0)
			var winner_color := Color(((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, 1.0) if rgba != 0 else Color.WHITE
			var pot := float(header.size()) * 1.0
			var prize := pot * 0.95

			_confetti.shower(_first_marble_pos + Vector3(0, 2, 0))
			_camera.set_mode(CinematicCamera.Mode.WINNER)
			_winner_overlay.show_winner(winner_name, winner_color, "Won %.2f USDT" % prize)

			var result_data: Array = []
			for i in range(header.size()):
				var r: int = header[i].get("rgba", 0)
				var c := Color(((r >> 24) & 0xFF) / 255.0, ((r >> 16) & 0xFF) / 255.0, ((r >> 8) & 0xFF) / 255.0, 1.0) if r != 0 else Color.WHITE
				result_data.append({"name": header[i]["name"], "color": c, "time": float(last_tick) / 60.0 if i == 0 else 0.0, "payout": prize if i == 0 else 0.0})

			await get_tree().create_timer(2.0).timeout
			_results_panel.show_results(result_data)
			_betting_panel.hide_panel()

			_history.add_round({
				"round_number": _header_data.get("round_id", 0),
				"winner_name": winner_name,
				"winner_color": winner_color,
				"seed_hash": FairSeed.to_hex(_header_data.get("server_seed_hash", PackedByteArray())),
				"round_id": _header_data.get("round_id", 0),
				"marble_count": header.size(),
				"verified": false,
			})

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
