extends PanelContainer
signal collapsed_changed(collapsed: bool)
var heading: Label
var toggle_button: Button
var body: VBoxContainer
var collapsed := false

func _init(title: String = "Panel", start_collapsed: bool = false) -> void:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	heading = Label.new()
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("f2dfae"))
	header.add_child(heading)
	toggle_button = Button.new()
	toggle_button.custom_minimum_size = Vector2(30, 26)
	toggle_button.pressed.connect(func(): set_collapsed(not collapsed))
	header.add_child(toggle_button)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	column.add_child(body)
	set_collapsed(start_collapsed, false)

func set_title(title: String) -> void:
	heading.text = title

func set_collapsed(value: bool, notify: bool = true) -> void:
	var changed = collapsed != value
	collapsed = value
	body.visible = not value
	toggle_button.text = "+" if value else "−"
	toggle_button.tooltip_text = "Restore panel" if value else "Minimize panel"
	reset_size()
	if is_inside_tree():
		call_deferred("reset_size")
	if changed and notify:
		collapsed_changed.emit(value)
