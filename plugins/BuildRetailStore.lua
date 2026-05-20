-- Studio edit-mode map updater for the retail game.
-- Requires Rojo connected so ReplicatedStorage.Shared.RetailStoreBlueprint exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local STORE_NAME = "RetailStore"
local BLUEPRINT_NAME = "RetailStoreBlueprint"
local CATALOG_NAME = "RetailCatalog"
local BLUEPRINT_VERSION = 35

local autoUpdateEnabled = false
local autoUpdateQueued = false
local sourceChangedConnections: { [ModuleScript]: RBXScriptConnection } = {}
local sharedChildConnection: RBXScriptConnection? = nil
local lastStatusLabel: TextLabel? = nil

local function log(message: string)
	print(`[RetailMapUpdater] {message}`)
	if lastStatusLabel then
		lastStatusLabel.TextColor3 = Color3.fromRGB(184, 232, 190)
		lastStatusLabel.Text = message
	end
end

local function warnPlugin(message: string)
	warn(`[RetailMapUpdater] {message}`)
	if lastStatusLabel then
		lastStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 150)
		lastStatusLabel.Text = message
	end
end

local function getBlueprintModule(): ModuleScript
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		error("Connect Rojo first: Plugins -> Rojo -> Connect to localhost:34872.")
	end

	local moduleScript = shared:FindFirstChild(BLUEPRINT_NAME)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error("RetailStoreBlueprint was not found. Save files and reconnect Rojo.")
	end

	return moduleScript
end

local function getCatalogModule(): ModuleScript
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		error("Connect Rojo first: Plugins -> Rojo -> Connect to localhost:34872.")
	end

	local moduleScript = shared:FindFirstChild(CATALOG_NAME)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error("RetailCatalog was not found. Save files and reconnect Rojo.")
	end

	return moduleScript
end

local function requireFreshBlueprint()
	local runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "RetailMapBuildRuntime"
	runtimeFolder.Parent = ReplicatedStorage

	local catalogClone = getCatalogModule():Clone()
	catalogClone.Name = CATALOG_NAME
	catalogClone.Parent = runtimeFolder

	local blueprintClone = getBlueprintModule():Clone()
	blueprintClone.Name = BLUEPRINT_NAME
	blueprintClone.Parent = runtimeFolder

	local ok, result = pcall(require, blueprintClone)
	runtimeFolder:Destroy()

	if not ok then
		error(result)
	end

	return result
end

local function countParts(model: Instance): number
	local total = 0
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

local function updateMap()
	ChangeHistoryService:SetWaypoint("Before retail map update")

	local blueprint = requireFreshBlueprint()
	if typeof(blueprint) ~= "table" or typeof(blueprint.build) ~= "function" then
		error("RetailStoreBlueprint did not return a table with a build function.")
	end

	local store = blueprint.build({
		parent = Workspace,
		storeName = STORE_NAME,
		forceRebuild = true,
	})
	if not store or not store:IsA("Model") then
		error("RetailStoreBlueprint.build did not return the RetailStore model.")
	end

	ChangeHistoryService:SetWaypoint("After retail map update")
	Selection:Set({ store })
	log(`Updated {STORE_NAME} v{store:GetAttribute("BlueprintVersion") or BLUEPRINT_VERSION} ({countParts(store)} parts).`)
end

local function clearMap()
	local existing = Workspace:FindFirstChild(STORE_NAME)
	if not existing then
		log("No RetailStore found to clear.")
		return
	end

	ChangeHistoryService:SetWaypoint("Before clearing retail map")
	existing:Destroy()
	ChangeHistoryService:SetWaypoint("After clearing retail map")
	log("Cleared RetailStore from Workspace.")
end

local function selectMap()
	local existing = Workspace:FindFirstChild(STORE_NAME)
	if existing then
		Selection:Set({ existing })
		log("Selected RetailStore.")
	else
		warnPlugin("No RetailStore found. Click Update Map first.")
	end
end

local function runSafely(actionName: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warnPlugin(`{actionName} failed: {tostring(err)}`)
	end
end

local function queueAutoUpdate()
	if not autoUpdateEnabled or autoUpdateQueued then
		return
	end

	autoUpdateQueued = true
	task.delay(0.75, function()
		autoUpdateQueued = false
		if autoUpdateEnabled then
			runSafely("Auto update", updateMap)
		end
	end)
end

local function clearSourceWatches()
	for moduleScript, connection in sourceChangedConnections do
		connection:Disconnect()
		sourceChangedConnections[moduleScript] = nil
	end
end

local function watchSource(moduleScript: ModuleScript)
	sourceChangedConnections[moduleScript] = moduleScript.Changed:Connect(function(propertyName)
		if propertyName == "Source" or propertyName == "Parent" then
			queueAutoUpdate()
		end
	end)
end

local function watchSources()
	clearSourceWatches()
	watchSource(getBlueprintModule())
	watchSource(getCatalogModule())
end

local toolbar = plugin:CreateToolbar("Retail Game")

local updateButton = toolbar:CreateButton(
	"Update Map",
	"Rebuild RetailStore v35 in Workspace using the latest Rojo-synced blueprint.",
	"rbxassetid://6031075938"
)

local clearButton = toolbar:CreateButton(
	"Clear Map",
	"Delete RetailStore from Workspace.",
	"rbxassetid://6031094678"
)

local selectButton = toolbar:CreateButton(
	"Select Map",
	"Select RetailStore in Explorer.",
	"rbxassetid://6031091002"
)

local autoButton = toolbar:CreateButton(
	"Auto Update",
	"Toggle automatic map rebuild when RetailStoreBlueprint or RetailCatalog changes.",
	"rbxassetid://6031280882"
)

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	360,
	120,
	280,
	100
)
local statusWidget = plugin:CreateDockWidgetPluginGui("RetailMapUpdaterStatus", widgetInfo)
statusWidget.Title = "Retail Map"

local statusFrame = Instance.new("Frame")
statusFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
statusFrame.BorderSizePixel = 0
statusFrame.Size = UDim2.fromScale(1, 1)
statusFrame.Parent = statusWidget

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingTop = UDim.new(0, 10)
statusPadding.PaddingRight = UDim.new(0, 10)
statusPadding.PaddingBottom = UDim.new(0, 10)
statusPadding.PaddingLeft = UDim.new(0, 10)
statusPadding.Parent = statusFrame

lastStatusLabel = Instance.new("TextLabel")
lastStatusLabel.BackgroundTransparency = 1
lastStatusLabel.Font = Enum.Font.Gotham
lastStatusLabel.TextColor3 = Color3.fromRGB(220, 226, 236)
lastStatusLabel.TextSize = 14
lastStatusLabel.TextWrapped = true
lastStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
lastStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
lastStatusLabel.Size = UDim2.fromScale(1, 1)
lastStatusLabel.Text = "Ready. Connect Rojo, then click Update Map."
lastStatusLabel.Parent = statusFrame

updateButton.Click:Connect(function()
	statusWidget.Enabled = true
	runSafely("Update map", updateMap)
end)

clearButton.Click:Connect(function()
	statusWidget.Enabled = true
	runSafely("Clear map", clearMap)
end)

selectButton.Click:Connect(function()
	statusWidget.Enabled = true
	selectMap()
end)

autoButton.Click:Connect(function()
	statusWidget.Enabled = true
	autoUpdateEnabled = not autoUpdateEnabled
	autoButton:SetActive(autoUpdateEnabled)

	if autoUpdateEnabled then
		runSafely("Watch sources", watchSources)

		if sharedChildConnection then
			sharedChildConnection:Disconnect()
		end

		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared then
			sharedChildConnection = shared.ChildAdded:Connect(function(child)
				if child.Name == BLUEPRINT_NAME or child.Name == CATALOG_NAME then
					runSafely("Watch sources", watchSources)
					queueAutoUpdate()
				end
			end)
		end

		log("Auto Update enabled.")
	else
		clearSourceWatches()
		if sharedChildConnection then
			sharedChildConnection:Disconnect()
			sharedChildConnection = nil
		end

		log("Auto Update disabled.")
	end
end)

log("Loaded. Use Retail Game -> Update Map after Rojo connects.")
