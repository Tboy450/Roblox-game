local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MAX_ACTIVE_CUSTOMERS = 4
local CUSTOMER_SPEED = 8
local CAR_SPEED = 28
local ARRIVAL_GAP = { 8, 14 }
local SHOP_WAIT = { 2, 5 }
local REGISTER_WAIT = { 1.4, 2.4 }

local SHIRT_COLORS = {
	Color3.fromRGB(65, 120, 185),
	Color3.fromRGB(185, 110, 75),
	Color3.fromRGB(88, 150, 105),
	Color3.fromRGB(146, 96, 174),
	Color3.fromRGB(198, 150, 76),
	Color3.fromRGB(80, 140, 145),
}

local VEHICLE_STYLES = {
	{
		name = "Compact",
		bodySize = Vector3.new(6.5, 2.2, 10),
		cabinSize = Vector3.new(5.2, 2.2, 4.8),
		bodyColor = Color3.fromRGB(188, 72, 64),
	},
	{
		name = "Sedan",
		bodySize = Vector3.new(7.2, 2.2, 11.5),
		cabinSize = Vector3.new(5.4, 2.3, 5.2),
		bodyColor = Color3.fromRGB(64, 96, 156),
	},
	{
		name = "SUV",
		bodySize = Vector3.new(7.8, 2.8, 11.8),
		cabinSize = Vector3.new(6, 2.6, 5.6),
		bodyColor = Color3.fromRGB(78, 102, 84),
	},
	{
		name = "Van",
		bodySize = Vector3.new(8.2, 3.1, 12.4),
		cabinSize = Vector3.new(6.8, 2.8, 6.2),
		bodyColor = Color3.fromRGB(182, 184, 188),
	},
	{
		name = "Pickup",
		bodySize = Vector3.new(8, 2.4, 12.8),
		cabinSize = Vector3.new(5.2, 2.4, 4.4),
		bodyColor = Color3.fromRGB(166, 96, 54),
		bed = true,
	},
	{
		name = "Coupe",
		bodySize = Vector3.new(6.8, 1.9, 10.4),
		cabinSize = Vector3.new(4.2, 1.8, 3.8),
		bodyColor = Color3.fromRGB(42, 44, 52),
		spoiler = true,
	},
	{
		name = "DeliveryTruck",
		bodySize = Vector3.new(8.5, 2.8, 13.6),
		cabinSize = Vector3.new(5.5, 2.7, 4),
		bodyColor = Color3.fromRGB(230, 226, 210),
		cargoBox = true,
	},
	{
		name = "RoofRackSUV",
		bodySize = Vector3.new(8, 2.9, 12),
		cabinSize = Vector3.new(6.1, 2.6, 5.8),
		bodyColor = Color3.fromRGB(82, 92, 126),
		roofRack = true,
	},
}

local currentStore: Model? = nil
local trafficFolder: Model? = nil
local runtimeFolder: Folder? = nil
local markers: { [string]: BasePart } = {}
local parkingSpots: { BasePart } = {}
local occupiedSpots: { [BasePart]: boolean } = {}
local activeCustomers = 0
local registerOwner: Model? = nil
local registerQueue: { Model } = {}
local visitGeneration = 0
local closingRevision = 0

local retailRemotes = ReplicatedStorage:WaitForChild("RetailRemotes")
local processNpcCheckout = retailRemotes:WaitForChild("ProcessNpcCheckout") :: BindableFunction
local createNpcOrder = retailRemotes:WaitForChild("CreateNpcOrder") :: BindableFunction
local cancelNpcOrder = retailRemotes:WaitForChild("CancelNpcOrder") :: BindableFunction

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function tweenModelTo(model: Model, targetPosition: Vector3, speed: number, shouldContinue: (() -> boolean)?): boolean
	if not model.Parent or (shouldContinue and not shouldContinue()) then
		return false
	end
	local startPivot = model:GetPivot()
	local startPosition = startPivot.Position
	local distance = (targetPosition - startPosition).Magnitude
	if distance < 0.05 then
		return true
	end

	local direction = Vector3.new(targetPosition.X - startPosition.X, 0, targetPosition.Z - startPosition.Z)
	local targetCFrame = if direction.Magnitude > 0.01 then CFrame.lookAt(targetPosition, targetPosition + direction)
		else CFrame.new(targetPosition) * startPivot.Rotation
	local value = Instance.new("CFrameValue")
	value.Value = startPivot
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(value.Value)
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), { Value = targetCFrame })
	tween:Play()
	while tween.PlaybackState == Enum.PlaybackState.Playing do
		if not model.Parent or (shouldContinue and not shouldContinue()) then
			tween:Cancel()
			break
		end
		task.wait(0.05)
	end
	local completed = tween.PlaybackState == Enum.PlaybackState.Completed and model.Parent ~= nil
	connection:Disconnect()
	value:Destroy()
	tween:Destroy()
	if completed then
		model:PivotTo(targetCFrame)
	end
	return completed
end

local function moveModelAlong(model: Model, waypoints: { Vector3 }, speed: number, shouldContinue: (() -> boolean)?): boolean
	for _, waypoint in waypoints do
		if not tweenModelTo(model, waypoint, speed, shouldContinue) then
			return false
		end
	end
	return model.Parent ~= nil
end

local function walkCustomerTo(npc: Model, destination: Vector3, shouldContinue: () -> boolean): boolean
	for _ = 1, 2 do
		if not npc.Parent or not shouldContinue() then
			return false
		end
		local path = PathfindingService:CreatePath({ AgentRadius = 1.8, AgentHeight = 6, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 5 })
		local ok = pcall(function()
			path:ComputeAsync(npc:GetPivot().Position + Vector3.new(0, 2, 0), destination + Vector3.new(0, 2, 0))
		end)
		if ok and path.Status == Enum.PathStatus.Success and shouldContinue() then
			local waypointIndex = 1
			local blocked = false
			local connection = path.Blocked:Connect(function(index)
				if index >= waypointIndex then
					blocked = true
				end
			end)
			local reached = true
			for index, waypoint in path:GetWaypoints() do
				waypointIndex = index
				if not tweenModelTo(npc, waypoint.Position, CUSTOMER_SPEED, function()
					return shouldContinue() and not blocked
				end) then
					reached = false
					break
				end
			end
			connection:Disconnect()
			path:Destroy()
			if reached then
				return true
			end
		else
			path:Destroy()
		end
		task.wait(0.2)
	end
	return false
end

local function createNpc(name: string, shirtColor: Color3, position: Vector3): Model
	local npc = Instance.new("Model")
	npc.Name = name
	npc.Parent = runtimeFolder

	local root = createPart(npc, "Root", Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	createPart(npc, "Legs", Vector3.new(1.6, 2.4, 0.9), CFrame.new(position + Vector3.new(0, 1.2, 0)), Color3.fromRGB(45, 50, 58), Enum.Material.SmoothPlastic)
	createPart(npc, "Torso", Vector3.new(2.1, 2.4, 1), CFrame.new(position + Vector3.new(0, 3.6, 0)), shirtColor, Enum.Material.SmoothPlastic)
	createPart(npc, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(position + Vector3.new(0, 5.45, 0)), Color3.fromRGB(222, 185, 145), Enum.Material.SmoothPlastic)
	npc.PrimaryPart = root
	return npc
end

local function addPurchaseBag(npc: Model)
	local root = npc.PrimaryPart
	if not root then
		return
	end

	createPart(
		npc,
		"PurchaseBag",
		Vector3.new(1.1, 1.4, 0.8),
		root.CFrame * CFrame.new(1.25, 2.1, 0),
		Color3.fromRGB(224, 212, 184),
		Enum.Material.Fabric
	)
end

local function createVehicle(style, cframe: CFrame): Model
	local vehicle = Instance.new("Model")
	vehicle.Name = style.name
	vehicle.Parent = runtimeFolder

	local root = createPart(vehicle, "Root", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	createPart(vehicle, "Body", style.bodySize, CFrame.new(0, 1.5, 0), style.bodyColor, Enum.Material.Metal)
	createPart(vehicle, "Cabin", style.cabinSize, CFrame.new(0, 3.2, 0.6), Color3.fromRGB(160, 180, 192), Enum.Material.Glass)
	createPart(vehicle, "FrontGlass", Vector3.new(style.cabinSize.X - 0.8, 1.5, 0.25), CFrame.new(0, 3.35, -style.cabinSize.Z / 2 + 0.25), Color3.fromRGB(120, 145, 160), Enum.Material.Glass)
	createPart(vehicle, "Headlights", Vector3.new(style.bodySize.X - 1.2, 0.35, 0.2), CFrame.new(0, 1.85, -style.bodySize.Z / 2 - 0.05), Color3.fromRGB(245, 235, 170), Enum.Material.Neon)
	createPart(vehicle, "TailLights", Vector3.new(style.bodySize.X - 1.2, 0.3, 0.2), CFrame.new(0, 1.75, style.bodySize.Z / 2 + 0.05), Color3.fromRGB(210, 48, 40), Enum.Material.Neon)
	if style.bed then
		createPart(vehicle, "OpenBed", Vector3.new(style.bodySize.X - 0.8, 0.7, 4.8), CFrame.new(0, 2.75, 3.3), Color3.fromRGB(42, 42, 46), Enum.Material.Metal)
		createPart(vehicle, "Tailgate", Vector3.new(style.bodySize.X - 0.5, 1.2, 0.25), CFrame.new(0, 2.45, style.bodySize.Z / 2 + 0.15), style.bodyColor, Enum.Material.Metal)
	elseif style.cargoBox then
		createPart(vehicle, "CargoBox", Vector3.new(style.bodySize.X + 0.5, 4.2, 6.8), CFrame.new(0, 4.25, 2.8), Color3.fromRGB(236, 234, 224), Enum.Material.SmoothPlastic)
		createPart(vehicle, "CargoLogoPanel", Vector3.new(style.bodySize.X + 0.7, 1.9, 0.18), CFrame.new(0, 4.25, 6.25), Color3.fromRGB(58, 112, 156), Enum.Material.SmoothPlastic)
	elseif style.roofRack then
		createPart(vehicle, "RoofRack", Vector3.new(style.cabinSize.X + 0.5, 0.18, style.cabinSize.Z + 0.5), CFrame.new(0, 4.75, 0.6), Color3.fromRGB(32, 34, 38), Enum.Material.Metal)
	elseif style.spoiler then
		createPart(vehicle, "Spoiler", Vector3.new(style.bodySize.X - 1, 0.3, 0.55), CFrame.new(0, 2.75, style.bodySize.Z / 2 - 0.7), style.bodyColor, Enum.Material.Metal)
	end
	for _, x in { -style.bodySize.X / 2 + 0.7, style.bodySize.X / 2 - 0.7 } do
		for _, z in { -style.bodySize.Z / 2 + 1.8, style.bodySize.Z / 2 - 1.8 } do
			createPart(vehicle, "Wheel", Vector3.new(0.8, 1.5, 1.5), CFrame.new(x, 0.8, z), Color3.fromRGB(30, 30, 32), Enum.Material.Rubber)
		end
	end

	vehicle.PrimaryPart = root
	vehicle:PivotTo(cframe)
	return vehicle
end

local function getMarker(name: string): BasePart
	return markers[name]
end

local function randomBetween(range: { number }): number
	return math.random(range[1] * 10, range[2] * 10) / 10
end

local function trafficStillActive(generation: number): boolean
	return generation == visitGeneration and currentStore ~= nil and currentStore.Parent ~= nil
end

local function storeIsOpen(): boolean
	return currentStore ~= nil and currentStore:GetAttribute("StoreOpen") ~= false
end

local function waitTraffic(range: { number }, generation: number, requireOpen: boolean): boolean
	local remaining = randomBetween(range)
	while remaining > 0 do
		if not trafficStillActive(generation) then
			return false
		end
		if requireOpen and not storeIsOpen() then
			return false
		end

		local step = math.min(0.25, remaining)
		task.wait(step)
		remaining -= step
	end

	return trafficStillActive(generation) and (not requireOpen or storeIsOpen())
end

local function getFreeSpot(): BasePart?
	for _, spot in parkingSpots do
		if not occupiedSpots[spot] then
			return spot
		end
	end
	return nil
end

local function getCarEntryPath(spot: BasePart): { Vector3 }
	local roadSpawn = getMarker("RoadSpawn").Position
	local roadApproach = getMarker("RoadApproach").Position
	local driveEntry = getMarker("DriveEntry").Position
	local driveCenter = getMarker("DriveCenter").Position
	return {
		roadSpawn,
		roadApproach,
		driveEntry,
		driveCenter,
		Vector3.new(spot.Position.X, spot.Position.Y, driveCenter.Z),
		spot.Position,
	}
end

local function getCarExitPath(spot: BasePart): { Vector3 }
	local driveCenter = getMarker("DriveCenter").Position
	return {
		Vector3.new(spot.Position.X, spot.Position.Y, driveCenter.Z),
		driveCenter,
		getMarker("DriveEntry").Position,
		getMarker("RoadExit").Position,
	}
end

local function updateTrafficSummary()
	if currentStore then
		currentStore:SetAttribute("ActiveShoppers", activeCustomers)
		currentStore:SetAttribute("TrafficAcceptingCustomers", storeIsOpen())
		currentStore:SetAttribute("CheckoutQueueLength", #registerQueue)
		currentStore:SetAttribute("StoreClosing", not storeIsOpen() and activeCustomers > 0)
		local occupiedCount = 0
		for _, occupied in occupiedSpots do
			if occupied then
				occupiedCount += 1
			end
		end
		currentStore:SetAttribute("OccupiedParkingSpots", occupiedCount)
	end
end

local function releaseNpcRegister(npc: Model)
	if registerOwner == npc then
		registerOwner = nil
	end
	local index = table.find(registerQueue, npc)
	if index then
		table.remove(registerQueue, index)
	end
	updateTrafficSummary()
end

local function waitForNpcRegister(npc: Model, canShop: () -> boolean): boolean
	table.insert(registerQueue, npc)
	updateTrafficSummary()
	npc:SetAttribute("TrafficState", "Queuing")
	local previousIndex = 0
	local deadline = os.clock() + 45
	while npc.Parent and canShop() and os.clock() < deadline do
		local index = table.find(registerQueue, npc)
		if not index then
			break
		end
		if index ~= previousIndex then
			local slot = markers[`NpcQueueSlot{index}`] or getMarker("NpcRegisterQueue")
			if not walkCustomerTo(npc, slot.Position, canShop) then
				break
			end
			previousIndex = index
		end
		if registerQueue[1] == npc and not registerOwner and canShop() then
			registerOwner = npc
			return true
		end
		task.wait(0.2)
	end
	releaseNpcRegister(npc)
	return false
end

local function getShopMarkers(): { BasePart }
	local shops = {}
	for _, name in { "ShopProduce", "ShopDairy", "ShopFrozen", "ShopPantry", "ShopHousehold", "ShopBakery" } do
		local marker = markers[name]
		if marker then
			table.insert(shops, marker)
		end
	end
	return shops
end

local function moveCustomerToParking(npc: Model, spot: BasePart, groupOffset: number, generation: number)
	local function canLeave()
		return trafficStillActive(generation)
	end
	if not npc.Parent or not canLeave() then
		return
	end
	npc:SetAttribute("TrafficState", "Leaving")
	local outsideEntry = getMarker("StoreEntryOutside").Position
	local parkingExit = spot.Position + Vector3.new(groupOffset * 1.8, 0, -6)
	if npc:GetPivot().Position.Z < outsideEntry.Z then
		if not walkCustomerTo(npc, outsideEntry, canLeave) then
			return
		end
	end
	walkCustomerTo(npc, parkingExit, canLeave)
end

local function runCustomerTrip(npc: Model, generation: number, revision: number)
	local function canShop()
		return trafficStillActive(generation) and storeIsOpen() and revision == closingRevision
	end
	local shopMarkers = getShopMarkers()
	if #shopMarkers == 0 or not canShop() then
		return
	end
	local shopMarker = shopMarkers[math.random(1, #shopMarkers)]
	local secondShopMarker = shopMarkers[math.random(1, #shopMarkers)]
	local outsideEntry = getMarker("StoreEntryOutside").Position
	local insideEntry = getMarker("StoreEntryInside").Position
	npc:SetAttribute("TrafficState", "Entering")
	local shoppingPath = { outsideEntry, insideEntry, shopMarker.Position }
	if secondShopMarker ~= shopMarker then
		table.insert(shoppingPath, secondShopMarker.Position)
	end
	for _, destination in shoppingPath do
		if not walkCustomerTo(npc, destination, canShop) then
			return
		end
	end
	npc:SetAttribute("TrafficState", "Shopping")
	if not waitTraffic(SHOP_WAIT, generation, true) or not canShop() then
		return
	end
	local ok, order = pcall(function()
		return createNpcOrder:Invoke()
	end)
	if not ok then
		warn("[RetailTraffic] Failed to create NPC order:", order)
		order = nil
	end
	if not order then
		return
	end
	npc:SetAttribute("NpcOrderId", order)

	if not waitForNpcRegister(npc, canShop) then
		return
	end

	npc:SetAttribute("TrafficState", "Checkout")
	if not walkCustomerTo(npc, getMarker("NpcRegisterSpot").Position, canShop)
		or not waitTraffic(REGISTER_WAIT, generation, true) or not canShop() then
		return
	end
	local checkoutOk, checkoutResult = pcall(function()
		return processNpcCheckout:Invoke(order)
	end)
	if not checkoutOk then
		warn("[RetailTraffic] NPC checkout failed:", checkoutResult)
	elseif typeof(checkoutResult) == "number" then
		addPurchaseBag(npc)
		npc:SetAttribute("NpcOrderId", nil)
	end
end

local function runVisitGroup(spot: BasePart, groupSize: number, generation: number)
	local revision = closingRevision
	local function visitActive()
		return trafficStillActive(generation)
	end
	occupiedSpots[spot] = true
	activeCustomers += groupSize
	updateTrafficSummary()

	local style = VEHICLE_STYLES[math.random(1, #VEHICLE_STYLES)]
	local entryPath = getCarEntryPath(spot)
	local vehicle = createVehicle(style, CFrame.lookAt(entryPath[1], entryPath[2]))
	if not moveModelAlong(vehicle, { table.unpack(entryPath, 2) }, CAR_SPEED, visitActive) then
		vehicle:Destroy()
		return
	end

	local customers = {}
	for index = 1, groupSize do
		local offset = index - (groupSize + 1) / 2
		local npc = createNpc(`Customer{index}`, SHIRT_COLORS[math.random(1, #SHIRT_COLORS)], spot.Position + Vector3.new(offset * 1.8, 0, -7))
		table.insert(customers, npc)
	end

	local finished = 0
	for index, npc in customers do
		local offset = index - (groupSize + 1) / 2
		task.spawn(function()
			local ok, err = pcall(runCustomerTrip, npc, generation, revision)
			releaseNpcRegister(npc)
			local orderId = npc:GetAttribute("NpcOrderId")
			if orderId then
				local cancelled, cancelError = pcall(function()
					cancelNpcOrder:Invoke(orderId)
				end)
				if not cancelled then
					warn("[RetailTraffic] Order return failed:", cancelError)
				end
			end
			if not ok then
				warn("[RetailTraffic] Customer trip failed:", err)
			end
			local left, leaveError = pcall(moveCustomerToParking, npc, spot, offset, generation)
			if not left then
				warn("[RetailTraffic] Customer exit failed:", leaveError)
			end
			if npc.Parent then
				npc:Destroy()
			end
			finished += 1
		end)
		task.wait(0.45)
	end

	while finished < groupSize and trafficStillActive(generation) do
		task.wait(0.25)
	end

	if vehicle.Parent then
		moveModelAlong(vehicle, getCarExitPath(spot), CAR_SPEED, visitActive)
		vehicle:Destroy()
	end

	if generation == visitGeneration then
		activeCustomers -= groupSize
		activeCustomers = math.max(0, activeCustomers)
		occupiedSpots[spot] = nil
		updateTrafficSummary()
	end
end

local function spawnCashier()
	local cashierSpot = getMarker("CashierSpot")
	createNpc("NpcCashier", Color3.fromRGB(72, 118, 170), cashierSpot.Position)
end

local function configureStore(store: Model)
	currentStore = store
	if currentStore:GetAttribute("StoreOpen") == nil then
		currentStore:SetAttribute("StoreOpen", true)
	end
	local outdoor = store:FindFirstChild("Outdoor")
	trafficFolder = if outdoor then outdoor:FindFirstChild("NpcTraffic") :: Model? else nil
	if not trafficFolder then
		return false
	end

	markers = {}
	parkingSpots = {}
	occupiedSpots = {}
	activeCustomers = 0
	registerOwner = nil
	registerQueue = {}
	visitGeneration += 1

	local oldRuntime = store:FindFirstChild("DynamicTraffic")
	if oldRuntime then
		oldRuntime:Destroy()
	end

	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "DynamicTraffic"
	runtimeFolder.Parent = store

	for _, child in trafficFolder:GetChildren() do
		if child:IsA("BasePart") then
			markers[child.Name] = child
			if child:GetAttribute("TrafficMarkerKind") == "Parking" then
				table.insert(parkingSpots, child)
			end
		end
	end

	table.sort(parkingSpots, function(a, b)
		return (a:GetAttribute("ParkingIndex") or 0) < (b:GetAttribute("ParkingIndex") or 0)
	end)

	spawnCashier()
	currentStore:GetAttributeChangedSignal("StoreOpen"):Connect(function()
		if store ~= currentStore then
			return
		end
		if not storeIsOpen() then
			closingRevision += 1
		end
		updateTrafficSummary()
	end)
	updateTrafficSummary()
	return true
end

local function runTrafficLoop(generation: number)
	while generation == visitGeneration do
		if not waitTraffic(ARRIVAL_GAP, generation, false) then
			break
		end

		if not currentStore or not currentStore.Parent or activeCustomers >= MAX_ACTIVE_CUSTOMERS or not storeIsOpen() then
			continue
		end

		local freeSpot = getFreeSpot()
		if not freeSpot then
			continue
		end

		local maxGroupSize = math.max(1, MAX_ACTIVE_CUSTOMERS - activeCustomers)
		local groupSize = math.random(1, math.min(4, maxGroupSize))
		task.spawn(runVisitGroup, freeSpot, groupSize, generation)
	end
end

local function startForStore(store: Model)
	if not configureStore(store) then
		return
	end

	local generation = visitGeneration
	task.spawn(runTrafficLoop, generation)
end

local existingStore = Workspace:FindFirstChild("RetailStore")
if existingStore and existingStore:IsA("Model") then
	startForStore(existingStore)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "RetailStore" and child:IsA("Model") then
		startForStore(child)
	end
end)
