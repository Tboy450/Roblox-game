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
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
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
	guide_toggle.text = "Show first-day guide (H)"
	guide_toggle.button_pressed = preferences.values.guide_enabled
	guide_toggle.toggled.connect(_guide_toggled)
	column.add_child(guide_toggle)
	for entry in [["Resume", resume_requested], ["Save progress", save_requested], ["Load progress", load_requested], ["Save and quit", quit_requested]]:
		var button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 32
		button.pressed.connect(entry[1].emit)
		column.add_child(button)
		buttons[entry[0]] = button
	status = _text(column, "Esc resumes. Tab / arrows also adjust controls.", 14)
	_update_labels()
	hide()
	panel.hide()
	veil.hide()

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

func layout(viewport_size: Vector2, ui_scale: float) -> void:
	scale = Vector2.ONE * ui_scale
	veil.size = viewport_size / ui_scale
	panel.position = (viewport_size / ui_scale - panel.size) / 2
