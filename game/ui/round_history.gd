class_name RoundHistory
extends CanvasLayer

# Bottom-bar showing last N round results as compact colored chips.
# Each chip shows the winner marble color + round number. Clicking opens
# the provably fair verification popup for that round.

const MAX_VISIBLE := 10

signal round_clicked(round_data: Dictionary)

var _bar: HBoxContainer
var _panel: PanelContainer
var _rounds: Array = []  # [{round_number, winner_name, winner_color, seed_hash}]

func _ready() -> void:
	layer = 10

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "RECENT ROUNDS"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_bar)

	_panel.add_child(vbox)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.position = Vector2(-250, -50)
	_panel.size = Vector2(500, 50)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.add_child(_panel)
	add_child(anchor)

func add_round(data: Dictionary) -> void:
	_rounds.append(data)
	if _rounds.size() > MAX_VISIBLE:
		_rounds.pop_front()
	_rebuild()

func _rebuild() -> void:
	for c in _bar.get_children():
		c.queue_free()
	for i in range(_rounds.size()):
		var data: Dictionary = _rounds[i]
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(40, 28)
		chip.tooltip_text = "Round #%s — %s" % [data.get("round_number", "?"), data.get("winner_name", "?")]
		var style := StyleBoxFlat.new()
		style.bg_color = data.get("winner_color", Color.GRAY)
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		chip.add_theme_stylebox_override("normal", style)
		chip.text = "#%s" % str(data.get("round_number", "?"))
		chip.add_theme_font_size_override("font_size", 9)
		chip.add_theme_color_override("font_color", Color.WHITE)
		chip.pressed.connect(func(): round_clicked.emit(data))
		_bar.add_child(chip)
