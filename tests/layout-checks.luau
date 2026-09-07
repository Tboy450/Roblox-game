-- Runs against the real generated blueprint; intentionally excludes trim attached to fixtures.
local layout = Blueprint.build({ parent = workspace })
local solids, walls = {}, {}
local function intersects(a, b)
	for _, axis in { "X", "Y", "Z" } do
		if math.abs(a.Position[axis] - b.Position[axis]) >= (a.Size[axis] + b.Size[axis]) / 2 - 0.01 then return false end
	end
	return true
end
local function path(item)
	return item.Parent.Name .. "/" .. item.Name
end
local errors = {}
for _, item in layout:GetDescendants() do
	if not item:IsA("BasePart") then continue end
	if item:GetAttribute("BlueprintWall") then
		table.insert(walls, item)
	elseif item.CanCollide and item.Size.Y > 0.4 and item.Position.Y - item.Size.Y / 2 < 12
		and item.Position.Y + item.Size.Y / 2 > 1.8 and not item.Name:match("^Pillar") then
		table.insert(solids, item)
	end
end
for _, wall in walls do
	for _, item in solids do
		if intersects(wall, item) then table.insert(errors, path(item) .. " intersects " .. path(wall)) end
	end
end
for _, message in errors do print("FAIL: " .. message) end
assert(#errors == 0, `Fixtures in room walls: {#errors}`)
print("PASS: perimeter fixture-to-wall clearance")

local furniture = {
	StockRoom = { "RackWest", "RackNorth", "RackEast", "StockPallet1", "StockPallet2", "StockWorkTable", "PalletJackBase", "ShrinkWrapRolls" },
	Bakery = { "Display1", "Display2", "Display3", "Oven", "PrepCounter", "StandMixer", "BreadRack", "IngredientBin1", "IngredientBin2", "CoolingRack" },
	Pharmacy = { "ServiceCounter", "DropoffWindowCounter", "MedicineShelf1", "MedicineShelf2", "LockedMedsCabinet", "VaccineFridge", "WaitingBench", "PrivacyDivider", "ConsultTable", "ConsultChair1", "ConsultChair2" },
	Restrooms = { "SinkCounter", "RestroomTrashCan", "BabyChangingStation", "RestroomVestibuleScreen", "ToiletBase1", "ToiletBase2", "ToiletBase3" },
	AdminNook = { "ManagerDesk", "DeskReturn", "FilingCabinet1", "FilingCabinet2", "OfficeSafe", "ManagerChair" },
	BreakRoom = { "KitchenetteCounter", "Fridge", "VendingMachine", "CafeTable", "BreakChairNorth", "BreakChairSouth", "BreakChairEast", "BreakBench", "StaffLocker1", "StaffLocker2", "StaffLocker3" },
	LoadingDock = { "DockBox-1", "DockBox0", "DockBox1", "ReceivingPallet", "ShippingPallet", "PalletJack", "ForkliftBase" },
	WalkInCooler = { "CoolerShelf-1", "CoolerShelf0", "CoolerShelf1", "CoolerPullCase", "CoolerCrate1", "CoolerCrate2", "CoolerCrate3", "CoolerCrate4" },
}
errors = {}
for roomName, names in furniture do
	local room = layout:FindFirstChild(roomName)
	for i, name in names do
		local a = room:FindFirstChild(name)
		assert(a, `Missing {roomName}/{name}`)
		for j = i + 1, #names do
			local b = room:FindFirstChild(names[j])
			assert(b, `Missing {roomName}/{names[j]}`)
			if intersects(a, b) then table.insert(errors, path(a) .. " intersects " .. path(b)) end
		end
	end
end
for _, message in errors do print("FAIL: " .. message) end
assert(#errors == 0, `Overlapping room fixtures: {#errors}`)
print("PASS: principal furniture separation in eight perimeter rooms")

local byName = {}
for _, item in layout:GetDescendants() do
	if item:IsA("BasePart") then byName[item.Name] = item end
end
local frontFixtures = {}
for _, name in { "ServiceDesk", "ReturnBin", "PickupLockers", "LostAndFoundShelf", "TeamBacker", "PetCareStation", "SeasonalEndcap", "BasketStack-1", "BasketStack0", "BasketStack1", "MagazineRack", "WaterFountain", "BagHolder1", "BagHolder2" } do
	assert(byName[name], "Missing front fixture " .. name)
	table.insert(frontFixtures, byName[name])
end
table.insert(frontFixtures, layout:FindFirstChild("FrontEnd"):FindFirstChild("PetLotteryKiosk"):FindFirstChild("Base"))
for _, lane in layout:FindFirstChild("FrontEnd"):FindFirstChild("Checkout"):GetChildren() do
	table.insert(frontFixtures, lane:FindFirstChild("Counter"))
end
errors = {}
for i, a in frontFixtures do
	for j = i + 1, #frontFixtures do
		if intersects(a, frontFixtures[j]) then table.insert(errors, path(a) .. " intersects " .. path(frontFixtures[j])) end
	end
end
for _, message in errors do print("FAIL: " .. message) end
assert(#errors == 0, `Overlapping front fixtures: {#errors}`)
print("PASS: service, pet kiosk, checkout, and front-display fixture separation")
local function clearRoute(name, from, to)
	for step = 0, 40 do
		local position = from + (to - from) * (step / 40)
		local body = { Position = Vector3.new(position.X, 4.2, position.Z), Size = Vector3.new(3.6, 5.6, 3.6) }
		for _, obstacle in { solids, walls } do
			for _, item in obstacle do
				assert(not intersects(body, item), `{name} blocked by {path(item)} at {position.X}, {position.Z}`)
			end
		end
	end
end
for _, x in { -36, 0, 36 } do
	clearRoute(`Back room {x}`, Vector3.new(x, 0, -22), Vector3.new(x, 0, -41))
end
clearRoute("Rear cross aisle", Vector3.new(-38, 0, -23.25), Vector3.new(38, 0, -23.25))
for _, doorway in {
	{ name = "Pharmacy", z = -14, fromX = -38, toX = -49 },
	{ name = "Bakery", z = 16, fromX = -38, toX = -51 },
	{ name = "Restrooms", z = -16, fromX = 38, toX = 50 },
	{ name = "Break room", z = 8, fromX = 38, toX = 48 },
	{ name = "Office", z = 30, fromX = 38, toX = 45 },
} do
	clearRoute(doorway.name, Vector3.new(doorway.fromX, 0, doorway.z), Vector3.new(doorway.toX, 0, doorway.z))
end
local ordinaryBays = {}
for _, item in layout:GetDescendants() do
	if item:GetAttribute("TrafficMarkerKind") == "Parking" then
		table.insert(ordinaryBays, { Position = Vector3.new(item.Position.X, 2, item.Position.Z), Size = Vector3.new(item:GetAttribute("BayWidth"), 2, item:GetAttribute("BayDepth")) })
	end
end
assert(#ordinaryBays == 10, "Ten ordinary parking bays should have matching traffic markers")
for i, side in { -1, 1 } do
	local pad, aisle = byName[`AccessibleSpace{i}`], byName[`AccessibleAisle{i}`]
	assert(pad:GetAttribute("ReservedParking") and aisle:GetAttribute("AccessAisle"))
	assert(pad.Size.X == 12 and pad.Size.Z == 16 and aisle.Size.X == 6, "Reserved bays need a separate full-width access aisle")
	assert(math.abs(pad.Position.X - aisle.Position.X) == (pad.Size.X + aisle.Size.X) / 2, "Access aisle must adjoin its bay")
	assert(aisle.Position.Z - aisle.Size.Z / 2 == 59, "Access aisle must meet the front sidewalk")
	clearRoute("Access aisle", Vector3.new(side * 12, 0, 74), Vector3.new(side * 12, 0, 58))
	clearRoute("Sidewalk to entrance", Vector3.new(side * 12, 0, 58), Vector3.new(0, 0, 58))
	for _, bay in ordinaryBays do
		for _, reserved in { pad, aisle, byName.EntryWalk, byName[`LotWalk{side}`] } do
			local footprint = { Position = Vector3.new(reserved.Position.X, 2, reserved.Position.Z), Size = Vector3.new(reserved.Size.X, 2, reserved.Size.Z) }
			assert(not intersects(bay, footprint), "Ordinary parking cannot cover reserved spaces or walking routes")
		end
	end
end
for i, bay in ordinaryBays do
	for j = i + 1, #ordinaryBays do assert(not intersects(bay, ordinaryBays[j]), "Parking bays must not overlap") end
end
local mainFloor = byName.MainFloor
assert(mainFloor.Position.Z + mainFloor.Size.Z / 2 == 50, "The main floor must reach the front wall, including both corners")
assert(byName.EntryThreshold.Position.Z - byName.EntryThreshold.Size.Z / 2 == 50)
assert(byName.EntryWalk.Position.Z - byName.EntryWalk.Size.Z / 2 == 59)
local interiorProps = layout:FindFirstChild("InteriorProps")
assert(not interiorProps:FindFirstChild("Mirror") and not interiorProps:FindFirstChild("Microwave"), "Remove legacy duplicate room props")
assert(not interiorProps:FindFirstChild("Toilet-1") and not interiorProps:FindFirstChild("BreakChair0"))
assert(not layout:FindFirstChild("BD_W"), "Back rooms must not have a second parallel divider")
print("PASS: room entrances, rear cross aisle, reserved parking, sidewalk connections, and continuous front floor")
