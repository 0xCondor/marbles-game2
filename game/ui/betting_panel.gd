class_name BettingPanel
extends CanvasLayer

# Left-side betting panel: marble selection grid, bet amount, place bet button.
# In MVP/demo mode all bets are mock (no real wallet). The panel emits signals
# that a real integration layer would connect to the server API.

signal bet_placed(marble_index: int, amount: float)
signal bet_cancelled()

var _panel: PanelContainer
var _marble_grid: GridContainer
var _bet_input: SpinBox
var _place_btn: Button
var _balance_label: Label
var _selected_marble: int = -1
var _marble_buttons: Array[Button] = []
var _locked := false

func _ready() -> void:
	layer = 10
	visible = false

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.92)
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.position = Vector2(0, -220)
	_panel.size = Vector2(240, 440)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "PLACE YOUR BET"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_balance_label = Label.new()
	_balance_label.text = "Balance: 1000.00 USDT"
	_balance_label.add_theme_font_size_override("font_size", 12)
	_balance_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_balance_label)

	var grid_label := Label.new()
	grid_label.text = "Select marble:"
	grid_label.add_theme_font_size_override("font_size", 11)
	grid_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(grid_label)

	_marble_grid = GridContainer.new()
	_marble_grid.columns = 5
	_marble_grid.add_theme_constant_override("h_separation", 4)
	_marble_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_marble_grid)

	var amount_label := Label.new()
	amount_label.text = "Bet amount:"
	amount_label.add_theme_font_size_override("font_size", 11)
	amount_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(amount_label)

	_bet_input = SpinBox.new()
	_bet_input.min_value = 0.1
	_bet_input.max_value = 1000.0
	_bet_input.step = 0.1
	_bet_input.value = 1.0
	_bet_input.suffix = " USDT"
	vbox.add_child(_bet_input)

	_place_btn = Button.new()
	_place_btn.text = "PLACE BET"
	_place_btn.disabled = true
	_place_btn.custom_minimum_size = Vector2(0, 40)
	_place_btn.pressed.connect(_on_place_pressed)
	vbox.add_child(_place_btn)

	_panel.add_child(vbox)
	add_child(_panel)

func show_panel(marble_colors: Array) -> void:
	_selected_marble = -1
	_locked = false
	_place_btn.disabled = true
	_place_btn.text = "PLACE BET"
	_marble_buttons.clear()
	for c in _marble_grid.get_children():
		c.queue_free()
	for i in range(marble_colors.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = marble_colors[i]
		style_normal.corner_radius_bottom_left = 6
		style_normal.corner_radius_bottom_right = 6
		style_normal.corner_radius_top_left = 6
		style_normal.corner_radius_top_right = 6
		btn.add_theme_stylebox_override("normal", style_normal)
		var style_hover := style_normal.duplicate()
		style_hover.border_color = Color.WHITE
		style_hover.border_width_bottom = 2
		style_hover.border_width_top = 2
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.tooltip_text = "Marble #%d" % i
		btn.pressed.connect(_on_marble_selected.bind(i))
		_marble_grid.add_child(btn)
		_marble_buttons.append(btn)
	visible = true

func lock_bets() -> void:
	_locked = true
	_place_btn.disabled = true
	_place_btn.text = "BETS LOCKED"

func hide_panel() -> void:
	visible = false

func update_balance(amount: float, currency: String = "USDT") -> void:
	_balance_label.text = "Balance: %.2f %s" % [amount, currency]

func _on_marble_selected(index: int) -> void:
	if _locked:
		return
	_selected_marble = index
	_place_btn.disabled = false
	for i in range(_marble_buttons.size()):
		var btn := _marble_buttons[i]
		var is_selected := i == index
		var style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if is_selected:
			style.border_color = Color(1.0, 0.85, 0.3)
			style.border_width_bottom = 3
			style.border_width_top = 3
			style.border_width_left = 3
			style.border_width_right = 3
		btn.add_theme_stylebox_override("normal", style)

func _on_place_pressed() -> void:
	if _selected_marble < 0 or _locked:
		return
	bet_placed.emit(_selected_marble, _bet_input.value)
	_place_btn.text = "BET PLACED ✓"
	_place_btn.disabled = true
