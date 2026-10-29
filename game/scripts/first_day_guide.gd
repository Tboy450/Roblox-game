extends RefCounted
## Derive the next useful action from live or resumed progress; never change it.
const Catalog = preload("res://scripts/catalog.gd")
const Settings = preload("res://scripts/player_settings.gd")

static func _step(index: int, title: String, detail: String, target: String = "") -> Dictionary:
	return {"step": index, "total": 8, "title": title, "detail": detail, "target": target}

static func current(state, shopper_phase: String, keys: Dictionary = {}) -> Dictionary:
	if state.day > 1:
		return {}
	if keys.is_empty():
		keys = Settings.new().labels()
	if state.sold > 0:
		if not state.last_report.is_empty():
			return _step(8, "First day complete", "Review your report. %s begins the next day, keeping your cash and stock." % keys.next_day)
		if state.is_open:
			return _step(7, "Close and review", "Your first sale is complete. Press %s to close and review the day's accounts." % keys.open_close)
		return _step(7, "Finish your resumed day", "Your sale is saved. Press %s to reopen, then %s to close and prepare the report." % [keys.open_close, keys.open_close])
	if state.carried > 0:
		var product: String = state.carried_product
		if int(state.stocks[product]) + state.reserved_units(product) < state.CAPACITY:
			var slot = state.slot_for_product(product)
			return _step(4, "Stock " + Catalog.PRODUCTS[product].short, "Look at the matching shelf and press %s. The NEXT marker follows its assigned location." % keys.interact, "shelf" if slot == "beans" else "shelf_" + slot)
		if not state.is_open:
			return _step(5, "Make room for your case", "This shelf is full. Press %s to open; sell goods before restocking the remaining case." % keys.open_close)
	if state.receiving > 0 and state.carried == 0:
		return _step(3, "Collect your delivery", "Walk to Receiving, look toward the table and press %s to pick up the case." % keys.interact, "receiving")
	if state.incoming > 0 and state.carried == 0:
		return _step(2, "Delivery on its way", "Head to Receiving. Your case arrives in %.1f seconds; %s collects it after arrival." % [state.delivery_seconds, keys.interact], "receiving")
	var stocked: int = state.reserved_units()
	for quantity in state.stocks.values():
		stocked += int(quantity)
	if stocked > 0:
		if not state.is_open:
			return _step(5, "Open for shoppers", "Your goods are stocked. Press %s to open the store." % keys.open_close)
		if shopper_phase == "waiting_at_checkout":
			return _step(6, "Serve your first shopper", "Approach Checkout 01 and press %s to complete the quoted sale." % keys.interact, "checkout")
		return _step(6, "A shopper is on the way", "Leave the store open while a shopper picks up goods. Wait at Checkout 01 until they are ready.", "checkout")
	var goods := PackedStringArray()
	var select := PackedStringArray()
	for index in range(Catalog.IDS.size()):
		goods.append(Catalog.PRODUCTS[Catalog.IDS[index]].short.to_lower())
		select.append(keys["select_%d" % (index + 1)])
	return _step(1, "Order your first case", "Choose %s or %s with %s, then press %s to order a case." % [", ".join(goods.slice(0, -1)), goods[-1], " / ".join(select), keys.buy_case])
