-- runBootstrap is supplied by the test runner and executes the real server script.
local function services(parent, mode, assetLibrary)
	local shared = { WaitForChild = function(_, name) return name end }
	local config = { GetAttribute = function() return mode end }
	return {
		Workspace = parent,
		ReplicatedStorage = {
			FindFirstChild = function() return config end,
			WaitForChild = function() return shared end,
		},
		ServerStorage = { FindFirstChild = function() return assetLibrary end },
	}
end
local bootParent = Instance.new("Workspace")
local imported = AssetTest.build({ parent = bootParent, library = library })
local warningLog = runBootstrap(services(bootParent, "Legacy", nil))
assert(#warningLog == 0 and bootParent:FindFirstChild("RetailStore") == imported,
	"Startup must preserve imported art even when config points to Legacy")
local emptyParent = Instance.new("Workspace")
warningLog = runBootstrap(services(emptyParent, "AssetTest", nil))
assert(#warningLog == 1 and count(emptyParent) == 0, "Missing imports must not fall back to the legacy map")
warningLog = runBootstrap(services(emptyParent, "UnknownMode", library))
assert(#warningLog == 1 and count(emptyParent) == 0, "Unknown mode must fail without replacing geometry")
warningLog = runBootstrap(services(emptyParent, "AssetTest", library))
assert(#warningLog == 0 and count(emptyParent) == 1
	and emptyParent:FindFirstChild("RetailStore"):GetAttribute("ImportedArt"), "Opt-in startup must publish the actual asset test")
print("PASS: server startup preserves imports, rejects invalid modes/missing assets, and loads the opt-in test")
