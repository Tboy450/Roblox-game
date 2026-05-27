local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local connectedPrompts: { [ProximityPrompt]: RBXScriptConnection } = {}
local RetailCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RetailCatalog"))
local RetailCurrency = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RetailCurrency"))
local retailRemotes = ReplicatedStorage:FindFirstChild("RetailRemotes")
if not retailRemotes then
	retailRemotes = Instance.new("Folder")
	retailRemotes.Name = "RetailRemotes"
	retailRemotes.Parent = ReplicatedStorage
end

local openShelfEditor = retailRemotes:FindFirstChild("OpenShelfEditor")
if not openShelfEditor then
	openShelfEditor = Instance.new("RemoteEvent")
	openShelfEditor.Name = "OpenShelfEditor"
	openShelfEditor.Parent = retailRemotes
end

local selectShelfProduct = retailRemotes:FindFirstChild("SelectShelfProduct")
if not selectShelfProduct then
	selectShelfProduct = Instance.new("RemoteEvent")
	selectShelfProduct.Name = "SelectShelfProduct"
	selectShelfProduct.Parent = retailRemotes
end

local function getRemoteEvent(name: string): RemoteEvent
	local remote = retailRemotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = retailRemotes
	end

	return remote :: RemoteEvent
end

local openRegisterPanel = getRemoteEvent("OpenRegisterPanel")
local updateRegisterPanel = getRemoteEvent("UpdateRegisterPanel")
local adjustRegisterChange = getRemoteEvent("AdjustRegisterChange")
local resetRegisterChange = getRemoteEvent("ResetRegisterChange")
local finishRegisterSale = getRemoteEvent("FinishRegisterSale")
local openPlayerMenu = getRemoteEvent("OpenPlayerMenu")
local requestStoreToggle = getRemoteEvent("RequestStoreToggle")
local processNpcCheckout = retailRemotes:FindFirstChild("ProcessNpcCheckout")
if not processNpcCheckout then
	processNpcCheckout = Instance.new("BindableFunction")
	processNpcCheckout.Name = "ProcessNpcCheckout"
	processNpcCheckout.Parent = retailRemotes
end
local createNpcOrder = retailRemotes:FindFirstChild("CreateNpcOrder")
if not createNpcOrder then
	createNpcOrder = Instance.new("BindableFunction")
	createNpcOrder.Name = "CreateNpcOrder"
	createNpcOrder.Parent = retailRemotes
end

type RegisterState = {
	itemCount: number,
	totalCents: number,
	paidCents: number,
	changeGivenCents: number,
	items: { { name: string, priceCents: number } },
	receiptNumber: number,
	completed: boolean?,
}

local registerStates: { [string]: RegisterState } = {}
local ORDER_PRODUCTS = {}
for _, department in RetailCatalog.departments do
	for _, product in department.products do
		table.insert(ORDER_PRODUCTS, product)
	end
end
local CUSTOMER_TENDER = { 500, 1000, 2000, 5000, 10000 }
local receiptCounter = 1000
local ALLOWED_DENOMINATIONS: { [number]: boolean } = {}
for _, denomination in RetailCurrency.denominations do
	ALLOWED_DENOMINATIONS[denomination.cents] = true
end
local ACTION_COOLDOWNS = {
	ClockIn = 0.8,
	CollectItem = 0.2,
	Checkout = 0.8,
	InspectSign = 1.2,
	InspectDisplay = 4,
	BakeBatch = 6,
	FillPrescription = 6,
	OpenDock = 4,
	CheckTemperature = 6,
	PickupOrder = 5,
	CleanSpill = 8,
	TakeTrash = 6,
	ReturnCart = 4,
	CollectStock = 0.8,
	RestockShelf = 0.35,
	ConfigureShelf = 0.5,
	ServiceCustomer = 3,
	ServeCustomer = 2,
	QueueCustomer = 2,
	QueueServiceCustomer = 1.5,
	ProcessReturn = 2,
	ResolveComplaint = 3,
	ServicePickup = 2,
	RestockServiceBags = 1,
	CheckLostFound = 1.5,
	OpenPlayerRegister = 0.5,
	OpenPetMenu = 0.5,
	CarePet = 6,
	ToggleStoreOpen = 1,
}
local SHIFT_REQUIRED_ACTIONS: { [string]: boolean } = {
	CollectItem = true,
	InspectDisplay = true,
	BakeBatch = true,
	FillPrescription = true,
	OpenDock = true,
	CheckTemperature = true,
	PickupOrder = true,
	CleanSpill = true,
	TakeTrash = true,
	ReturnCart = true,
	CollectStock = true,
	RestockShelf = true,
	ConfigureShelf = true,
	ServiceCustomer = true,
	ServeCustomer = true,
	QueueCustomer = true,
	QueueServiceCustomer = true,
	ProcessReturn = true,
	ResolveComplaint = true,
	ServicePickup = true,
	RestockServiceBags = true,
	CheckLostFound = true,
	Checkout = true,
	OpenPlayerRegister = true,
	CarePet = true,
}
local lastActionAt: { [Player]: { [string]: number } } = {}

local function getStat(player: Player, name: string): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local stat = leaderstats:FindFirstChild(name)
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end

	return stat :: IntValue
end

local function setupPlayer(player: Player)
	getStat(player, "Cash").Value = 1500
	getStat(player, "Basket").Value = 0
	getStat(player, "BasketValue").Value = 0
	getStat(player, "Stock").Value = 0
	getStat(player, "Tasks").Value = 0
	getStat(player, "Shift").Value = 0
	getStat(player, "Customers").Value = 0
	player:SetAttribute("RetailMessage", "Ready for work")
end

local function message(player: Player, text: string)
	player:SetAttribute("RetailMessage", text)
	print(`[RetailMechanics] {player.Name}: {text}`)
end

local function actionIsCoolingDown(player: Player, action: string, target: BasePart): boolean
	local cooldown = ACTION_COOLDOWNS[action]
	if not cooldown or cooldown <= 0 then
		return false
	end

	local perPlayer = lastActionAt[player]
	if not perPlayer then
		perPlayer = {}
		lastActionAt[player] = perPlayer
	end

	local key = `{action}:{target:GetFullName()}`
	local now = os.clock()
	local last = perPlayer[key]
	if last and now - last < cooldown then
		return true
	end

	perPlayer[key] = now
	return false
end

local function getShelfUnit(target: BasePart): Model?
	local current: Instance? = target
	while current do
		if current:IsA("Model") and current:GetAttribute("ShelfId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function updateSignText(sign: BasePart, text: string)
	for _, desc in sign:GetDescendants() do
		if desc:IsA("TextLabel") then
			desc.Text = text
		end
	end
end

local function updatePromptText(part: BasePart, text: string)
	for _, child in part:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child.ObjectText = text
		end
	end
end

local function updateStoreOpenVisuals(store: Instance)
	local storeOpen = store:GetAttribute("StoreOpen") ~= false
	for _, desc in store:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("StoreOpenControl") == true then
			desc.Color = if storeOpen then Color3.fromRGB(56, 116, 74) else Color3.fromRGB(132, 72, 62)
			for _, child in desc:GetChildren() do
				if child:IsA("ProximityPrompt") then
					child.ActionText = if storeOpen then "Close" else "Open"
					child.ObjectText = if storeOpen then "Store Open" else "Store Closed"
				end
			end
		elseif desc:IsA("BasePart") and desc:GetAttribute("StoreStatusDisplay") == true then
			desc.Color = if storeOpen then Color3.fromRGB(52, 120, 72) else Color3.fromRGB(132, 72, 62)
			updateSignText(desc, if storeOpen then "OPEN" else "CLOSED")
		end
	end
end

local function setStoreOpenFromPlayer(player: Player?, store: Instance, nextOpen: boolean)
	store:SetAttribute("StoreOpen", nextOpen)
	updateStoreOpenVisuals(store)
	if player then
		message(player, if nextOpen then "Store opened - shoppers can enter" else "Store closed - shoppers will leave and new arrivals pause")
	end
end

local SERVICE_ATTRIBUTE_DEFAULTS = {
	ServiceQueue = 0,
	ServiceReturns = 3,
	ServicePickupOrders = 2,
	ServiceBags = 6,
	ServiceSatisfaction = 75,
	ServiceTicketsHandled = 0,
}

local function getRetailStoreFromTarget(target: BasePart): Instance?
	return target:FindFirstAncestor("RetailStore") or Workspace:FindFirstChild("RetailStore")
end

local function readServiceAttribute(store: Instance, attributeName: string): number
	local defaultValue = SERVICE_ATTRIBUTE_DEFAULTS[attributeName] or 0
	local value = store:GetAttribute(attributeName)
	if typeof(value) ~= "number" then
		value = defaultValue
		store:SetAttribute(attributeName, value)
	end
	return value
end

local function setServiceAttribute(store: Instance, attributeName: string, value: number)
	store:SetAttribute(attributeName, math.max(0, math.floor(value)))
end

local function updateServiceAreaVisuals(store: Instance)
	local queue = readServiceAttribute(store, "ServiceQueue")
	local returns = readServiceAttribute(store, "ServiceReturns")
	local pickups = readServiceAttribute(store, "ServicePickupOrders")
	local bags = readServiceAttribute(store, "ServiceBags")
	local satisfaction = readServiceAttribute(store, "ServiceSatisfaction")

	for _, desc in store:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("ServiceStatusDisplay") == true then
			local color = if queue > 3 or returns > 3 then Color3.fromRGB(136, 94, 58) else Color3.fromRGB(54, 92, 118)
			desc.Color = color
			updateSignText(desc, `QUEUE {queue} | RETURNS {returns} | PICKUP {pickups}`)
		elseif desc:IsA("BasePart") and desc:GetAttribute("ServiceDesk") == true then
			desc.Color = if queue > 0 then Color3.fromRGB(98, 98, 104) else Color3.fromRGB(88, 88, 92)
			updatePromptText(desc, if queue > 0 then `Queue {queue}` else "Customer Service")
		elseif desc:IsA("BasePart") and desc:GetAttribute("ServiceReturnBin") == true then
			desc.Color = if returns > 0 then Color3.fromRGB(128, 92, 62) else Color3.fromRGB(84, 76, 68)
			updatePromptText(desc, if returns > 0 then `Returns {returns}` else "Returns Empty")
		elseif desc:IsA("BasePart") and desc:GetAttribute("ServicePickupLockers") == true then
			desc.Color = if pickups > 0 then Color3.fromRGB(58, 72, 92) else Color3.fromRGB(54, 58, 66)
			updatePromptText(desc, if pickups > 0 then `Pickup Orders {pickups}` else "Pickup Empty")
		elseif desc:IsA("BasePart") and desc:GetAttribute("ServiceBagRack") == true then
			desc.Color = if bags <= 2 then Color3.fromRGB(132, 72, 62) else Color3.fromRGB(210, 212, 206)
			updatePromptText(desc, `Bags {bags}/12`)
		end
	end

	store:SetAttribute("ServiceSatisfaction", math.clamp(satisfaction, 0, 100))
end

local function awardCash(player: Player, cents: number)
	getStat(player, "Cash").Value += cents
end

local function getShelfCapacity(unit: Model): number
	return math.max(1, math.floor(unit:GetAttribute("ShelfCapacity") or 9))
end

local function getShelfStock(unit: Model): number
	return math.clamp(math.floor(unit:GetAttribute("ShelfStock") or getShelfCapacity(unit)), 0, getShelfCapacity(unit))
end

local function getShelfProduct(unit: Model)
	local departmentIndex = RetailCatalog.wrapDepartmentIndex(unit:GetAttribute("ShelfDepartmentIndex") or 1)
	local productIndex = RetailCatalog.wrapProductIndex(departmentIndex, unit:GetAttribute("ShelfProductIndex") or 1)
	local department = RetailCatalog.getDepartment(departmentIndex)
	local product = RetailCatalog.getProduct(departmentIndex, productIndex)
	return departmentIndex, productIndex, department, product
end

local function getShelfModels(store: Instance): { Model }
	local shelves = {}
	for _, desc in store:GetDescendants() do
		if desc:IsA("Model") and desc:GetAttribute("ShelfId") ~= nil then
			table.insert(shelves, desc)
		end
	end
	return shelves
end

local function updateStoreInventorySummary(store: Instance)
	local totalUnits = 0
	local lowStockShelves = 0
	local emptyShelves = 0

	for _, shelf in getShelfModels(store) do
		local stock = getShelfStock(shelf)
		totalUnits += stock
		if stock <= 3 then
			lowStockShelves += 1
		end
		if stock == 0 then
			emptyShelves += 1
		end
	end

	store:SetAttribute("StoreInventoryUnits", totalUnits)
	store:SetAttribute("LowStockShelves", lowStockShelves)
	store:SetAttribute("EmptyShelves", emptyShelves)
end

local function refreshShelfVisuals(unit: Model)
	local departmentIndex, productIndex, department, product = getShelfProduct(unit)
	local stock = getShelfStock(unit)

	unit:SetAttribute("ShelfDepartmentIndex", departmentIndex)
	unit:SetAttribute("ShelfProductIndex", productIndex)
	unit:SetAttribute("ShelfDepartmentName", department.name)
	unit:SetAttribute("ShelfProductName", product.name)
	unit:SetAttribute("ShelfCapacity", getShelfCapacity(unit))
	unit:SetAttribute("ShelfStock", stock)

	local topSign = unit:FindFirstChild("TopSign")
	if topSign and topSign:IsA("BasePart") then
		topSign.Color = department.signColor
		updateSignText(topSign, `{string.upper(department.name)} | {string.upper(product.name)}`)
	end

	local productSelector = unit:FindFirstChild("ProductSelector")
	if productSelector and productSelector:IsA("BasePart") then
		productSelector.Color = product.color
		productSelector:SetAttribute("RetailPriceCents", product.priceCents)
		updatePromptText(productSelector, product.name)
	end

	local shelfControl = unit:FindFirstChild("ShelfControl")
	if shelfControl and shelfControl:IsA("BasePart") then
		shelfControl.Color = department.signColor
		updatePromptText(shelfControl, `Set {product.name}`)
	end

	local restockControl = unit:FindFirstChild("RestockControl")
	if restockControl and restockControl:IsA("BasePart") then
		updatePromptText(restockControl, `{product.name} Stock`)
	end

	for _, desc in unit:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("ShelfProductVisual") == true then
			local boardY = desc:GetAttribute("ShelfBoardY")
			local slotIndex = desc:GetAttribute("ShelfSlotIndex")
			desc.Size = product.size
			desc.Color = product.color
			desc.Material = product.material
			desc:SetAttribute("RetailPriceCents", product.priceCents)
			if typeof(boardY) == "number" then
				desc.Position = Vector3.new(desc.Position.X, boardY + product.size.Y / 2 + 0.2, desc.Position.Z)
			end
			local visible = typeof(slotIndex) ~= "number" or slotIndex <= stock
			desc.Transparency = if visible then 0 else 1
			desc.CanCollide = visible
			updatePromptText(desc, product.name)
		end
	end
end

local function applyShelfSelection(unit: Model)
	local departmentIndex, productIndex, department, product = getShelfProduct(unit)
	unit:SetAttribute("ShelfDepartmentIndex", departmentIndex)
	unit:SetAttribute("ShelfProductIndex", productIndex)
	unit:SetAttribute("ShelfDepartmentName", department.name)
	unit:SetAttribute("ShelfProductName", product.name)
	refreshShelfVisuals(unit)
end

local function setShelfStock(unit: Model, stock: number)
	unit:SetAttribute("ShelfStock", math.clamp(math.floor(stock), 0, getShelfCapacity(unit)))
	refreshShelfVisuals(unit)

	local store = unit:FindFirstAncestor("RetailStore")
	if store then
		updateStoreInventorySummary(store)
	end
end

local function getShelfProductName(target: BasePart): string?
	local unit = getShelfUnit(target)
	if not unit then
		return nil
	end

	local name = unit:GetAttribute("ShelfProductName")
	return if typeof(name) == "string" then name else nil
end

local function getTargetPriceCents(target: BasePart): number
	local unit = getShelfUnit(target)
	if unit then
		local _, _, _, product = getShelfProduct(unit)
		return product.priceCents
	end

	return math.max(0, math.floor(target:GetAttribute("RetailPriceCents") or 399))
end

local function getRegisterModel(target: BasePart): Model?
	local current: Instance? = target
	while current do
		if current:IsA("Model") and current:GetAttribute("RegisterId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function findRegisterById(store: Instance, registerId: string): Model?
	for _, desc in store:GetDescendants() do
		if desc:IsA("Model") and desc:GetAttribute("RegisterId") == registerId then
			return desc
		end
	end
	return nil
end

local function playerIsNearRegister(player: Player, register: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local drawer = register:FindFirstChild("CashDrawer")
	if not root or not root:IsA("BasePart") or not drawer or not drawer:IsA("BasePart") then
		return false
	end

	return (root.Position - drawer.Position).Magnitude <= 18
end

local function createRegisterOrder(): RegisterState
	local itemCount = math.random(2, 7)
	local totalCents = 0
	local items = {}
	for _ = 1, itemCount do
		local product = ORDER_PRODUCTS[math.random(1, #ORDER_PRODUCTS)]
		totalCents += product.priceCents
		table.insert(items, {
			name = product.name,
			priceCents = product.priceCents,
		})
	end

	local paidCents = totalCents
	for _, amount in CUSTOMER_TENDER do
		if amount >= totalCents then
			paidCents = amount
			break
		end
	end
	if paidCents < totalCents then
		paidCents = math.ceil(totalCents / 2000) * 2000
	end

	receiptCounter += 1

	return {
		itemCount = itemCount,
		totalCents = totalCents,
		paidCents = paidCents,
		changeGivenCents = 0,
		items = items,
		receiptNumber = receiptCounter,
	}
end

local function getRegisterState(registerId: string): RegisterState
	local state = registerStates[registerId]
	if not state then
		state = createRegisterOrder()
		registerStates[registerId] = state
	end

	return state
end

local function getChangeDue(state: RegisterState): number
	return math.max(0, state.paidCents - state.totalCents)
end

local function getSuggestedChange(changeDueCents: number): string
	local remaining = changeDueCents
	local pieces = {}
	for _, denomination in RetailCurrency.denominations do
		local count = math.floor(remaining / denomination.cents)
		if count > 0 then
			table.insert(pieces, if count == 1 then denomination.name else `{denomination.name}x{count}`)
			remaining -= count * denomination.cents
		end
	end

	return if #pieces > 0 then table.concat(pieces, " + ") else "No change"
end

local function registerPayload(registerId: string, state: RegisterState, extra: { [string]: any }?)
	local changeDueCents = getChangeDue(state)
	local changeRemainingCents = math.max(0, changeDueCents - state.changeGivenCents)
	local changeOverCents = math.max(0, state.changeGivenCents - changeDueCents)
	local itemLines = {}
	for _, item in state.items do
		table.insert(itemLines, `{item.name} {RetailCurrency.formatCents(item.priceCents)}`)
	end

	local payload = {
		registerId = registerId,
		itemCount = state.itemCount,
		items = itemLines,
		receiptNumber = state.receiptNumber,
		totalCents = state.totalCents,
		paidCents = state.paidCents,
		changeDueCents = changeDueCents,
		changeGivenCents = state.changeGivenCents,
		changeRemainingCents = changeRemainingCents,
		changeOverCents = changeOverCents,
		suggestedTender = getSuggestedChange(changeRemainingCents),
		completed = state.completed == true,
	}
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	return payload
end

local function setRegisterDisplay(register: Model, text: string)
	local statusDisplay = register:FindFirstChild("StatusDisplay")
	if statusDisplay and statusDisplay:IsA("BasePart") then
		updateSignText(statusDisplay, text)
	end
end

local function setReceiptPaper(register: Model, text: string)
	local receiptPaper = register:FindFirstChild("ReceiptPaper")
	if receiptPaper and receiptPaper:IsA("BasePart") then
		updateSignText(receiptPaper, text)
	end
end

local function buildReceiptText(state: RegisterState, source: string, bonusCents: number?): string
	local lines = {
		`Receipt #{state.receiptNumber}`,
		`Lane: {source}`,
	}
	for index, item in state.items do
		if index <= 4 then
			table.insert(lines, `{item.name} {RetailCurrency.formatCents(item.priceCents)}`)
		end
	end
	if #state.items > 4 then
		table.insert(lines, `+{#state.items - 4} more items`)
	end
	table.insert(lines, `Total {RetailCurrency.formatCents(state.totalCents)}`)
	table.insert(lines, `Paid {RetailCurrency.formatCents(state.paidCents)}`)
	table.insert(lines, `Change {RetailCurrency.formatCents(getChangeDue(state))}`)
	if bonusCents and bonusCents > 0 then
		table.insert(lines, `Pet tip {RetailCurrency.formatCents(bonusCents)}`)
	end
	return table.concat(lines, "\n")
end

local function recordStoreSale(totalCents: number, source: string)
	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	store:SetAttribute("StoreCashCents", (store:GetAttribute("StoreCashCents") or 0) + totalCents)
	store:SetAttribute("StoreCustomers", (store:GetAttribute("StoreCustomers") or 0) + 1)
	if source == "NPC" then
		store:SetAttribute("NpcCustomersProcessed", (store:GetAttribute("NpcCustomersProcessed") or 0) + 1)
	else
		store:SetAttribute("PlayerCustomersProcessed", (store:GetAttribute("PlayerCustomersProcessed") or 0) + 1)
	end
end

local function getPetCheckoutBonusCents(player: Player?): number
	if not player then
		return 0
	end
	return math.max(0, math.floor(player:GetAttribute("PetCheckoutBonusCents") or 0))
end

local function completeRegisterSale(player: Player?, register: Model, state: RegisterState, source: string): (string, number)
	recordStoreSale(state.totalCents, source)
	state.completed = true
	local bonusCents = getPetCheckoutBonusCents(player)
	local receiptText = buildReceiptText(state, source, bonusCents)

	if player then
		awardCash(player, state.totalCents + bonusCents)
		getStat(player, "Tasks").Value += state.itemCount
		getStat(player, "Customers").Value += 1
		local bonusText = if bonusCents > 0 then ` + pet tip {RetailCurrency.formatCents(bonusCents)}` else ""
		message(player, `Printed receipt #{state.receiptNumber} for {RetailCurrency.formatCents(state.totalCents)}{bonusText}`)
	elseif source == "NPC" then
		for _, activePlayer in Players:GetPlayers() do
			awardCash(activePlayer, state.totalCents)
			getStat(activePlayer, "Customers").Value += 1
		end
	end

	setRegisterDisplay(register, `RECEIPT #{state.receiptNumber}`)
	setReceiptPaper(register, `#{state.receiptNumber}\n{RetailCurrency.formatCents(state.totalCents)}`)
	return receiptText, bonusCents
end

local function beginNextRegisterOrder(registerId: string, register: Model): RegisterState
	local nextState = createRegisterOrder()
	registerStates[registerId] = nextState
	setRegisterDisplay(register, `NEXT {RetailCurrency.formatCents(nextState.totalCents)}`)
	setReceiptPaper(register, "RECEIPT\nREADY")
	return nextState
end

local function findShelfById(store: Instance, shelfId: number): Model?
	for _, desc in store:GetDescendants() do
		if desc:IsA("Model") and desc:GetAttribute("ShelfId") == shelfId then
			return desc
		end
	end
	return nil
end

local function playerIsNearShelf(player: Player, unit: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local topSign = unit:FindFirstChild("TopSign")
	if not root or not root:IsA("BasePart") or not topSign or not topSign:IsA("BasePart") then
		return false
	end

	return (root.Position - topSign.Position).Magnitude <= 18
end

local function handleRetailAction(player: Player, action: string, target: BasePart)
	local basket = getStat(player, "Basket")
	local basketValue = getStat(player, "BasketValue")
	local stock = getStat(player, "Stock")
	local tasks = getStat(player, "Tasks")
	local shift = getStat(player, "Shift")
	local customers = getStat(player, "Customers")

	if SHIFT_REQUIRED_ACTIONS[action] and shift.Value == 0 then
		message(player, "Clock in at a time clock before starting store tasks")
		return
	end
	if actionIsCoolingDown(player, action, target) then
		return
	end

	if action == "CollectItem" then
		local shelf = getShelfUnit(target)
		if shelf then
			local shelfStock = getShelfStock(shelf)
			if shelfStock <= 0 then
				message(player, `{getShelfProductName(target) or "Shelf"} is out of stock`)
				return
			end
			setShelfStock(shelf, shelfStock - 1)
		end

		basket.Value += 1
		basketValue.Value += getTargetPriceCents(target)
		tasks.Value += 1
		message(player, `Added {getShelfProductName(target) or target.Name} for {RetailCurrency.formatCents(getTargetPriceCents(target))}`)
	elseif action == "ClockIn" then
		shift.Value = if shift.Value == 0 then 1 else 0
		message(player, if shift.Value == 1 then "Clocked in for the shift" else "Clocked out")
	elseif action == "InspectTasks" then
		local store = Workspace:FindFirstChild("RetailStore")
		local lowStock = if store then store:GetAttribute("LowStockShelves") or 0 else 0
		local status = if store and store:GetAttribute("StoreOpen") == false then "closed" else "open"
		local serviceQueue = if store then readServiceAttribute(store, "ServiceQueue") else 0
		local serviceReturns = if store then readServiceAttribute(store, "ServiceReturns") else 0
		message(player, `Store {status}. Tasks: restock {lowStock} low shelves, service queue {serviceQueue}, returns {serviceReturns}, run register`)
	elseif action == "InspectSign" then
		message(player, "Parking, pickup, and store entrance are open")
	elseif action == "InspectDisplay" then
		awardCash(player, 100)
		tasks.Value += 1
		message(player, `Checked {target.Name} display`)
	elseif action == "BakeBatch" then
		awardCash(player, 300)
		tasks.Value += 1
		message(player, "Prepared a bakery batch")
	elseif action == "FillPrescription" then
		awardCash(player, 400)
		tasks.Value += 1
		message(player, "Filled a prescription")
	elseif action == "OpenDock" then
		awardCash(player, 200)
		tasks.Value += 1
		message(player, "Operated the loading dock")
	elseif action == "CheckTemperature" then
		awardCash(player, 200)
		tasks.Value += 1
		message(player, "Checked cooler temperature")
	elseif action == "PickupOrder" then
		awardCash(player, 400)
		tasks.Value += 1
		message(player, "Loaded a curbside pickup order")
	elseif action == "CleanSpill" then
		awardCash(player, 300)
		tasks.Value += 1
		message(player, "Cleaned a spill")
	elseif action == "TakeTrash" then
		awardCash(player, 200)
		tasks.Value += 1
		message(player, "Emptied the front trash can")
	elseif action == "ReturnCart" then
		awardCash(player, 100)
		tasks.Value += 1
		message(player, "Returned carts to the corral")
	elseif action == "CollectStock" then
		local bonus = math.max(0, math.floor(player:GetAttribute("PetStockBonusUnits") or 0))
		local amount = 6 + bonus
		stock.Value += amount
		tasks.Value += 1
		local bonusText = if bonus > 0 then ` ({bonus} pet bonus)` else ""
		message(player, `Picked up {amount} stock units{bonusText}`)
	elseif action == "RestockShelf" then
		local unit = getShelfUnit(target)
		if not unit then
			return
		end

		local currentStock = getShelfStock(unit)
		local capacity = getShelfCapacity(unit)
		if currentStock >= capacity then
			message(player, `{getShelfProductName(target) or "Shelf"} is already full`)
			return
		end
		if stock.Value <= 0 then
			message(player, "Need stock before restocking shelves")
			return
		end

		local moved = math.min(3, stock.Value, capacity - currentStock)
		stock.Value -= moved
		setShelfStock(unit, currentStock + moved)
		awardCash(player, moved * 100)
		tasks.Value += 1
		message(player, `Restocked {getShelfProductName(target) or target.Parent.Name} +{moved} ({currentStock + moved}/{capacity})`)
	elseif action == "ConfigureShelf" then
		local unit = getShelfUnit(target)
		if not unit then
			return
		end

		openShelfEditor:FireClient(
			player,
			unit:GetAttribute("ShelfId"),
			unit:GetAttribute("ShelfDepartmentIndex"),
			unit:GetAttribute("ShelfProductIndex"),
			getShelfStock(unit),
			getShelfCapacity(unit)
		)
	elseif action == "ServiceCustomer" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local queue = readServiceAttribute(store, "ServiceQueue")
		local bags = readServiceAttribute(store, "ServiceBags")
		local satisfaction = readServiceAttribute(store, "ServiceSatisfaction")
		if queue > 0 then
			setServiceAttribute(store, "ServiceQueue", queue - 1)
			if bags > 0 then
				setServiceAttribute(store, "ServiceBags", bags - 1)
			end
			setServiceAttribute(store, "ServiceSatisfaction", math.clamp(satisfaction + 3, 0, 100))
			setServiceAttribute(store, "ServiceTicketsHandled", readServiceAttribute(store, "ServiceTicketsHandled") + 1)
			awardCash(player, 350)
			customers.Value += 1
			message(player, `Helped service ticket. Queue now {math.max(0, queue - 1)}`)
		else
			setServiceAttribute(store, "ServiceSatisfaction", math.clamp(satisfaction + 1, 0, 100))
			awardCash(player, 125)
			message(player, "Handled a quick service question")
		end
		tasks.Value += 1
		updateServiceAreaVisuals(store)
	elseif action == "ServeCustomer" or action == "QueueCustomer" then
		awardCash(player, 400)
		tasks.Value += 1
		customers.Value += 1
		message(player, "Helped a waiting customer")
	elseif action == "QueueServiceCustomer" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end
		if store:GetAttribute("StoreOpen") == false then
			message(player, "Open the store before calling service customers")
			return
		end

		local queue = readServiceAttribute(store, "ServiceQueue")
		if queue >= 8 then
			message(player, "Service queue is full")
			return
		end

		setServiceAttribute(store, "ServiceQueue", queue + 1)
		if math.random(1, 3) == 1 then
			setServiceAttribute(store, "ServiceReturns", readServiceAttribute(store, "ServiceReturns") + 1)
		end
		updateServiceAreaVisuals(store)
		message(player, `Called next service ticket. Queue now {queue + 1}`)
	elseif action == "ProcessReturn" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local returns = readServiceAttribute(store, "ServiceReturns")
		if returns <= 0 then
			message(player, "No returns waiting at the service desk")
			return
		end

		setServiceAttribute(store, "ServiceReturns", returns - 1)
		setServiceAttribute(store, "ServiceSatisfaction", math.clamp(readServiceAttribute(store, "ServiceSatisfaction") + 2, 0, 100))
		awardCash(player, 250)
		tasks.Value += 1
		updateServiceAreaVisuals(store)
		message(player, `Processed a return. Returns left {math.max(0, returns - 1)}`)
	elseif action == "ResolveComplaint" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local queue = readServiceAttribute(store, "ServiceQueue")
		if queue > 0 then
			setServiceAttribute(store, "ServiceQueue", queue - 1)
			customers.Value += 1
		end
		setServiceAttribute(store, "ServiceSatisfaction", math.clamp(readServiceAttribute(store, "ServiceSatisfaction") + 5, 0, 100))
		awardCash(player, 300)
		tasks.Value += 1
		updateServiceAreaVisuals(store)
		message(player, if queue > 0 then "Resolved a customer service issue" else "Filed the complaint log")
	elseif action == "ServicePickup" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local pickups = readServiceAttribute(store, "ServicePickupOrders")
		if pickups <= 0 then
			message(player, "No pickup orders staged at service")
			return
		end

		setServiceAttribute(store, "ServicePickupOrders", pickups - 1)
		awardCash(player, 275)
		tasks.Value += 1
		customers.Value += 1
		updateServiceAreaVisuals(store)
		message(player, `Handed off a pickup order. Orders left {math.max(0, pickups - 1)}`)
	elseif action == "RestockServiceBags" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local bags = readServiceAttribute(store, "ServiceBags")
		if bags >= 12 then
			message(player, "Service bags are already full")
			return
		end
		if stock.Value <= 0 then
			message(player, "Need stock before refilling service bags")
			return
		end

		local moved = math.min(4, stock.Value, 12 - bags)
		stock.Value -= moved
		setServiceAttribute(store, "ServiceBags", bags + moved)
		awardCash(player, moved * 35)
		tasks.Value += 1
		updateServiceAreaVisuals(store)
		message(player, `Restocked service bags +{moved} ({bags + moved}/12)`)
	elseif action == "CheckLostFound" then
		local store = getRetailStoreFromTarget(target)
		if not store then
			return
		end

		local foundPickup = math.random(1, 2) == 1
		if foundPickup then
			setServiceAttribute(store, "ServicePickupOrders", readServiceAttribute(store, "ServicePickupOrders") + 1)
		else
			setServiceAttribute(store, "ServiceReturns", readServiceAttribute(store, "ServiceReturns") + 1)
		end
		awardCash(player, 100)
		tasks.Value += 1
		updateServiceAreaVisuals(store)
		message(player, if foundPickup then "Found a pickup order tag in lost and found" else "Found a return item in lost and found")
	elseif action == "Checkout" then
		if basket.Value <= 0 then
			message(player, "Basket is empty")
			return
		end

		local bonusCents = getPetCheckoutBonusCents(player)
		local earned = basketValue.Value + bonusCents
		awardCash(player, earned)
		tasks.Value += basket.Value
		receiptCounter += 1
		local bonusText = if bonusCents > 0 then ` with {RetailCurrency.formatCents(bonusCents)} pet tip` else ""
		message(player, `Printed basket receipt #{receiptCounter}: {basket.Value} items for {RetailCurrency.formatCents(basketValue.Value)}{bonusText}`)
		basket.Value = 0
		basketValue.Value = 0
	elseif action == "OpenPlayerRegister" then
		local register = getRegisterModel(target)
		if not register then
			return
		end

		local registerId = register:GetAttribute("RegisterId")
		if typeof(registerId) ~= "string" then
			return
		end

		local state = getRegisterState(registerId)
		setRegisterDisplay(register, `NEXT {RetailCurrency.formatCents(state.totalCents)}`)
		openRegisterPanel:FireClient(player, registerPayload(registerId, state))
	elseif action == "OpenPetMenu" then
		openPlayerMenu:FireClient(player, "pets")
	elseif action == "CarePet" then
		local currentDiscount = math.max(0, math.floor(player:GetAttribute("PetRollDiscountCents") or 0))
		local bonus = if player:GetAttribute("EquippedPetName") then 150 else 100
		bonus += math.max(0, math.floor(player:GetAttribute("PetCareBonusCents") or 0))
		local nextDiscount = math.min(300, currentDiscount + bonus)
		player:SetAttribute("PetRollDiscountCents", nextDiscount)
		awardCash(player, 75)
		tasks.Value += 1
		local petName = player:GetAttribute("EquippedPetName")
		local petText = if typeof(petName) == "string" then ` for {petName}` else ""
		message(player, `Prepared pet care{petText}. Next pet roll discount {RetailCurrency.formatCents(nextDiscount)}`)
	elseif action == "ToggleStoreOpen" then
		local store = target:FindFirstAncestor("RetailStore") or Workspace:FindFirstChild("RetailStore")
		if not store then
			return
		end

		local nextOpen = store:GetAttribute("StoreOpen") == false
		setStoreOpenFromPlayer(player, store, nextOpen)
	else
		warn(`[RetailMechanics] Unknown action '{action}' on {target:GetFullName()}`)
	end
end

adjustRegisterChange.OnServerEvent:Connect(function(player, registerId, cents)
	if typeof(registerId) ~= "string" or typeof(cents) ~= "number" then
		return
	end

	cents = math.floor(cents)
	if not ALLOWED_DENOMINATIONS[cents] then
		return
	end

	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	local register = findRegisterById(store, registerId)
	if not register or register:GetAttribute("RegisterKind") ~= "Player" or not playerIsNearRegister(player, register) then
		return
	end

	local state = getRegisterState(registerId)
	if state.completed then
		updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
		return
	end
	local changeDueCents = getChangeDue(state)
	if state.changeGivenCents + cents > changeDueCents then
		local overBy = state.changeGivenCents + cents - changeDueCents
		message(player, `That would overpay change by {RetailCurrency.formatCents(overBy)}`)
		updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
		return
	end

	state.changeGivenCents += cents
	updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
end)

resetRegisterChange.OnServerEvent:Connect(function(player, registerId)
	if typeof(registerId) ~= "string" then
		return
	end

	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	local register = findRegisterById(store, registerId)
	if not register or register:GetAttribute("RegisterKind") ~= "Player" or not playerIsNearRegister(player, register) then
		return
	end

	local state = getRegisterState(registerId)
	if state.completed then
		updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
		return
	end
	state.changeGivenCents = 0
	updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
end)

finishRegisterSale.OnServerEvent:Connect(function(player, registerId)
	if typeof(registerId) ~= "string" then
		return
	end

	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	local register = findRegisterById(store, registerId)
	if not register or register:GetAttribute("RegisterKind") ~= "Player" or not playerIsNearRegister(player, register) then
		return
	end

	local state = getRegisterState(registerId)
	if state.completed then
		message(player, "Receipt already printed; next customer is loading")
		updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
		return
	end
	if state.changeGivenCents ~= getChangeDue(state) then
		message(player, `Need exact change: {RetailCurrency.formatCents(getChangeDue(state))}`)
		updateRegisterPanel:FireClient(player, registerPayload(registerId, state))
		return
	end

	local receiptText, bonusCents = completeRegisterSale(player, register, state, "Player")
	updateRegisterPanel:FireClient(
		player,
		registerPayload(registerId, state, {
			receiptText = receiptText,
			bonusCents = bonusCents,
			saleComplete = true,
		})
	)
	task.delay(3, function()
		if registerStates[registerId] ~= state then
			return
		end

		local nextState = beginNextRegisterOrder(registerId, register)
		updateRegisterPanel:FireClient(player, registerPayload(registerId, nextState))
	end)
end)

createNpcOrder.OnInvoke = function()
	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return nil
	end

	local itemCount = 0
	local totalCents = 0
	local items = {}
	local wantedItems = math.random(1, 4)

	for _ = 1, wantedItems do
		local stockedShelves = {}
		for _, shelf in getShelfModels(store) do
			if getShelfStock(shelf) > 0 then
				table.insert(stockedShelves, shelf)
			end
		end

		if #stockedShelves == 0 then
			break
		end

		local shelf = stockedShelves[math.random(1, #stockedShelves)]
		local _, _, _, product = getShelfProduct(shelf)
		setShelfStock(shelf, getShelfStock(shelf) - 1)
		itemCount += 1
		totalCents += product.priceCents
		table.insert(items, {
			name = product.name,
			priceCents = product.priceCents,
		})
	end

	if itemCount == 0 then
		return nil
	end

	return {
		itemCount = itemCount,
		totalCents = totalCents,
		items = items,
	}
end

processNpcCheckout.OnInvoke = function(order)
	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return nil
	end

	local npcRegister = findRegisterById(store, "NpcRegister")
	if not npcRegister then
		return nil
	end

	local state = if typeof(order) == "table"
		and typeof(order.itemCount) == "number"
		and typeof(order.totalCents) == "number"
		then {
			itemCount = math.max(1, math.floor(order.itemCount)),
			totalCents = math.max(0, math.floor(order.totalCents)),
			paidCents = math.max(0, math.floor(order.totalCents)),
			changeGivenCents = 0,
			items = if typeof(order.items) == "table" then order.items else {
				{
					name = "NPC basket",
					priceCents = math.max(0, math.floor(order.totalCents)),
				},
			},
			receiptNumber = receiptCounter + 1,
		}
		else getRegisterState("NpcRegister")
	if state.receiptNumber == receiptCounter + 1 then
		receiptCounter += 1
	end
	local totalCents = state.totalCents
	setRegisterDisplay(npcRegister, `SALE {RetailCurrency.formatCents(totalCents)}`)
	completeRegisterSale(nil, npcRegister, state, "NPC")
	setRegisterDisplay(npcRegister, "WAITING")
	return totalCents
end

selectShelfProduct.OnServerEvent:Connect(function(player, shelfId, departmentIndex, productIndex)
	if typeof(shelfId) ~= "number" or typeof(departmentIndex) ~= "number" or typeof(productIndex) ~= "number" then
		return
	end

	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	local unit = findShelfById(store, shelfId)
	if not unit or not playerIsNearShelf(player, unit) then
		return
	end

	local selectedDepartmentIndex = RetailCatalog.wrapDepartmentIndex(departmentIndex)
	local selectedProductIndex = RetailCatalog.wrapProductIndex(selectedDepartmentIndex, productIndex)
	local previousDepartmentIndex = RetailCatalog.wrapDepartmentIndex(unit:GetAttribute("ShelfDepartmentIndex") or 1)
	local previousProductIndex = RetailCatalog.wrapProductIndex(previousDepartmentIndex, unit:GetAttribute("ShelfProductIndex") or 1)
	if selectedDepartmentIndex == previousDepartmentIndex and selectedProductIndex == previousProductIndex then
		message(player, `{unit:GetAttribute("ShelfProductName")} is already assigned to this shelf`)
		return
	end

	unit:SetAttribute("ShelfDepartmentIndex", selectedDepartmentIndex)
	unit:SetAttribute("ShelfProductIndex", selectedProductIndex)
	applyShelfSelection(unit)
	setShelfStock(unit, 0)
	message(player, `Set {unit:GetAttribute("ShelfProductName")} in {unit:GetAttribute("ShelfDepartmentName")} - shelf needs stock`)
end)

requestStoreToggle.OnServerEvent:Connect(function(player)
	local store = Workspace:FindFirstChild("RetailStore")
	if not store then
		return
	end

	local nextOpen = store:GetAttribute("StoreOpen") == false
	setStoreOpenFromPlayer(player, store, nextOpen)
end)

local function connectPrompt(prompt: ProximityPrompt)
	if connectedPrompts[prompt] then
		return
	end

	local target = prompt.Parent
	if not target or not target:IsA("BasePart") then
		return
	end

	local action = target:GetAttribute("RetailAction")
	if typeof(action) ~= "string" then
		return
	end

	connectedPrompts[prompt] = prompt.Triggered:Connect(function(player)
		handleRetailAction(player, action, target)
	end)

	prompt.Destroying:Connect(function()
		local connection = connectedPrompts[prompt]
		if connection then
			connection:Disconnect()
			connectedPrompts[prompt] = nil
		end
	end)
end

local function connectStore(store: Instance)
	table.clear(registerStates)
	if store:GetAttribute("StoreOpen") == nil then
		store:SetAttribute("StoreOpen", true)
	end
	for attributeName, defaultValue in SERVICE_ATTRIBUTE_DEFAULTS do
		if typeof(store:GetAttribute(attributeName)) ~= "number" then
			store:SetAttribute(attributeName, defaultValue)
		end
	end
	updateStoreOpenVisuals(store)
	updateServiceAreaVisuals(store)
	store:GetAttributeChangedSignal("StoreOpen"):Connect(function()
		updateStoreOpenVisuals(store)
	end)
	for attributeName in {
		"ServiceQueue",
		"ServiceReturns",
		"ServicePickupOrders",
		"ServiceBags",
		"ServiceSatisfaction",
	} do
		store:GetAttributeChangedSignal(attributeName):Connect(function()
			updateServiceAreaVisuals(store)
		end)
	end

	for _, desc in store:GetDescendants() do
		if desc:IsA("Model") and desc:GetAttribute("ShelfId") ~= nil then
			applyShelfSelection(desc)
		end

		if desc:IsA("ProximityPrompt") then
			connectPrompt(desc)
		end

		if desc:IsA("Model") then
			local registerId = desc:GetAttribute("RegisterId")
			if typeof(registerId) == "string" then
				if registerId == "NpcRegister" then
					setRegisterDisplay(desc, "WAITING")
				else
					beginNextRegisterOrder(registerId, desc)
				end
			end
		end
	end
	updateStoreInventorySummary(store)

	store.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			connectPrompt(desc)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

local existingStore = Workspace:FindFirstChild("RetailStore")
if existingStore then
	connectStore(existingStore)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "RetailStore" then
		connectStore(child)
	end
end)
