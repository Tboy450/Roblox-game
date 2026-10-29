extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Settings = preload("res://scripts/player_settings.gd")

static func _key(world, code: Key) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	world._input(event)

static func scene_checks(world, check: Callable, directory: String) -> void:
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world._apply_settings()
	world._refresh()
	check.call(world.dashboard_panel.collapsed and not world.dashboard_panel.body.visible and "$500.00" in world.dashboard_panel.heading.text, "Dashboard starts compact while keeping cash and day visible")
	world.dashboard_panel.toggle_button.pressed.emit()
	check.call(not world.dashboard_panel.collapsed and world.dashboard_panel.body.visible, "Plus button restores dashboard details")
	world.dashboard_panel.toggle_button.pressed.emit()
	world.state.order_case()
	var progress = JSON.stringify(world.state.save_data())
	_key(world, KEY_F2)
	check.call(world.dashboard_panel.collapsed and world.guide_panel.collapsed and world.report_panel.collapsed and not world.guide_marker.visible, "F2 minimizes every HUD panel and clears the guide marker")
	check.call(JSON.stringify(world.state.save_data()) == progress, "Panel controls do not change store progress")
	_key(world, KEY_F2)
	check.call(not world.dashboard_panel.collapsed and not world.guide_panel.collapsed and not world.report_panel.collapsed and world.guide_marker.visible, "F2 restores panel bodies and current guidance")
	_key(world, KEY_TAB)
	check.call(world.panel_cursor and not world.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Tab releases a panel cursor without moving the player")
	check.call(world.get_viewport().gui_get_focus_owner() == world.dashboard_panel.toggle_button, "Panel mode starts with keyboard focus on the dashboard")
	_key(world, KEY_RIGHT)
	check.call(world.get_viewport().gui_get_focus_owner() == world.guide_panel.toggle_button, "Arrow navigation skips the hidden day report")
	_key(world, KEY_ENTER)
	check.call(world.guide_panel.collapsed, "Enter minimizes the focused panel")
	_key(world, KEY_SPACE)
	check.call(not world.guide_panel.collapsed, "Space restores the focused panel")
	_key(world, KEY_RIGHT)
	check.call(world.get_viewport().gui_get_focus_owner() == world.dashboard_panel.toggle_button, "Panel keyboard navigation wraps to the first visible panel")
	_key(world, KEY_LEFT)
	check.call(world.get_viewport().gui_get_focus_owner() == world.guide_panel.toggle_button, "Reverse panel navigation wraps to the last visible panel")
	world.simulate(1)
	check.call(world.state.delivery_seconds == 3, "Panel cursor does not silently pause store time")
	var buy = InputEventKey.new()
	buy.keycode = KEY_BRACKETRIGHT
	buy.pressed = true
	world._unhandled_input(buy)
	check.call(world.state.prices.beans == 149, "Panel cursor blocks accidental gameplay shortcuts")
	world.persistence_enabled = true
	world.settings_path = directory.path_join("panel-preferences.cfg")
	world.guide_panel.toggle_button.pressed.emit()
	var preferences = Settings.new()
	check.call(preferences.load_file(world.settings_path) and preferences.values.guide_collapsed and not world.guide_panel.body.visible, "Individual panel state persists through the actual preference file")
	world.guide_panel.toggle_button.pressed.emit()
	_key(world, KEY_TAB)
	check.call(not world.panel_cursor and world.player.controls_enabled and world.get_viewport().gui_get_focus_owner() == null, "Tab returns to movement and releases panel focus")
	_key(world, KEY_TAB)
	world.set_paused(true)
	check.call(not world.panel_cursor and world.game_paused and not world.player.controls_enabled, "Pause safely exits panel cursor mode")
	_key(world, KEY_F2)
	check.call(world.dashboard_panel.collapsed and world.guide_panel.collapsed and world.game_paused, "Compact shortcut also works while the pause menu is open")
	world.set_paused(false)
	world.state.close_store()
	world._layout_hud()
	check.call(world.report_panel.visible and world.report_panel.collapsed and world.report_panel.toggle_button.text == "+", "Minimized day report retains a restore title bar")
	world.report_panel.toggle_button.pressed.emit()
	world._layout_hud()
	check.call(world.report_panel.body.visible and world.guide_panel.position.y >= world.report_panel.position.y + world.report_panel.get_combined_minimum_size().y, "Restoring a report keeps the guide stacked below it")
	world.persistence_enabled = false
	# Guide placement: lower right, clear of overhead signs, the prompt row and the dashboard.
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world.dashboard_panel.set_collapsed(false, false)
	world.prompt.text = "E  Stock Cedar Hand Soap  /  R swap when empty"
	var placed := true
	for scale in [1.0, 1.25]:
		world.preferences.values.ui_scale = scale
		world.hud_layer.scale = Vector2.ONE * scale
		world._refresh()
		world._layout_hud()
		var logical: Vector2 = world.get_viewport().get_visible_rect().size / scale
		var guide := Rect2(world.guide_panel.position, world.guide_panel.get_combined_minimum_size())
		var prompt := Rect2(world.prompt.position, world.prompt.get_combined_minimum_size())
		var dashboard := Rect2(world.dashboard_panel.position, world.dashboard_panel.get_combined_minimum_size())
		placed = placed and world.guide_panel.visible and guide.position.y >= logical.y * 0.4 and guide.end.y <= world.notice.position.y
		placed = placed and guide.end.x <= logical.x and not guide.intersects(prompt) and not guide.intersects(dashboard)
	check.call(placed, "First-day guide sits lower right, clear of overhead signs, the prompt and the dashboard at 100% and 125%")
	world.prompt.text = ""
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world._apply_settings()
