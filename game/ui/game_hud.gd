class_name GameHUD
extends CanvasLayer

# Casino-grade heads-up display. Shows round state, timer, pot, marble count.
# Designed for 1920×1080 base resolution; anchors stretch to fill any viewport.

var _state_label: Label
var _timer_label: Label
var _pot_label: Label
var _marble_count_label: Label
var _top_bar: PanelContainer
var _bottom_info: HBoxContainer

func _ready() -> void:
	layer = 10

	_top_bar = PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.05, 0.06, 0.1, 0.85)
	top_style.corner_radius_bottom_left = 12
	top_style.corner_radius_bottom_right = 12
	top_style.content_margin_left = 24
	top_style.content_margin_right = 24
	top_style.content_margin_top = 10
	top_style.content_margin_bottom = 10
	_top_bar.add_theme_stylebox_override("panel", top_style)
	_top_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_bar.position = Vector2(-200, 0)
	_top_bar.size = Vector2(400, 60)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 32)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_state_label = _make_label("WAITING", 18, Color(0.4, 0.85, 1.0))
	_timer_label = _make_label("00:00", 28, Color.WHITE)
	_pot_label = _make_label("POT: 0.00", 16, Color(1.0, 0.85, 0.3))
	_marble_count_label = _make_label("0/20", 14, Color(0.7, 0.7, 0.7))

	hbox.add_child(_state_label)
	hbox.add_child(_timer_label)
	hbox.add_child(_pot_label)
	hbox.add_child(_marble_count_label)
	_top_bar.add_child(hbox)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_container.size = Vector2(0, 60)
	center_container.add_child(_top_bar)
	add_child(center_container)

func update_state(state_name: String) -> void:
	_state_label.text = state_name
	match state_name:
		"WAITING":
			_state_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		"BUY_IN":
			_state_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		"RACING":
			_state_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		"SETTLE":
			_state_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

func update_timer(seconds: float) -> void:
	if seconds < 0:
		_timer_label.text = "--:--"
	else:
		var mins := int(seconds) / 60
		var secs := int(seconds) % 60
		_timer_label.text = "%02d:%02d" % [mins, secs]

func update_pot(amount: float, currency: String = "USDT") -> void:
	_pot_label.text = "POT: %.2f %s" % [amount, currency]

func update_marble_count(current: int, max_count: int) -> void:
	_marble_count_label.text = "%d/%d" % [current, max_count]

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
