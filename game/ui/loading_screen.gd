class_name LoadingScreen
extends CanvasLayer

# Full-screen loading overlay with progress bar and branding.
# Used during scene transitions and initial load.

var _bg: ColorRect
var _progress_bar: ProgressBar
var _status_label: Label
var _title_label: Label

func _ready() -> void:
	layer = 50

	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.05, 0.08, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-200, -60)
	center.size = Vector2(400, 120)
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER

	_title_label = Label.new()
	_title_label.text = "MARBLES"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_title_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(300, 8)
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.16, 0.22)
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.85, 0.3)
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	center.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = "Loading..."
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_status_label)

	add_child(center)

func set_progress(value: float, status: String = "") -> void:
	_progress_bar.value = clampf(value, 0.0, 1.0)
	if not status.is_empty():
		_status_label.text = status

func fade_out(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(_bg, "color:a", 0.0, duration)
	tween.parallel().tween_property(_title_label, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(_progress_bar, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(_status_label, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
