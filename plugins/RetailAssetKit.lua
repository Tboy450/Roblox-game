-- Install in Roblox's local Plugins folder. Use only in the asset test place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local toolbar = plugin:CreateToolbar("Retail Asset Kit")

local function requireTestPlace()
	assert(RunService:IsEdit(), "Stop Play before preparing assets")
	local config = ReplicatedStorage:FindFirstChild("RetailMapConfig")
	assert(config and config:GetAttribute("Mode") == "AssetTest", "Connect asset-test.project.json to a separate test place on port 34873 first")
	return ReplicatedStorage:WaitForChild("Shared")
end

local function prepare(id: string)
	local shared = requireTestPlace()
	local definitions = require(shared:WaitForChild("RetailAssetDefinitions"))
	local definition = definitions[id]
	local selected = Selection:Get()
	assert(#selected == 1 and selected[1]:IsA("Model"), "Select exactly one imported fixture Model")
	local source = selected[1]
	local clone = source:Clone()
	local ok, result = pcall(function()
		clone.PrimaryPart = nil
		local meshes = 0
		for _, child in clone:GetDescendants() do
			assert(not child:IsA("LuaSourceContainer") and not child:IsA("ProximityPrompt"), "Select visual meshes only, without scripts or prompts")
			if child:IsA("MeshPart") then meshes += 1 end
			if child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false; child.CanTouch = false end
		end
		assert(meshes > 0, "The selected model contains no imported MeshParts")
		-- Normalize uniform importer unit conversion, then verify all three axes.
		local _, size = clone:GetBoundingBox()
		local expected = definition.boundsMax - definition.boundsMin
		assert(size.Y > 0, "Imported geometry has no height")
		clone:ScaleTo(clone:GetScale() * expected.Y / size.Y)
		local boundsCF, actual = clone:GetBoundingBox()
		for _, axis in { "X", "Y", "Z" } do
			assert(math.abs(actual[axis] - expected[axis]) <= math.max(0.03, expected[axis] * 0.025), `Wrong orientation or dimensions on {axis}; import using the authored Y-up orientation`)
		end
		-- Restore the authored origin from known bounds, independent of importer pivot choice.
		local center = (definition.boundsMin + definition.boundsMax) / 2
		clone.WorldPivot = CFrame.new(boundsCF.Position - center)
		clone:PivotTo(CFrame.new())
		clone.Name = id
		clone:SetAttribute("StoreAssetPrepared", true)
		clone:SetAttribute("AssetUnits", "Studs")
		clone:SetAttribute("AssetVersion", definition.version)
		local library = ServerStorage:FindFirstChild("RetailAssetLibrary")
		assert(library, "RetailAssetLibrary is missing; reconnect the asset test Rojo project")
		assert(not library:FindFirstChild(id), `A prepared {id} already exists; rename that copy explicitly before preparing another version`)
		ChangeHistoryService:SetWaypoint("Before prepare " .. id)
		clone.Parent = library
		ChangeHistoryService:SetWaypoint("Prepared " .. id)
		Selection:Set({ clone })
		print(`[RetailAssetKit] Prepared {id}; authored scale and pivot verified. Original import retained.`)
	end)
	if not ok then clone:Destroy(); error(result) end
end

local function button(name: string, callback: () -> ())
	local result = toolbar:CreateButton(name, name, "")
	result.Click:Connect(function()
		local ok, err = pcall(callback)
		if not ok then warn("[RetailAssetKit] " .. tostring(err)) end
	end)
end

button("Prepare Shelf", function() prepare("gondola_01") end)
button("Prepare Checkout", function() prepare("checkout_01") end)
button("Build Kit Test", function()
	local shared = requireTestPlace()
	ChangeHistoryService:SetWaypoint("Before retail kit test")
	local test = require(shared:WaitForChild("RetailAssetTestBlueprint"))
	local store = test.build({ parent = workspace, library = ServerStorage:WaitForChild("RetailAssetLibrary") })
	ChangeHistoryService:SetWaypoint("After retail kit test")
	Selection:Set({ store })
end)
