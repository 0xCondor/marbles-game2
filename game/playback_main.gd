extends Node3D

# Local replay playback with full casino UI.

var _hud: GameHUD
var _winner_overlay: WinnerOverlay
var _results_panel: RaceResultsPanel
var _confetti: Confetti
var _camera: CinematicCamera
var _track: Track
var _replay: Dictionary

func _ready() -> void:
	_build_environment()

	var path := _latest_replay_path()
	if path.is_empty():
		push_error("no replays found in user://replays/")
		return
	_replay = ReplayReader.read(path)
	if _replay.is_empty():
		push_error("failed to read replay: %s" % path)
		return
	var track_id := int(_replay.get("track_id", TrackRegistry.RAMP))
	_track = TrackRegistry.instance(track_id)
	add_child(_track)

	_camera = CinematicCamera.new()
	_camera.track = _track
	add_child(_camera)
	_camera.set_mode(CinematicCamera.Mode.OVERVIEW)

	_hud = GameHUD.new()
	add_child(_hud)
	var header: Array = _replay["header"]
	_hud.update_state("REPLAY")
	_hud.update_marble_count(header.size(), 20)
	_hud.update_pot(float(header.size()) * 1.0)

	_results_panel = RaceResultsPanel.new()
	add_child(_results_panel)

	_winner_overlay = WinnerOverlay.new()
	add_child(_winner_overlay)

	_confetti = Confetti.new()
	add_child(_confetti)

	print("PLAYBACK: loaded %s (%d frames, %d marbles, track=%s)" % [path, (_replay["frames"] as Array).size(), header.size(), TrackRegistry.name_of(track_id)])

	var player := PlaybackPlayer.new()
	add_child(player)
	player.playback_finished.connect(_on_playback_finished)
	player.load_replay(_replay)

	await get_tree().create_timer(1.0).timeout
	_camera.set_mode(CinematicCamera.Mode.FOLLOW)

var _race_timer := 0.0
var _timing := true

func _process(delta: float) -> void:
	if _timing:
		_race_timer += delta
		_hud.update_timer(_race_timer)

func _on_playback_finished(last_tick: int, first_marble_pos: Vector3) -> void:
	_timing = false
	_hud.update_state("FINISHED")

	var header: Array = _replay["header"]
	if not header.is_empty():
		var winner_name: String = header[0]["name"]
		var rgba: int = header[0].get("rgba", 0)
		var winner_color := Color(((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, 1.0) if rgba != 0 else Color.WHITE
		var pot := float(header.size()) * 1.0
		var prize := pot * 0.95

		_confetti.shower(first_marble_pos + Vector3(0, 2, 0))
		_winner_overlay.show_winner(winner_name, winner_color, "Won %.2f USDT" % prize)

		var result_data: Array = []
		for i in range(header.size()):
			var r: int = header[i].get("rgba", 0)
			var c := Color(((r >> 24) & 0xFF) / 255.0, ((r >> 16) & 0xFF) / 255.0, ((r >> 8) & 0xFF) / 255.0, 1.0) if r != 0 else Color.WHITE
			result_data.append({"name": header[i]["name"], "color": c, "time": float(last_tick) / 60.0 if i == 0 else 0.0, "payout": prize if i == 0 else 0.0})

		await get_tree().create_timer(2.0).timeout
		_results_panel.show_results(result_data)

	print("PLAYBACK: done at tick=%d" % last_tick)

func _latest_replay_path() -> String:
	var dir := DirAccess.open("user://replays/")
	if dir == null:
		return ""
	var best := ""
	var best_mod := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".bin"):
			continue
		var full := "user://replays/%s" % file_name
		var mod := FileAccess.get_modified_time(full)
		if mod >= best_mod:
			best_mod = mod
			best = full
	return best

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
