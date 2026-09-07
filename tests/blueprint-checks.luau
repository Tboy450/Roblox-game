local store = Blueprint.build({ parent = workspace })
local parts = {}
for _, item in store:GetDescendants() do
	if item:IsA("BasePart") then table.insert(parts, item) end
end
assert(store:GetAttribute("BlueprintVersion") == 52)
local function named(name)
	for _, part in parts do if part.Name == name then return part end end
	error("Missing part " .. name)
end
local function contains(part, x, y, z)
	local d = part.Position
	local s = part.Size
	return math.abs(d.X - x) <= s.X / 2 + 0.0001 and math.abs(d.Y - y) <= s.Y / 2 + 0.0001 and math.abs(d.Z - z) <= s.Z / 2 + 0.0001
end
for _, center in { -42, 42 } do
	for x = center - 10, center + 10, 0.25 do
		for y = 1.05, 14.95, 0.25 do
			local sealed = false
			for _, part in parts do
				if part.CanCollide and contains(part, x, y, 50) then sealed = true break end
			end
			assert(sealed, `Front window gap at {x}, {y}`)
		end
	end
end
local function overlap(a, b)
	for _, axis in { "X", "Y", "Z" } do
		if math.abs(a.Position[axis] - b.Position[axis]) >= (a.Size[axis] + b.Size[axis]) / 2 - 0.01 then return false end
	end
	return true
end
local blocked = {}
local officeFrames = 0
for _, part in parts do
	if part.Name:match("^AdminDoorFrame") then
		officeFrames += 1
		assert(part.Position.Z == 27.1 or part.Position.Z == 32.9, "Office frame must border the office entrance")
	end
end
assert(officeFrames == 2, "Office entrance must have two frame posts")
for _, marker in parts do
	local kind = marker:GetAttribute("TrafficMarkerKind")
	if kind == "Shop" or kind == "Queue" or kind == "Register" or kind == "CustomerPath" or kind == "Staff" then
		local body = { Position = marker.Position + Vector3.new(0, 3.2, 0), Size = Vector3.new(3.6, 5.6, 3.6) }
		for _, fixture in parts do
			if fixture.CanCollide and overlap(body, fixture) then
				table.insert(blocked, `{marker.Name} intersects {fixture.Name}`)
			end
		end
	end
end
assert(#blocked == 0, "Blocked shopper destinations: " .. table.concat(blocked, "; "))
for _, rootName in { "FrontTimeClock", "FrontTaskBoard", "StoreStatusControl", "StoreStatusSign" } do
	for _, otherName in { "FrontTimeClock", "FrontTaskBoard", "StoreStatusControl", "StoreStatusSign" } do
		if rootName ~= otherName then assert(not overlap(named(rootName), named(otherName)), rootName .. " overlaps " .. otherName) end
	end
end
for _, lane in store:FindFirstChild("FrontEnd"):FindFirstChild("Checkout"):GetChildren() do
	local printer = lane:FindFirstChild("ReceiptPrinter")
	for _, propName in { "Monitor", "CashDrawer", "Scanner" } do
		assert(not overlap(printer, lane:FindFirstChild(propName)), `Printer overlaps {propName}`)
	end
end
local oldStore = store
store = Blueprint.build({ parent = workspace })
assert(oldStore.destroyed and #workspace:GetChildren() == 1, "Rebuild must replace the old model exactly once")
assert(Blueprint.build({ parent = workspace, forceRebuild = false }) == store, "Non-forced build must preserve existing store")
print(`PASS: {#parts} generated parts; sealed windows, shopper clearance, fixture spacing, rebuild lifecycle`)
