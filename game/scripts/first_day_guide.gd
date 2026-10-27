extends RefCounted
## Derive the next useful action from live or resumed progress; never change it.
const Catalog = preload("res://scripts/catalog.gd")

static func _step(index: int, title: String, detail: String, target: String = "") -> Dictionary:
	return {"step": index, "total": 8, "title": title, "detail": detail, "target": target}

static func current(state, shopper_phase: String) -> Dictionary:
	if state.day > 1:
		return {}
	if state.sold > 0:
		if not state.last_report.is_empty():
			return _step(8, "First day complete", "Review your report. N begins the next day, keeping your cash and stock.")
		if state.is_open:
			return _step(7, "Close and review", "Your first sale is complete. Press O to close and review the day's accounts.")
		return _step(7, "Finish your resumed day", "Your sale is saved. Press O to reopen, then O to close and prepare the report.")
	if state.carried > 0:
		var product: String = state.carried_product
		if int(state.stocks[product]) + state.reserved_units(product) < state.CAPACITY:
			var slot = state.slot_for_product(product)
			return _step(4, "Stock " + Catalog.PRODUCTS[product].short, "Look at the matching shelf and press E. The NEXT marker follows its assigned location.", "shelf" if slot == "beans" else "shelf_" + slot)
		if not state.is_open:
			return _step(5, "Make room for your case", "This shelf is full. Press O to open; sell goods before restocking the remaining case.")
	if state.receiving > 0 and state.carried == 0:
		return _step(3, "Collect your delivery", "Walk to Receiving, look toward the table and press E to pick up the case.", "receiving")
	if state.incoming > 0 and state.carried == 0:
		return _step(2, "Delivery on its way", "Head to Receiving. Your case arrives in %.1f seconds; E collects it after arrival." % state.delivery_seconds, "receiving")
	var stocked: int = state.reserved_units()
	for quantity in state.stocks.values():
		stocked += int(quantity)
	if stocked > 0:
		if not state.is_open:
			return _step(5, "Open for shoppers", "Your goods are stocked. Press O to open the store.")
		if shopper_phase == "waiting_at_checkout":
			return _step(6, "Serve your first shopper", "Approach Checkout 01 and press E to complete the quoted sale.", "checkout")
		return _step(6, "A shopper is on the way", "Leave the store open while a shopper picks up goods. Wait at Checkout 01 until they are ready.", "checkout")
	return _step(1, "Order your first case", "Choose beans, oats or soap with 1 / 2 / 3, then press B to order a case.")
