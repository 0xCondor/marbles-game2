extends Node3D

const MARBLE_COUNT := 20

func _ready() -> void:
	SceneHelpers.build_environment(self)
	add_child(RampTrack.new())

	var round_id := int(Time.get_unix_time_from_system())
	var server_seed := FairSeed.generate_server_seed()
	var server_seed_hash := FairSeed.hash_server_seed(server_seed)
	var client_seeds: Array = []
	for i in range(MARBLE_COUNT):
		client_seeds.append("")  # MVP: no per-player seed mixing yet

	print("COMMIT: round_id=%d server_seed_hash=%s" % [round_id, FairSeed.to_hex(server_seed_hash)])

	var slots := FairSeed.derive_spawn_slots(server_seed, round_id, client_seeds, SpawnRail.SLOT_COUNT)
	var marbles := MarbleSpawner.spawn(self, slots)

	var finish := FinishLine.new()
	add_child(finish)
	var recorder := TickRecorder.new()
	recorder.set_round_context(round_id, server_seed, server_seed_hash, client_seeds, slots)
	recorder.track(marbles, finish)
	add_child(recorder)
	var cam := LeaderCamera.new()
	add_child(cam)
	cam.setup(marbles)
