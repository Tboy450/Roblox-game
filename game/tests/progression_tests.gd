extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Saves = preload("res://scripts/save_store.gd")

static func _write(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

static func _key(world, code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	world._unhandled_input(event)

static func run(check: Callable, directory: String) -> void:
	var state = State.new()
	for product in Catalog.IDS:
		check.call(state.order_case(product), "Supplier accepts " + product)
		state.tick(4)
		check.call(state.collect_case(), "Receiving preserves product type: " + product)
		if product != "beans":
			check.call(state.restock("beans") == 0 and state.carried == 12, "Mismatched case cannot stock beans")
		check.call(state.restock(product) == 12, "Matching case stocks " + product)
	check.call(state.cash == 46340 and state.purchases == 3660, "Three supplier costs reconcile independently")
	check.call(state.stocks == {"beans": 12, "oats": 12, "soap": 12}, "Product inventory is separate")
	check.call(not state.order_case("unknown") and not state.set_price("unknown", 100), "Unknown products are rejected")
	check.call(not state.set_price("beans", 0) and not state.set_price("beans", 10000), "Editable prices stay in supported cent range")
	state.set_price("beans", 199)
	state.open_store()
	var bean_order = state.reserve(2, "beans")
	state.set_price("beans", 279)
	check.call(state.orders[bean_order].unit_price == 199, "Active basket retains the quoted pickup price")
	check.call(state.checkout(bean_order) and state.revenue == 398 and state.cost_of_goods == 140, "Checkout charges the quoted price with the matching supplier cost")
	var soap_order = state.reserve(3, "soap")
	check.call(state.cancel(soap_order) and state.stocks.soap == 12 and state.stocks.beans == 10, "Refund returns the correct product only")
	var oat_order = state.reserve(1, "oats")
	var snapshot = state.save_data()
	check.call(state.orders.has(oat_order) and state.stocks.oats == 11 and snapshot.stocks.oats == 12, "Saving normalizes unpaid goods without changing the live basket")
	var loaded = State.new()
	check.call(loaded.apply_save(JSON.parse_string(JSON.stringify(snapshot))).is_empty(), "Save round-trips through real JSON number types")
	check.call(not loaded.is_open and loaded.orders.is_empty() and loaded.stocks.oats == 12, "Resume closes store and restores unpaid goods exactly once")
	check.call(loaded.cash == state.cash and loaded.prices.beans == 279 and loaded.revenue == 398, "Cash, prices and daily counters survive resume")
	var baseline = JSON.stringify(loaded.save_data())
	var damaged: Array = []
	var bad = snapshot.duplicate(true)
	bad.cash = -1
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.prices.soap = 12.5
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.stocks.oats = 13
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.stocks.erase("beans")
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.carried = 3
	bad.carried_product = "unknown"
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.delivery_seconds = 3
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.version = 2
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.day_closed = "true"
	damaged.append(bad)
	bad = snapshot.duplicate(true)
	bad.cash += 1
	damaged.append(bad)
	for malformed in damaged:
		check.call(not loaded.apply_save(malformed).is_empty() and JSON.stringify(loaded.save_data()) == baseline, "Invalid save is rejected without partial state mutation")
	check.call(not loaded.apply_save([]).is_empty(), "Non-object saves are rejected")
	# Partly carried and in-transit cases are durable, including delivery timing.
	check.call(loaded.order_case("beans"), "Order before saving supplier pipeline")
	loaded.tick(4)
	loaded.collect_case()
	loaded.restock("beans")
	loaded.order_case("soap")
	loaded.tick(1.5)
	var pipeline = State.new()
	check.call(pipeline.apply_save(loaded.save_data()).is_empty() and pipeline.carried == 10 and pipeline.carried_product == "beans" and pipeline.incoming_product == "soap", "Partial carried case and incoming product survive resume")
	pipeline.tick(2.49)
	check.call(pipeline.incoming == 12, "Saved delivery does not arrive early")
	pipeline.tick(0.02)
	check.call(pipeline.receiving_product == "soap" and pipeline.receiving == 12, "Saved delivery finishes once")
	var path = directory.path_join("progress.json")
	check.call(Saves.save(loaded, path).ok, "Initial durable save succeeds")
	loaded.set_price("oats", 333)
	check.call(Saves.save(loaded, path).ok and FileAccess.file_exists(path + ".bak"), "Replacement save retains a valid backup")
	var file_loaded = State.new()
	check.call(Saves.load_into(file_loaded, path).ok and file_loaded.prices.oats == 333, "Primary save reloads current prices")
	_write(path, "{broken")
	var recovery = Saves.load_into(file_loaded, path)
	check.call(recovery.ok and recovery.recovered and file_loaded.prices.oats == 249, "Damaged primary recovers the previous valid save")
	check.call(Saves.save(loaded, path).ok, "Recovery can resume saving without discarding the good backup")
	_write(path, "{broken again")
	check.call(Saves.load_into(file_loaded, path).ok and file_loaded.prices.oats == 249, "Saving after corruption preserves the existing valid backup")
	var future = loaded.save_data()
	future.version = 2
	var future_text = JSON.stringify(future)
	_write(path, future_text)
	baseline = JSON.stringify(file_loaded.save_data())
	check.call(not Saves.load_into(file_loaded, path).ok and JSON.stringify(file_loaded.save_data()) == baseline, "A future schema is not silently replaced by an older backup")
	check.call(not Saves.save(loaded, path).ok and FileAccess.get_file_as_string(path) == future_text, "Older game refuses to overwrite a future save")
	future.version = 1000000001
	future_text = JSON.stringify(future)
	_write(path, future_text)
	check.call(not Saves.load_into(file_loaded, path).ok and not Saves.save(loaded, path).ok and FileAccess.get_file_as_string(path) == future_text, "Unknown large future versions remain protected without an arbitrary version ceiling")
	_write(path, "{damaged")
	_write(path + ".bak", "{damaged too")
	check.call(not Saves.load_into(file_loaded, path).ok and JSON.stringify(file_loaded.save_data()) == baseline, "Two damaged files leave the running game unchanged")
	check.call(not Saves.save(loaded, directory.path_join("missing/subfolder/save.json")).ok, "Write failure returns an error")
	state.close_store()
	var closed = State.new()
	check.call(closed.apply_save(state.save_data()).is_empty() and closed.last_report == state.last_report, "Closed-day report is rebuilt from validated ledger data")
	check.call(closed.next_day() and closed.day == 2 and closed.revenue == 0 and closed.stocks.soap == 12, "Day progress and unsold stock survive save and next-day transition")

static func scene_checks(world, check: Callable, directory: String) -> void:
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.shopper_choice = 0
	for product in Catalog.IDS:
		_key(world, KEY_1 + Catalog.IDS.find(product))
		_key(world, KEY_B)
		check.call(world.state.incoming_product == product and Catalog.PRODUCTS[product].name in world.supplier_hint.text, "Product selection and order controls buy the selected goods")
		world.simulate(4)
		world.player.position = Vector3(-8, 0.3, 8.5)
		check.call(world.perform_action("receiving"), "Scene receiving action handles " + product)
		world.player.position = Vector3(float(Catalog.PRODUCTS[product].shelf_x), 0.3, 5.7)
		check.call(world.perform_action("shelf" if product == "beans" else "shelf_" + product), "Scene stocks matching product shelf: " + product)
	check.call(world.stock_root.get_child_count() == 36, "Three shelves render separate stock visuals")
	_key(world, KEY_2)
	for adjustment in range(4):
		_key(world, KEY_BRACKETRIGHT)
	check.call("$2.89" in world.shelf_signs.oats.text, "Shelf price sign reflects a live price edit")
	world.state.open_store()
	for product in Catalog.IDS:
		for step in range(1000):
			world.simulate(0.1)
			if world.shopper_phase == "waiting_at_checkout":
				break
		check.call(world.shopper_phase == "waiting_at_checkout" and world.shopper_product == product, "Shopper selects and reaches checkout for " + product)
		check.call(world._money(world.state.prices[product]) in world.register_display.text, "Register display uses the actual basket total")
		world.player.position = Vector3(3.7, 0.3, 6.2)
		check.call(world.perform_action("checkout"), "Scene completes a typed-product purchase")
		check.call(Catalog.PRODUCTS[product].short in world.receipt_display.text, "Receipt shows the purchased product")
		for step in range(300):
			if not is_instance_valid(world.shopper):
				break
			world.simulate(0.1)
		check.call(not is_instance_valid(world.shopper), "Shopper exits after a completed purchase")
	check.call(world.state.revenue == 737 and world.state.cost_of_goods == 305 and world.state.cash == 47077, "Three in-scene sales reconcile mixed prices and costs")
	world.persistence_enabled = true
	world.save_path = directory.path_join("scene.json")
	world.state.reserve(1, "soap")
	check.call(world._save_game(false) and world.state.reserved_units() == 1, "Scene save leaves the running basket untouched")
	world.state.set_price("soap", 999)
	check.call(world._load_game(false) and world.state.prices.soap == 299 and world.state.stocks.soap == 11 and world.state.reserved_units() == 0, "Scene load restores progress and releases the saved unpaid basket")
	check.call(world._load_game(false) and world.state.stocks.soap == 11, "Repeated loads do not duplicate refunded stock")
	world.state.set_price("soap", 399)
	_write(world.save_path, "{bad")
	_write(world.save_path + ".bak", "{bad")
	check.call(not world._load_game(false) and world.save_blocked and world.save_countdown == -1 and world.state.prices.soap == 399, "Failed manual load pauses pending autosave and preserves current progress")
	world.persistence_enabled = false
