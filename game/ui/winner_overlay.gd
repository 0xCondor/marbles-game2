class_name WinnerOverlay
extends CanvasLayer

# Full-screen winner announcement with animated entrance.

var _panel: PanelContainer
var _winner_label: Label
var _payout_label: Label
var _marble_swatch: ColorRect
var _container: VBoxContainer
var _bg: ColorRect

signal dismissed()

func _ready() -> void:
	layer = 20
	visible = false

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.6)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.95)
	style.border_color = Color(1.0, 0.85, 0.3, 0.8)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	_panel.add_theme_stylebox_override("panel", style)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 16)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "WINNER!"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)

	var marble_row := HBoxContainer.new()
	marble_row.alignment = BoxContainer.ALIGNMENT_CENTER
	marble_row.add_theme_constant_override("separation", 12)

	_marble_swatch = ColorRect.new()
	_marble_swatch.custom_minimum_size = Vector2(24, 24)
	marble_row.add_child(_marble_swatch)

	_winner_label = Label.new()
	_winner_label.add_theme_font_size_override("font_size", 28)
	_winner_label.add_theme_color_override("font_color", Color.WHITE)
	marble_row.add_child(_winner_label)
	_container.add_child(marble_row)

	_payout_label = Label.new()
	_payout_label.add_theme_font_size_override("font_size", 20)
	_payout_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_payout_label)

	_panel.add_child(_container)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(_panel)
	add_child(center)

func show_winner(marble_name: String, marble_color: Color, payout_text: String) -> void:
	_winner_label.text = marble_name
	_marble_swatch.color = marble_color
	_payout_label.text = payout_text
	visible = true
	_panel.scale = Vector2(0.5, 0.5)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.4)

func hide_winner() -> void:
	var tween := create_tween()
	tween.tween_property(_bg, "color:a", 0.0, 0.3)
	tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		_bg.color.a = 0.6
		_panel.modulate.a = 1.0
		dismissed.emit()
	)
