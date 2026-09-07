local Orders = require("../src/server/NpcStockOrders")
local function fixture()
	local store = { attributes = { StoreOpen = true } }
	function store:GetAttribute(key) return self.attributes[key] end
	function store:SetAttribute(key, value) self.attributes[key] = value end
	local shelf = { owner = store, attributes = { ShelfDepartmentIndex = 1, ShelfProductIndex = 1, ShelfCapacity = 9, ShelfStock = 9 } }
	shelf.GetAttribute = store.GetAttribute
	shelf.SetAttribute = store.SetAttribute
	function shelf:IsDescendantOf(parent) return self.owner == parent end
	local ledger = Orders.new(function(unit) return unit:GetAttribute("ShelfStock") end,
		function(unit, count) unit:SetAttribute("ShelfStock", count) end,
		function(unit) return unit:GetAttribute("ShelfDepartmentIndex"), unit:GetAttribute("ShelfProductIndex"), {}, { name = "Milk", priceCents = 349 } end)
	return ledger, store, shelf
end

do
	local ledger, store, shelf = fixture()
	local id = ledger.create(store, { shelf }, 3)
	assert(shelf:GetAttribute("ShelfStock") == 6, "A basket must reserve actual stock")
	assert(ledger.cancel(id), "Abandoned order should be cancellable")
	assert(shelf:GetAttribute("ShelfStock") == 9, "Cancellation must restore all items")
	assert(not ledger.cancel(id), "Repeated cancellation must not duplicate stock")
	assert(ledger.finish(store, id) == nil, "Cancelled orders cannot pay out")
end
do
	local ledger, store, shelf = fixture()
	local id = ledger.create(store, { shelf }, 4)
	local order = ledger.finish(store, id)
	assert(order.itemCount == 4 and order.totalCents == 1396, "Receipt must match reserved products")
	assert(ledger.finish(store, id) == nil, "A sale cannot be counted twice")
	assert(not ledger.cancel(id) and shelf:GetAttribute("ShelfStock") == 5, "Sold items cannot be returned by trip cleanup")
end
do
	local ledger, store, shelf = fixture()
	local first = ledger.create(store, { shelf }, 4)
	local second = ledger.create(store, { shelf }, 4)
	store:SetAttribute("StoreOpen", false)
	assert(ledger.create(store, { shelf }, 1) == nil, "Closed stores cannot reserve stock")
	assert(ledger.finish(store, first) == nil, "Closed stores cannot process abandoned baskets")
	ledger.cancelStore(store)
	assert(shelf:GetAttribute("ShelfStock") == 9, "Closing must return every pending basket")
	store:SetAttribute("StoreOpen", true)
	assert(ledger.finish(store, second) == nil, "Reopening must not revive cancelled orders")
end
do
	local ledger, store, shelf = fixture()
	local id = ledger.create(store, { shelf }, 2)
	shelf:SetAttribute("ShelfProductIndex", 2)
	ledger.cancel(id)
	assert(shelf:GetAttribute("ShelfStock") == 7, "Returns cannot refill a different product")
	assert(store:GetAttribute("RecoveredStockUnits") == 2, "Changed products must return to stock collection")
end
do
	local ledger, store, shelf = fixture()
	local id = ledger.create(store, { shelf }, 2)
	shelf:SetAttribute("ShelfStock", 9)
	ledger.cancel(id)
	assert(shelf:GetAttribute("ShelfStock") == 9 and store:GetAttribute("RecoveredStockUnits") == 2, "Restocked shelves must send overflow to collection")
end
do
	local ledger, store, shelf = fixture()
	shelf:SetAttribute("ShelfStock", 1)
	local id = ledger.create(store, { shelf }, 4)
	assert(ledger.create(store, { shelf }, 4) == nil, "Empty shelves cannot create a sale")
	assert(ledger.finish({}, id) == nil, "Another store cannot claim this reservation")
	assert(ledger.finish(store, id).itemCount == 1, "An order must not oversell a shelf")
end
print("PASS: NPC reservations, refunds, closing/reopening, exact totals, and duplicate checkout prevention")
