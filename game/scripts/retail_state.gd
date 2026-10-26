extends RefCounted
## Simulation owns inventory and integer-cent accounting; visuals only observe it.
signal changed

const CASE_SIZE := 12
const UNIT_COST := 70
const PRICE := 149
const CAPACITY := 12
var cash := 50000
var day := 1
var is_open := false
var shelf := 0
var carried := 0
var receiving := 0
var incoming := 0
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

func order_case() -> bool:
	var cost := CASE_SIZE * UNIT_COST
	if incoming > 0 or receiving > 0 or cash < cost:
		return false
	cash -= cost
	purchases += cost
	incoming = CASE_SIZE
	delivery_seconds = 4.0
	changed.emit()
	return true

func tick(delta: float) -> void:
	if incoming == 0:
		return
	delivery_seconds = maxf(0.0, delivery_seconds - maxf(delta, 0.0))
	if delivery_seconds == 0.0:
		receiving += incoming
		incoming = 0
		changed.emit()

func collect_case() -> bool:
	if receiving == 0 or carried > 0:
		return false
	carried = receiving
	receiving = 0
	changed.emit()
	return true

func restock() -> int:
	# Reserved units still occupy their shelf slots until the order is settled.
	var count := mini(carried, CAPACITY - shelf - reserved_units())
	if count <= 0:
		return 0
	shelf += count
	carried -= count
	changed.emit()
	return count

func reserved_units() -> int:
	var total := 0
	for order in orders.values():
		total += int(order["quantity"])
	return total

func reserve(quantity: int = 1) -> int:
	if not is_open or quantity <= 0 or shelf < quantity:
		return -1
	var id := next_order_id
	next_order_id += 1
	shelf -= quantity
	orders[id] = {"quantity": quantity, "unit_price": PRICE, "unit_cost": UNIT_COST}
	changed.emit()
	return id

func checkout(id: int) -> bool:
	if not orders.has(id):
		return false
	var order: Dictionary = orders[id]
	orders.erase(id) # Consume once before updating money.
	var quantity := int(order["quantity"])
	var total := quantity * int(order["unit_price"])
	cash += total
	revenue += total
	cost_of_goods += quantity * int(order["unit_cost"])
	sold += quantity
	changed.emit()
	return true

func cancel(id: int) -> bool:
	if not orders.has(id):
		return false
	shelf += int(orders[id]["quantity"])
	orders.erase(id)
	walkouts += 1
	changed.emit()
	return true

func open_store() -> void:
	is_open = true
	last_report = {}
	changed.emit()

func close_store() -> Dictionary:
	is_open = false
	for id in orders.keys():
		cancel(id)
	last_report = {"day": day, "revenue": revenue, "cost_of_goods": cost_of_goods,
		"gross_profit": revenue - cost_of_goods, "purchases": purchases,
		"cash": cash, "cash_change": cash - opening_cash, "sold": sold, "walkouts": walkouts}
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
