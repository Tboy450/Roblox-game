extends CanvasLayer
signal resume_requested
signal save_requested
signal load_requested
signal quit_requested
signal settings_changed
const Settings = preload("res://scripts/player_settings.gd")
var preferences = Settings.new()
var panel: PanelContainer
var veil: ColorRect
var status: Label
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var buttons: Dictionary = {}
var guide_toggle: CheckButton
var main_page: VBoxContainer
var controls_page: VBoxContainer
var binding_buttons: Dictionary = {}
var bind_status: Label
var capture_action := ""

func _ready() -> void:
	layer = 10
	veil = ColorRect.new()
	veil.color = Color(0.015, 0.035, 0.03, 0.83)
	add_child(veil)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 440
	var style = StyleBoxFlat.new()
	style.bg_color = Color("142b23")
	style.set_content_margin_all(18)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	main_page = VBoxContainer.new()
	main_page.add_theme_constant_override("separation", 8)
	panel.add_child(main_page)
	var column = main_page
	_text(column, "PAUSED / CORNERFIELD", 24)
	_text(column, "Store time and movement are stopped.", 15)
	for key in ["sensitivity", "move_speed", "ui_scale"]:
		value_labels[key] = _text(column, "", 16)
		var slider = HSlider.new()
		slider.min_value = Settings.LIMITS[key].x
		slider.max_value = Settings.LIMITS[key].y
		slider.step = {"sensitivity": 0.0001, "move_speed": 0.1, "ui_scale": 0.05}[key]
		slider.value = preferences.values[key]
		slider.custom_minimum_size.y = 20
		slider.value_changed.connect(_changed.bind(key))
		column.add_child(slider)
		sliders[key] = slider
	guide_toggle = CheckButton.new()
	guide_toggle.button_pressed = preferences.values.guide_enabled
	guide_toggle.toggled.connect(_guide_toggled)
	column.add_child(guide_toggle)
	for entry in [["Key bindings", show_controls.bind(true)], ["Resume", resume_requested.emit], ["Save progress", save_requested.emit],
			["Load progress", load_requested.emit], ["Save and quit", quit_requested.emit]]:
		var button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 32
		button.pressed.connect(entry[1])
		column.add_child(button)
		buttons[entry[0]] = button
	status = _text(column, "Esc resumes. Tab / arrows also adjust controls.", 14)
	_build_controls()
	_update_labels()
	hide()
	panel.hide()
	veil.hide()

func _build_controls() -> void:
	controls_page = VBoxContainer.new()
	controls_page.add_theme_constant_override("separation", 8)
	panel.add_child(controls_page)
	_text(controls_page, "CONTROLS / KEY BINDINGS", 24)
	_text(controls_page, "Choose an action, then press its new key. A key already in use\nswaps places. Esc cancels; Esc, Tab and F2 stay fixed.", 14)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	controls_page.add_child(grid)
	for action in Settings.ACTIONS:
		var label = _text(grid, Settings.ACTIONS[action][0], 15)
		label.custom_minimum_size.x = 150
		var button = Button.new()
		button.custom_minimum_size = Vector2(100, 28)
		button.pressed.connect(begin_capture.bind(action))
		grid.add_child(button)
		binding_buttons[action] = button
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	controls_page.add_child(row)
	for entry in [["Reset defaults", _reset_bindings], ["Back", show_controls.bind(false)]]:
		var button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(150, 32)
		button.pressed.connect(entry[1])
		row.add_child(button)
		buttons[entry[0]] = button
	bind_status = _text(controls_page, "", 14)
	controls_page.hide()

func _text(parent: Node, text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e4ce"))
	parent.add_child(label)
	return label

func _changed(value: float, key: String) -> void:
	if preferences.set_value(key, value):
		_update_labels()
		settings_changed.emit()

func _guide_toggled(enabled: bool) -> void:
	preferences.set_value("guide_enabled", enabled)
	settings_changed.emit()

func _update_labels() -> void:
	value_labels.sensitivity.text = "Mouse sensitivity   %.1f×" % (float(preferences.values.sensitivity) / 0.002)
	value_labels.move_speed.text = "Movement speed   %.1f m/s" % preferences.values.move_speed
	value_labels.ui_scale.text = "UI scale   %d%%" % roundi(float(preferences.values.ui_scale) * 100)
	guide_toggle.text = "Show first-day guide (%s)" % preferences.key_label("toggle_guide")
	for action in binding_buttons:
		binding_buttons[action].text = "Press a key…" if action == capture_action else preferences.key_label(action)

func show_controls(open: bool) -> void:
	capture_action = ""
	main_page.visible = not open
	controls_page.visible = open
	bind_status.text = ""
	_update_labels()
	panel.reset_size()
	if visible:
		(binding_buttons.move_forward if open else buttons["Key bindings"]).grab_focus()

func begin_capture(action: String) -> void:
	capture_action = action
	bind_status.text = "Press a key for %s. Esc cancels." % Settings.ACTIONS[action][0]
	_update_labels()

## Receives the next key press while capturing; the store routes it here first.
func capture_key(event: InputEventKey) -> void:
	var action = capture_action
	var code = Settings.event_code(event)
	if code == KEY_ESCAPE:
		bind_status.text = "%s unchanged." % Settings.ACTIONS[action][0]
	elif not Settings.valid_key(code):
		bind_status.text = "%s is fixed or unsupported. Choose another key; Esc cancels." % Settings.key_name(code)
		return
	else:
		var displaced = preferences.action_for_key(code)
		preferences.bind(action, code)
		bind_status.text = "%s: %s" % [Settings.ACTIONS[action][0], preferences.key_label(action)]
		if not displaced.is_empty() and displaced != action:
			bind_status.text += "   ·   %s moved to %s" % [Settings.ACTIONS[displaced][0], preferences.key_label(displaced)]
		settings_changed.emit()
	capture_action = ""
	_update_labels()
	binding_buttons[action].grab_focus()

func _reset_bindings() -> void:
	capture_action = ""
	preferences.reset_bindings()
	_update_labels()
	bind_status.text = "Default keys restored."
	settings_changed.emit()

func layout(viewport_size: Vector2, ui_scale: float) -> void:
	scale = Vector2.ONE * ui_scale
	veil.size = viewport_size / ui_scale
	panel.position = (viewport_size / ui_scale - panel.size) / 2
