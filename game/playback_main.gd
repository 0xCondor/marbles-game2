extends Node3D

func _ready() -> void:
	SceneHelpers.build_environment(self)
	add_child(RampTrack.new())
	add_child(FixedCamera.new())

	var path := SceneHelpers.latest_replay_path()
	if path.is_empty():
		push_error("no replays found in user://replays/")
		return
	var replay := ReplayReader.read(path)
	if replay.is_empty():
		push_error("failed to read replay: %s" % path)
		return
	print("PLAYBACK: loaded %s (%d frames, %d marbles)" % [path, (replay["frames"] as Array).size(), (replay["header"] as Array).size()])

	var player := PlaybackPlayer.new()
	add_child(player)
	player.playback_finished.connect(_on_playback_finished)
	player.load_replay(replay)

func _on_playback_finished(last_tick: int, first_marble_pos: Vector3) -> void:
	print("PLAYBACK: done at tick=%d, first marble pos=%s" % [last_tick, first_marble_pos])
	get_tree().quit()
