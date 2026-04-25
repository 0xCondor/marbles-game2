class_name FairnessPopup
extends CanvasLayer

# Provably fair verification popup. Shows server seed, seed hash, round ID,
# and allows the player to verify the round independently.

var _panel: PanelContainer
var _bg: ColorRect
var _content: VBoxContainer

func _ready() -> void:
	layer = 30
	visible = false

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			hide_popup()
	)
	add_child(_bg)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	style.border_color = Color(0.3, 0.35, 0.5)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "PROVABLY FAIR"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var desc := Label.new()
	desc.text = "Verify this round independently using the data below.\nSHA-256(server_seed) must equal the committed hash."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(desc)

	_panel.add_child(_content)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(_panel)
	add_child(center)

func show_popup(data: Dictionary) -> void:
	# Remove old dynamic rows
	var children := _content.get_children()
	for i in range(2, children.size()):
		children[i].queue_free()

	_add_row("Round ID", str(data.get("round_id", "?")))
	_add_row("Server Seed Hash", str(data.get("seed_hash", "?")))
	_add_row("Server Seed", str(data.get("server_seed", "Revealed after race")))
	_add_row("Marbles", str(data.get("marble_count", "?")))
	_add_row("Winner", str(data.get("winner_name", "?")))

	var verify_label := Label.new()
	verify_label.text = "SHA-256(server_seed) == hash: %s" % ("VERIFIED" if data.get("verified", false) else "PENDING")
	verify_label.add_theme_font_size_override("font_size", 13)
	verify_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if data.get("verified", false) else Color(1.0, 0.85, 0.3))
	verify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(verify_label)

	visible = true

func hide_popup() -> void:
	visible = false

func _add_row(key: String, value: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var k := Label.new()
	k.text = key + ":"
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	k.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(v)
	_content.add_child(hbox)
