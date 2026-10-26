-- Isolated fixture integration scene. Requires prepared, genuinely imported meshes.
-- Legacy mechanics continue to use semantic targets, independent of mesh names.
local Catalog = require(script.Parent:WaitForChild("RetailCatalog"))
local Definitions = require(script.Parent:WaitForChild("RetailAssetDefinitions"))
local AssetTest = {}

local function folder(name: string, parent: Instance): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

local function part(parent: Instance, name: string, position: Vector3, size: Vector3, visible: boolean?, collide: boolean?): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.Position = position
	result.Size = size
	result.Transparency = if visible then 0 else 1
	result.CanCollide = collide == true
	result.CanTouch = false
	result.Color = Color3.fromRGB(206, 210, 196)
	result.Parent = parent
	return result
end

local function sign(target: BasePart, text: string)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 80
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(246, 245, 225)
		label.Parent = gui
	end
end

local function action(parent: Instance, role: string, position: Vector3, actionId: string): Part
	local target = part(parent, role, position, Vector3.new(0.6, 0.6, 0.6))
	target:SetAttribute("InteractionId", parent.Name .. "." .. role)
	target:SetAttribute("RuntimeRole", role)
	target:SetAttribute("RetailAction", actionId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionId
	prompt.ObjectText = role
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.15
	prompt.Parent = target
	return target
end

local function validateTemplate(library: Instance, id: string): Model
	local template = library:FindFirstChild(id)
	assert(template and template:IsA("Model"), `Import and prepare {id} in ServerStorage.RetailAssetLibrary first`)
	assert(template:GetAttribute("StoreAssetPrepared") == true, `{id} has not been prepared by the Retail Asset Kit plugin`)
	assert(template:GetAttribute("AssetUnits") == "Studs", `{id} must use calibrated stud units`)
	assert(template:GetAttribute("AssetVersion") == Definitions[id].version, `{id} asset version does not match its definition`)
	local meshCount = 0
	for _, descendant in template:GetDescendants() do
		assert(not descendant:IsA("LuaSourceContainer") and not descendant:IsA("ProximityPrompt"), `{id} must contain visual geometry only`)
		if descendant:IsA("MeshPart") then meshCount += 1 end
	end
	assert(meshCount > 0, `{id} contains no imported MeshParts`)
	return template :: Model
end

function AssetTest.build(options: { parent: Instance, library: Instance }): Model
	local existing = options.parent:FindFirstChild("RetailStore")
	if existing then
		assert(existing:GetAttribute("RetailMapMode") == "AssetTest", "Use a separate empty test place; the existing store will not be replaced")
		return existing :: Model
	end
	-- Validate every dependency before building or publishing anything.
	local templates = {}
	for _, id in { "gondola_01", "checkout_01" } do templates[id] = validateTemplate(options.library, id) end
	local store = Instance.new("Model")
	store.Name = "RetailStore"
	store:SetAttribute("RetailMapMode", "AssetTest")
	store:SetAttribute("ImportedArt", true)
	store:SetAttribute("StoreOpen", false)
	store:SetAttribute("AssetTestVersion", 1)
	local function assemble(): Model
		local visuals = folder("Visuals", store)
		local collisions = folder("Collisions", store)
		local interactions = folder("InteractionAnchors", store)
		folder("Navigation", store)
		part(collisions, "Floor", Vector3.new(0, 0.5, 0), Vector3.new(44, 1, 44), false, true)
		part(visuals, "FloorFinish", Vector3.new(0, 0.98, 0), Vector3.new(44, 0.02, 44), true)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "TestSpawn"
		spawn.Position = Vector3.new(0, 2, 16)
		spawn.Size = Vector3.new(4, 1, 4)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Parent = interactions

		local function place(id: string, origin: Vector3)
			local visual = templates[id]:Clone()
			visual.Name = id
			visual:SetAttribute("PlacementId", id .. ".test")
			for _, child in visual:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide = false
					child.CanTouch = false
				end
			end
			visual:PivotTo(CFrame.new(origin))
			visual.Parent = visuals
			for index, proxy in Definitions[id].collisions do
				part(collisions, `{id}_{index}`, origin + proxy.center, proxy.size, false, true)
			end
		end
		local shelfOrigin = Vector3.new(-9, 1, -7)
		place("gondola_01", shelfOrigin)
		local shelf = Instance.new("Model")
		shelf.Name = "ShelfUnit1"
		shelf:SetAttribute("ShelfId", 1)
		shelf:SetAttribute("ShelfDepartmentIndex", 1)
		shelf:SetAttribute("ShelfProductIndex", 1)
		shelf:SetAttribute("ShelfCapacity", 12)
		shelf:SetAttribute("ShelfStock", 12)
		shelf:SetAttribute("PlacementId", "gondola_01.test")
		shelf.Parent = interactions
		local product = Catalog.getProduct(1, 1)
		local topSign = part(shelf, "TopSign", shelfOrigin + Vector3.new(0, 9.8, 0), Vector3.new(11, 0.8, 0.1), true)
		sign(topSign, "SHELF TEST")
		action(shelf, "ShelfControl", shelfOrigin + Vector3.new(-4, 2.3, 2.3), "ConfigureShelf")
		action(shelf, "RestockControl", shelfOrigin + Vector3.new(0, 2.3, 2.3), "RestockShelf")
		action(shelf, "ProductSelector", shelfOrigin + Vector3.new(4, 2.3, 2.3), "CollectItem")
		for tier = 0, 3 do
			local boardY = shelfOrigin.Y + 0.65 + tier * 2.45
			for slot = 1, 3 do
				local index = tier * 3 + slot
				local position = Vector3.new(shelfOrigin.X + (slot - 2) * 4, boardY + product.size.Y / 2 + 0.2, shelfOrigin.Z + 0.2)
				local item = part(shelf, `Product_{index}`, position, product.size, true)
				item:SetAttribute("ShelfProductVisual", true)
				item:SetAttribute("DecorativeProduct", true)
				item:SetAttribute("ShelfBoardY", boardY)
				item:SetAttribute("ShelfSlotIndex", index)
				local price = part(shelf, `PriceTag{index}`, Vector3.new(position.X, boardY + 0.05, shelfOrigin.Z + 2.02), Vector3.new(1.4, 0.3, 0.02), true)
				price:SetAttribute("ShelfPriceDisplay", true)
				sign(price, "PRICE")
			end
		end

		local checkoutOrigin = Vector3.new(7, 1, 5)
		place("checkout_01", checkoutOrigin)
		local register = Instance.new("Model")
		register.Name = "PlayerRegister"
		register:SetAttribute("RegisterId", "PlayerRegister")
		register:SetAttribute("RegisterKind", "Player")
		register:SetAttribute("PlacementId", "checkout_01.test")
		register.Parent = interactions
		for role, position in Definitions.checkout_01.anchors do
			if role == "Scanner" or role == "CashDrawer" then
				action(register, role, checkoutOrigin + position, "OpenPlayerRegister")
			else
				local target = part(register, role, checkoutOrigin + position, Vector3.new(1.8, 0.45, 0.02))
				target:SetAttribute("RuntimeRole", role)
				sign(target, "READY")
			end
		end
		local controls = Instance.new("Model")
		controls.Name = "TestControls"
		controls.Parent = interactions
		for index, definition in {
			{ "TimeClock", "ClockIn" }, { "StockCollection", "CollectStock" }, { "TaskBoard", "InspectTasks" },
		} do
			local target = action(controls, definition[1], Vector3.new(-15 + index * 5, 4, 14), definition[2])
			target.Transparency = 0
			target.Size = Vector3.new(3, 2, 0.4)
			sign(target, definition[1])
		end
		-- Publish last so mechanics see the complete fixture contract.
		store.Parent = options.parent
		return store
	end
	local ok, result = pcall(assemble)
	if not ok then store:Destroy(); error(result) end
	return result
end

return AssetTest
