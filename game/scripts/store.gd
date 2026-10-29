extends Node3D
## First standalone slice. Build the scene and UI from source; no editor clicks.
const State = preload("res://scripts/retail_state.gd")
const Player = preload("res://scripts/player.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Saves = preload("res://scripts/save_store.gd")
const Preferences = preload("res://scripts/player_settings.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Guide = preload("res://scripts/first_day_guide.gd")
const Foldable = preload("res://scripts/foldable_panel.gd")
const UNIT := 0.28
const PRICE_TAG_WIDTH := 0.26
var state = State.new()
var player: CharacterBody3D
var hud: Label
var prompt: Label
var notice: Label
var report: Label
var stock_root: Node3D
var shopper: Node3D
var shopper_path: Array[Vector3] = []
var shopper_phase := "absent"
var shopper_order := -1
var shopper_patience := 0.0
var arrival_timer := 2.0
var targets: Array[Dictionary] = []
var notice_timer := 0.0
var selected_product := "beans"
var shelf_signs: Dictionary = {}
var price_tags: Dictionary = {}
var merchandise: Dictionary = {}
var supplier_hint: Label
var save_hint: Label
var save_note := ""
var controls_list: Label
var receiving_sign: Label3D
var hours_sign: Label3D
var key_names: Dictionary = {}
var register_display: Label3D
var receipt_display: Label3D
var last_receipt := ""
var shopper_product := "beans"
var shopper_choice := 0
var persistence_enabled := true
var save_path := Saves.DEFAULT_PATH
var save_countdown := -1.0
var save_blocked := false
var preferences = Preferences.new()
var settings_path := Preferences.DEFAULT_PATH
var pause_menu: CanvasLayer
var game_paused := false
var hud_layer: CanvasLayer
var crosshair: Label
var controls_hint: Label
var shopper_slot := "beans"
var guide_panel: PanelContainer
var guide_title: Label
var guide_detail: Label
var guide_marker: Label3D
var dashboard_panel: PanelContainer
var report_panel: PanelContainer
var panel_cursor := false

func _ready() -> void:
	name = "CornerfieldMarket"
	_build_environment()
	_build_fixtures()
	_build_hud()
	guide_marker = _sign("NEXT\n↓", Vector3.ZERO, 36, 0.004)
	guide_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide_marker.modulate = Color("ffdc88")
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(-2.8, 0.4, 7.7)
	add_child(player)
	state.changed.connect(_on_state_changed)
	persistence_enabled = persistence_enabled and not "--no-save" in OS.get_cmdline_user_args() and not "--verify-prototype" in OS.get_cmdline_user_args()
	if persistence_enabled:
		preferences.load_file(settings_path)
	pause_menu = PauseMenu.new()
	pause_menu.preferences = preferences
	add_child(pause_menu)
	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.save_requested.connect(_menu_save)
	pause_menu.load_requested.connect(_menu_load)
	pause_menu.quit_requested.connect(_quit_game)
	pause_menu.settings_changed.connect(_settings_changed)
	_apply_settings()
	if persistence_enabled:
		get_tree().auto_accept_quit = false
		if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
			_load_game(false)
	_refresh()
	if notice.text.is_empty():
		_message("Choose goods with %s / %s / %s, then %s to order. %s collects or stocks a case." % [_key("select_1"), _key("select_2"), _key("select_3"), _key("buy_case"), _key("interact")])
	if "--verify-prototype" in OS.get_cmdline_user_args():
		print("CORNERFIELD_SCENE_READY")
		get_tree().quit(0)

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.65
	return material

func _box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = title
	root.position = at
	parent.add_child(root, true)
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	root.add_child(visual)
	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func _collider(title: String, at: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = title
	body.position = at
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body, true)

func _asset(path: String, title: String, at: Vector3) -> Node3D:
	var packed = load(path) as PackedScene
	assert(packed != null, "Missing authored asset: run scripts/prepare-game-assets.ps1")
	var model = packed.instantiate() as Node3D
	model.name = title
	model.position = at
	model.scale = Vector3.ONE * UNIT
	add_child(model, true)
	return model

func _sign(text: String, at: Vector3, font_size: int = 48, pixel: float = 0.006) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = Color("f2edd9")
	label.outline_modulate = Color("163b30")
	label.outline_size = 8
	add_child(label)
	return label

func _tag_text(parent: Node3D, at: Vector3, font_size: int) -> Label3D:
	var label = Label3D.new()
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.0004
	label.modulate = Color("1b2621")
	label.outline_size = 0
	parent.add_child(label)
	return label

func _price_tag(at: Vector3) -> Dictionary:
	var card = _box(self, "PriceTag", at, Vector3(PRICE_TAG_WIDTH, 0.13, 0.006), Color("f6f2e4"), false)
	var accent = _box(card, "Accent", Vector3(0, 0.057, 0.0035), Vector3(PRICE_TAG_WIDTH, 0.016, 0.002), Color.WHITE, false)
	return {"card": card, "accent": accent.get_child(0).material_override,
		"title": _tag_text(card, Vector3(0, 0.029, 0.0045), 56), "price": _tag_text(card, Vector3(0, -0.022, 0.0045), 124)}

func _build_environment() -> void:
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("91adb7")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4e3d9")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff1da")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	_box(self, "ExteriorGround", Vector3(0, -0.15, 0), Vector3(50, 0.3, 50), Color("616b63"))
	_asset("res://assets/generated/store-shell.glb", "HoudiniStoreShell", Vector3.ZERO)
	_collider("StoreFloor", Vector3(0, 0.14, 0), Vector3(22.4, 0.28, 17.92))
	_collider("BackWall", Vector3(0, 2.2, -8.96), Vector3(22.4, 4, 0.2))
	for x in [-11.2, 11.2]:
		_collider("SideWall", Vector3(x, 2.2, 0), Vector3(0.2, 4, 17.92))
	for x in [-6.6, 6.6]:
		_collider("FrontWindowWall", Vector3(x, 2.1, 8.96), Vector3(9.2, 3.6, 0.2))
	# Ceiling and practical fixtures remain distinct from the Houdini shell.
	_box(self, "Ceiling", Vector3(0, 4.42, 0), Vector3(22.3, 0.12, 17.8), Color("dbd9cd"), false)
	for x in [-7.0, 0.0, 7.0]:
		for z in [-4.0, 2.0, 7.0]:
			_box(self, "FluorescentHousing", Vector3(x, 4.25, z), Vector3(1.9, 0.08, 0.3), Color("f2efdb"), false)
			var light = OmniLight3D.new()
			light.position = Vector3(x, 3.9, z)
			light.light_color = Color("fff0ce")
			light.light_energy = 0.65
			light.omni_range = 7.0
			add_child(light)
	_sign("CORNERFIELD MARKET", Vector3(0, 4.2, 9.2), 64, 0.009)
	_sign("EVERYDAY GOODS  /  NEIGHBORHOOD PRICES", Vector3(0, 3.45, -8.8), 48, 0.007)

func _build_fixtures() -> void:
	for x in [-7.0, 0.0, 7.0]:
		for z in [-4.0, 0.0, 4.0]:
			_asset("res://assets/generated/shelf.glb", "HoudiniShelf", Vector3(x, 0.28, z))
			_collider("ShelfCollision", Vector3(x, 1.47, z), Vector3(3.4, 2.38, 1.12))
	stock_root = Node3D.new()
	stock_root.name = "DynamicStock"
	add_child(stock_root)
	for product in Catalog.IDS:
		var info: Dictionary = Catalog.PRODUCTS[product]
		merchandise[product] = load("res://assets/generated/" + info.model) as PackedScene
		assert(merchandise[product] != null, "Missing packaging: run scripts/prepare-game-assets.ps1")
		shelf_signs[product] = _sign("", Vector3(info.shelf_x, 2.9, 4.45), 32, 0.005)
		# One tag per tier, hung from the Houdini price rail under the middle facing.
		price_tags[product] = []
		for tier in range(4):
			price_tags[product].append(_price_tag(Vector3(info.shelf_x, 0.28 + (0.85 + tier * 2.45) * UNIT - 0.065, 4.556)))
		targets.append({"id": "shelf" if product == "beans" else "shelf_" + product,
			"slot": product, "product": product, "at": Vector3(info.shelf_x, 1.1, 4.65), "label": "Stock " + info.name})
	_asset("res://assets/generated/checkout.glb", "BlenderCheckout", Vector3(5, 0.28, 6.5))
	_collider("CheckoutCabinet", Vector3(5, 0.77, 6.5), Vector3(1.176, 0.98, 2.408))
	_collider("BaggingReturn", Vector3(6.106, 1.184, 5.884), Vector3(0.896, 0.0784, 1.176))
	targets.append({"id": "checkout", "at": Vector3(4.55, 1.4, 6.0), "label": "Complete customer's purchase"})
	_sign("CHECKOUT 01", Vector3(5, 2.5, 6.3), 44, 0.005)
	register_display = _sign("READY", Vector3(4.776, 1.753, 5.754), 28, 0.0009)
	register_display.outline_size = 0
	receipt_display = _sign("", Vector3(5.308, 1.438, 5.682), 24, 0.00035)
	receipt_display.rotation.x = -PI / 2
	receipt_display.modulate = Color("182c24")
	receipt_display.outline_size = 0
	_box(self, "ReceivingTable", Vector3(-8, 0.73, 7.45), Vector3(2.2, 0.9, 0.9), Color("725f48"))
	receiving_sign = _sign("", Vector3(-8, 1.7, 7.45), 36, 0.005)
	targets.append({"id": "receiving", "at": Vector3(-8, 1.2, 7.9), "label": "Collect delivered case"})
	hours_sign = _sign("", Vector3(0.9, 1.8, 8.7), 32, 0.005)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_hud() -> void:
	var layer = CanvasLayer.new()
	hud_layer = layer
	layer.name = "RetailHUD"
	add_child(layer)
	dashboard_panel = Foldable.new("CORNERFIELD / MARKET", true)
	var panel = dashboard_panel
	panel.custom_minimum_size.x = 400
	panel.position = Vector2(24, 24)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.09, 0.075, 0.94)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column = panel.body
	hud = _label(column, "", 17, Color("e3e8dc"))
	supplier_hint = _label(column, "", 15, Color("dfd0a4"))
	controls_list = _label(column, "", 15, Color("aebeb2"))
	save_hint = _label(column, "", 14, Color("aebeb2"))
	prompt = _label(layer, "", 22, Color("fff0c4"))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(450, 585)
	notice = _label(layer, "", 17, Color("fff6df"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.position = Vector2(24, 660)
	controls_hint = _label(layer, "", 15, Color("d4ddd7"))
	crosshair = _label(layer, "+", 24, Color("f2edd9"))
	crosshair.position = Vector2(632, 344)
	report_panel = Foldable.new("DAY REPORT")
	report_panel.custom_minimum_size.x = 320
	report_panel.add_theme_stylebox_override("panel", style.duplicate())
	layer.add_child(report_panel)
	report = _label(report_panel.body, "", 18, Color("f6e9be"))
	guide_panel = Foldable.new("FIRST DAY")
	guide_panel.custom_minimum_size.x = 320
	var guide_style = StyleBoxFlat.new()
	guide_style.bg_color = Color(0.06, 0.15, 0.12, 0.94)
	guide_style.set_content_margin_all(14)
	guide_style.set_corner_radius_all(8)
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	layer.add_child(guide_panel)
	var guide_column = guide_panel.body
	guide_column.add_theme_constant_override("separation", 8)
	guide_title = _label(guide_column, "", 17, Color("f2dfae"))
	guide_detail = _label(guide_column, "", 16, Color("e1e9df"))
	guide_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dashboard_panel.collapsed_changed.connect(_panel_changed.bind("dashboard_collapsed"))
	guide_panel.collapsed_changed.connect(_panel_changed.bind("guide_collapsed"))
	report_panel.collapsed_changed.connect(_panel_changed.bind("report_collapsed"))

func _money(cents: int) -> String:
	return "$%.2f" % (float(cents) / 100.0)

func _refresh() -> void:
	if not is_instance_valid(hud):
		return
	var stock_lines := ""
	for product in Catalog.IDS:
		stock_lines += "\n%s %d / 12  @ %s" % [Catalog.PRODUCTS[product].short, state.stocks[product], _money(state.prices[product])]
	for slot in Catalog.IDS:
		var product: String = state.shelf_assignments[slot]
		shelf_signs[slot].text = "%s\n%s  %s" % [Catalog.PRODUCTS[product].department, Catalog.PRODUCTS[product].name, _money(state.prices[product])]
		for tag in price_tags[slot]:
			tag.title.text = Catalog.PRODUCTS[product].name.to_upper()
			tag.price.text = _money(state.prices[product])
			tag.accent.albedo_color = Color(Catalog.PRODUCTS[product].color)
	for target in targets:
		if target.has("slot"):
			target.product = state.shelf_assignments[target.slot]
			target.label = "Stock " + Catalog.PRODUCTS[target.product].name
	var carried_name = Catalog.PRODUCTS[state.carried_product].short if state.carried > 0 else "—"
	hud.text = "DAY %d  /  %s\nCash %s    Sales %s%s\nCarrying %d %s\nReceiving %d    On order %d\nCustomer: %s" % [
		state.day, "OPEN" if state.is_open else "CLOSED", _money(state.cash), _money(state.revenue), stock_lines,
		state.carried, carried_name, state.receiving, state.incoming, shopper_phase.replace("_", " ")]
	supplier_hint.text = "BUY: %s · 12 units / %s" % [Catalog.PRODUCTS[selected_product].name, _money(12 * int(Catalog.PRODUCTS[selected_product].cost))]
	dashboard_panel.set_title("MARKET / DAY %d %s\n%s · Buy %s" % [state.day, "OPEN" if state.is_open else "CLOSED", _money(state.cash), Catalog.PRODUCTS[selected_product].short])
	for child in stock_root.get_children():
		stock_root.remove_child(child)
		child.queue_free()
	for product in Catalog.IDS:
		var slot_id = state.slot_for_product(product)
		for index in range(int(state.stocks[product])):
			var tier = index / 3
			var slot = index % 3
			var at = Vector3(float(Catalog.PRODUCTS[slot_id].shelf_x) - 0.92 + slot * 0.92, 0.28 + 0.71 * UNIT + tier * 2.45 * UNIT, 4.12)
			_product_visual(product, at)
	register_display.text = "READY"
	if state.orders.has(shopper_order):
		var basket: Dictionary = state.orders[shopper_order]
		register_display.text = "TOTAL\n" + _money(int(basket.quantity) * int(basket.unit_price))
	receipt_display.text = last_receipt
	if state.last_report.is_empty():
		report.text = ""
	else:
		var summary: Dictionary = state.last_report
		report_panel.set_title("DAY %d / CLOSED\nSales %s" % [summary.day, _money(summary.revenue)])
		report.text = "Revenue      %s\nGoods sold   %s\nGross profit %s\nPurchases    %s\nCash change  %s\n\n%d sold · %d walkouts\n%s  Begin next day" % [
			_money(summary.revenue), _money(summary.cost_of_goods), _money(summary.gross_profit),
			_money(summary.purchases), _money(summary.cash_change), summary.sold, summary.walkouts, _key("next_day")]
	report_panel.visible = not report.text.is_empty()
	_update_guide()

func _update_guide() -> void:
	if not is_instance_valid(guide_panel) or not is_instance_valid(guide_marker):
		return
	var step = Guide.current(state, shopper_phase, key_names)
	var enabled = bool(preferences.values.guide_enabled) and not step.is_empty()
	guide_panel.visible = enabled and not game_paused
	guide_marker.visible = false
	if not enabled:
		return
	guide_panel.set_title("FIRST DAY / %d OF %d" % [step.step, step.total])
	guide_title.text = step.title
	guide_detail.text = step.detail
	if game_paused or guide_panel.collapsed or step.target.is_empty():
		return
	for target in targets:
		if target.id == step.target:
			guide_marker.position = target.at + Vector3(0, 2.3, 0)
			guide_marker.visible = true

func _message(text: String) -> void:
	notice.text = text
	notice_timer = 7.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if game_paused and not pause_menu.capture_action.is_empty():
			# A key-binding capture owns the next key, including Esc to cancel it.
			pause_menu.capture_key(event)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			set_paused(not game_paused)
			get_viewport().set_input_as_handled()
		elif not game_paused and event.keycode == KEY_TAB:
			panel_cursor = not panel_cursor
			player.controls_enabled = not panel_cursor
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel_cursor else Input.MOUSE_MODE_CAPTURED
			if panel_cursor:
				dashboard_panel.toggle_button.grab_focus()
			else:
				get_viewport().gui_release_focus()
			_message("Panels: arrows select, Enter toggles, Tab returns. Store time continues; Esc pauses." if panel_cursor else "Movement restored.")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			compact_panels()
			get_viewport().set_input_as_handled()
		elif panel_cursor and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			_focus_panel(-1 if event.keycode in [KEY_LEFT, KEY_UP] else 1)
			get_viewport().set_input_as_handled()
		elif panel_cursor and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			var focused = get_viewport().gui_get_focus_owner()
			for panel in [dashboard_panel, report_panel, guide_panel]:
				if panel.is_visible_in_tree() and focused == panel.toggle_button:
					panel.set_collapsed(not panel.collapsed)
					break
			get_viewport().set_input_as_handled()

func _focus_panel(direction: int) -> void:
	var buttons: Array[Button] = []
	for panel in [dashboard_panel, report_panel, guide_panel]:
		if panel.is_visible_in_tree():
			buttons.append(panel.toggle_button)
	if buttons.is_empty():
		return
	var index = buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + direction, buttons.size()) if index >= 0 else 0].grab_focus()

func compact_panels() -> void:
	var compact = not (dashboard_panel.collapsed and guide_panel.collapsed and report_panel.collapsed)
	dashboard_panel.set_collapsed(compact)
	guide_panel.set_collapsed(compact)
	report_panel.set_collapsed(compact)

func _panel_changed(collapsed: bool, key: String) -> void:
	preferences.set_value(key, collapsed)
	_update_guide()
	_layout_hud()
	if persistence_enabled:
		preferences.save_file(settings_path)

func set_paused(paused: bool) -> void:
	pause_menu.show_controls(false)
	game_paused = paused
	panel_cursor = false
	player.controls_enabled = not paused
	pause_menu.visible = paused
	pause_menu.panel.visible = paused
	pause_menu.veil.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		pause_menu.buttons.Resume.grab_focus()
	else:
		get_viewport().gui_release_focus()
	_update_guide()
	_layout_hud()

func _apply_settings() -> void:
	player.sensitivity = float(preferences.values.sensitivity)
	player.move_speed = float(preferences.values.move_speed)
	player.move_keys = ["move_forward", "move_back", "move_left", "move_right"].map(func(action): return preferences.bindings[action])
	if preferences.labels() != key_names:
		key_names = preferences.labels()
		_update_key_text()
	hud_layer.scale = Vector2.ONE * float(preferences.values.ui_scale)
	dashboard_panel.set_collapsed(preferences.values.dashboard_collapsed, false)
	guide_panel.set_collapsed(preferences.values.guide_collapsed, false)
	report_panel.set_collapsed(preferences.values.report_collapsed, false)
	_update_guide()
	_layout_hud()

func _key(action: String) -> String:
	return key_names.get(action, "?")

func _update_key_text() -> void:
	var move := PackedStringArray()
	var single := true
	for action in ["move_forward", "move_left", "move_back", "move_right"]:
		move.append(_key(action))
		single = single and _key(action).length() == 1
	controls_hint.text = "%s Move   %s Interact   Esc Pause   Tab Panel cursor   F2 Compact/restore   %s Guide" % ["".join(move) if single else " / ".join(move), _key("interact"), _key("toggle_guide")]
	controls_list.text = "%s / %s / %s  Select goods    %s / %s  Price ±10¢\n%s  Order case    %s  Open / close    %s  Next day\n%s  Swap empty shelf with selected goods (closed)" % [
		_key("select_1"), _key("select_2"), _key("select_3"), _key("price_down"), _key("price_up"),
		_key("buy_case"), _key("open_close"), _key("next_day"), _key("reassign_shelf")]
	receiving_sign.text = "RECEIVING  /  %s TO ORDER" % _key("buy_case")
	hours_sign.text = "%s  OPEN / CLOSE\n%s  NEXT DAY" % [_key("open_close"), _key("next_day")]
	_save_note(save_note)
	_refresh()

func _save_note(note: String) -> void:
	save_note = note
	save_hint.text = "%s  Save    %s  Load" % [_key("save_game"), _key("load_game")] + ("" if note.is_empty() else "  /  " + note)

func _settings_changed() -> void:
	_apply_settings()
	if persistence_enabled:
		pause_menu.status.text = "Settings saved." if preferences.save_file(settings_path) else "Settings apply now; file could not be saved."

func _layout_hud() -> void:
	if not is_instance_valid(pause_menu):
		return
	var ui_scale = float(preferences.values.ui_scale)
	var screen = get_viewport().get_visible_rect().size
	var logical = screen / ui_scale
	crosshair.position = logical / 2 - crosshair.get_combined_minimum_size() / 2
	prompt.position = Vector2((logical.x - prompt.get_combined_minimum_size().x) / 2, logical.y - 120)
	notice.position = Vector2(24, logical.y - 68)
	notice.size.x = logical.x - 48
	controls_hint.position = Vector2(24, logical.y - 28)
	report_panel.position = Vector2(maxf(24, logical.x - 344), 24)
	guide_panel.position = Vector2(maxf(24, logical.x - 344), 24 if report.text.is_empty() else 40 + report_panel.get_combined_minimum_size().y)
	pause_menu.layout(screen, ui_scale)

func _menu_save() -> void:
	pause_menu.status.text = "Progress saved." if _save_game() else "Could not save. Current progress remains in memory."

func _menu_load() -> void:
	pause_menu.status.text = "Loaded; store is closed." if _load_game() else "Could not load; current progress is unchanged."

func _quit_game() -> void:
	if persistence_enabled and not _save_game(false):
		pause_menu.status.text = "Could not save. Stay here and retry before quitting."
		return
	get_tree().quit()

func reassign_nearby_shelf() -> bool:
	if game_paused or panel_cursor:
		return false
	var target = nearest_target()
	if target.is_empty() or not target.has("slot"):
		_message("Look at an empty shelf nearby to reassign it.")
		return false
	var assigned = state.assign_shelf(target.slot, selected_product)
	_message("Shelf assigned to " + Catalog.PRODUCTS[selected_product].name + "." if assigned else "Close the store first; both affected shelves must be empty, including unpaid goods.")
	return assigned

func _product_visual(product: String, at: Vector3) -> void:
	var root = merchandise[product].instantiate() as Node3D
	root.name = product
	root.position = at
	root.set_meta("product_id", product)
	stock_root.add_child(root, true)

func _on_state_changed() -> void:
	_refresh()
	if persistence_enabled and not save_blocked:
		save_countdown = 0.75

func _save_game(manual: bool = true) -> bool:
	if not persistence_enabled:
		return false
	var result = Saves.save(state, save_path)
	save_countdown = -1.0
	save_blocked = not result.ok
	_save_note("Saved" if result.ok else "Save paused")
	if manual or not result.ok:
		_message("Progress saved. Unpaid baskets return to shelves on resume." if result.ok else result.error)
	return result.ok

func _load_game(manual: bool = true) -> bool:
	if not persistence_enabled:
		return false
	var result = Saves.load_into(state, save_path)
	if not result.ok:
		save_blocked = true
		save_countdown = -1.0
		_save_note("Save paused")
		_message("Load failed; current progress unchanged. " + result.error)
		return false
	if is_instance_valid(shopper):
		shopper.queue_free()
	shopper = null
	shopper_order = -1
	shopper_phase = "absent"
	shopper_path.clear()
	arrival_timer = 2.0
	last_receipt = ""
	save_countdown = -1.0
	save_blocked = false
	player.position = Vector3(-2.8, 0.4, 7.7)
	player.velocity = Vector3.ZERO
	_refresh()
	_save_note("Backup recovered" if result.recovered else "Loaded")
	if manual or result.recovered:
		_message("Recovered the previous valid save. Store resumed closed." if result.recovered else "Loaded. Store resumed closed; unpaid goods returned to shelves.")
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and persistence_enabled:
		if not save_blocked:
			_save_game(false)
		get_tree().quit()

func nearest_target() -> Dictionary:
	var nearest: Dictionary = {}
	var best := 2.4
	for target in targets:
		var offset: Vector3 = target.at - player.camera.global_position
		var distance = offset.length()
		if distance < best and offset.normalized().dot(-player.camera.global_basis.z) > 0.25:
			best = distance
			nearest = target
	return nearest

func perform_action(id: String) -> bool:
	# All physical actions validate distance here, including programmatic callers.
	if game_paused or panel_cursor:
		return false
	var target: Dictionary = {}
	for item in targets:
		if item.id == id:
			target = item
	if target.is_empty() or player.camera.global_position.distance_to(target.at) > 2.4:
		return false
	if target.has("product"):
		var added = state.restock(target.product)
		_message("Stocked %d %s." % [added, Catalog.PRODUCTS[target.product].short] if added > 0 else "Carry the matching case, and leave room on this shelf.")
		return added > 0
	match id:
		"receiving":
			var success = state.collect_case()
			_message("Carrying a case. Stock the marked pantry shelf." if success else "No case ready. %s orders one; delivery takes four seconds." % _key("buy_case"))
			return success
		"checkout":
			var basket: Dictionary = state.orders.get(shopper_order, {})
			if shopper_phase == "waiting_at_checkout" and state.checkout(shopper_order):
				last_receipt = Catalog.PRODUCTS[basket.product].short + "\n" + _money(int(basket.quantity) * int(basket.unit_price))
				shopper_order = -1
				_leave_shop()
				_message("Sale complete: " + last_receipt.replace("\n", " ") + ". Thank you!")
				return true
			_message("No customer ready at checkout.")
	return false

func _interact() -> void:
	if game_paused or panel_cursor:
		return
	var target = nearest_target()
	if not target.is_empty():
		perform_action(target.id)

func _unhandled_input(event: InputEvent) -> void:
	if game_paused or panel_cursor:
		return
	var action: String = preferences.action_for(event)
	match action:
		"interact":
			_interact()
		"toggle_guide":
			pause_menu.guide_toggle.button_pressed = not pause_menu.guide_toggle.button_pressed
		"reassign_shelf":
			reassign_nearby_shelf()
		"select_1", "select_2", "select_3":
			selected_product = Catalog.IDS[int(action.right(1)) - 1]
			_refresh()
		"price_down", "price_up":
			var change = -10 if action == "price_down" else 10
			state.set_price(selected_product, clampi(int(state.prices[selected_product]) + change, 1, 9999))
		"buy_case":
			_message("Ordered " + Catalog.PRODUCTS[selected_product].name + ". Delivery in four seconds." if state.order_case(selected_product) else "Collect the waiting case first, or check your cash.")
		"save_game":
			_save_game()
		"load_game":
			_load_game()
		"open_close":
			if state.is_open:
				state.close_store()
				if is_instance_valid(shopper):
					shopper_order = -1
					_leave_shop()
				_message("Closed. Unpaid stock returned; the daily report is ready.")
			else:
				state.open_store()
				_message("Store open. Shoppers will visit the pantry shelf.")
		"next_day":
			if state.next_day():
				_message("New day. Stock and cash carried forward.")

func _spawn_shopper() -> void:
	for offset in range(Catalog.IDS.size()):
		var candidate: String = Catalog.IDS[(shopper_choice + offset) % Catalog.IDS.size()]
		if int(state.stocks[candidate]) > 0:
			shopper_product = candidate
			break
	shopper_choice += 1
	shopper_slot = state.slot_for_product(shopper_product)
	shopper = Node3D.new()
	shopper.name = "ShopperPrototype"
	shopper.position = Vector3(-1, 0.28, 10.8)
	add_child(shopper)
	var torso = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 1.25
	torso.mesh = capsule
	torso.material_override = _material(Color("5e8195"))
	torso.position.y = 0.8
	shopper.add_child(torso)
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	head.mesh = sphere
	head.material_override = _material(Color("bd9475"))
	head.position.y = 1.56
	shopper.add_child(head)
	_box(shopper, "Basket", Vector3(0.32, 0.65, 0), Vector3(0.4, 0.3, 0.3), Color("315d48"), false)
	shopper_phase = "browsing"
	shopper_order = -1
	if shopper_slot == "soap":
		shopper_path = [Vector3(0, 0.28, 8.4), Vector3(8, 0.28, 8.4), Vector3(8, 0.28, 5.4), Vector3(7, 0.28, 5.4)]
	else:
		shopper_path = [Vector3(-3, 0.28, 7.3), Vector3(-3, 0.28, 5.4), Vector3(float(Catalog.PRODUCTS[shopper_slot].shelf_x), 0.28, 5.4)]
	_refresh()

func _leave_shop() -> void:
	shopper_phase = "leaving"
	shopper_path = [Vector3(2, 0.28, 8), Vector3(-1, 0.28, 10.8)]
	_refresh()

func simulate(delta: float) -> void:
	if game_paused:
		return
	state.tick(delta)
	if not is_instance_valid(shopper):
		if state.is_open:
			arrival_timer -= delta
			if arrival_timer <= 0:
				_spawn_shopper()
		return
	if not state.is_open and shopper_phase != "leaving":
		state.cancel(shopper_order)
		shopper_order = -1
		_leave_shop()
	if not shopper_path.is_empty():
		var waypoint = shopper_path[0]
		shopper.position = shopper.position.move_toward(waypoint, delta * 1.8)
		if shopper.position.distance_to(waypoint) < 0.03:
			shopper_path.pop_front()
		return
	match shopper_phase:
		"browsing":
			shopper_order = state.reserve(1, shopper_product)
			if shopper_order < 0:
				state.walkouts += 1
				_leave_shop()
			else:
				shopper_phase = "walking_to_checkout"
				if shopper_slot == "soap":
					shopper_path = [Vector3(8, 0.28, 5.4), Vector3(8, 0.28, 8.4), Vector3(5, 0.28, 8)]
				else:
					shopper_path = [Vector3(-3, 0.28, 5.4), Vector3(-3, 0.28, 7.3), Vector3(2, 0.28, 8), Vector3(5, 0.28, 8)]
				_refresh()
		"walking_to_checkout":
			shopper_phase = "waiting_at_checkout"
			shopper_patience = 45.0
			_message("Customer ready at Checkout 01. %s to serve." % _key("interact"))
			_refresh()
		"waiting_at_checkout":
			shopper_patience -= delta
			if shopper_patience <= 0:
				state.cancel(shopper_order)
				shopper_order = -1
				_leave_shop()
		"leaving":
			shopper.queue_free()
			shopper = null
			shopper_phase = "absent"
			arrival_timer = 4.0
			_refresh()

func _process(delta: float) -> void:
	_layout_hud()
	if game_paused:
		prompt.text = ""
		return
	simulate(delta)
	_update_guide()
	if save_countdown >= 0 and not save_blocked:
		save_countdown -= delta
		if save_countdown <= 0:
			_save_game(false)
	var target = {} if panel_cursor else nearest_target()
	prompt.text = "" if target.is_empty() else "%s  %s" % [_key("interact"), target.label]
	if target.has("slot"):
		prompt.text += "  /  %s swap when empty" % _key("reassign_shelf")
	notice_timer -= delta
	if notice_timer <= 0:
		notice.text = ""
