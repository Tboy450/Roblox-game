runtimeFolder = Instance.new("Folder")
local count = 0
for _, style in VEHICLE_STYLES do
	local vehicle = createVehicle(style, CFrame.new())
	assert(vehicle.PrimaryPart and vehicle:FindFirstChild("Roof"), "Car must have a root and painted roof")
	assert(vehicle:FindFirstChild("Mirror-1") and vehicle:FindFirstChild("Mirror1"), "Mirrors must exist on both sides")
	local wheels, hubs = 0, 0
	for _, part in vehicle:GetChildren() do
		assert(part.Anchored and not part.CanCollide, "Traffic model parts must not push players")
		assert(math.abs(part.CFrame.Position.X) + part.Size.X / 2 < 6, "Vehicle must fit a 12-stud bay")
		assert(math.abs(part.CFrame.Position.Z) + part.Size.Z / 2 < 8, "Vehicle must fit a 16-stud bay")
		if part.Name == "Wheel" or part.Name == "WheelHub" then
			assert(part.Shape == Enum.PartType.Cylinder and part.Size.Y == part.Size.Z, "Wheels must have circular faces")
			if part.Name == "Wheel" then wheels += 1 else hubs += 1 end
		end
	end
	assert(wheels == 4 and hubs == 4, "Every style needs four tires and hubs")
	local cargo = vehicle:FindFirstChild("CargoBox") or vehicle:FindFirstChild("OpenBed")
	if cargo then
		local cabin = vehicle:FindFirstChild("Cabin")
		assert(cabin.CFrame.Position.Z + cabin.Size.Z / 2 < cargo.CFrame.Position.Z - cargo.Size.Z / 2, "Cab must not occupy cargo space")
	end
	count += 1
end
assert(count == 8, "All eight vehicle styles must build")
print("PASS: eight vehicle styles, round wheels, mirrors, bay fit, separate cab/cargo geometry")
