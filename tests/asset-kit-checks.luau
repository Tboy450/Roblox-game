-- Runs against the real integration builder with construction doubles.
local baseIsA = methods.IsA
function methods:IsA(class)
	return (class == "BasePart" and self.ClassName == "MeshPart")
		or (class == "LuaSourceContainer" and self.ClassName == "Script") or baseIsA(self, class)
end
function methods:Clone()
	local copy = Instance.new(self.ClassName)
	for key, value in self.props do if key ~= "Parent" then copy[key] = value end end
	for key, value in self.attributes do copy:SetAttribute(key, value) end
	for _, child in self:GetChildren() do child:Clone().Parent = copy end
	return copy
end
function methods:PivotTo(frame)
	for _, child in self:GetDescendants() do
		if child:IsA("BasePart") then child.Position = child.Position + frame.Position end
	end
end
local function count(parent) return #parent:GetChildren() end
local function template(library, id)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("StoreAssetPrepared", true)
	model:SetAttribute("AssetUnits", "Studs")
	model:SetAttribute("AssetVersion", 1)
	local mesh = Instance.new("MeshPart")
	mesh.Name = "ImportedGeometry"
	mesh.Position = Vector3.new(0, 0, 0)
	mesh.Parent = model
	model.Parent = library
	return model
end
local library = Instance.new("Folder")
local parent = Instance.new("Workspace")
assert(not pcall(function() AssetTest.build({ parent = parent, library = library }) end))
assert(count(parent) == 0, "Missing assets must not publish a partial map")
local shelfTemplate = template(library, "gondola_01")
local checkoutTemplate = template(library, "checkout_01")
checkoutTemplate:SetAttribute("AssetUnits", "Meters")
assert(not pcall(function() AssetTest.build({ parent = parent, library = library }) end))
assert(count(parent) == 0, "Wrong units must fail before publishing")
checkoutTemplate:SetAttribute("AssetUnits", "Studs")
local scriptFixture = Instance.new("Script")
scriptFixture.Parent = checkoutTemplate
assert(not pcall(function() AssetTest.build({ parent = parent, library = library }) end))
assert(count(parent) == 0, "Imported scripts must be rejected")
scriptFixture:Destroy()
local originalClone = methods.Clone
function methods:Clone()
	if self.Name == "checkout_01" then error("simulated second-asset clone failure") end
	return originalClone(self)
end
assert(not pcall(function() AssetTest.build({ parent = parent, library = library }) end))
assert(count(parent) == 0 and count(library) == 2, "Assembly failure must preserve templates and avoid partial publication")
methods.Clone = originalClone
local store = AssetTest.build({ parent = parent, library = library })
assert(store:GetAttribute("ImportedArt") and store:GetAttribute("RetailMapMode") == "AssetTest")
for _, name in { "Visuals", "Collisions", "InteractionAnchors", "Navigation" } do assert(store:FindFirstChild(name)) end
local anchors = store:FindFirstChild("InteractionAnchors")
local shelf = anchors:FindFirstChild("ShelfUnit1")
assert(shelf:GetAttribute("ShelfId") == 1 and shelf:GetAttribute("ShelfStock") == 12)
assert(shelf:FindFirstChild("ShelfControl"):GetAttribute("RetailAction") == "ConfigureShelf")
assert(shelf:FindFirstChild("RestockControl"):GetAttribute("RetailAction") == "RestockShelf")
assert(shelf:FindFirstChild("ProductSelector"):GetAttribute("RetailAction") == "CollectItem")
local products = 0
local ids = {}
for _, child in store:GetDescendants() do
	if child:GetAttribute("ShelfProductVisual") then
		products += 1
		assert(not child.CanCollide and child:GetAttribute("DecorativeProduct"), "Stock visuals must not obstruct shoppers")
	end
	local id = child:GetAttribute("InteractionId")
	if id then assert(not ids[id], "Duplicate interaction ID"); ids[id] = true end
end
assert(products == 12, "Four shelves of three runtime stock slots expected")
local register = anchors:FindFirstChild("PlayerRegister")
assert(register:GetAttribute("RegisterId") == "PlayerRegister")
assert(register:FindFirstChild("CashDrawer"):GetAttribute("RetailAction") == "OpenPlayerRegister")
assert(register:FindFirstChild("MonitorScreen") and register:FindFirstChild("ReceiptPaper"))
assert(count(library) == 2 and shelfTemplate.Parent == library and checkoutTemplate.Parent == library)
for _, visual in store:FindFirstChild("Visuals"):GetDescendants() do
	if visual:IsA("MeshPart") then assert(visual.Anchored and not visual.CanCollide and not visual.CanTouch) end
end
assert(AssetTest.build({ parent = parent, library = library }) == store and count(parent) == 1,
	"Repeated builds must preserve imported geometry, stock state and prompt count")
store:SetAttribute("RetailMapMode", "Legacy")
assert(not pcall(function() AssetTest.build({ parent = parent, library = library }) end))
assert(parent:FindFirstChild("RetailStore") == store and not store.destroyed, "Legacy store must not be replaced")
print("PASS: imported kit validation, atomic publication, stock/checkout contracts, collision separation and idempotence")
