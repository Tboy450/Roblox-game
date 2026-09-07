local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() local i = table.find(callbacks, callback); if i then table.remove(callbacks, i) end end }
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(callbacks) do callback(...) end
		end,
	}
end

local runStateChanged = signal()
local mode = "edit"
local waypoints = 0
local delayed = {}
local services = {
	ChangeHistoryService = { SetWaypoint = function() waypoints += 1 end },
	ReplicatedStorage = { DescendantAdded = signal(), FindFirstChild = function() return nil end },
	RunService = setmetatable({
		IsEdit = function() return mode == "edit" end,
		IsRunning = function() return mode == "running" end,
		GetPropertyChangedSignal = function(_, property)
			assert(property == "RunState", "Unexpected RunService property")
			return runStateChanged
		end,
	}, { __index = function(_, key) error(`Unsupported RunService member: {key}`) end }),
	Selection = {},
	StarterGui = {},
	StarterPlayer = {},
	Workspace = { FindFirstChild = function() return nil end },
}
local game = { GetService = function(_, name) return assert(services[name], name) end }
local buttons = {}
local plugin = {
	Unloading = signal(),
	CreateToolbar = function()
		return { CreateButton = function(_, name)
			local button = { Click = signal(), SetActive = function() end }
			buttons[name] = button
			return button
		end }
	end,
	CreateDockWidgetPluginGui = function() return {} end,
}
local Instance = { new = function() return {} end }
local Color3 = { fromRGB = function(...) return { ... } end }
local UDim = { new = function(...) return { ... } end }
local UDim2 = { fromScale = function(...) return { ... } end }
local DockWidgetPluginGuiInfo = { new = function(...) return { ... } end }
local Enum = { InitialDockState = { Float = 1 }, Font = { Gotham = 1 }, TextXAlignment = { Left = 1 }, TextYAlignment = { Top = 1 } }
local warnings = {}
local function warn(message) table.insert(warnings, message) end
local task = { delay = function(_, callback) table.insert(delayed, callback) end }
local function flush()
	local pending = delayed
	delayed = {}
	for _, callback in pending do callback() end
end
