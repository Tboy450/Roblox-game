local ArenaExpansion = {}

local VERSION = 1
local MODEL_NAME = "ShooterExpansion"

ArenaExpansion.VERSION = VERSION

local COLORS = {
	dark = Color3.fromRGB(28, 34, 43),
	metal = Color3.fromRGB(67, 79, 91),
	light = Color3.fromRGB(116, 132, 145),
	cyan = Color3.fromRGB(50, 218, 240),
	orange = Color3.fromRGB(255, 151, 53),
	concrete = Color3.fromRGB(112, 113, 116),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Anchored = true
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Parent = parent
	return value
end

local function neon(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local value = part(parent, name, size, cframe, color, Enum.Material.Neon)
	value.CanCollide = false
	value.CanQuery = false
	return value
end

local function isExcluded(instance: Instance, existing: Instance?): boolean
	if existing and instance:IsDescendantOf(existing) then
		return true
	end
	if instance:FindFirstAncestorWhichIsA("Tool") then
		return true
	end
	local teleporters = workspace:FindFirstChild("Teleporters")
	if teleporters and instance:IsDescendantOf(teleporters) then
		return true
	end
	return false
end

local function findReference(): Vector3
	local p1 = workspace:FindFirstChild("p1")
	if p1 and p1:IsA("BasePart") then
		return p1.Position
	end

	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			return descendant.Position
		end
	end
	return Vector3.zero
end

local function findArenaBounds(existing: Instance?): (number, number, number, number, number)
	local reference = findReference()
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	local groundY = reference.Y
	local found = 0

	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Anchored and not isExcluded(descendant, existing) then
			local offset = descendant.Position - reference
			if Vector2.new(offset.X, offset.Z).Magnitude <= 230 and math.abs(offset.Y) <= 100 then
				local half = descendant.Size / 2
				minX = math.min(minX, descendant.Position.X - half.X)
				maxX = math.max(maxX, descendant.Position.X + half.X)
				minZ = math.min(minZ, descendant.Position.Z - half.Z)
				maxZ = math.max(maxZ, descendant.Position.Z + half.Z)
				groundY = math.min(groundY, descendant.Position.Y - half.Y)
				found += 1
			end
		end
	end

	if found < 4 then
		return reference.X - 55, reference.X + 55, reference.Z - 45, reference.Z + 45, reference.Y - 1
	end
	return minX, maxX, minZ, maxZ, groundY
end

local function coverCrate(parent: Instance, position: Vector3, rotation: number, color: Color3)
	local cframe = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	part(parent, "CoverCrate", Vector3.new(10, 8, 8), cframe, color, Enum.Material.Metal)
	neon(parent, "CrateStrip", Vector3.new(7.5, 0.2, 0.3), cframe * CFrame.new(0, 4.1, -4.05), COLORS.cyan)
end

local function barrier(parent: Instance, position: Vector3, rotation: number)
	local cframe = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	part(parent, "BlastBarrier", Vector3.new(13, 6, 2.5), cframe, COLORS.concrete, Enum.Material.Concrete)
	part(parent, "BarrierFoot", Vector3.new(15, 1, 5), cframe * CFrame.new(0, -2.5, 0), COLORS.dark, Enum.Material.Metal)
	neon(parent, "WarningStrip", Vector3.new(8, 0.35, 0.2), cframe * CFrame.new(0, 1.3, -1.27), COLORS.orange)
end

local function teleporterPad(parent: Instance, name: string, position: Vector3, labelText: string): Part
	local pad = part(parent, name, Vector3.new(7, 0.6, 7), CFrame.new(position), Color3.fromRGB(73, 225, 105), Enum.Material.Neon)
	pad:SetAttribute("ShooterExpansionTeleporter", true)

	local light = Instance.new("PointLight")
	light.Color = pad.Color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = pad

	local label = Instance.new("BillboardGui")
	label.Name = "PortalLabel"
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.Size = UDim2.fromOffset(190, 42)
	label.StudsOffset = Vector3.new(0, 3.8, 0)
	label.Parent = pad

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(18, 28, 24)
	text.BackgroundTransparency = 0.2
	text.BorderSizePixel = 0
	text.Font = Enum.Font.GothamBold
	text.Text = labelText
	text.TextColor3 = Color3.fromRGB(215, 255, 225)
	text.TextScaled = true
	text.Parent = label

	return pad
end

local function roomAcrossShopPosition(floorY: number): Vector3
	local shop = workspace:FindFirstChild("Shop")
	if shop then
		local shopCenter = Vector3.zero
		if shop:IsA("Model") then
			local shopCFrame = shop:GetBoundingBox()
			shopCenter = shopCFrame.Position
		elseif shop:IsA("BasePart") then
			shopCenter = shop.Position
		end
		-- The shop faces the room bounded by the Z=-7 and Z=-24.5 walls.
		-- Four studs east and eighteen south lands in its clear center.
		return Vector3.new(shopCenter.X + 4, floorY + 0.3, shopCenter.Z - 18)
	end
	return Vector3.new(-59.4, floorY + 0.3, -15.3)
end

function ArenaExpansion.build(options)
	options = options or {}
	local parent = options.parent or workspace
	local existing = parent:FindFirstChild(MODEL_NAME)
	if existing and options.forceRebuild == false then
		return existing
	end

	local minX, maxX, minZ, maxZ, groundY = findArenaBounds(existing)
	if existing then
		existing:Destroy()
	end

	local depth = math.clamp(maxZ - minZ, 80, 140)
	local centerZ = (minZ + maxZ) / 2
	local expansionWidth = 92
	local centerX = maxX + expansionWidth / 2 - 2
	local floorY = groundY

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("ExpansionVersion", VERSION)
	model:SetAttribute("PreservesOriginalArena", true)
	model:SetAttribute("OriginalArenaMaxX", maxX)
	model.Parent = parent

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = model

	local cover = Instance.new("Folder")
	cover.Name = "Cover"
	cover.Parent = model

	local teleporters = Instance.new("Folder")
	teleporters.Name = "ExpansionTeleporters"
	teleporters.Parent = model

	local floor = part(
		geometry,
		"ExpansionFloor",
		Vector3.new(expansionWidth, 2, depth),
		CFrame.new(centerX, floorY - 1, centerZ),
		Color3.fromRGB(76, 80, 86),
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor

	part(geometry, "EastBoundary", Vector3.new(3, 22, depth), CFrame.new(centerX + expansionWidth / 2, floorY + 10, centerZ), COLORS.dark, Enum.Material.Metal)
	part(geometry, "NorthBoundary", Vector3.new(expansionWidth, 22, 3), CFrame.new(centerX, floorY + 10, centerZ - depth / 2), COLORS.dark, Enum.Material.Metal)
	part(geometry, "SouthBoundary", Vector3.new(expansionWidth, 22, 3), CFrame.new(centerX, floorY + 10, centerZ + depth / 2), COLORS.dark, Enum.Material.Metal)

	local deckY = floorY + 16
	part(geometry, "OverlookDeck", Vector3.new(38, 2, 28), CFrame.new(centerX + 20, deckY, centerZ), COLORS.metal, Enum.Material.DiamondPlate)
	part(geometry, "DeckSupportA", Vector3.new(3, 16, 3), CFrame.new(centerX + 5, floorY + 8, centerZ - 10), COLORS.dark, Enum.Material.Metal)
	part(geometry, "DeckSupportB", Vector3.new(3, 16, 3), CFrame.new(centerX + 35, floorY + 8, centerZ + 10), COLORS.dark, Enum.Material.Metal)
	part(geometry, "DeckRailNorth", Vector3.new(38, 3.5, 0.5), CFrame.new(centerX + 20, deckY + 2, centerZ - 14), COLORS.light, Enum.Material.Metal)
	part(geometry, "DeckRailSouth", Vector3.new(38, 3.5, 0.5), CFrame.new(centerX + 20, deckY + 2, centerZ + 14), COLORS.light, Enum.Material.Metal)

	for stepIndex = 1, 8 do
		local stepX = centerX - 6 + stepIndex * 3.2
		local stepY = floorY + stepIndex
		part(geometry, "OverlookStep", Vector3.new(5, 2, 12), CFrame.new(stepX, stepY, centerZ - 21), COLORS.light, Enum.Material.DiamondPlate)
	end

	local bunker = part(geometry, "BunkerCore", Vector3.new(24, 12, 24), CFrame.new(centerX - 20, floorY + 6, centerZ), COLORS.dark, Enum.Material.Metal)
	neon(geometry, "BunkerBand", Vector3.new(18, 1, 0.3), bunker.CFrame * CFrame.new(0, 2, -12.15), COLORS.cyan)

	coverCrate(cover, Vector3.new(centerX - 28, floorY + 4, centerZ - 27), 15, COLORS.metal)
	coverCrate(cover, Vector3.new(centerX + 31, floorY + 4, centerZ + 29), -12, COLORS.metal)
	coverCrate(cover, Vector3.new(centerX + 3, floorY + 4, centerZ + 24), 30, COLORS.metal)
	barrier(cover, Vector3.new(centerX - 2, floorY + 3.5, centerZ - 24), 20)
	barrier(cover, Vector3.new(centerX + 29, floorY + 3.5, centerZ - 15), 90)

	-- The destination occupies the former north expansion spawn location. It
	-- remains reachable without allowing Roblox to randomly spawn players there.
	teleporterPad(
		teleporters,
		"ShopRoomEntrance",
		roomAcrossShopPosition(floorY),
		"SMALL ROOM"
	)
	teleporterPad(
		teleporters,
		"SmallRoomReturn",
		Vector3.new(centerX + 28, floorY + 0.3, centerZ - depth / 2 + 12),
		"RETURN TO SHOP ROOM"
	)

	return model
end

return ArenaExpansion
