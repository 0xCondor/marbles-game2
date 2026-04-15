class_name ReplayWriter
extends RefCounted

# Binary replay format v2 per docs/tick-schema.md + fairness.md.
# v2 adds the fairness block (server_seed, hash, per-marble slot + client_seed).
# v0 raw f32 for pos + quat; quantization deferred to M2.5.
#
# Input is the flat recorder format (ticks/flags/states as Packed*Arrays).
# We stream directly to FileAccess via a small fixed-size StreamPeerBuffer,
# so memory use is O(marble_count) not O(total_frames * marble_count).

const PROTOCOL_VERSION := 2
const FLOATS_PER_MARBLE := 7

static func write(path: String, replay: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()

	# Header (one-shot via StreamPeerBuffer so we can reuse the little-endian
	# put_* helpers — dumped in one store_buffer call).
	var hdr := StreamPeerBuffer.new()
	hdr.big_endian = false
	hdr.put_u8(PROTOCOL_VERSION)
	hdr.put_u64(int(replay["round_id"]))
	hdr.put_u32(int(replay["tick_rate_hz"]))

	var server_seed: PackedByteArray = replay["server_seed"]
	hdr.put_u8(server_seed.size())
	hdr.put_data(server_seed)
	var server_seed_hash: PackedByteArray = replay["server_seed_hash"]
	hdr.put_u8(server_seed_hash.size())
	hdr.put_data(server_seed_hash)
	hdr.put_u32(int(replay["slot_count"]))

	var header: Array = replay["header"]
	hdr.put_u32(header.size())
	for m in header:
		hdr.put_u32(int(m["id"]) & 0xFFFFFFFF)
		hdr.put_u32(0)  # rgba — still stubbed, see PROGRESS.md open question
		var name_bytes: PackedByteArray = String(m["name"]).to_utf8_buffer()
		hdr.put_u8(name_bytes.size())
		hdr.put_data(name_bytes)
		var cseed_bytes: PackedByteArray = String(m.get("client_seed", "")).to_utf8_buffer()
		hdr.put_u8(cseed_bytes.size())
		hdr.put_data(cseed_bytes)
		hdr.put_u32(int(m.get("slot", 0)))
	f.store_buffer(hdr.data_array)

	# Frame body: stream per-frame to avoid holding the whole replay in RAM.
	var frame_count: int = int(replay["frame_count"])
	var marble_count: int = int(replay["marble_count"])
	var ticks: PackedInt32Array = replay["ticks"]
	var flags: PackedByteArray = replay["flags"]
	var states: PackedFloat32Array = replay["states"]
	var floats_per_frame := marble_count * FLOATS_PER_MARBLE

	var frame_hdr := StreamPeerBuffer.new()
	frame_hdr.big_endian = false
	frame_hdr.put_u32(frame_count)
	f.store_buffer(frame_hdr.data_array)

	# Per-frame: u32 tick + u8 flags + floats_per_frame × f32. Build a reusable
	# buffer of exactly that size to keep allocator pressure flat.
	var per_frame_bytes := 4 + 1 + floats_per_frame * 4
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.resize(per_frame_bytes)
	for i in range(frame_count):
		buf.seek(0)
		buf.put_u32(int(ticks[i]))
		buf.put_u8(int(flags[i]) & 0xFF)
		var base := i * floats_per_frame
		for j in range(floats_per_frame):
			buf.put_float(states[base + j])
		f.store_buffer(buf.data_array)

	f.close()
	return OK
