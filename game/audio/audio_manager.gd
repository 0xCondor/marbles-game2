class_name AudioManager
extends Node

# Centralized audio bus. Plays sound effects and music via named channels.
# Audio files are loaded from res://audio/sfx/ and res://audio/music/.
# If a file is missing the call is silently skipped — this lets the game
# run without audio assets during development.
#
# Usage from any scene:
#   AudioManager.instance.play_sfx("countdown_tick")
#   AudioManager.instance.play_music("race_ambient")
#   AudioManager.instance.stop_music()

static var instance: AudioManager

const SFX_PATH := "res://audio/sfx/"
const MUSIC_PATH := "res://audio/music/"

var _sfx_players: Dictionary = {}  # name → AudioStreamPlayer
var _music_player: AudioStreamPlayer

# Known SFX names — add audio files with these names to res://audio/sfx/
# Supported formats: .ogg, .wav, .mp3
const SFX_NAMES := [
	"countdown_tick",    # 3-2-1 beep
	"countdown_go",      # GO! horn
	"race_start",        # race begins
	"marble_roll",       # looping roll (pitch-shifted by speed)
	"marble_impact",     # marble-wall or marble-marble collision
	"marble_cross",      # marble crosses finish
	"winner_fanfare",    # winner announcement
	"bet_placed",        # bet confirmed
	"button_click",      # generic UI click
	"round_end",         # round settled
]

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_music_player.volume_db = -6.0
	add_child(_music_player)

	for sfx_name in SFX_NAMES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(player)
		_sfx_players[sfx_name] = player

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sfx_players.has(sfx_name):
		return
	var player: AudioStreamPlayer = _sfx_players[sfx_name]
	var stream := _load_audio(SFX_PATH + sfx_name)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_music(track_name: String, volume_db: float = -6.0) -> void:
	var stream := _load_audio(MUSIC_PATH + track_name)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music(fade_seconds: float = 1.0) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_seconds)
	tween.tween_callback(_music_player.stop)

func stop_sfx(sfx_name: String) -> void:
	if _sfx_players.has(sfx_name):
		(_sfx_players[sfx_name] as AudioStreamPlayer).stop()

func _load_audio(base_path: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var path := base_path + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
