extends RefCounted
## Simulation owns stock and integer-cent accounting; visuals only observe it.
signal changed
const Catalog = preload("res://scripts/catalog.gd")
const CASE_SIZE := 12
const CAPACITY := 12
# Legacy first-product constants/accessor retain the original regression contract.
const UNIT_COST := 70
const PRICE := 149
var cash := 50000
var day := 1
var is_open := false
var stocks: Dictionary = {"beans": 0, "oats": 0, "soap": 0}
var prices: Dictionary = {"beans": 149, "oats": 249, "soap": 299}
var shelf: int:
	get: return int(stocks["beans"])
	set(value): stocks["beans"] = value
var carried := 0
var carried_product := ""
var receiving := 0
var receiving_product := ""
var incoming := 0
var incoming_product := ""
var delivery_seconds := 0.0
var orders: Dictionary = {}
var next_order_id := 1
var revenue := 0
var cost_of_goods := 0
var purchases := 0
var sold := 0
var walkouts := 0
var opening_cash := 50000
var last_report: Dictionary = {}

func order_case(product: String = "beans") -> bool:
	if not Catalog.PRODUCTS.has(product):
		return false
	var cost := CASE_SIZE * int(Catalog.PRODUCTS[product].cost)
	if incoming > 0 or receiving > 0 or cash < cost:
		return false
	cash -= cost
	purchases += cost
	incoming = CASE_SIZE
	incoming_product = product
	delivery_seconds = 4.0
	changed.emit()
	return true

func tick(delta: float) -> void:
	if incoming == 0:
		return
	delivery_seconds = maxf(0.0, delivery_seconds - maxf(delta, 0.0))
	if delivery_seconds == 0.0:
		receiving = incoming
		receiving_product = incoming_product
		incoming = 0
		incoming_product = ""
		changed.emit()

func collect_case() -> bool:
	if receiving == 0 or carried > 0:
		return false
	carried = receiving
	carried_product = receiving_product
	receiving = 0
	receiving_product = ""
	changed.emit()
	return true

func restock(product: String = "beans") -> int:
	if not stocks.has(product) or carried_product != product:
		return 0
	# Unpaid reservations still occupy capacity so cancellation cannot overfill.
	var count := mini(carried, CAPACITY - int(stocks[product]) - reserved_units(product))
	if count <= 0:
		return 0
	stocks[product] += count
	carried -= count
	if carried == 0:
		carried_product = ""
	changed.emit()
	return count

func reserved_units(product: String = "") -> int:
	var total := 0
	for order in orders.values():
		if product.is_empty() or order.product == product:
			total += int(order.quantity)
	return total

func set_price(product: String, cents: int) -> bool:
	if not prices.has(product) or cents < 1 or cents > 9999:
		return false
	prices[product] = cents
	changed.emit()
	return true

func reserve(quantity: int = 1, product: String = "beans") -> int:
	if not stocks.has(product) or not is_open or quantity <= 0 or int(stocks[product]) < quantity:
		return -1
	var id := next_order_id
	next_order_id += 1
	stocks[product] -= quantity
	# Snapshot price at pickup; later shelf-price edits do not reprice this basket.
	orders[id] = {"product": product, "quantity": quantity, "unit_price": int(prices[product]), "unit_cost": int(Catalog.PRODUCTS[product].cost)}
	changed.emit()
	return id

func checkout(id: int) -> bool:
	if not orders.has(id):
		return false
	var order: Dictionary = orders[id]
	orders.erase(id)
	var quantity := int(order.quantity)
	var total := quantity * int(order.unit_price)
	cash += total
	revenue += total
	cost_of_goods += quantity * int(order.unit_cost)
	sold += quantity
	changed.emit()
	return true

func cancel(id: int) -> bool:
	if not orders.has(id):
		return false
	var order: Dictionary = orders[id]
	stocks[order.product] += int(order.quantity)
	orders.erase(id)
	walkouts += 1
	changed.emit()
	return true

func open_store() -> void:
	is_open = true
	last_report = {}
	changed.emit()

func daily_report() -> Dictionary:
	return {"day": day, "revenue": revenue, "cost_of_goods": cost_of_goods,
		"gross_profit": revenue - cost_of_goods, "purchases": purchases,
		"cash": cash, "cash_change": cash - opening_cash, "sold": sold, "walkouts": walkouts}

func close_store() -> Dictionary:
	is_open = false
	for id in orders.keys():
		cancel(id)
	last_report = daily_report()
	changed.emit()
	return last_report.duplicate()

func next_day() -> bool:
	if is_open or last_report.is_empty():
		return false
	day += 1
	opening_cash = cash
	revenue = 0
	cost_of_goods = 0
	purchases = 0
	sold = 0
	walkouts = 0
	last_report = {}
	changed.emit()
	return true

func save_data() -> Dictionary:
	# Transient shoppers are not saved. Return their units in the saved snapshot
	# without changing the running game or counting a restart as a walkout.
	var saved_stocks = stocks.duplicate()
	for order in orders.values():
		saved_stocks[order.product] += int(order.quantity)
	return {"version": 1, "cash": cash, "day": day, "opening_cash": opening_cash,
		"revenue": revenue, "cost_of_goods": cost_of_goods, "purchases": purchases,
		"sold": sold, "walkouts": walkouts, "next_order_id": next_order_id,
		"stocks": saved_stocks, "prices": prices.duplicate(),
		"carried": carried, "carried_product": carried_product,
		"receiving": receiving, "receiving_product": receiving_product,
		"incoming": incoming, "incoming_product": incoming_product,
		"delivery_seconds": delivery_seconds, "day_closed": not last_report.is_empty()}

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

func apply_save(data: Variant) -> String:
	# Validate everything before touching live state. JSON numbers may be floats.
	if not data is Dictionary or not _whole(data.get("version"), 1, 1):
		return "Unsupported save version or malformed save."
	for field in ["cash", "opening_cash", "revenue", "cost_of_goods", "purchases"]:
		if not _whole(data.get(field), 0, 9000000000000):
			return "Invalid money field: " + field
	for field in ["day", "next_order_id"]:
		if not _whole(data.get(field), 1, 1000000000):
			return "Invalid counter: " + field
	for field in ["sold", "walkouts"]:
		if not _whole(data.get(field), 0, 1000000000):
			return "Invalid counter: " + field
	if int(data.cash) != int(data.opening_cash) + int(data.revenue) - int(data.purchases):
		return "Save cash does not reconcile."
	if not data.get("stocks") is Dictionary or not data.get("prices") is Dictionary or data.stocks.size() != Catalog.IDS.size() or data.prices.size() != Catalog.IDS.size():
		return "Invalid product inventory."
	var saved_stocks: Dictionary = {}
	var saved_prices: Dictionary = {}
	for product in Catalog.IDS:
		if not _whole(data.stocks.get(product), 0, CAPACITY) or not _whole(data.prices.get(product), 1, 9999):
			return "Invalid stock or price for " + product
		saved_stocks[product] = int(data.stocks[product])
		saved_prices[product] = int(data.prices[product])
	for field in ["carried", "receiving", "incoming"]:
		if not _whole(data.get(field), 0, CASE_SIZE):
			return "Invalid case quantity."
		var product = data.get(field + "_product")
		if not product is String or (int(data[field]) == 0 and product != "") or (int(data[field]) > 0 and not Catalog.PRODUCTS.has(product)):
			return "Invalid case product."
	if not _whole(data.receiving, 0, 0) and int(data.receiving) != CASE_SIZE:
		return "Incomplete receiving case."
	if not _whole(data.incoming, 0, 0) and int(data.incoming) != CASE_SIZE:
		return "Incomplete incoming case."
	if int(data.receiving) > 0 and int(data.incoming) > 0:
		return "Receiving slot is overbooked."
	var seconds = data.get("delivery_seconds")
	if not (typeof(seconds) == TYPE_FLOAT or typeof(seconds) == TYPE_INT) or not is_finite(float(seconds)) or seconds < 0 or seconds > 4:
		return "Invalid delivery timer."
	if (int(data.incoming) == 0) != (float(seconds) == 0.0):
		return "Delivery timer does not match the incoming case."
	if not data.get("day_closed") is bool:
		return "Invalid day state."
	for field in ["cash", "day", "opening_cash", "revenue", "cost_of_goods", "purchases", "sold", "walkouts", "next_order_id", "carried", "receiving", "incoming"]:
		set(field, int(data[field]))
	stocks = saved_stocks
	prices = saved_prices
	carried_product = data.carried_product
	receiving_product = data.receiving_product
	incoming_product = data.incoming_product
	delivery_seconds = float(seconds)
	orders.clear()
	is_open = false
	last_report = daily_report() if data.day_closed else {}
	changed.emit()
	return ""
