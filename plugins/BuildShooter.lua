-- Studio updater for the Shooter project.
-- It adds or refreshes ShooterExpansion while preserving the existing arena.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- Local plugins are also loaded into Play test data models. The updater is an
-- edit-mode tool, so never create its toolbar while a test is running.
if RunService:IsRunning() then
	return
end

local SHARED_NAME = "ShooterShared"
local EXPANSION_MODULE_NAME = "ArenaExpansion"
local EXPANSION_NAME = "ShooterExpansion"
local EXPANSION_VERSION = 1
local PLUGIN_VERSION = 3

local autoUpdate = false
local queued = false
local sourceConnection: RBXScriptConnection? = nil
local statusLabel: TextLabel? = nil

local function status(message: string, isError: boolean?)
	if isError then
		warn(`[ShooterUpdater] {message}`)
	else
		print(`[ShooterUpdater] {message}`)
	end
	if statusLabel then
		statusLabel.Text = message
		statusLabel.TextColor3 = if isError then Color3.fromRGB(255, 149, 135) else Color3.fromRGB(112, 232, 160)
	end
end

local function getModule(): ModuleScript
	local shared = ReplicatedStorage:FindFirstChild(SHARED_NAME)
	if not shared then
		error("Connect Rojo to the Shooter project first; ShooterShared is missing.")
	end
	local module = shared:FindFirstChild(EXPANSION_MODULE_NAME)
	if not module or not module:IsA("ModuleScript") then
		error("ShooterShared.ArenaExpansion is missing. Check the Rojo sync.")
	end
	return module
end

local function sourceVersion(module: ModuleScript): number?
	local ok, source = pcall(function()
		return module.Source
	end)
	if not ok then
		return nil
	end
	local text = source:match("local VERSION%s*=%s*(%d+)")
	return if text then tonumber(text) else nil
end

local function requireFresh(module: ModuleScript)
	local runtime = Instance.new("Folder")
	runtime.Name = "ShooterPluginRuntime"
	runtime.Parent = ReplicatedStorage
	local clone = module:Clone()
	clone.Parent = runtime
	local ok, result = pcall(require, clone)
	runtime:Destroy()
	if not ok then
		error(result)
	end
	return result
end

local function updateExpansion()
	local module = getModule()
	local syncedVersion = sourceVersion(module)
	if syncedVersion ~= EXPANSION_VERSION then
		error(`Plugin v{EXPANSION_VERSION} does not match synced expansion v{syncedVersion or "unknown"}. Restart Studio after updating the plugin.`)
	end

	ChangeHistoryService:SetWaypoint("Before Shooter expansion update")
	local expansion = requireFresh(module)
	if typeof(expansion) ~= "table" or typeof(expansion.build) ~= "function" then
		error("ArenaExpansion must return a table with a build function.")
	end
	local model = expansion.build({ parent = Workspace, forceRebuild = true })
	if not model or not model:IsA("Model") then
		error("ArenaExpansion.build did not return a Model.")
	end
	ChangeHistoryService:SetWaypoint("After Shooter expansion update")
	Selection:Set({ model })
	status(`Updated {EXPANSION_NAME} v{EXPANSION_VERSION}. Existing arena preserved.`)
end

local function clearExpansion()
	local model = Workspace:FindFirstChild(EXPANSION_NAME)
	if not model then
		status("No ShooterExpansion exists to clear.")
		return
	end
	ChangeHistoryService:SetWaypoint("Before clearing Shooter expansion")
	model:Destroy()
	ChangeHistoryService:SetWaypoint("After clearing Shooter expansion")
	status("Cleared ShooterExpansion only. Existing arena preserved.")
end

local function selectExpansion()
	local model = Workspace:FindFirstChild(EXPANSION_NAME)
	if model then
		Selection:Set({ model })
		status("Selected ShooterExpansion.")
	else
		status("No ShooterExpansion found. Click Update Expansion first.", true)
	end
end

local function repairPortals()
	local portals = {}
	for _, descendant in Workspace:GetDescendants() do
		local lowerName = string.lower(descendant.Name)
		if descendant:IsA("BasePart") and table.find({ "p1", "p2", "pt1", "pt2" }, lowerName) then
			table.insert(portals, descendant)
		end
	end
	if #portals == 0 then
		error("No p1/p2 or pt1/pt2 portal tiles were found anywhere in Workspace.")
	end

	ChangeHistoryService:SetWaypoint("Before repairing Shooter portals")
	local removed = 0
	for _, portal in portals do
		portal.CanTouch = true
		for _, descendant in portal:GetDescendants() do
			if descendant:IsA("BaseScript") then
				descendant.Enabled = false
				descendant:Destroy()
				removed += 1
			end
		end
	end
	ChangeHistoryService:SetWaypoint("After repairing Shooter portals")
	Selection:Set(portals)
	status(`Repaired {#portals} named portal tiles and removed {removed} broken legacy script{if removed == 1 then "" else "s"}. The Rojo server now pairs sibling tiles by floor.`)
end

local function isBridgeColor(color: Color3): boolean
	local isRed = color.R >= 0.8 and color.G <= 0.25 and color.B <= 0.25
	local isGreen = color.G >= 0.8 and color.R <= 0.25 and color.B <= 0.25
	local isBlue = color.B >= 0.5 and color.R <= 0.25 and color.G <= 0.25
	return isRed or isGreen or isBlue
end

local function repairBridge()
	local bridge = Workspace:FindFirstChild("Obby Part")
	if not bridge then
		error("Workspace.Obby Part was not found.")
	end

	ChangeHistoryService:SetWaypoint("Before repairing Shooter colored bridge")
	local surfaces = 0
	local repaired = 0
	for _, descendant in bridge:GetDescendants() do
		if descendant:IsA("BasePart") then
			local isWalkwayShape = descendant.Size.Y <= 4 and descendant.Size.X >= 5 and descendant.Size.Z >= 5
			if descendant.Anchored and isWalkwayShape and isBridgeColor(descendant.Color) then
				surfaces += 1
				if not descendant.CanCollide or descendant.CollisionGroup ~= "Default" then
					repaired += 1
				end
				descendant.CanCollide = true
				descendant.CanQuery = true
				descendant.CanTouch = true
				descendant.CollisionGroup = "Default"
			end
		end
	end
	if surfaces == 0 then
		error("No red, green, or blue walkway surfaces were found inside Workspace.Obby Part.")
	end
	ChangeHistoryService:SetWaypoint("After repairing Shooter colored bridge")
	Selection:Set({ bridge })
	status(`Colored bridge repaired: all {surfaces} surfaces are solid ({repaired} changed).`)
end

local function checkSystems()
	local missing = {}
	if not ReplicatedStorage:FindFirstChild(SHARED_NAME) then
		table.insert(missing, "ShooterShared")
	end
	if not ServerScriptService:FindFirstChild("ShooterBootstrap") then
		table.insert(missing, "ShooterBootstrap")
	end
	if not Workspace:FindFirstChild("Shop") then
		table.insert(missing, "Workspace.Shop")
	end
	local namedPortals = {}
	local legacyPortalScripts = 0
	for _, descendant in Workspace:GetDescendants() do
		local lowerName = string.lower(descendant.Name)
		if descendant:IsA("BasePart") and table.find({ "p1", "p2", "pt1", "pt2" }, lowerName) then
			table.insert(namedPortals, descendant)
			for _, portalDescendant in descendant:GetDescendants() do
				if portalDescendant:IsA("BaseScript") then
					legacyPortalScripts += 1
				end
			end
		end
	end
	if #namedPortals < 2 then
		table.insert(missing, "paired p1/p2 tiles")
	end
	if #missing > 0 then
		status(`Needs attention: {table.concat(missing, ", ")}.`, true)
	elseif legacyPortalScripts > 0 then
		status(`Found {legacyPortalScripts} broken legacy portal script{if legacyPortalScripts == 1 then "" else "s"}. Click Repair Portals.`, true)
	else
		status(`Shooter sync OK. Shop and {#namedPortals} repaired portal tiles found. Plugin v{PLUGIN_VERSION}.`)
	end
end

local function safe(action: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		status(`{action} failed: {tostring(err)}`, true)
	end
end

local function queueUpdate()
	if not autoUpdate or queued then
		return
	end
	queued = true
	task.delay(0.7, function()
		queued = false
		if autoUpdate then
			safe("Auto update", updateExpansion)
		end
	end)
end

local toolbar = plugin:CreateToolbar("Shooter")
local updateButton = toolbar:CreateButton("Update Expansion", "Rebuild only ShooterExpansion beside the existing arena.", "rbxassetid://6031075938")
local checkButton = toolbar:CreateButton("Check Systems", "Check Shooter Rojo sync, shop, and portal objects.", "rbxassetid://6031280882")
local repairButton = toolbar:CreateButton("Repair Portals", "Remove broken legacy scripts from p1/p2 so ShooterBootstrap can control them.", "rbxassetid://6031075938")
local bridgeButton = toolbar:CreateButton("Repair Bridge", "Make every red, green, and blue bridge walkway solid.", "rbxassetid://6031075938")
local selectButton = toolbar:CreateButton("Select Expansion", "Select ShooterExpansion in Explorer.", "rbxassetid://6031091002")
local clearButton = toolbar:CreateButton("Clear Expansion", "Remove only ShooterExpansion.", "rbxassetid://6031094678")
local autoButton = toolbar:CreateButton("Auto Update", "Rebuild the expansion when ArenaExpansion changes through Rojo.", "rbxassetid://6031280882")

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 390, 150, 300, 110)
local widget = plugin:CreateDockWidgetPluginGui("ShooterUpdaterStatus", widgetInfo)
widget.Title = "Shooter Updater"

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(23, 29, 38)
frame.BorderSizePixel = 0
frame.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = frame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromScale(1, 1)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextColor3 = Color3.fromRGB(220, 228, 238)
statusLabel.TextSize = 14
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = `Shooter updater v{PLUGIN_VERSION} ready. Existing arena is never replaced.`
statusLabel.Parent = frame

updateButton.Click:Connect(function()
	widget.Enabled = true
	safe("Update expansion", updateExpansion)
end)
checkButton.Click:Connect(function()
	widget.Enabled = true
	safe("Check systems", checkSystems)
end)
repairButton.Click:Connect(function()
	widget.Enabled = true
	safe("Repair portals", repairPortals)
end)
bridgeButton.Click:Connect(function()
	widget.Enabled = true
	safe("Repair bridge", repairBridge)
end)
selectButton.Click:Connect(function()
	widget.Enabled = true
	selectExpansion()
end)
clearButton.Click:Connect(function()
	widget.Enabled = true
	safe("Clear expansion", clearExpansion)
end)
autoButton.Click:Connect(function()
	widget.Enabled = true
	autoUpdate = not autoUpdate
	autoButton:SetActive(autoUpdate)
	if sourceConnection then
		sourceConnection:Disconnect()
		sourceConnection = nil
	end
	if autoUpdate then
		sourceConnection = getModule().Changed:Connect(function(property)
			if property == "Source" or property == "Parent" then
				queueUpdate()
			end
		end)
		status("Auto Update enabled.")
	else
		status("Auto Update disabled.")
	end
end)

status(`Loaded Shooter updater v{PLUGIN_VERSION}. Existing arena will be preserved.`)
