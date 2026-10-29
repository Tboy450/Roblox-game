extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Catalog = preload("res://scripts/catalog.gd")

static func _key(world, code: Key) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	world._unhandled_input(event)

static func _shows(world, slot: String, product: String, cents: int) -> bool:
	var info: Dictionary = Catalog.PRODUCTS[product]
	var matches = world.price_tags[slot].size() == 4
	for tag in world.price_tags[slot]:
		matches = matches and tag.card.is_visible_in_tree() and tag.title.text == info.name.to_upper()
		matches = matches and tag.price.text == world._money(cents) and tag.accent.albedo_color == Color(info.color)
	return matches

static func scene_checks(world, check: Callable, _directory: String) -> void:
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	world._refresh()
	var defaults = true
	for product in Catalog.IDS:
		defaults = defaults and _shows(world, product, product, Catalog.PRODUCTS[product].price)
	check.call(defaults, "Every product shelf tier carries a tag with its goods, colour and price")
	var fits = true
	var font = ThemeDB.fallback_font
	var tag: Dictionary = world.price_tags.beans[0]
	for product in Catalog.IDS:
		var title_width = font.get_string_size(Catalog.PRODUCTS[product].name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, tag.title.font_size).x * tag.title.pixel_size
		fits = fits and title_width <= world.PRICE_TAG_WIDTH - 0.02
	var price_width = font.get_string_size(world._money(9999), HORIZONTAL_ALIGNMENT_LEFT, -1, tag.price.font_size).x * tag.price.pixel_size
	check.call(fits and price_width <= world.PRICE_TAG_WIDTH - 0.02, "Longest product name and highest allowed price fit on the tag")
	var on_rail = true
	for slot in Catalog.IDS:
		for tier in range(4):
			var at: Vector3 = world.price_tags[slot][tier].card.global_position
			on_rail = on_rail and is_equal_approx(at.x, Catalog.PRODUCTS[slot].shelf_x) and at.z > float(Catalog.PRODUCTS[slot].shelf_z) + 0.546 and at.z < float(Catalog.PRODUCTS[slot].shelf_z) + 0.56
			on_rail = on_rail and (tier == 0 or at.y > world.price_tags[slot][tier - 1].card.global_position.y + 0.6)
	check.call(on_rail, "Tags sit on each tier's rail face, inside the shelf collision proxy")
	_key(world, KEY_2)
	_key(world, KEY_BRACKETRIGHT)
	check.call(_shows(world, "oats", "oats", 259) and _shows(world, "beans", "beans", 149) and _shows(world, "soap", "soap", 299), "Price keys update only the selected product's tags")
	var snapshot = world.state.save_data()
	world.player.position = Vector3(-7, 0.3, 5.7)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	_key(world, KEY_3)
	_key(world, KEY_R)
	check.call(_shows(world, "beans", "soap", 299) and _shows(world, "soap", "beans", 149), "Swapping shelves moves tag names, prices and colours with the goods")
	world.state.set_price("soap", 349)
	check.call(_shows(world, "beans", "soap", 349) and _shows(world, "oats", "oats", 259), "A swapped product's price change reaches its new physical shelf")
	check.call(world.state.apply_save(snapshot).is_empty() and _shows(world, "beans", "beans", 149) and _shows(world, "oats", "oats", 259) and _shows(world, "soap", "soap", 299), "Loading progress restores tags from saved layout and prices")
	world.selected_product = "beans"
