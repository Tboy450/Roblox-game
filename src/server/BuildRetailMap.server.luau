-- Rebuilds retail store on Play. Deletes any old copy first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BLUEPRINT_VERSION = 45

local function buildStore()
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	if not shared then
		error("[BuildRetailMap] ReplicatedStorage.Shared missing — connect Rojo in Studio first.")
	end

	local module = shared:WaitForChild("RetailStoreBlueprint", 10)
	if not module then
		error("[BuildRetailMap] RetailStoreBlueprint missing — save files and reconnect Rojo.")
	end

	local RetailStoreBlueprint = require(module)
	return RetailStoreBlueprint.build({
		parent = Workspace,
		storeName = "RetailStore",
		forceRebuild = true,
	})
end

local ok, result = pcall(buildStore)
if not ok then
	warn("[BuildRetailMap] FAILED:", result)
	return
end

local store = result
local partCount = 0
for _, desc in store:GetDescendants() do
	if desc:IsA("BasePart") then
		partCount += 1
	end
end

print("========================================")
print(`[BuildRetailMap] RETAIL STORE v{BLUEPRINT_VERSION} READY`)
print(`  Parts: {partCount}`)
print(`  BlueprintVersion attribute: {store:GetAttribute("BlueprintVersion")}`)
print("  Blueprint v45: pet care, stock ordering, register streaks, and HUD action polish")
print("========================================")
