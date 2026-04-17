class_name SceneHelpers
extends RefCounted

static func build_environment(parent: Node) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	parent.add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	parent.add_child(env)

static func latest_replay_path() -> String:
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
