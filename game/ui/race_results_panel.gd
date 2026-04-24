class_name RaceResultsPanel
extends CanvasLayer

# Slide-in results panel showing full race standings with marble colors,
# names, finish times, and payouts. Casino-grade presentation.

var _panel: PanelContainer
var _list: VBoxContainer
var _title: Label

func _ready() -> void:
	layer = 15
	visible = false

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.position = Vector2(-320, -250)
	_panel.size = Vector2(300, 500)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	_title = Label.new()
	_title.text = "RACE RESULTS"
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	vbox.add_child(_list)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 420)
	scroll.add_child(vbox)
	_panel.add_child(scroll)
	add_child(_panel)

func show_results(placements: Array) -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in range(placements.size()):
		var entry: Dictionary = placements[i]
		var row := _make_row(i + 1, entry)
		_list.add_child(row)
	visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)

func hide_results() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)

func _make_row(place: int, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var place_label := Label.new()
	place_label.text = "#%d" % place
	place_label.add_theme_font_size_override("font_size", 14)
	var place_color := Color(1.0, 0.85, 0.3) if place == 1 else Color(0.75, 0.75, 0.75) if place == 2 else Color(0.6, 0.45, 0.3) if place == 3 else Color(0.5, 0.5, 0.5)
	place_label.add_theme_color_override("font_color", place_color)
	place_label.custom_minimum_size = Vector2(32, 0)
	row.add_child(place_label)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.color = entry.get("color", Color.WHITE)
	row.add_child(swatch)

	var name_label := Label.new()
	name_label.text = entry.get("name", "?")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var time_label := Label.new()
	var time_s: float = entry.get("time", 0.0)
	time_label.text = "%.2fs" % time_s if time_s > 0 else "DNF"
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	row.add_child(time_label)

	if entry.has("payout") and entry["payout"] > 0:
		var payout_label := Label.new()
		payout_label.text = "+%.2f" % entry["payout"]
		payout_label.add_theme_font_size_override("font_size", 12)
		payout_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		row.add_child(payout_label)

	return row
