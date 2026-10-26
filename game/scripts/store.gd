extends Node3D
## First standalone slice. Build the scene and UI from source; no editor clicks.
const State = preload("res://scripts/retail_state.gd")
const Player = preload("res://scripts/player.gd")
const UNIT := 0.28
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

func _ready() -> void:
	name = "CornerfieldMarket"
	_build_environment()
	_build_fixtures()
	_build_hud()
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(-2.8, 0.4, 7.7)
	add_child(player)
	player.interacted.connect(_interact)
	state.changed.connect(_refresh)
	_refresh()
	_message("Welcome. Order your first case with B, then collect it from Receiving.")
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
	_sign("PANTRY  /  HARVEST BEANS  $1.49", Vector3(-7, 2.9, 4.45), 36, 0.005)
	targets.append({"id": "shelf", "at": Vector3(-7, 1.1, 4.65), "label": "E  Stock pantry shelf"})
	_asset("res://assets/generated/checkout.glb", "BlenderCheckout", Vector3(5, 0.28, 6.5))
	_collider("CheckoutCabinet", Vector3(5, 0.77, 6.5), Vector3(1.176, 0.98, 2.408))
	_collider("BaggingReturn", Vector3(6.106, 1.184, 5.884), Vector3(0.896, 0.0784, 1.176))
	targets.append({"id": "checkout", "at": Vector3(4.55, 1.4, 6.0), "label": "E  Complete customer's purchase"})
	_sign("CHECKOUT 01", Vector3(5, 2.5, 6.3), 44, 0.005)
	_box(self, "ReceivingTable", Vector3(-8, 0.73, 7.45), Vector3(2.2, 0.9, 0.9), Color("725f48"))
	_sign("RECEIVING  /  B TO ORDER", Vector3(-8, 1.7, 7.45), 36, 0.005)
	targets.append({"id": "receiving", "at": Vector3(-8, 1.2, 7.9), "label": "E  Collect delivered case"})
	_sign("O  OPEN / CLOSE\nN  NEXT DAY", Vector3(0.9, 1.8, 8.7), 32, 0.005)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_hud() -> void:
	var layer = CanvasLayer.new()
	layer.name = "RetailHUD"
	add_child(layer)
	var panel = PanelContainer.new()
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
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	_label(column, "CORNERFIELD  /  MARKET", 22, Color("f2e6bc"))
	hud = _label(column, "", 17, Color("e3e8dc"))
	_label(column, "B  Order 12 beans ($8.40)\nO  Open / close    N  Next day", 15, Color("aebeb2"))
	prompt = _label(layer, "", 22, Color("fff0c4"))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(450, 585)
	notice = _label(layer, "", 17, Color("fff6df"))
	notice.position = Vector2(24, 660)
	var controls = _label(layer, "WASD  Move     Mouse  Look     E  Interact     Esc  Release mouse", 15, Color("d4ddd7"))
	controls.position = Vector2(24, 694)
	var crosshair = _label(layer, "+", 24, Color("f2edd9"))
	crosshair.position = Vector2(632, 344)
	report = _label(layer, "", 20, Color("f6e9be"))
	report.position = Vector2(870, 32)

func _money(cents: int) -> String:
	return "$%.2f" % (float(cents) / 100.0)

func _refresh() -> void:
	if not is_instance_valid(hud):
		return
	hud.text = "DAY %d  /  %s\nCash %s    Sales %s\nShelf %d / 12    Carrying %d\nReceiving %d    On order %d\nCustomer: %s" % [
		state.day, "OPEN" if state.is_open else "CLOSED", _money(state.cash), _money(state.revenue),
		state.shelf, state.carried, state.receiving, state.incoming, shopper_phase.replace("_", " ")]
	for child in stock_root.get_children():
		stock_root.remove_child(child)
		child.queue_free()
	for index in range(state.shelf):
		var tier = index / 3
		var slot = index % 3
		var at = Vector3(-7.92 + slot * 0.92, 0.28 + 0.65 * UNIT + tier * 2.45 * UNIT + 0.17, 4.12)
		_box(stock_root, "HarvestBeans", at, Vector3(0.22, 0.34, 0.2), Color("c17b38"), false)
		var wrap = _box(stock_root, "PaperLabel", at + Vector3(0, 0, 0.102), Vector3(0.2, 0.16, 0.006), Color("e9dfb5"), false)
		wrap.set_meta("decorative", true)
	if state.last_report.is_empty():
		report.text = ""
	else:
		var summary: Dictionary = state.last_report
		report.text = "DAY %d  /  CLOSED\n\nRevenue      %s\nGoods sold   %s\nGross profit %s\nPurchases    %s\nCash change  %s\n\n%d sold · %d walkouts\nN  Begin next day" % [summary.day,
			_money(summary.revenue), _money(summary.cost_of_goods), _money(summary.gross_profit),
			_money(summary.purchases), _money(summary.cash_change), summary.sold, summary.walkouts]

func _message(text: String) -> void:
	notice.text = text
	notice_timer = 7.0

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
	var target: Dictionary = {}
	for item in targets:
		if item.id == id:
			target = item
	if target.is_empty() or player.camera.global_position.distance_to(target.at) > 2.4:
		return false
	match id:
		"receiving":
			var success = state.collect_case()
			_message("Carrying a case. Stock the marked pantry shelf." if success else "No case ready. B orders one; delivery takes four seconds.")
			return success
		"shelf":
			var added = state.restock()
			_message("Stocked %d units." % added if added > 0 else "Collect a case first, or wait until there is shelf space.")
			return added > 0
		"checkout":
			if shopper_phase == "waiting_at_checkout" and state.checkout(shopper_order):
				shopper_order = -1
				_leave_shop()
				_message("Sale complete. Harvest beans: $1.49. Thank you!")
				return true
			_message("No customer ready at checkout.")
	return false

func _interact() -> void:
	var target = nearest_target()
	if not target.is_empty():
		perform_action(target.id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_message("Case ordered. Delivery arrives in four seconds." if state.order_case() else "Collect the waiting case first, or check your cash.")
			KEY_O:
				if state.is_open:
					state.close_store()
					if is_instance_valid(shopper):
						shopper_order = -1
						_leave_shop()
					_message("Closed. Unpaid stock returned; the daily report is ready.")
				else:
					state.open_store()
					_message("Store open. Shoppers will visit the pantry shelf.")
			KEY_N:
				if state.next_day():
					_message("New day. Stock and cash carried forward.")

func _spawn_shopper() -> void:
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
	shopper_path = [Vector3(-3, 0.28, 7.3), Vector3(-4.7, 0.28, 5.4), Vector3(-7, 0.28, 5.4)]
	_refresh()

func _leave_shop() -> void:
	shopper_phase = "leaving"
	shopper_path = [Vector3(2, 0.28, 8), Vector3(-1, 0.28, 10.8)]
	_refresh()

func simulate(delta: float) -> void:
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
			shopper_order = state.reserve(1)
			if shopper_order < 0:
				state.walkouts += 1
				_leave_shop()
			else:
				shopper_phase = "walking_to_checkout"
				shopper_path = [Vector3(-4.7, 0.28, 5.4), Vector3(-3, 0.28, 7.3), Vector3(2, 0.28, 8), Vector3(5, 0.28, 8)]
				_refresh()
		"walking_to_checkout":
			shopper_phase = "waiting_at_checkout"
			shopper_patience = 45.0
			_message("Customer ready at Checkout 01. E to serve.")
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
	simulate(delta)
	var target = nearest_target()
	prompt.text = str(target.label) if not target.is_empty() else ""
	notice_timer -= delta
	if notice_timer <= 0:
		notice.text = ""
