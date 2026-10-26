-- Rebuilds retail store on Play, replacing the previous map when construction finishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function buildStore()
	local existing = Workspace:FindFirstChild("RetailStore")
	if existing and existing:GetAttribute("ImportedArt") == true then
		print("[BuildRetailMap] Preserving imported store and its interaction anchors")
		return existing
	end
	local config = ReplicatedStorage:FindFirstChild("RetailMapConfig")
	local mode = if config then config:GetAttribute("Mode") else "Legacy"
	if mode == nil then mode = "Legacy" end
	if mode ~= "Legacy" and mode ~= "AssetTest" then
		error(`Unknown retail map mode: {tostring(mode)}. No store was replaced.`)
	end
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	if not shared then
		error("[BuildRetailMap] ReplicatedStorage.Shared missing — connect Rojo in Studio first.")
	end
	if mode == "AssetTest" then
		local library = game:GetService("ServerStorage"):FindFirstChild("RetailAssetLibrary")
		if not library then error("Import the fixture kit into ServerStorage.RetailAssetLibrary in the separate test place first") end
		local assetTest = require(shared:WaitForChild("RetailAssetTestBlueprint"))
		return assetTest.build({ parent = Workspace, library = library })
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
print(`[BuildRetailMap] RETAIL STORE READY ({store:GetAttribute("RetailMapMode") or "Legacy"})`)
print(`  Parts: {partCount}`)
print(`  BlueprintVersion attribute: {store:GetAttribute("BlueprintVersion")}`)
if store:GetAttribute("RetailMapMode") == "AssetTest" then
	print("  Fixture integration test: imported shelf and player checkout; NPC/store-day integration pending")
else
	print("  Legacy retail blueprint and mechanics")
end
print("========================================")
