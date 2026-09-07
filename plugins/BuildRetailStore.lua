-- Studio edit-mode map updater for the retail game.
-- Requires Rojo connected so ReplicatedStorage.Shared.RetailStoreBlueprint exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local STORE_NAME = "RetailStore"
local BLUEPRINT_NAME = "RetailStoreBlueprint"
local CATALOG_NAME = "RetailCatalog"
local HUD_CLIENT_SOURCE_NAME = "RetailHudClientSource"
local HUD_RUNNER_NAME = "RetailHudRunner"
local CLIENT_SCRIPT_NAME = "Client"
local PLUGIN_VERSION = 52
local MIN_BLUEPRINT_VERSION = 52

local autoUpdateEnabled = false
local autoUpdateQueued = false
local sourceChangedConnections: { [LuaSourceContainer]: RBXScriptConnection } = {}
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

local function readModuleBlueprintVersion(moduleScript: ModuleScript): number?
	local ok, source = pcall(function()
		return moduleScript.Source
	end)
	if not ok or typeof(source) ~= "string" then
		return nil
	end

	local versionText = source:match("BLUEPRINT_VERSION%s*=%s*(%d+)")
	return if versionText then tonumber(versionText) else nil
end

local function versionLabel(version: number?): string
	return if version then `v{version}` else "unknown"
end

local function checkSync()
	local moduleScript = getBlueprintModule()
	local syncedVersion = readModuleBlueprintVersion(moduleScript)
	local store = Workspace:FindFirstChild(STORE_NAME)
	local builtVersion = if store then store:GetAttribute("BlueprintVersion") else nil
	if syncedVersion and syncedVersion >= MIN_BLUEPRINT_VERSION then
		log(`Updater v{PLUGIN_VERSION}; synced blueprint {versionLabel(syncedVersion)}; map {versionLabel(builtVersion)}. Ready to Update Map.`)
	else
		warnPlugin(
			`Blueprint {versionLabel(syncedVersion)} is older than v{MIN_BLUEPRINT_VERSION}. Connect the retail Rojo project at localhost:34872, then Update Map.`
		)
	end
end

local function requireFreshBlueprint(blueprintModule: ModuleScript?)
	local runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "RetailMapBuildRuntime"
	runtimeFolder.Parent = ReplicatedStorage

	local catalogClone = getCatalogModule():Clone()
	catalogClone.Name = CATALOG_NAME
	catalogClone.Parent = runtimeFolder

	local blueprintClone = (blueprintModule or getBlueprintModule()):Clone()
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

local function findStarterPlayerClient(): LocalScript?
	local starterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not starterPlayerScripts then
		return nil
	end

	local client = starterPlayerScripts:FindFirstChild(CLIENT_SCRIPT_NAME)
	if client and client:IsA("LocalScript") then
		return client
	end
	return nil
end

local function findReplicatedClientSource(): LocalScript?
	local source = ReplicatedStorage:FindFirstChild(HUD_CLIENT_SOURCE_NAME)
	if source and source:IsA("LocalScript") then
		return source
	end

	if source then
		local client = source:FindFirstChild(CLIENT_SCRIPT_NAME)
		if client and client:IsA("LocalScript") then
			return client
		end
	end

	return nil
end

local function findHudClientSource(screenGui: ScreenGui): LocalScript?
	local replicatedSource = findReplicatedClientSource()
	if replicatedSource then
		return replicatedSource
	end

	local starterGuiClient = StarterGui:FindFirstChild(CLIENT_SCRIPT_NAME)
	if starterGuiClient and starterGuiClient:IsA("LocalScript") then
		return starterGuiClient
	end

	local runnerClient = screenGui:FindFirstChild(CLIENT_SCRIPT_NAME)
	if runnerClient and runnerClient:IsA("LocalScript") then
		return runnerClient
	end

	return findStarterPlayerClient()
end

local function ensureHudRunner(): (boolean, string)
	local runner = StarterGui:FindFirstChild(HUD_RUNNER_NAME)
	if runner and not runner:IsA("ScreenGui") then
		return false, `{HUD_RUNNER_NAME} exists in StarterGui but is a {runner.ClassName}, not a ScreenGui.`
	end

	if not runner then
		runner = Instance.new("ScreenGui")
		runner.Name = HUD_RUNNER_NAME
		runner.Parent = StarterGui
	end

	local screenGui = runner :: ScreenGui
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = true

	local sourceClient = findHudClientSource(screenGui)
	local existingClient = screenGui:FindFirstChild(CLIENT_SCRIPT_NAME)
	if existingClient and existingClient:IsA("LocalScript") then
		existingClient.Disabled = false
		if sourceClient and sourceClient ~= existingClient and existingClient.Source ~= sourceClient.Source then
			existingClient.Source = sourceClient.Source
			return true, "HUD runner refreshed."
		end
		return true, "HUD runner ready."
	elseif existingClient then
		existingClient:Destroy()
	end

	if not sourceClient or not sourceClient:IsA("LocalScript") then
		return false, "HUD Client script missing. Check Rojo synced ReplicatedStorage > RetailHudClientSource."
	end

	local clientClone = sourceClient:Clone()
	clientClone.Name = CLIENT_SCRIPT_NAME
	clientClone.Disabled = false
	clientClone.Parent = screenGui
	return true, "HUD runner repaired."
end

local function updateMap()
	if not RunService:IsEdit() then
		error("Stop the play test before updating the edit-mode map. Rojo changes are applied on the next Play.")
	end
	ChangeHistoryService:SetWaypoint("Before retail map update")

	local blueprintModule = getBlueprintModule()
	local syncedVersion = readModuleBlueprintVersion(blueprintModule)
	if not syncedVersion or syncedVersion < MIN_BLUEPRINT_VERSION then
		error(
			`Synced blueprint {versionLabel(syncedVersion)} is too old. Connect the retail project at localhost:34872; this updater accepts v{MIN_BLUEPRINT_VERSION} and newer.`
		)
	end

	local blueprint = requireFreshBlueprint(blueprintModule)
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

	local hudReady, hudMessage = ensureHudRunner()

	ChangeHistoryService:SetWaypoint("After retail map update")
	Selection:Set({ store })
	local builtVersionAttribute = store:GetAttribute("BlueprintVersion")
	local builtVersion = if typeof(builtVersionAttribute) == "number" then builtVersionAttribute else nil
	if hudReady then
		log(
			`Updated {STORE_NAME} {versionLabel(builtVersion)} ({countParts(store)} parts). Updater v{PLUGIN_VERSION}; Rojo {versionLabel(syncedVersion)}. {hudMessage}`
		)
	else
		warnPlugin(`Updated map, but HUD setup needs attention: {hudMessage}. Updater v{PLUGIN_VERSION}; Rojo {versionLabel(syncedVersion)}.`)
	end
end

local function clearMap()
	if not RunService:IsEdit() then
		error("Stop the play test before clearing the map.")
	end
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
		if autoUpdateEnabled and RunService:IsEdit() then
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

local function watchSource(moduleScript: LuaSourceContainer)
	sourceChangedConnections[moduleScript] = moduleScript.Changed:Connect(function(propertyName)
		if propertyName == "Source" or propertyName == "Parent" then
			queueAutoUpdate()
		end
	end)
end

local function watchSources()
	clearSourceWatches()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if shared then
		for _, name in { BLUEPRINT_NAME, CATALOG_NAME } do
			local source = shared:FindFirstChild(name)
			if source and source:IsA("ModuleScript") then
				watchSource(source)
			end
		end
	end
	local client = findReplicatedClientSource()
	if client then
		watchSource(client)
	end
end

local toolbar = plugin:CreateToolbar("Retail Game")

local updateButton = toolbar:CreateButton(
	"Update Map",
	"Rebuild RetailStore using the latest Rojo-synced blueprint (v52 and newer).",
	"rbxassetid://6031075938"
)

local checkButton = toolbar:CreateButton(
	"Check Sync",
	"Show updater plugin version and Rojo-synced blueprint version.",
	"rbxassetid://6031280882"
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
	150,
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
lastStatusLabel.Text = `Updater v{PLUGIN_VERSION} ready. Connect Rojo, then click Check Sync or Update Map.`
lastStatusLabel.Parent = statusFrame

updateButton.Click:Connect(function()
	statusWidget.Enabled = true
	runSafely("Update map", updateMap)
end)

checkButton.Click:Connect(function()
	statusWidget.Enabled = true
	runSafely("Check sync", checkSync)
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
		queueAutoUpdate()
		log("Auto Update enabled.")
	else
		clearSourceWatches()
		log("Auto Update disabled.")
	end
end)

ReplicatedStorage.DescendantAdded:Connect(function(child)
	if not autoUpdateEnabled then
		return
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if child == shared or child.Name == HUD_CLIENT_SOURCE_NAME
		or (child.Parent == shared and (child.Name == BLUEPRINT_NAME or child.Name == CATALOG_NAME)) then
		watchSources()
		queueAutoUpdate()
	end
end)

RunService:GetPropertyChangedSignal("RunState"):Connect(function()
	if RunService:IsEdit() then
		queueAutoUpdate()
	end
end)

plugin.Unloading:Connect(function()
	autoUpdateEnabled = false
	clearSourceWatches()
end)
log(`Loaded updater v{PLUGIN_VERSION}. Use Retail Game -> Check Sync after Rojo connects.`)
