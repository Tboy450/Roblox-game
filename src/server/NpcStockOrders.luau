-- Server-owned reservations keep abandoned baskets from deleting shelf stock.
local NpcStockOrders = {}

function NpcStockOrders.new(getStock, setStock, getProduct)
	local pending = {}
	local nextId = 0
	local ledger = {}

	function ledger.create(store, shelves, wantedItems)
		if store:GetAttribute("StoreOpen") == false then
			return nil
		end
		local order = { store = store, items = {}, reservations = {}, itemCount = 0, totalCents = 0 }
		for _ = 1, wantedItems do
			local available = {}
			for _, shelf in shelves do
				if shelf:IsDescendantOf(store) and getStock(shelf) > 0 then
					table.insert(available, shelf)
				end
			end
			if #available == 0 then
				break
			end
			local shelf = available[math.random(1, #available)]
			local departmentIndex, productIndex, _, product = getProduct(shelf)
			setStock(shelf, getStock(shelf) - 1)
			order.itemCount += 1
			order.totalCents += product.priceCents
			table.insert(order.items, { name = product.name, priceCents = product.priceCents })
			table.insert(order.reservations, { shelf = shelf, departmentIndex = departmentIndex, productIndex = productIndex })
		end
		if order.itemCount == 0 then
			return nil
		end
		nextId += 1
		pending[nextId] = order
		return nextId
	end

	function ledger.finish(store, id)
		local order = pending[id]
		if not order or order.store ~= store or store:GetAttribute("StoreOpen") == false then
			return nil
		end
		pending[id] = nil
		return order
	end

	function ledger.cancel(id)
		local order = pending[id]
		if not order then
			return false
		end
		pending[id] = nil
		local recovered = 0
		for _, reservation in order.reservations do
			local shelf = reservation.shelf
			if shelf:IsDescendantOf(order.store)
				and shelf:GetAttribute("ShelfDepartmentIndex") == reservation.departmentIndex
				and shelf:GetAttribute("ShelfProductIndex") == reservation.productIndex
				and getStock(shelf) < shelf:GetAttribute("ShelfCapacity") then
				setStock(shelf, getStock(shelf) + 1)
			else
				recovered += 1
			end
		end
		if recovered > 0 then
			order.store:SetAttribute("RecoveredStockUnits", (order.store:GetAttribute("RecoveredStockUnits") or 0) + recovered)
		end
		return true
	end

	function ledger.cancelStore(store)
		for id, order in pending do
			if order.store == store then
				ledger.cancel(id)
			end
		end
	end

	return ledger
end

return NpcStockOrders
