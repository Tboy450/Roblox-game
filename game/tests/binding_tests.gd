extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Settings = preload("res://scripts/player_settings.gd")
const Guide = preload("res://scripts/first_day_guide.gd")

static func _event(code: Key, physical: bool = true, pressed: bool = true) -> InputEventKey:
	var event = InputEventKey.new()
	event.pressed = pressed
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
	return event

static func _key(world, code: Key, global_input: bool = false) -> void:
	var event = _event(code)
	event.keycode = code
	if global_input:
		world._input(event)
	else:
		world._unhandled_input(event)

static func _held_axis(world, code: Key) -> Vector2:
	Input.parse_input_event(_event(code))
	Input.flush_buffered_events()
	var axis = world.player.input_axis()
	Input.parse_input_event(_event(code, true, false))
	Input.flush_buffered_events()
	return axis

static func run(check: Callable, directory: String) -> void:
	var keys = Settings.new()
	check.call(Settings.valid_bindings(keys.bindings) and keys.bindings.size() == Settings.ACTIONS.size(), "Default bindings give every gameplay action its own usable key")
	check.call(keys.key_label("move_forward") == "W" and keys.key_label("price_down") == "[" and keys.key_label("save_game") == "F5", "Binding labels show printed key names")
	check.call(keys.action_for(_event(KEY_B)) == "buy_case" and keys.action_for(_event(KEY_B, false)) == "buy_case", "Physical and keycode-only events resolve to the bound action")
	var before = keys.bindings.duplicate()
	var rejected = true
	for code in [KEY_ESCAPE, KEY_TAB, KEY_F2, KEY_NONE, KEY_MASK_SHIFT | KEY_K, 0x500000]:
		rejected = rejected and not keys.bind("interact", code)
	check.call(rejected and not keys.bind("missing", KEY_K) and keys.bindings == before, "Fixed, modified and unknown keys or actions are rejected without change")
	check.call(keys.bind("buy_case", KEY_E) and keys.bindings.buy_case == KEY_E and keys.bindings.interact == KEY_B and Settings.valid_bindings(keys.bindings), "Binding a used key swaps the two actions instead of duplicating it")
	keys.bind("move_forward", KEY_UP)
	keys.set_value("move_speed", 5.0)
	var path = directory.path_join("bindings.cfg")
	var loaded = Settings.new()
	check.call(keys.save_file(path) and loaded.load_file(path) and loaded.bindings == keys.bindings and is_equal_approx(loaded.values.move_speed, 5.0), "Custom bindings survive a settings file round-trip")
	var older = ConfigFile.new()
	older.set_value("controls", "ui_scale", 1.1)
	var older_path = directory.path_join("settings-before-bindings.cfg")
	older.save(older_path)
	var upgraded = Settings.new()
	check.call(upgraded.load_file(older_path) and upgraded.bindings == Settings.default_bindings() and is_equal_approx(upgraded.values.ui_scale, 1.1), "Settings saved before rebinding existed load with default keys")
	var whole = true
	for bad in [{"interact": KEY_B}, {"interact": KEY_TAB}, {"interact": "E"}, {"interact": 69.0}]:
		var config = ConfigFile.new()
		config.set_value("controls", "ui_scale", 0.9)
		for action in bad:
			config.set_value("bindings", action, bad[action])
		config.save(path)
		var bindings_before = loaded.bindings.duplicate()
		var values_before = loaded.values.duplicate()
		whole = whole and not loaded.load_file(path) and loaded.bindings == bindings_before and loaded.values == values_before
	check.call(whole, "Duplicate, fixed or malformed bindings reject the whole settings file")
	var custom = Settings.new()
	custom.bind("buy_case", KEY_K)
	check.call("press K to order" in Guide.current(State.new(), "absent", custom.labels()).detail, "First-day guide names the player's bound keys")

static func scene_checks(world, check: Callable, directory: String) -> void:
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world.preferences.reset_bindings()
	world._apply_settings()
	world.persistence_enabled = true
	world.settings_path = directory.path_join("binding-preferences.cfg")
	world.save_path = directory.path_join("binding-progress.json")
	var menu = world.pause_menu
	_key(world, KEY_ESCAPE, true)
	menu.buttons["Key bindings"].pressed.emit()
	menu.layout(Vector2(1280, 720), 1.25)
	var rect = Rect2(menu.panel.position * 1.25, menu.panel.size * 1.25)
	check.call(menu.controls_page.visible and not menu.main_page.visible and world.get_viewport().gui_get_focus_owner() == menu.binding_buttons.move_forward, "Key bindings page opens from pause with keyboard focus")
	check.call(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 1280 and rect.end.y <= 720, "Key bindings page fits the viewport at maximum UI scale")
	menu.binding_buttons.buy_case.pressed.emit()
	check.call(menu.capture_action == "buy_case" and menu.binding_buttons.buy_case.text == "Press a key…", "Choosing an action waits for its new key")
	_key(world, KEY_ESCAPE, true)
	check.call(world.game_paused and menu.controls_page.visible and menu.capture_action.is_empty() and world.preferences.bindings.buy_case == KEY_B, "Esc cancels a capture without unpausing or changing the key")
	menu.binding_buttons.buy_case.pressed.emit()
	var compact = world.dashboard_panel.collapsed
	_key(world, KEY_TAB, true)
	_key(world, KEY_F2, true)
	check.call(menu.capture_action == "buy_case" and world.preferences.bindings.buy_case == KEY_B and world.dashboard_panel.collapsed == compact and "fixed" in menu.bind_status.text, "Tab and F2 cannot be captured and keep waiting for a usable key")
	_key(world, KEY_K, true)
	var saved = Settings.new()
	check.call(world.preferences.bindings.buy_case == KEY_K and menu.binding_buttons.buy_case.text == "K" and saved.load_file(world.settings_path) and saved.bindings.buy_case == KEY_K, "Captured key applies immediately and saves to the preferences file")
	check.call("K TO ORDER" in world.receiving_sign.text and "K  Order case" in world.controls_list.text, "World sign and dashboard hints show the new key")
	menu.binding_buttons.interact.pressed.emit()
	_key(world, KEY_K, true)
	check.call(world.preferences.bindings.interact == KEY_K and world.preferences.bindings.buy_case == KEY_E and "Order case moved to E" in menu.bind_status.text, "Capturing a used key swaps it and reports the moved action")
	world.persistence_enabled = false
	_key(world, KEY_ESCAPE, true)
	_key(world, KEY_ESCAPE, true)
	check.call(world.game_paused and menu.main_page.visible and not menu.controls_page.visible, "Pause reopens on the main page after leaving key bindings")
	_key(world, KEY_ESCAPE, true)
	_key(world, KEY_B)
	check.call(world.state.incoming == 0, "A key moved away from an action no longer triggers it")
	_key(world, KEY_E)
	check.call(world.state.incoming == 12, "The rebound order key buys the selected case")
	world.simulate(4)
	world.player.position = Vector3(-8, 0.3, 8.5)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	world._process(0.0)
	check.call(world.prompt.text.begins_with("K  Collect"), "Interaction prompt shows the rebound interact key")
	_key(world, KEY_K)
	check.call(world.state.carried == 12, "The rebound interact key collects the delivery")
	world._update_guide()
	check.call("press K" in world.guide_detail.text, "First-day guide follows the player's interact key")
	world.preferences.bind("move_forward", KEY_UP)
	world._apply_settings()
	check.call(_held_axis(world, KEY_UP) == Vector2(0, -1) and _held_axis(world, KEY_W) == Vector2.ZERO, "Movement reads the rebound physical key and ignores the old one")
	world.set_paused(true)
	menu.buttons["Key bindings"].pressed.emit()
	menu.buttons["Reset defaults"].pressed.emit()
	world.set_paused(false)
	check.call(world.preferences.bindings == Settings.default_bindings() and world.controls_hint.text.begins_with("WASD Move   E Interact") and world.player.move_keys == [KEY_W, KEY_S, KEY_A, KEY_D], "Reset restores default keys, hints and movement")
