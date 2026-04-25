class_name CountdownDisplay
extends CanvasLayer

# Full-screen countdown: 3... 2... 1... GO! with scale + fade animation.

signal countdown_finished()

var _label: Label
var _bg: ColorRect

func _ready() -> void:
	layer = 25
	visible = false

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.3)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 120)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

func start_countdown(from: int = 3) -> void:
	visible = true
	for i in range(from, 0, -1):
		await _show_number(str(i), Color(1.0, 0.4, 0.3) if i == 1 else Color(1.0, 0.85, 0.3) if i == 2 else Color.WHITE)
	await _show_number("GO!", Color(0.3, 1.0, 0.4))
	visible = false
	countdown_finished.emit()

func _show_number(text: String, color: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.scale = Vector2(2.0, 2.0)
	_label.pivot_offset = _label.size * 0.5
	_label.modulate.a = 1.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.3)
	tween.tween_interval(0.4)
	tween.tween_property(_label, "modulate:a", 0.0, 0.2)
	await tween.finished
