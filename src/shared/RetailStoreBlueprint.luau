-- Retail supermarket layout and procedural fixtures.
local RetailStoreBlueprint = {}
local RetailCatalog = require(script.Parent:WaitForChild("RetailCatalog"))

local DEFAULT_NAME = "RetailStore"
local BLUEPRINT_VERSION = 55
local STARTING_TILL_CENTS = 20000

export type BuildOptions = {
	parent: Instance?,
	storeName: string?,
	forceRebuild: boolean?,
}

local function part(props: {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.Position = props.position
	p.Anchored = true
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Reflectance = 0
	p.CastShadow = true
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.parent
	return p
end

function RetailStoreBlueprint.build(options: BuildOptions?): Model
	local parent = (options and options.parent) or workspace
	local storeName = (options and options.storeName) or DEFAULT_NAME
	local forceRebuild = if options and options.forceRebuild ~= nil then options.forceRebuild else true

	local existing = parent:FindFirstChild(storeName)
	if existing and not forceRebuild then
		return existing :: Model
	end

	for _, child in parent:GetChildren() do
		local lowerName = string.lower(child.Name)
		local isRojoBaseplate = lowerName:find("rojo") ~= nil and lowerName:find("baseplate") ~= nil
		if child:IsA("BasePart") and (child.Name:find("MapHint") or child.Name:find("Rojo Synced") or isRojoBaseplate) then
			child:Destroy()
		end
	end

	local store = Instance.new("Model")
	store.Name = storeName
	store:SetAttribute("BlueprintVersion", BLUEPRINT_VERSION)
	store:SetAttribute("StoreOpen", true)
	store:SetAttribute("StoreStartingTillCents", STARTING_TILL_CENTS)
	store:SetAttribute("StoreCashCents", STARTING_TILL_CENTS)
	store:SetAttribute("StoreTenderReceivedCents", 0)
	store:SetAttribute("StoreChangePaidCents", 0)
	store:SetAttribute("StoreNetSalesCents", 0)
	store:SetAttribute("StoreCustomers", 0)
	store:SetAttribute("NpcCustomersProcessed", 0)
	store:SetAttribute("PlayerCustomersProcessed", 0)
	-- Publish only the finished model so gameplay never binds to a partial build.

	-- Walk surface top is always floorY + 0.5 (1-stud-thick floors at floorY)
	local floorY = 0.5
	local walkTop = floorY + 0.5
	local wallH = 14
	local wallT = 1
	local W, D = 152, 100
	local halfW, halfD = W / 2, D / 2
	local wingOffset = (W - 120) / 2
	local wallCenterY = floorY + wallH / 2 + 0.5

	local function storePart(props: {
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3,
		material: Enum.Material?,
		transparency: number?,
		canCollide: boolean?,
		parent: Instance?,
	}): Part
		-- Keep measured dimensions: grid rounding breaks door openings and wall-mounted fixtures.
		return part({
			name = props.name,
			size = props.size,
			position = props.position,
			color = props.color,
			material = props.material,
			transparency = props.transparency,
			canCollide = props.canCollide,
			parent = props.parent or store,
		})
	end

	local function detailPart(props: {
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3,
		material: Enum.Material?,
		transparency: number?,
		canCollide: boolean?,
		parent: Instance?,
	}): Part
		return part({
			name = props.name,
			size = props.size,
			position = props.position,
			color = props.color,
			material = props.material,
			transparency = props.transparency,
			canCollide = props.canCollide,
			parent = props.parent or store,
		})
	end

	local function decorFloor(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance?)
		return storePart({
			name = name,
			size = size,
			position = position,
			color = color,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.35,
			canCollide = false,
			parent = parent,
		})
	end

	local function fixtureDetail(model: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
		local detail = detailPart({ name = name, size = size, position = position, color = color,
			material = material, canCollide = false, parent = model })
		detail:SetAttribute("FixtureDetail", true)
		return detail
	end

	local function addSign(
		parent: Instance,
		name: string,
		cx: number,
		cy: number,
		cz: number,
		w: number,
		text: string,
		color: Color3,
		height: number?,
		axis: string?
	): Part
		local signHeight = height or math.clamp(w * 0.15, 1.0, 1.9)
		local sign = detailPart({
			name = name,
			size = if axis == "X" then Vector3.new(0.35, signHeight, w) else Vector3.new(w, signHeight, 0.35),
			position = Vector3.new(cx, cy, cz),
			color = color,
			canCollide = false,
			parent = parent,
		})
		if sign then
			local faces = if axis == "X" then { Enum.NormalId.Left, Enum.NormalId.Right } else { Enum.NormalId.Front, Enum.NormalId.Back }
			for _, face in faces do
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.LightInfluence = 0.2
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 88
				gui.Parent = sign

				local label = Instance.new("TextLabel")
				label.Name = "Label"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = text
				label.TextColor3 = Color3.fromRGB(245, 245, 245)
				label.TextScaled = true
				label.Font = Enum.Font.GothamBold
				label.Parent = gui
			end
		end

		return sign
	end

	local function addPrompt(target: BasePart, actionId: string, actionText: string, objectText: string, holdDuration: number?)
		target:SetAttribute("RetailAction", actionId)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = holdDuration or 0.15
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = target
	end

	local function wallPart(props)
		local wall = detailPart(props)
		wall:SetAttribute("BlueprintWall", true)
		return wall
	end

	-- Wall along X axis (runs in X), placed at fixed Z
	local function wallX(
		name: string,
		xCenter: number,
		zFixed: number,
		lengthX: number,
		door: { offset: number, width: number }?,
		parentModel: Instance?
	)
		local y = wallCenterY
		if not door then
			wallPart({
				name = name,
				size = Vector3.new(lengthX, wallH, wallT),
				position = Vector3.new(xCenter, y, zFixed),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
			return
		end

		local halfLen = lengthX / 2
		local doorStart = door.offset - door.width / 2
		local doorEnd = door.offset + door.width / 2
		local leftLen = (halfLen + doorStart)
		local rightLen = (halfLen - doorEnd)
		if leftLen > 0 then
			wallPart({
				name = `{name}_L`,
				size = Vector3.new(leftLen, wallH, wallT),
				position = Vector3.new(xCenter - halfLen + leftLen / 2, y, zFixed),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
		end
		if rightLen > 0 then
			wallPart({
				name = `{name}_R`,
				size = Vector3.new(rightLen, wallH, wallT),
				position = Vector3.new(xCenter + halfLen - rightLen / 2, y, zFixed),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
		end
		wallPart({ name = `{name}_Lintel`, size = Vector3.new(door.width, 6, wallT),
			position = Vector3.new(xCenter + door.offset, walkTop + 11, zFixed),
			color = Color3.fromRGB(215, 213, 210), material = Enum.Material.Brick, parent = parentModel })
	end

	-- Wall along Z axis (runs in Z), placed at fixed X
	local function wallZ(
		name: string,
		xFixed: number,
		zCenter: number,
		lengthZ: number,
		door: { offset: number, width: number }?,
		parentModel: Instance?
	)
		local y = wallCenterY
		if not door then
			wallPart({
				name = name,
				size = Vector3.new(wallT, wallH, lengthZ),
				position = Vector3.new(xFixed, y, zCenter),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
			return
		end

		local halfLen = lengthZ / 2
		local doorStart = door.offset - door.width / 2
		local doorEnd = door.offset + door.width / 2
		local southLen = halfLen + doorStart
		local northLen = halfLen - doorEnd
		if southLen > 0 then
			wallPart({
				name = `{name}_S`,
				size = Vector3.new(wallT, wallH, southLen),
				position = Vector3.new(xFixed, y, zCenter - halfLen + southLen / 2),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
		end
		if northLen > 0 then
			wallPart({
				name = `{name}_N`,
				size = Vector3.new(wallT, wallH, northLen),
				position = Vector3.new(xFixed, y, zCenter + halfLen - northLen / 2),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
				parent = parentModel,
			})
		end
		wallPart({ name = `{name}_Lintel`, size = Vector3.new(wallT, 6, door.width),
			position = Vector3.new(xFixed, walkTop + 11, zCenter + door.offset),
			color = Color3.fromRGB(215, 213, 210), material = Enum.Material.Brick, parent = parentModel })
	end

	local function enclosedRoom(opts: {
		name: string,
		parent: Instance?,
		cx: number,
		cz: number,
		width: number,
		depth: number,
		floorColor: Color3,
		sign: string?,
		doorSide: "south" | "east" | "west" | "none"?,
		doorOffset: number?,
		skipNorth: boolean?,
		skipWest: boolean?,
		skipEast: boolean?,
	})
		local room = Instance.new("Model")
		room.Name = opts.name
		room.Parent = opts.parent or store

		local w, d = opts.width, opts.depth
		local cx, cz = opts.cx, opts.cz
		local doorOffset = opts.doorOffset or 0
		local floorOverlayH = 0.04
		room:SetAttribute("RoomCenter", Vector3.new(cx, 0, cz))
		room:SetAttribute("RoomSize", Vector3.new(w, wallH, d))

		storePart({
			name = "Floor",
			size = Vector3.new(w - wallT, floorOverlayH, d - wallT),
			position = Vector3.new(cx, walkTop + floorOverlayH / 2 + 0.005, cz),
			color = opts.floorColor,
			material = Enum.Material.Concrete,
			canCollide = false,
			parent = room,
		})

		storePart({
			name = "Ceiling",
			size = Vector3.new(w - wallT, 0.35, d - wallT),
			position = Vector3.new(cx, 13.825, cz),
			color = Color3.fromRGB(198, 198, 200),
			material = Enum.Material.SmoothPlastic,
			parent = room,
		})

		local northZ = cz - d / 2
		local southZ = cz + d / 2
		local westX = cx - w / 2
		local eastX = cx + w / 2

		if not opts.skipNorth then wallX(`{opts.name}_N`, cx, northZ, w, nil, room) end
		if opts.doorSide == "south" then
			wallX(`{opts.name}_S`, cx, southZ, w, { offset = doorOffset, width = 8 }, room)
		else
			wallX(`{opts.name}_S`, cx, southZ, w, nil, room)
		end
		if opts.skipWest then
			-- Exterior shell already supplies this side wall.
		elseif opts.doorSide == "west" then
			wallZ(`{opts.name}_W`, westX, cz, d, { offset = doorOffset, width = 6 }, room)
		else
			wallZ(`{opts.name}_W`, westX, cz, d, nil, room)
		end
		if opts.skipEast then
			-- Exterior shell already supplies this side wall.
		elseif opts.doorSide == "east" then
			wallZ(`{opts.name}_E`, eastX, cz, d, { offset = doorOffset, width = 6 }, room)
		else
			wallZ(`{opts.name}_E`, eastX, cz, d, nil, room)
		end

		if opts.sign then
			local sideDoor = opts.doorSide == "west" or opts.doorSide == "east"
			local signX = if sideDoor then (if opts.doorSide == "west" then westX - 0.7 else eastX + 0.7) else cx + doorOffset
			local signZ = if sideDoor then cz + doorOffset else southZ + 0.7
			addSign(room, "Sign", signX, 10.5, signZ, if sideDoor then 6 else 8, opts.sign, Color3.fromRGB(65, 65, 70), 1.2, if sideDoor then "X" else "Z")
		end

		return room
	end

	local function surfaceFloor(
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3,
		material: Enum.Material,
		parent: Instance?,
		topY: number
	)
		return storePart({
			name = name,
			size = Vector3.new(size.X, 1, size.Z),
			position = Vector3.new(position.X, topY - 0.5, position.Z),
			color = color,
			material = material,
			parent = parent,
		})
	end

	local function zoneMarker(name: string, cx: number, cz: number, w: number, d: number, color: Color3)
		-- Non-colliding overlay well above walk surface (prevents z-fight flicker when moving)
		decorFloor(`{name}Marker`, Vector3.new(w - 2, 0.05, d - 2), Vector3.new(cx, floorY + 0.68, cz), color)
	end

	local function addSoftLight(cx: number, cz: number, parent: Instance)
		local fixture = storePart({
			name = `Light_{cx}_{cz}`,
			size = Vector3.new(3, 0.3, 1),
			position = Vector3.new(cx, 13.45, cz),
			color = Color3.fromRGB(218, 216, 208),
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 0.5
		light.Range = 20
		light.Color = Color3.fromRGB(255, 244, 230)
		light.Parent = fixture
	end

	-- ========== MAIN SHELL (symmetric) ==========
	local entranceW = 20

	-- Floor chain with no gaps and no overlaps: interior → threshold → parking
	local floor = detailPart({
		name = "MainFloor",
		size = Vector3.new(W, 1, D),
		position = Vector3.new(0, floorY, 0),
		color = Color3.fromRGB(188, 188, 192),
		material = Enum.Material.Concrete,
	})

	detailPart({
		name = "EntryThreshold",
		size = Vector3.new(entranceW, 1, 9),
		position = Vector3.new(0, floorY + 0.06, halfD + 4.5),
		color = Color3.fromRGB(178, 178, 182),
		material = Enum.Material.Concrete,
	})

	storePart({
		name = "MainCeiling",
		size = Vector3.new(W, 1, D),
		position = Vector3.new(0, floorY + wallH, 0),
		color = Color3.fromRGB(202, 202, 204),
		material = Enum.Material.SmoothPlastic,
	})

	-- ========== ROOF SYSTEM ==========
	local roof = Instance.new("Model")
	roof.Name = "Roof"
	roof.Parent = store

	local roofY = floorY + wallH + 1
	local fasciaH = 2

	storePart({
		name = "RoofMain",
		size = Vector3.new(W + 2, 1, D + 2),
		position = Vector3.new(0, roofY, 0),
		color = Color3.fromRGB(72, 74, 78),
		material = Enum.Material.Metal,
		parent = roof,
	})

	-- Entrance canopy (covers door approach)
	storePart({
		name = "EntranceCanopy",
		size = Vector3.new(entranceW + 10, 0.8, 12),
		position = Vector3.new(0, roofY - 0.4, halfD + 2),
		color = Color3.fromRGB(88, 90, 94),
		material = Enum.Material.Metal,
		parent = roof,
	})
	storePart({
		name = "CanopyFrontLip",
		size = Vector3.new(entranceW + 12, 0.4, 1.2),
		position = Vector3.new(0, roofY - 0.7, halfD + 8),
		color = Color3.fromRGB(60, 62, 66),
		material = Enum.Material.Metal,
		parent = roof,
	})

	-- Fascia / parapet band
	local fasciaY = roofY + 0.9
	storePart({
		name = "FasciaNorth",
		size = Vector3.new(W + 2, fasciaH, 1),
		position = Vector3.new(0, fasciaY, -halfD - 0.5),
		color = Color3.fromRGB(55, 58, 62),
		material = Enum.Material.SmoothPlastic,
		parent = roof,
	})
	storePart({
		name = "FasciaSouth",
		size = Vector3.new(W + 2, fasciaH, 1),
		position = Vector3.new(0, fasciaY, halfD + 0.5),
		color = Color3.fromRGB(55, 58, 62),
		material = Enum.Material.SmoothPlastic,
		parent = roof,
	})
	storePart({
		name = "FasciaWest",
		size = Vector3.new(1, fasciaH, D + 2),
		position = Vector3.new(-halfW - 0.5, fasciaY, 0),
		color = Color3.fromRGB(55, 58, 62),
		material = Enum.Material.SmoothPlastic,
		parent = roof,
	})
	storePart({
		name = "FasciaEast",
		size = Vector3.new(1, fasciaH, D + 2),
		position = Vector3.new(halfW + 0.5, fasciaY, 0),
		color = Color3.fromRGB(55, 58, 62),
		material = Enum.Material.SmoothPlastic,
		parent = roof,
	})

	-- Skylights (sales floor)
	for _, sx in { -38, 0, 38 } do
		storePart({
			name = `Skylight_{sx}`,
			size = Vector3.new(8, 0.2, 8),
			position = Vector3.new(sx, roofY + 0.65, 4),
			color = Color3.fromRGB(140, 180, 210),
			material = Enum.Material.Glass,
			transparency = 0.35,
			canCollide = false,
			parent = roof,
		})
	end

	-- HVAC units on back roof
	for _, hx in { -44, 0, 44 } do
		storePart({
			name = `HVAC_{hx}`,
			size = Vector3.new(8, 3, 6),
			position = Vector3.new(hx, roofY + 2.2, -halfD + 10),
			color = Color3.fromRGB(110, 112, 115),
			material = Enum.Material.Metal,
			parent = roof,
		})
		storePart({
			name = `HVACVent_{hx}`,
			size = Vector3.new(6, 0.4, 4),
			position = Vector3.new(hx, roofY + 3.8, -halfD + 10),
			color = Color3.fromRGB(80, 82, 85),
			material = Enum.Material.Metal,
			parent = roof,
		})
	end

	addSign(roof, "RooftopSign", 0, fasciaY + 2.5, halfD + 1.3, 32, "RETAIL STORE", Color3.fromRGB(20, 90, 160))

	wallX("ExtNorth", 0, -halfD, W, nil)
	wallZ("ExtWest", -halfW, 0, D, nil)
	wallZ("ExtEast", halfW, 0, D, nil)

	for _, segment in {
		{ name = "ExtSouthFarL", cx = -56 - wingOffset, len = 8 },
		{ name = "ExtSouthInnerL", cx = -23 - wingOffset / 2, len = 18 + wingOffset },
		{ name = "ExtSouthInnerR", cx = 23 + wingOffset / 2, len = 18 + wingOffset },
		{ name = "ExtSouthFarR", cx = 56 + wingOffset, len = 8 },
	} do
		wallPart({
			name = segment.name,
			size = Vector3.new(segment.len, wallH, wallT),
			position = Vector3.new(segment.cx, wallCenterY, halfD),
			color = Color3.fromRGB(215, 213, 210),
			material = Enum.Material.Brick,
		})
	end

	for _, filler in {
		{ name = "FrontDoorWallFillL", x = -12 },
		{ name = "FrontDoorWallFillR", x = 12 },
	} do
		wallPart({
			name = filler.name,
			size = Vector3.new(4, wallH, wallT),
			position = Vector3.new(filler.x, wallCenterY, halfD),
			color = Color3.fromRGB(215, 213, 210),
			material = Enum.Material.Brick,
		})
	end

	for _, window in {
		{ name = "WindowL", x = -42 - wingOffset, width = 16 },
		{ name = "WindowR", x = 42 + wingOffset, width = 16 },
	} do
		detailPart({
			name = window.name,
			size = Vector3.new(window.width, 7, 0.2),
			position = Vector3.new(window.x, 6.5, halfD),
			color = Color3.fromRGB(145, 170, 190),
			material = Enum.Material.Glass,
			transparency = 0.5,
			canCollide = true,
		})
		wallPart({
			name = `{window.name}_Header`,
			size = Vector3.new(window.width, 5, wallT),
			position = Vector3.new(window.x, 12.5, halfD),
			color = Color3.fromRGB(215, 213, 210),
			material = Enum.Material.Brick,
		})
		wallPart({
			name = `{window.name}_Sill`,
			size = Vector3.new(window.width, 2, wallT),
			position = Vector3.new(window.x, 2, halfD),
			color = Color3.fromRGB(215, 213, 210),
			material = Enum.Material.Brick,
		})
		for _, side in { -1, 1 } do
			wallPart({
				name = `{window.name}_Jamb{side}`,
				size = Vector3.new(2, wallH, wallT),
				position = Vector3.new(window.x + side * (window.width / 2 + 1), wallCenterY, halfD),
				color = Color3.fromRGB(215, 213, 210),
				material = Enum.Material.Brick,
			})
		end
		for _, edge in { 3, 10 } do
			detailPart({
				name = `{window.name}_Trim{edge}`,
				size = Vector3.new(window.width, 0.15, 0.3),
				position = Vector3.new(window.x, edge, halfD),
				color = Color3.fromRGB(62, 66, 70),
				material = Enum.Material.Metal,
				canCollide = false,
			})
		end
	end

	local entrance = Instance.new("Model")
	entrance.Name = "Entrance"
	entrance.Parent = store
	wallPart({ name = "EntranceLintel", size = Vector3.new(20, 5.2, wallT), position = Vector3.new(0, 12.4, halfD),
		color = Color3.fromRGB(215, 213, 210), material = Enum.Material.Brick, parent = entrance })
	local entranceStatus = addSign(entrance, "EntranceStatus", 7, 7, halfD + 0.4, 3.4, "OPEN", Color3.fromRGB(52, 120, 72), 1)
	entranceStatus:SetAttribute("StoreStatusDisplay", true)

	for _, panel in {
		{ name = "DoorGlassL", x = -4.5 },
		{ name = "DoorGlassR", x = 4.5 },
	} do
		detailPart({
			name = panel.name,
			size = Vector3.new(7, 8, 0.25),
			position = Vector3.new(panel.x, floorY + 4.5, halfD - 0.65),
			color = Color3.fromRGB(150, 185, 205),
			material = Enum.Material.Glass,
			transparency = 0.45,
			canCollide = false,
			parent = entrance,
		})
	end
	for _, frame in {
		{ name = "DoorFrameL", x = -9.5, y = floorY + 4.8, sx = 0.5, sy = 9 },
		{ name = "DoorFrameC", x = 0, y = floorY + 4.8, sx = 0.5, sy = 9 },
		{ name = "DoorFrameR", x = 9.5, y = floorY + 4.8, sx = 0.5, sy = 9 },
		{ name = "DoorHeader", x = 0, y = floorY + 9.1, sx = 20, sy = 0.5 },
	} do
		detailPart({
			name = frame.name,
			size = Vector3.new(frame.sx, frame.sy, 0.5),
			position = Vector3.new(frame.x, frame.y, halfD - 0.35),
			color = Color3.fromRGB(62, 66, 70),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = entrance,
		})
	end

	-- Lights on symmetric grid (recessed below main ceiling)
	for x = -60, 60, 20 do
		for z = -30, 30, 20 do
			addSoftLight(x, z, store)
		end
	end

	-- Back rooms share one continuous boundary, with no duplicate divider or narrow wall gaps.
	local backZ = -halfD + 12
	enclosedRoom({
		name = "StockRoom",
		cx = -38,
		cz = backZ,
		width = 44,
		depth = 24,
		floorColor = Color3.fromRGB(138, 138, 142),
		sign = "STOCK",
		doorSide = "south",
		doorOffset = 2,
		skipNorth = true,
		skipWest = true,
	})
	enclosedRoom({
		name = "WalkInCooler",
		cx = 0,
		cz = backZ,
		width = 32 + wingOffset * 2,
		depth = 24,
		floorColor = Color3.fromRGB(165, 180, 192),
		sign = "COOLER",
		doorSide = "south",
		skipNorth = true,
		skipWest = true,
		skipEast = true,
	})
	enclosedRoom({
		name = "LoadingDock",
		cx = 38,
		cz = backZ,
		width = 44,
		depth = 24,
		floorColor = Color3.fromRGB(72, 72, 76),
		sign = "LOADING",
		doorSide = "south",
		doorOffset = -2,
		skipNorth = true,
		skipEast = true,
	})

	-- ========== WEST / EAST WINGS (mirrored) ==========
	-- Room furniture retains its authored proportions; complete wings move outward together below.
	local westCx, eastCx = -51, 51

	enclosedRoom({
		name = "Bakery",
		cx = westCx,
		cz = 14.5,
		width = 18,
		depth = 27,
		floorColor = Color3.fromRGB(192, 172, 148),
		sign = "BAKERY",
		doorSide = "east",
		skipWest = true,
		skipNorth = true,
		doorOffset = 1.5,
	})
	enclosedRoom({
		name = "Pharmacy",
		cx = westCx,
		cz = -12.5,
		width = 18,
		depth = 27,
		floorColor = Color3.fromRGB(168, 182, 192),
		sign = "PHARMACY",
		doorSide = "east",
		skipWest = true,
		skipNorth = true,
		doorOffset = -1.5,
	})

	local restrooms = Instance.new("Model")
	restrooms.Name = "Restrooms"
	restrooms.Parent = store
	for index, z in { -20.25, -8.75 } do
		enclosedRoom({ name = `Bathroom{index}`, parent = restrooms, cx = eastCx, cz = z,
			width = 18, depth = 11.5, floorColor = Color3.fromRGB(201, 213, 214), sign = `RESTROOM {index}`,
			doorSide = "west", skipEast = true, skipNorth = true })
	end
	enclosedRoom({
		name = "BreakRoom",
		cx = eastCx,
		cz = 7,
		width = 18,
		depth = 20,
		floorColor = Color3.fromRGB(148, 144, 140),
		sign = "BREAK ROOM",
		doorSide = "west",
		skipEast = true,
		skipNorth = true,
		doorOffset = 1,
	})
	local adminNook = Instance.new("Model")
	adminNook.Name = "AdminNook"
	adminNook.Parent = store
	decorFloor(
		"AdminNookFloor",
		Vector3.new(16, 0.05, 14),
		Vector3.new(eastCx, floorY + 0.68, 30),
		Color3.fromRGB(138, 134, 130),
		adminNook
	)
	decorFloor(
		"StaffWalkway",
		Vector3.new(6, 0.05, 56),
		Vector3.new(38, floorY + 0.68, 4),
		Color3.fromRGB(172, 172, 176),
		adminNook
	)

	-- ========== SALES FLOOR (symmetric zones + aisles) ==========
	zoneMarker("Produce", -50, -18, 20, 18, Color3.fromRGB(92, 128, 82))
	zoneMarker("Dairy", 0, -18, 20, 18, Color3.fromRGB(98, 112, 132))
	zoneMarker("Frozen", 50, -18, 20, 18, Color3.fromRGB(92, 118, 138))
	zoneMarker("General", 0, 14, 100, 32, Color3.fromRGB(148, 148, 152))

	local aisleSigns = Instance.new("Model")
	aisleSigns.Name = "AisleSigns"
	aisleSigns.Parent = store
	for _, sign in {
		{ name = "ProduceSign", x = -50, z = -20, text = "PRODUCE", color = Color3.fromRGB(72, 112, 68) },
		{ name = "DairySign", x = 0, z = -10, text = "DAIRY", color = Color3.fromRGB(72, 92, 122) },
		{ name = "FrozenSign", x = 50, z = 4, text = "FROZEN", color = Color3.fromRGB(62, 102, 126) },
		{ name = "PantrySign", x = -30, z = 30, text = "PANTRY", color = Color3.fromRGB(132, 92, 58) },
		{ name = "HouseholdSign", x = 30, z = 30, text = "HOUSEHOLD", color = Color3.fromRGB(92, 88, 112) },
	} do
		addSign(aisleSigns, sign.name, sign.x, floorY + 11.3, sign.z, 12, sign.text, sign.color)
	end

	local endcaps = Instance.new("Model")
	endcaps.Name = "PromotionalEndcaps"
	endcaps.Parent = store
	for _, endcap in {
		{ name = "SeasonalEndcap", x = -30, z = 12, color = Color3.fromRGB(70, 150, 130), prompt = "Seasonal Display" },
	} do
		local display = storePart({
			name = endcap.name,
			size = Vector3.new(7, 5, 4),
			position = Vector3.new(endcap.x, floorY + 3, endcap.z),
			color = endcap.color,
			material = Enum.Material.SmoothPlastic,
			parent = endcaps,
		})
		addPrompt(display, "InspectDisplay", "Inspect", endcap.prompt, 0.1)
		storePart({
			name = `{endcap.name}_Header`,
			size = Vector3.new(8, 1.2, 0.5),
			position = Vector3.new(endcap.x, floorY + 6.3, endcap.z + 2),
			color = Color3.fromRGB(245, 230, 160),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = endcaps,
		})
	end

	-- Produce bins (north of produce aisle — no shelf overlap)
	local bins = Instance.new("Model")
	bins.Name = "ProduceBins"
	bins.Parent = store
	for index, bx in { -60, -30, 0, 30, 60 } do
		local i, binZ = index - 3, -19
		local crate = detailPart({
			name = `Bin_{i}`,
			size = Vector3.new(6, 1.2, 4),
			position = Vector3.new(bx, 1.6, binZ),
			color = Color3.fromRGB(125, 90, 55),
			material = Enum.Material.Wood,
			parent = bins,
		})
		local fruitColor = if i % 3 == 0 then Color3.fromRGB(214, 66, 66)
			elseif i % 3 == 1 then Color3.fromRGB(239, 158, 52) else Color3.fromRGB(115, 170, 73)
		for _, side in { -1, 1 } do
			fixtureDetail(bins, `CrateRimX{i}_{side}`, Vector3.new(6, 0.65, 0.18), Vector3.new(bx, 2.5, binZ + side * 1.91), crate.Color, Enum.Material.Wood)
			fixtureDetail(bins, `CrateRimZ{i}_{side}`, Vector3.new(0.18, 0.65, 3.64), Vector3.new(bx + side * 2.91, 2.5, binZ), crate.Color, Enum.Material.Wood)
		end
		for row = -1, 1 do
			for column = -2, 2 do
				local fruit = fixtureDetail(bins, `Fruit{i}_{row}_{column}`, Vector3.new(0.86, 0.8, 0.86),
					Vector3.new(bx + column * 1.02, 2.59, binZ + row * 1.03), fruitColor)
				fruit.Shape = Enum.PartType.Ball
				fixtureDetail(bins, `FruitStem{i}_{row}_{column}`, Vector3.new(0.07, 0.16, 0.07), fruit.Position + Vector3.new(0, 0.42, 0), Color3.fromRGB(75, 87, 49), Enum.Material.Wood)
			end
		end
		local produce = detailPart({
			name = `Produce_{i}`,
			size = Vector3.new(5.4, 0.8, 3.4),
			position = Vector3.new(bx, 2.6, binZ),
			color = fruitColor,
			transparency = 1,
			canCollide = false,
			parent = bins,
		})
		produce:SetAttribute("RetailPriceCents", 149)
		addPrompt(produce, "CollectItem", "Pick up", "Produce", 0.1)
	end

	-- Shelves: posts + boards (nothing coplanar with floor — fixes bottom flicker)
	local shelfWalk = walkTop
	local shelfCounter = 0
	local function shelfUnit(cx: number, cz: number, defaultDepartmentIndex: number)
		shelfCounter += 1
		local department = RetailCatalog.getDepartment(defaultDepartmentIndex)
		local product = RetailCatalog.getProduct(defaultDepartmentIndex, 1)
		local unit = Instance.new("Model")
		unit.Name = `ShelfUnit{shelfCounter}`
		unit:SetAttribute("ShelfId", shelfCounter)
		unit:SetAttribute("ShelfDepartmentIndex", defaultDepartmentIndex)
		unit:SetAttribute("ShelfProductIndex", 1)
		unit:SetAttribute("ShelfDepartmentName", department.name)
		unit:SetAttribute("ShelfProductName", product.name)
		unit:SetAttribute("ShelfCapacity", 9)
		unit:SetAttribute("ShelfStock", 9)
		unit.Parent = store

		for _, side in { -1, 1 } do
			detailPart({
				name = if side == -1 then "PostL" else "PostR",
				size = Vector3.new(0.35, 11.2, 0.45),
				position = Vector3.new(cx + side * 5.8, shelfWalk + 5.6, cz - 1.7),
				color = Color3.fromRGB(82, 87, 91),
				material = Enum.Material.Metal,
				parent = unit,
			})
		end

		fixtureDetail(unit, "ToeKick", Vector3.new(11.5, 0.38, 3.6), Vector3.new(cx, shelfWalk + 0.19, cz), Color3.fromRGB(67, 73, 77), Enum.Material.Metal)
		fixtureDetail(unit, "TopCap", Vector3.new(12, 0.16, 3.9), Vector3.new(cx, shelfWalk + 11.2, cz), Color3.fromRGB(215, 221, 218), Enum.Material.Metal)
		local shelfBack = detailPart({
			name = "Back",
			size = Vector3.new(12, 11, 0.2),
			position = Vector3.new(cx, shelfWalk + 5.6, cz - 1.95),
			color = Color3.fromRGB(217, 222, 220),
			material = Enum.Material.Metal,
			parent = unit,
		})
		addPrompt(shelfBack, "RestockShelf", "Restock", "Shelf", 0.25)

		local topSign = addSign(
			unit,
			"TopSign",
			cx,
			shelfWalk + 11.8,
			cz + 1.95,
			11.5,
			`{string.upper(department.name)} | {string.upper(product.name)}`,
			department.signColor,
			0.85
		)
		addPrompt(topSign, "ConfigureShelf", "Configure", "Shelf", 0.15)

		local shelfControl = detailPart({
			name = "ShelfControl",
			size = Vector3.new(2.8, 1.2, 0.35),
			position = Vector3.new(cx - 4.4, shelfWalk + 2.3, cz + 2.05),
			color = department.signColor,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = unit,
		})
		addPrompt(shelfControl, "ConfigureShelf", "Set product", "Shelf Control", 0.1)

		local restockControl = detailPart({
			name = "RestockControl",
			size = Vector3.new(2.8, 1.2, 0.35),
			position = Vector3.new(cx, shelfWalk + 2.3, cz + 2.05),
			color = Color3.fromRGB(76, 92, 70),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = unit,
		})
		addPrompt(restockControl, "RestockShelf", "Restock", product.name, 0.15)

		local productSelector = detailPart({
			name = "ProductSelector",
			size = Vector3.new(2.8, 1.2, 0.35),
			position = Vector3.new(cx + 4.4, shelfWalk + 2.3, cz + 2.05),
			color = product.color,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = unit,
		})
		productSelector:SetAttribute("RetailPriceCents", product.priceCents)
		addPrompt(productSelector, "CollectItem", "Take item", product.name, 0.1)

		for level = 1, 3 do
			local boardY = shelfWalk + 0.2 + level * 2.8
			detailPart({
				name = `Shelf{level}`,
				size = Vector3.new(11.5, 0.25, 3.6),
				position = Vector3.new(cx, boardY, cz),
				color = Color3.fromRGB(216, 220, 216),
				material = Enum.Material.Metal,
				parent = unit,
			})
			fixtureDetail(unit, `PriceRail{level}`, Vector3.new(11.5, 0.38, 0.12), Vector3.new(cx, boardY, cz + 1.86), department.signColor)
			local slotIndex = 0
			for bx = -4, 4, 4 do
				slotIndex += 1
				local absoluteSlotIndex = (level - 1) * 3 + slotIndex
				local priceTag = addSign(unit, `PriceTag{absoluteSlotIndex}`, cx + bx, boardY, cz + 2.12, 1.5, string.format("$%.2f", product.priceCents / 100), Color3.fromRGB(46, 54, 61), 0.32)
				priceTag:SetAttribute("ShelfPriceDisplay", true)
				local productPart = detailPart({
					name = `Product_{level}_{slotIndex}`,
					size = product.size,
					position = Vector3.new(cx + bx, boardY + product.size.Y / 2 + 0.2, cz + 0.2),
					color = product.color,
					material = product.material,
					parent = unit,
				})
				productPart:SetAttribute("ShelfProductVisual", true)
				productPart:SetAttribute("ShelfBoardY", boardY)
				productPart:SetAttribute("ShelfSlotIndex", absoluteSlotIndex)
				productPart:SetAttribute("RetailPriceCents", product.priceCents)
			end
		end
	end

	-- Aisles: keep the front third open for checkout, queueing, and NPC traffic.
	-- Repositioned shelves to better fill expanded store
	local shelfRows = {
		{ z = -14, departments = { 1, 2, 3 } },
		{ z = 4, departments = { 4, 5, 2 } },
		{ z = 22, departments = { 1, 4, 5 } },
	}
	for _, row in shelfRows do
		for columnIndex, x in { -50, 0, 50 } do
			shelfUnit(x, row.z, row.departments[columnIndex])
		end
	end

	-- Freezer row (raised off floor, glass in front of frame)
	local freezerZ = -8
	for i = -1, 1 do
		local fx = i * 50
		local case = Instance.new("Model")
		case.Name = `Freezer{i}`
		case.Parent = store
		local caseBaseY = shelfWalk + 4.2
		storePart({
			name = "Frame",
			size = Vector3.new(10, 8, 2.8),
			position = Vector3.new(fx, caseBaseY, freezerZ),
			color = Color3.fromRGB(88, 92, 98),
			material = Enum.Material.Metal,
			parent = case,
		})
		local glass = storePart({
			name = "Glass",
			size = Vector3.new(8, 6, 0.15),
			position = Vector3.new(fx, caseBaseY, freezerZ + 1.5),
			color = Color3.fromRGB(170, 185, 195),
			material = Enum.Material.Glass,
			transparency = 0.45,
			parent = case,
		})
		glass:SetAttribute("RetailPriceCents", 549)
		addPrompt(glass, "CollectItem", "Take item", "Frozen Food", 0.15)
		storePart({
			name = "Plinth",
			size = Vector3.new(10, 0.35, 2.8),
			position = Vector3.new(fx, shelfWalk + 0.18, freezerZ),
			color = Color3.fromRGB(70, 74, 78),
			material = Enum.Material.Metal,
			parent = case,
		})
	end

	-- Front end: compact service point on the left, player register and staffed NPC lane on the right.
	local frontEnd = Instance.new("Model")
	frontEnd.Name = "FrontEnd"
	frontEnd.Parent = store

	zoneMarker("EntryQueuing", 0, halfD - 17, 24, 12, Color3.fromRGB(168, 168, 172))

	addSign(frontEnd, "ServiceSign", -46, floorY + 6, halfD - 15, 11, "SERVICE", Color3.fromRGB(75, 75, 82))
	local serviceDesk = storePart({
		name = "ServiceDesk",
		size = Vector3.new(10, 3, 3),
		position = Vector3.new(-46, floorY + 2, halfD - 15),
		color = Color3.fromRGB(88, 88, 92),
		material = Enum.Material.Wood,
		parent = frontEnd,
	})
	addPrompt(serviceDesk, "ServiceCustomer", "Help", "Customer Service", 0.2)
	serviceDesk:SetAttribute("ServiceDesk", true)
	local serviceStatusSign = addSign(frontEnd, "ServiceStatusSign", -46, floorY + 8.35, halfD - 15, 9.2, "QUEUE 0 | RETURNS 3", Color3.fromRGB(54, 92, 118), 1.25)
	serviceStatusSign:SetAttribute("ServiceStatusDisplay", true)
	local serviceBell = detailPart({
		name = "ServiceBell",
		size = Vector3.new(0.9, 0.35, 0.9),
		position = Vector3.new(-46, floorY + 3.7, halfD - 16.3),
		color = Color3.fromRGB(230, 196, 92),
		material = Enum.Material.Metal,
		canCollide = false,
		parent = frontEnd,
	})
	addPrompt(serviceBell, "QueueServiceCustomer", "Ring", "Service Bell", 0.1)
	local complaintClipboard = detailPart({
		name = "ComplaintClipboard",
		size = Vector3.new(1.4, 0.12, 1.8),
		position = Vector3.new(-49.2, floorY + 3.62, halfD - 16.2),
		color = Color3.fromRGB(238, 228, 194),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		parent = frontEnd,
	})
	addPrompt(complaintClipboard, "ResolveComplaint", "Resolve", "Service Issue", 0.25)
	local serviceBagRack = storePart({
		name = "ServiceBagRack",
		size = Vector3.new(2.2, 2.5, 0.65),
		position = Vector3.new(-42.5, floorY + 2.9, halfD - 16.4),
		color = Color3.fromRGB(210, 212, 206),
		material = Enum.Material.Metal,
		parent = frontEnd,
	})
	serviceBagRack:SetAttribute("ServiceBagRack", true)
	addPrompt(serviceBagRack, "RestockServiceBags", "Restock", "Service Bags", 0.2)
	local returnBin = storePart({
		name = "ReturnBin",
		size = Vector3.new(3.4, 1.7, 2.4),
		position = Vector3.new(-55.2, floorY + 1.35, 31),
		color = Color3.fromRGB(116, 88, 64),
		material = Enum.Material.Wood,
		parent = frontEnd,
	})
	returnBin:SetAttribute("ServiceReturnBin", true)
	addPrompt(returnBin, "ProcessReturn", "Process", "Returns", 0.25)
	for i = 1, 3 do
		detailPart({
			name = `ReturnPackage{i}`,
			size = Vector3.new(0.9, 0.55, 0.8),
			position = Vector3.new(-55.9 + i * 0.7, floorY + 2.45, 31.1),
			color = Color3.fromRGB(190, 148, 98),
			material = Enum.Material.Cardboard,
			canCollide = false,
			parent = frontEnd,
		})
	end
	local pickupLockers = storePart({
		name = "PickupLockers",
		size = Vector3.new(4.6, 5.2, 1.2),
		position = Vector3.new(-37.2, floorY + 3.1, halfD - 23.2),
		color = Color3.fromRGB(58, 72, 92),
		material = Enum.Material.Metal,
		parent = frontEnd,
	})
	pickupLockers:SetAttribute("ServicePickupLockers", true)
	addPrompt(pickupLockers, "ServicePickup", "Hand off", "Pickup Locker", 0.25)
	for row = 1, 3 do
		for col = 1, 2 do
			detailPart({
				name = `LockerDoor{row}_{col}`,
				size = Vector3.new(1.7, 1.1, 0.08),
				position = Vector3.new(-38.35 + col * 1.45, floorY + 1.45 + row * 1.1, halfD - 22.55),
				color = Color3.fromRGB(82, 102, 126),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				parent = frontEnd,
			})
		end
	end
	local lostFoundShelf = storePart({
		name = "LostAndFoundShelf",
		size = Vector3.new(4.2, 4.2, 1.1),
		position = Vector3.new(-55.5, floorY + 2.85, halfD - 15.2),
		color = Color3.fromRGB(94, 78, 62),
		material = Enum.Material.Wood,
		parent = frontEnd,
	})
	lostFoundShelf:SetAttribute("ServiceLostFoundShelf", true)
	addPrompt(lostFoundShelf, "CheckLostFound", "Check", "Lost and Found", 0.15)
	for i, z in { 39, 42, 45 } do
		local postA = detailPart({
			name = `ServiceQueuePostA{i}`,
			size = Vector3.new(0.3, 2.3, 0.3),
			position = Vector3.new(-51, floorY + 1.65, z),
			color = Color3.fromRGB(65, 68, 74),
			material = Enum.Material.Metal,
			parent = frontEnd,
		})
		local postB = detailPart({
			name = `ServiceQueuePostB{i}`,
			size = Vector3.new(0.3, 2.3, 0.3),
			position = Vector3.new(-41, floorY + 1.65, z),
			color = Color3.fromRGB(65, 68, 74),
			material = Enum.Material.Metal,
			parent = frontEnd,
		})
		detailPart({
			name = `ServiceQueueRail{i}`,
			size = Vector3.new(0.16, 0.16, 3),
			position = postA.Position + Vector3.new(0, 0.8, -1.5),
			color = Color3.fromRGB(92, 112, 132),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = frontEnd,
		})
	end

	local petKiosk = Instance.new("Model")
	petKiosk.Name = "PetLotteryKiosk"
	petKiosk.Parent = frontEnd
	storePart({
		name = "Base",
		size = Vector3.new(7, 1.2, 4),
		position = Vector3.new(-17, floorY + 1.1, halfD - 14),
		color = Color3.fromRGB(44, 52, 66),
		material = Enum.Material.Metal,
		parent = petKiosk,
	})
	local petConsole = storePart({
		name = "Console",
		size = Vector3.new(5.8, 4.6, 0.8),
		position = Vector3.new(-17, floorY + 3.9, halfD - 14.8),
		color = Color3.fromRGB(72, 54, 104),
		material = Enum.Material.SmoothPlastic,
		parent = petKiosk,
	})
	addPrompt(petConsole, "OpenPetMenu", "Open", "Pet Lottery", 0.1)
	storePart({
		name = "GlowPanel",
		size = Vector3.new(4.8, 2.8, 0.25),
		position = Vector3.new(-17, floorY + 4.1, halfD - 14.3),
		color = Color3.fromRGB(160, 100, 230),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = petKiosk,
	})
	storePart({
		name = "CapsuleDisplay",
		size = Vector3.new(2.6, 2.6, 2.6),
		position = Vector3.new(-17, floorY + 6.4, halfD - 14),
		color = Color3.fromRGB(245, 205, 88),
		material = Enum.Material.Glass,
		transparency = 0.25,
		canCollide = false,
		parent = petKiosk,
	})
	addSign(petKiosk, "PetLotterySign", -17, floorY + 7.8, halfD - 15.1, 6.4, "PETS", Color3.fromRGB(96, 58, 132), 1.2)
	local petCareStation = storePart({
		name = "PetCareStation",
		size = Vector3.new(4.2, 1.4, 2.8),
		position = Vector3.new(-24, floorY + 1.2, 40),
		color = Color3.fromRGB(70, 88, 92),
		material = Enum.Material.Wood,
		parent = petKiosk,
	})
	addPrompt(petCareStation, "CarePet", "Care", "Pet Care", 0.2)
	detailPart({
		name = "PetTreatJar",
		size = Vector3.new(1.2, 1.5, 1.2),
		position = Vector3.new(-25.2, floorY + 2.65, 40),
		color = Color3.fromRGB(236, 198, 92),
		material = Enum.Material.Glass,
		transparency = 0.25,
		canCollide = false,
		parent = petKiosk,
	})
	detailPart({
		name = "PetCareMat",
		size = Vector3.new(4.8, 0.08, 3.4),
		position = Vector3.new(-24, walkTop + 0.08, 40),
		color = Color3.fromRGB(92, 120, 126),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.25,
		canCollide = false,
		parent = petKiosk,
	})

	local teamStation = Instance.new("Model")
	teamStation.Name = "FrontTeamStation"
	teamStation.Parent = frontEnd
	local teamBacker = detailPart({
		name = "TeamBacker",
		size = Vector3.new(10, 7.8, 0.5),
		position = Vector3.new(-32, 5.2, 35.05),
		color = Color3.fromRGB(42, 58, 70),
		material = Enum.Material.SmoothPlastic,
		parent = teamStation,
	})
	addSign(teamStation, "TeamSign", -32, 8.6, 35.55, 6.4, "TEAM", Color3.fromRGB(42, 92, 118), 1.15)
	local frontTimeClock = detailPart({
		name = "FrontTimeClock",
		size = Vector3.new(2.2, 3, 0.45),
		position = Vector3.new(-35, 5.2, 35.55),
		color = Color3.fromRGB(38, 44, 54),
		material = Enum.Material.SmoothPlastic,
		parent = teamStation,
	})
	addPrompt(frontTimeClock, "ClockIn", "Clock in", "Time Clock", 0.15)
	local frontTaskBoard = detailPart({
		name = "FrontTaskBoard",
		size = Vector3.new(4.5, 3, 0.45),
		position = Vector3.new(-30, 5.2, 35.55),
		color = Color3.fromRGB(38, 88, 68),
		material = Enum.Material.SmoothPlastic,
		parent = teamStation,
	})
	addPrompt(frontTaskBoard, "InspectTasks", "Review", "Task Board", 0.1)
	local storeStatusControl = detailPart({
		name = "StoreStatusControl",
		size = Vector3.new(3.6, 1.1, 0.55),
		position = Vector3.new(-32.5, 3.1, 35.6),
		color = Color3.fromRGB(56, 116, 74),
		material = Enum.Material.SmoothPlastic,
		parent = teamStation,
	})
	storeStatusControl:SetAttribute("StoreOpenControl", true)
	addPrompt(storeStatusControl, "ToggleStoreOpen", "Close", "Store Open", 0.25)
	local storeStatusSign = addSign(teamStation, "StoreStatusSign", -32.5, 7.3, 35.55, 5.6, "OPEN", Color3.fromRGB(52, 120, 72), 1.05)
	storeStatusSign:SetAttribute("StoreStatusDisplay", true)
	storePart({
		name = "TeamShelf",
		size = Vector3.new(8.4, 0.35, 1.5),
		position = Vector3.new(-32, floorY + 1.85, halfD - 13.8),
		color = Color3.fromRGB(96, 82, 66),
		material = Enum.Material.Wood,
		parent = teamStation,
	})
	teamBacker.CastShadow = false

	local checkout = Instance.new("Model")
	checkout.Name = "Checkout"
	checkout.Parent = frontEnd
	local function buildRegisterLane(name: string, registerId: string, x: number, label: string, signColor: Color3, kind: string)
		local lane = Instance.new("Model")
		lane.Name = name
		lane:SetAttribute("RegisterId", registerId)
		lane:SetAttribute("RegisterKind", kind)
		lane.Parent = checkout
		local steel = Color3.fromRGB(193, 201, 203)
		local dark = Color3.fromRGB(43, 49, 54)
		fixtureDetail(lane, "CounterKickPlate", Vector3.new(11.8, 0.35, 3.05), Vector3.new(x, 1.2, 28), dark, Enum.Material.Metal)
		fixtureDetail(lane, "CounterFascia", Vector3.new(11.7, 0.5, 0.12), Vector3.new(x, 3.4, 29.56), signColor)
		for _, offset in { -2, 2 } do
			fixtureDetail(lane, `CabinetSeam{offset}`, Vector3.new(0.04, 1.8, 0.04), Vector3.new(x + offset, 2.3, 29.54), dark)
		end
		for _, side in { -1, 1 } do
			fixtureDetail(lane, `BeltGuide{side}`, Vector3.new(7.5, 0.16, 0.18), Vector3.new(x - 1.1, 4.15, 28 + side * 1.14), steel, Enum.Material.Metal)
		end
		fixtureDetail(lane, "BeltEndRoller", Vector3.new(0.22, 0.13, 2), Vector3.new(x - 4.55, 4.23, 28), steel, Enum.Material.Metal)
		fixtureDetail(lane, "BaggingTrayRim", Vector3.new(3.4, 0.18, 0.12), Vector3.new(x + 4.6, 3.82, 31.05), steel, Enum.Material.Metal)
		fixtureDetail(lane, "MonitorFoot", Vector3.new(1.45, 0.12, 0.9), Vector3.new(x + 4.8, 4.07, 26.8), dark)
		fixtureDetail(lane, "MonitorStand", Vector3.new(0.3, 0.8, 0.3), Vector3.new(x + 4.8, 4.53, 26.8), steel, Enum.Material.Metal)
		local monitorScreen = addSign(lane, "MonitorScreen", x + 4.8, 5.5, 26.59, 1.5, "REGISTER\nREADY", Color3.fromRGB(39, 74, 67), 1.06)
		monitorScreen.Size = Vector3.new(1.5, 1.06, 0.035)
		fixtureDetail(lane, "DrawerHandle", Vector3.new(1.5, 0.12, 0.15), Vector3.new(x + 4.4, 4.22, 29.16), steel, Enum.Material.Metal)
		fixtureDetail(lane, "CardReader", Vector3.new(0.75, 0.28, 1.2), Vector3.new(x - 5.3, 4.14, 28), dark)
		fixtureDetail(lane, "CardReaderScreen", Vector3.new(0.53, 0.025, 0.4), Vector3.new(x - 5.3, 4.295, 27.73), Color3.fromRGB(99, 183, 170))
		for row = 1, 3 do
			for column = -1, 1 do
				fixtureDetail(lane, `CardKey{row}_{column}`, Vector3.new(0.11, 0.025, 0.11), Vector3.new(x - 5.3 + column * 0.17, 4.295, 28.06 + row * 0.15), steel)
			end
		end

		detailPart({
			name = "Counter",
			size = Vector3.new(12, 3, 3),
			position = Vector3.new(x, floorY + 2, halfD - 22),
			color = Color3.fromRGB(210, 216, 214),
			material = Enum.Material.Metal,
			parent = lane,
		})
		detailPart({
			name = "Belt",
			size = Vector3.new(7.2, 0.2, 2),
			position = Vector3.new(x - 1.1, floorY + 3.6, halfD - 22),
			color = Color3.fromRGB(28, 28, 32),
			material = Enum.Material.Fabric,
			canCollide = false,
			parent = lane,
		})
		detailPart({
			name = "BaggingShelf",
			size = Vector3.new(3.4, 0.35, 2.6),
			position = Vector3.new(x + 4.6, floorY + 3.1, halfD - 20.2),
			color = steel,
			material = Enum.Material.Metal,
			parent = lane,
		})
		local scanner = detailPart({
			name = "Scanner",
			size = Vector3.new(1, 1, 1),
			position = Vector3.new(x + 2.7, floorY + 4, halfD - 22),
			color = Color3.fromRGB(35, 35, 40),
			material = Enum.Material.Metal,
			parent = lane,
		})
		detailPart({
			name = "Monitor",
			size = Vector3.new(1.8, 1.4, 0.35),
			position = Vector3.new(x + 4.8, 5.5, halfD - 23.2),
			color = Color3.fromRGB(24, 30, 36),
			material = Enum.Material.SmoothPlastic,
			parent = lane,
		})
		local cashDrawer = detailPart({
			name = "CashDrawer",
			size = Vector3.new(2.2, 0.7, 1.4),
			position = Vector3.new(x + 4.4, floorY + 3.75, halfD - 21.6),
			color = Color3.fromRGB(70, 72, 78),
			material = Enum.Material.Metal,
			parent = lane,
		})
		local receiptPrinter = detailPart({
			name = "ReceiptPrinter",
			size = Vector3.new(1, 0.8, 1),
			position = Vector3.new(x + 2.5, floorY + 4.15, halfD - 23.7),
			color = Color3.fromRGB(220, 220, 216),
			material = Enum.Material.SmoothPlastic,
			parent = lane,
		})
		local cashTray = detailPart({
			name = "CashTray",
			size = Vector3.new(2.6, 0.16, 1.5),
			position = Vector3.new(x + 4.4, floorY + 4.2, halfD - 21.6),
			color = Color3.fromRGB(28, 30, 34),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = lane,
		})
		for index, offset in { -0.75, -0.25, 0.25, 0.75 } do
			detailPart({
				name = `BillStack{index}`,
				size = Vector3.new(0.42, 0.08, 0.9),
				position = cashTray.Position + Vector3.new(offset, 0.14, -0.18),
				color = Color3.fromRGB(96, 154, 104),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				parent = lane,
			})
		end
		for index, offset in { -0.45, 0, 0.45 } do
			detailPart({
				name = `CoinCup{index}`,
				size = Vector3.new(0.32, 0.1, 0.32),
				position = cashTray.Position + Vector3.new(offset, 0.16, 0.48),
				color = Color3.fromRGB(190, 184, 154),
				material = Enum.Material.Metal,
				canCollide = false,
				parent = lane,
			})
		end
		local receiptPaper = detailPart({
			name = "ReceiptPaper",
			size = Vector3.new(0.95, 0.05, 1.35),
			position = Vector3.new(x + 2.5, floorY + 4.62, halfD - 23.25),
			color = Color3.fromRGB(242, 238, 222),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = lane,
		})
		local receiptGui = Instance.new("SurfaceGui")
		receiptGui.Face = Enum.NormalId.Top
		receiptGui.LightInfluence = 0.1
		receiptGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		receiptGui.PixelsPerStud = 80
		receiptGui.Parent = receiptPaper
		local receiptLabel = Instance.new("TextLabel")
		receiptLabel.Name = "Label"
		receiptLabel.Size = UDim2.fromScale(1, 1)
		receiptLabel.BackgroundTransparency = 1
		receiptLabel.Text = "RECEIPT\nREADY"
		receiptLabel.TextColor3 = Color3.fromRGB(42, 38, 32)
		receiptLabel.TextScaled = true
		receiptLabel.Font = Enum.Font.Code
		receiptLabel.Parent = receiptGui
		detailPart({
			name = "LaneLight",
			size = Vector3.new(0.3, 5, 0.3),
			position = Vector3.new(x + 5.6, floorY + 7, halfD - 24.2),
			color = if kind == "Player" then Color3.fromRGB(80, 180, 90) else Color3.fromRGB(82, 128, 185),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = lane,
		})
		fixtureDetail(lane, "LaneBeacon", Vector3.new(0.65, 0.7, 0.65), Vector3.new(x + 5.6, 10.15, 25.8), signColor, Enum.Material.Neon)
		addSign(lane, "LaneSign", x, floorY + 8.15, halfD - 25.2, 7.4, label, signColor, 1)
		local statusDisplay = addSign(lane, "StatusDisplay", x, floorY + 5.75, halfD - 18.7, 6.2, "READY", Color3.fromRGB(48, 52, 58), 1.05)
		statusDisplay:SetAttribute("RegisterStatusDisplay", true)
		detailPart({
			name = "CustomerMat",
			size = Vector3.new(5, 0.04, 3),
			position = Vector3.new(x, walkTop + 0.04, 32),
			color = signColor,
			canCollide = false,
			parent = lane,
		})

		if kind == "Player" then
			addSign(lane, "OpeningTillSign", x + 4.4, floorY + 5.2, halfD - 20.5, 3.4, "START\n$200", Color3.fromRGB(66, 78, 72), 0.9)
			addPrompt(cashDrawer, "OpenPlayerRegister", "Open", "Player Register", 0.15)
			addPrompt(scanner, "Checkout", "Scan basket", "Basket Checkout", 0.2)
		else
			receiptPrinter:SetAttribute("NpcRegisterProp", true)
		end

		return lane
	end

	buildRegisterLane("PlayerRegister", "PlayerRegister", 10, "PLAYER REGISTER", Color3.fromRGB(70, 110, 78), "Player")
	buildRegisterLane("NpcRegister", "NpcRegister", 30, "NPC REGISTER", Color3.fromRGB(62, 82, 126), "NPC")

	zoneMarker("Bagging", 20, halfD - 14.5, 30, 6, Color3.fromRGB(128, 128, 132))

	-- Carts moved to parking (not blocking entrance)

	-- Structural pillars at building exterior corners (inset from walls, clear of back rooms)
	local pillarInset = 3.5
	local pillarH = wallH + 0.5
	local pillarY = floorY + pillarH / 2 + 0.5
	for _, corner in {
		{ name = "PillarNW", x = -halfW + pillarInset, z = -halfD + pillarInset },
		{ name = "PillarNE", x = halfW - pillarInset, z = -halfD + pillarInset },
		{ name = "PillarSW", x = -halfW + pillarInset, z = halfD - pillarInset },
		{ name = "PillarSE", x = halfW - pillarInset, z = halfD - pillarInset },
	} do
		storePart({
			name = corner.name,
			size = Vector3.new(2.8, pillarH, 2.8),
			position = Vector3.new(corner.x, pillarY, corner.z),
			color = Color3.fromRGB(185, 183, 180),
			material = Enum.Material.Concrete,
		})
	end

	-- Stock / cooler / loading props (inside room centers)
	local stock = store:FindFirstChild("StockRoom")
	if stock then
		decorFloor("StockReceivingZone", Vector3.new(14, 0.08, 5), Vector3.new(-46, walkTop + 0.08, backZ + 7), Color3.fromRGB(196, 156, 74), stock)
		decorFloor("StockPickLane", Vector3.new(8, 0.08, 18), Vector3.new(-36, walkTop + 0.09, backZ - 3), Color3.fromRGB(190, 190, 196), stock)
		decorFloor("StockBackstockZone", Vector3.new(14, 0.08, 5), Vector3.new(-25, walkTop + 0.08, backZ + 7), Color3.fromRGB(104, 142, 112), stock)
		addSign(stock, "ReceivingSign", -47, floorY + 7.7, backZ + 6.5, 7.2, "RECEIVING", Color3.fromRGB(88, 82, 65), 1.2)
		addSign(stock, "PickListSign", -30, floorY + 9.7, backZ - 10.2, 6.6, "PICK LIST", Color3.fromRGB(70, 76, 86), 1.2)
		addSign(stock, "BackstockSign", -25, floorY + 7.7, backZ + 6.5, 7.2, "BACKSTOCK", Color3.fromRGB(62, 92, 72), 1.2)

		for _, rack in {
			{ name = "RackWest", x = -50, z = backZ - 3, width = 3, depth = 14, zone = "Case" },
			{ name = "RackNorth", x = -40, z = backZ - 8.5, width = 8, depth = 3, zone = "Bulk" },
			{ name = "RackEast", x = -22, z = backZ - 3, width = 3, depth = 14, zone = "Promo" },
		} do
			storePart({
				name = rack.name,
				size = Vector3.new(rack.width, 7, rack.depth),
				position = Vector3.new(rack.x, floorY + 4.1, rack.z),
				color = Color3.fromRGB(95, 98, 104),
				material = Enum.Material.Metal,
				parent = stock,
			})
			for shelf = -1, 1 do
				storePart({
					name = `{rack.name}_Shelf{shelf}`,
					size = Vector3.new(rack.width + 0.4, 0.35, rack.depth),
					position = Vector3.new(rack.x, floorY + 2.5 + shelf * 2.4, rack.z),
					color = Color3.fromRGB(125, 110, 90),
					material = Enum.Material.Wood,
					parent = stock,
				})
			end
			for itemIndex, item in {
				{ y = 2.1, z = backZ - 8.6, color = Color3.fromRGB(174, 120, 72) },
				{ y = 2.1, z = backZ - 4.2, color = Color3.fromRGB(150, 130, 95) },
				{ y = 4.4, z = backZ - 6.2, color = Color3.fromRGB(86, 126, 156) },
				{ y = 6.8, z = backZ - 1.5, color = Color3.fromRGB(145, 154, 104) },
				{ y = 6.8, z = backZ + 2.8, color = Color3.fromRGB(132, 108, 88) },
			} do
				detailPart({
					name = `{rack.zone}Box{itemIndex}`,
					size = Vector3.new(if rack.zone == "Bulk" then 1.2 else 2.4, 1.1, 1.6),
					position = Vector3.new(if rack.zone == "Bulk" then rack.x + (itemIndex - 3) * 1.3 else rack.x, floorY + item.y, if rack.zone == "Bulk" then rack.z else item.z),
					color = item.color,
					material = Enum.Material.SmoothPlastic,
					parent = stock,
				})
			end
		end
		for i, x in { -48, -24 } do
			local pallet = storePart({
				name = `StockPallet{i}`,
				size = Vector3.new(5, 2.4, 5),
				position = Vector3.new(x, floorY + 2, backZ + 7),
				color = Color3.fromRGB(125, 95, 68),
				material = Enum.Material.Wood,
				parent = stock,
			})
			addPrompt(pallet, "CollectStock", "Grab stock", "Stock Pallet", 0.2)
			for stack = 1, 3 do
				detailPart({
					name = `StockPallet{i}_Case{stack}`,
					size = Vector3.new(3.8, 1.1, 1.3),
					position = Vector3.new(x, floorY + 3.25 + stack * 0.55, backZ + 5.2 + stack * 0.85),
					color = if stack == 2 then Color3.fromRGB(168, 128, 76) else Color3.fromRGB(188, 146, 94),
					material = Enum.Material.SmoothPlastic,
					parent = stock,
				})
			end
		end
		local workTable = storePart({
			name = "StockWorkTable",
			size = Vector3.new(8, 2.4, 3),
			position = Vector3.new(-30, floorY + 1.7, backZ - 9),
			color = Color3.fromRGB(110, 112, 116),
			material = Enum.Material.Metal,
			parent = stock,
		})
		addPrompt(workTable, "InspectTasks", "Review", "Pick List", 0.15)
		storePart({
			name = "InventoryBoard",
			size = Vector3.new(8, 4, 0.35),
			position = Vector3.new(-30, floorY + 6.2, backZ - 10.4),
			color = Color3.fromRGB(42, 58, 52),
			material = Enum.Material.SmoothPlastic,
			parent = stock,
		})
		detailPart({
			name = "ClipboardStack",
			size = Vector3.new(2.2, 0.18, 1.4),
			position = Vector3.new(-32, floorY + 3.05, backZ - 8.8),
			color = Color3.fromRGB(236, 228, 192),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = stock,
		})
		for rail, x in { -52.8, -19.2 } do
			storePart({
				name = `StockWallBumper{rail}`,
				size = Vector3.new(1.4, 1.2, 17),
				position = Vector3.new(x, floorY + 1.8, backZ - 1),
				color = Color3.fromRGB(236, 184, 72),
				material = Enum.Material.Metal,
				parent = stock,
			})
		end
		storePart({
			name = "PalletJackBase",
			size = Vector3.new(5.5, 0.45, 1.1),
			position = Vector3.new(-30, floorY + 0.85, backZ + 6),
			color = Color3.fromRGB(214, 170, 45),
			material = Enum.Material.Metal,
			parent = stock,
		})
		detailPart({
			name = "PalletJackHandle",
			size = Vector3.new(0.35, 3.4, 0.35),
			position = Vector3.new(-27.1, floorY + 2.5, backZ + 6),
			color = Color3.fromRGB(55, 58, 62),
			material = Enum.Material.Metal,
			parent = stock,
		})
		storePart({
			name = "ShrinkWrapRolls",
			size = Vector3.new(2, 3.5, 2),
			position = Vector3.new(-56, floorY + 2.25, backZ + 1),
			color = Color3.fromRGB(225, 232, 238),
			material = Enum.Material.Plastic,
			transparency = 0.15,
			parent = stock,
		})
	end

	local pharmacy = store:FindFirstChild("Pharmacy")
	if pharmacy then
		decorFloor("PharmacyQueueMat", Vector3.new(4.5, 0.08, 10), Vector3.new(westCx + 6, walkTop + 0.08, -15), Color3.fromRGB(92, 126, 158), pharmacy)
		decorFloor("PharmacyConsultZone", Vector3.new(9, 0.08, 6), Vector3.new(-48.5, walkTop + 0.09, -22), Color3.fromRGB(150, 174, 184), pharmacy)
		decorFloor("PharmacyDropoffZone", Vector3.new(6, 0.08, 4), Vector3.new(westCx - 5, walkTop + 0.1, -16.5), Color3.fromRGB(72, 104, 132), pharmacy)
		decorFloor("PharmacyPickupZone", Vector3.new(6, 0.08, 4), Vector3.new(westCx - 5, walkTop + 0.11, -10), Color3.fromRGB(72, 120, 92), pharmacy)
		local pharmacyCounter = storePart({
			name = "ServiceCounter",
			size = Vector3.new(6.5, 3, 2.2),
			position = Vector3.new(westCx - 5, floorY + 2, -10),
			color = Color3.fromRGB(220, 222, 226),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		addPrompt(pharmacyCounter, "FillPrescription", "Fill", "Pharmacy Counter", 0.25)
		local dropoffCounter = storePart({
			name = "DropoffWindowCounter",
			size = Vector3.new(6.5, 2.2, 2.2),
			position = Vector3.new(westCx - 5, floorY + 1.6, -16.5),
			color = Color3.fromRGB(204, 212, 218),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		addPrompt(dropoffCounter, "FillPrescription", "Drop off", "Prescription Dropoff", 0.25)
		addSign(pharmacy, "PharmacyDropoffSign", westCx - 5, floorY + 5.9, -17.7, 3.8, "DROP", Color3.fromRGB(52, 86, 120), 0.82)
		addSign(pharmacy, "PharmacyPickupSign", westCx - 5, floorY + 5.9, -11.2, 3.8, "PICKUP", Color3.fromRGB(52, 100, 86), 0.82)
		for shelf, z in { -22, -6 } do
			storePart({
				name = `MedicineShelf{shelf}`,
				size = Vector3.new(5, 6, 2),
				position = Vector3.new(westCx - 5, floorY + 3.5, z),
				color = Color3.fromRGB(235, 238, 242),
				material = Enum.Material.SmoothPlastic,
				parent = pharmacy,
			})
			storePart({
				name = `MedicineBottles{shelf}`,
				size = Vector3.new(4, 1.2, 1.2),
				position = Vector3.new(westCx - 5, floorY + 5.6, z),
				color = Color3.fromRGB(92, 132, 185),
				material = Enum.Material.Plastic,
				parent = pharmacy,
			})
			for row = 1, 3 do
				for bottle = 1, 4 do
					detailPart({
						name = `MedicineBottle{shelf}_{row}_{bottle}`,
						size = Vector3.new(0.45, 0.75, 0.45),
						position = Vector3.new(westCx - 6.6 + bottle * 0.65, floorY + 2.3 + row * 1.25, z + 0.75),
						color = if (row + bottle) % 2 == 0 then Color3.fromRGB(230, 236, 242) else Color3.fromRGB(86, 132, 178),
						material = Enum.Material.Plastic,
						canCollide = false,
						parent = pharmacy,
					})
				end
			end
		end
		storePart({
			name = "PharmacyMonitor",
			size = Vector3.new(2.2, 1.6, 0.3),
			position = Vector3.new(westCx - 4, floorY + 4.1, -9.7),
			color = Color3.fromRGB(24, 28, 34),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		detailPart({
			name = "PrescriptionScanner",
			size = Vector3.new(1.1, 0.3, 1.2),
			position = Vector3.new(westCx - 2.8, floorY + 3.65, -9.8),
			color = Color3.fromRGB(36, 44, 52),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		storePart({
			name = "LockedMedsCabinet",
			size = Vector3.new(3, 6, 1.4),
			position = Vector3.new(westCx - 6.5, floorY + 3.8, -13),
			color = Color3.fromRGB(105, 118, 130),
			material = Enum.Material.Metal,
			parent = pharmacy,
		})
		detailPart({
			name = "LockedMedsWindow",
			size = Vector3.new(2.5, 3.8, 0.2),
			position = Vector3.new(westCx - 6.5, floorY + 4.3, -12.2),
			color = Color3.fromRGB(174, 206, 220),
			material = Enum.Material.Glass,
			transparency = 0.35,
			canCollide = false,
			parent = pharmacy,
		})
		storePart({
			name = "VaccineFridge",
			size = Vector3.new(3, 5, 2),
			position = Vector3.new(westCx - 7, floorY + 3.25, -3.5),
			color = Color3.fromRGB(235, 240, 244),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		storePart({
			name = "WaitingBench",
			size = Vector3.new(4, 1.5, 2),
			position = Vector3.new(westCx + 5, floorY + 1.25, -6),
			color = Color3.fromRGB(110, 90, 70),
			material = Enum.Material.Wood,
			parent = pharmacy,
		})
		storePart({
			name = "PrivacyDivider",
			size = Vector3.new(0.5, 5, 5),
			position = Vector3.new(westCx, floorY + 3.5, -6),
			color = Color3.fromRGB(190, 198, 204),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		storePart({
			name = "ConsultTable",
			size = Vector3.new(3.5, 1.5, 2.4),
			position = Vector3.new(-48.5, floorY + 1.25, -22),
			color = Color3.fromRGB(212, 214, 214),
			material = Enum.Material.SmoothPlastic,
			parent = pharmacy,
		})
		for chair, x in { -51.5, -45.5 } do
			storePart({
				name = `ConsultChair{chair}`,
				size = Vector3.new(1.8, 2, 1.8),
				position = Vector3.new(x, floorY + 1.5, -22),
				color = Color3.fromRGB(78, 104, 126),
				material = Enum.Material.SmoothPlastic,
				parent = pharmacy,
			})
		end
	end

	local bakery = store:FindFirstChild("Bakery")
	if bakery then
		decorFloor("BakeryCustomerMat", Vector3.new(7, 0.08, 11), Vector3.new(westCx + 5, walkTop + 0.08, 16), Color3.fromRGB(142, 92, 66), bakery)
		decorFloor("BakeryPrepZone", Vector3.new(12, 0.08, 7), Vector3.new(westCx - 1, walkTop + 0.09, 25), Color3.fromRGB(198, 182, 152), bakery)
		for i, z in { 8, 14, 20 } do
			storePart({
				name = `Display{i}`,
				size = Vector3.new(4, 1.2, 2),
				position = Vector3.new(westCx - 5, floorY + 1.2, z),
				color = Color3.fromRGB(168, 135, 98),
				material = Enum.Material.Wood,
				parent = bakery,
			})
			storePart({
				name = `DisplayGlass{i}`,
				size = Vector3.new(4, 1.3, 1.8),
				position = Vector3.new(westCx - 5, floorY + 2.45, z),
				color = Color3.fromRGB(205, 225, 235),
				material = Enum.Material.Glass,
				transparency = 0.45,
				canCollide = false,
				parent = bakery,
			})
			for pastry = 1, 3 do
				detailPart({
					name = `PastryTray{i}_{pastry}`,
					size = Vector3.new(1, 0.35, 0.75),
					position = Vector3.new(westCx - 6.1 + pastry * 0.8, floorY + 3.15, z - 0.3),
					color = if pastry == 2 then Color3.fromRGB(235, 196, 126) else Color3.fromRGB(200, 142, 82),
					material = Enum.Material.SmoothPlastic,
					canCollide = false,
					parent = bakery,
				})
			end
		end
		storePart({
			name = "Oven",
			size = Vector3.new(6, 5, 4),
			position = Vector3.new(westCx - 4, floorY + 3, 23),
			color = Color3.fromRGB(68, 68, 72),
			material = Enum.Material.Metal,
			parent = bakery,
		})
		for slot = 1, 3 do
			detailPart({
				name = `OvenGlow{slot}`,
				size = Vector3.new(4.8, 0.45, 0.22),
				position = Vector3.new(westCx - 4, floorY + 1.8 + slot * 1.1, 25.05),
				color = Color3.fromRGB(230, 132, 52),
				material = Enum.Material.Neon,
				canCollide = false,
				parent = bakery,
			})
		end
		local prepCounter = storePart({
			name = "PrepCounter",
			size = Vector3.new(8, 2.4, 2),
			position = Vector3.new(-47.5, floorY + 1.7, 24.5),
			color = Color3.fromRGB(210, 205, 198),
			material = Enum.Material.Marble,
			parent = bakery,
		})
		addPrompt(prepCounter, "BakeBatch", "Prepare", "Bakery Counter", 0.25)
		detailPart({
			name = "DoughBoard",
			size = Vector3.new(3.5, 0.16, 1.4),
			position = Vector3.new(-48.5, floorY + 3, 24.4),
			color = Color3.fromRGB(205, 168, 108),
			material = Enum.Material.Wood,
			canCollide = false,
			parent = bakery,
		})
		for dough = 1, 3 do
			detailPart({
				name = `DoughRound{dough}`,
				size = Vector3.new(0.9, 0.35, 0.9),
				position = Vector3.new(-50.1 + dough * 0.75, floorY + 3.25, 24.35),
				color = Color3.fromRGB(230, 205, 156),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				parent = bakery,
			})
		end
		local mixer = storePart({
			name = "StandMixer",
			size = Vector3.new(2.2, 2.4, 2),
			position = Vector3.new(westCx + 4.5, floorY + 2.2, 22),
			color = Color3.fromRGB(210, 214, 218),
			material = Enum.Material.Metal,
			parent = bakery,
		})
		addPrompt(mixer, "BakeBatch", "Mix", "Dough Mixer", 0.25)
		detailPart({
			name = "MixerBowl",
			size = Vector3.new(1.3, 0.8, 1.3),
			position = Vector3.new(westCx + 4.5, floorY + 3.8, 22),
			color = Color3.fromRGB(162, 170, 176),
			material = Enum.Material.Metal,
			parent = bakery,
		})
		storePart({
			name = "BreadRack",
			size = Vector3.new(3, 6, 2),
			position = Vector3.new(westCx + 3, floorY + 3.5, 8),
			color = Color3.fromRGB(130, 95, 58),
			material = Enum.Material.Wood,
			parent = bakery,
		})
		for shelf = 1, 4 do
			detailPart({
				name = `BreadRackLoaves{shelf}`,
				size = Vector3.new(2.2, 0.45, 1.1),
				position = Vector3.new(westCx + 3, floorY + 1.5 + shelf * 1.05, 8.2),
				color = Color3.fromRGB(202, 138, 72),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				parent = bakery,
			})
		end
		for bin, z in { 10, 12.5 } do
			storePart({
				name = `IngredientBin{bin}`,
				size = Vector3.new(2.5, 2, 2),
				position = Vector3.new(westCx + 3.8, floorY + 1.5, z),
				color = if z == 10 then Color3.fromRGB(238, 232, 214) else Color3.fromRGB(186, 166, 130),
				material = Enum.Material.SmoothPlastic,
				parent = bakery,
			})
		end
		storePart({
			name = "CoolingRack",
			size = Vector3.new(3, 6, 2),
			position = Vector3.new(westCx - 7, floorY + 3.5, 26.2),
			color = Color3.fromRGB(130, 132, 136),
			material = Enum.Material.Metal,
			parent = bakery,
		})
		for tray = 1, 4 do
			detailPart({
				name = `CoolingTray{tray}`,
				size = Vector3.new(2.4, 0.18, 1.5),
				position = Vector3.new(westCx - 7, floorY + 1.4 + tray * 1.15, 26.2),
				color = Color3.fromRGB(190, 192, 194),
				material = Enum.Material.Metal,
				canCollide = false,
				parent = bakery,
			})
		end
		storePart({
			name = "PastrySign",
			size = Vector3.new(7, 2, 0.4),
			position = Vector3.new(westCx - 5, floorY + 7, 14),
			color = Color3.fromRGB(120, 78, 42),
			material = Enum.Material.Wood,
			parent = bakery,
		})
		addSign(bakery, "BakeryMenuBoard", westCx + 1.5, floorY + 7.25, 20.8, 7.2, "BREAD", Color3.fromRGB(92, 64, 44), 1.15)
	end

	local restroom = store:FindFirstChild("Restrooms")
	if restroom then
		for index, centerZ in { -20.25, -8.75 } do
			local bathroom = restroom:FindFirstChild(`Bathroom{index}`)
			local northZ, southZ = centerZ - 5.75, centerZ + 5.75
			local tile = Color3.fromRGB(214, 229, 225)
			local porcelain = Color3.fromRGB(240, 243, 241)
			-- Thin interior finishes meet the shared walls without covering either doorway.
			for _, edge in { northZ + 0.56, southZ - 0.56 } do
				fixtureDetail(bathroom, `TileWallZ{edge}`, Vector3.new(17, 7, 0.08), Vector3.new(51, 4.55, edge), tile)
			end
			fixtureDetail(bathroom, "TileWallEast", Vector3.new(0.08, 7, 10.5), Vector3.new(59.44, 4.55, centerZ), tile)
			for _, side in { -1, 1 } do
				fixtureDetail(bathroom, `TileWallWest{side}`, Vector3.new(0.08, 7, 2.15), Vector3.new(42.56, 4.55, centerZ + side * 4.175), tile)
			end
			addSoftLight(51, centerZ, bathroom)

			local door = detailPart({ name = "PrivacyDoor", size = Vector3.new(0.22, 7.9, 5.9),
				position = Vector3.new(45.5, walkTop + 4, centerZ - 2.9), color = Color3.fromRGB(72, 114, 110),
				material = Enum.Material.SmoothPlastic, parent = bathroom })
			door.Orientation = Vector3.new(0, 90, 0)
			door:SetAttribute("RoomDoor", true)
			door:SetAttribute("DoorOpen", true)
			door:SetAttribute("DoorClosedPosition", Vector3.new(42, walkTop + 4, centerZ))
			door:SetAttribute("DoorOpenPosition", door.Position)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Close"
			prompt.ObjectText = `Restroom {index}`
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = door

			local toilet = detailPart({ name = "ToiletBase", size = Vector3.new(1.15, 1.3, 1.3),
				position = Vector3.new(57.2, 1.7, centerZ), color = porcelain, parent = bathroom })
			local bowl = fixtureDetail(bathroom, "ToiletBowl", Vector3.new(2.1, 0.85, 1.8), Vector3.new(56.85, 2.25, centerZ), porcelain)
			bowl.Shape = Enum.PartType.Ball
			local seat = fixtureDetail(bathroom, "ToiletSeat", Vector3.new(0.12, 1.9, 1.6), Vector3.new(56.8, 2.65, centerZ), porcelain)
			seat.Shape = Enum.PartType.Cylinder
			seat.Orientation = Vector3.new(0, 0, 90)
			local opening = fixtureDetail(bathroom, "ToiletOpening", Vector3.new(0.03, 1.25, 1.05), Vector3.new(56.8, 2.735, centerZ), Color3.fromRGB(65, 97, 106))
			opening.Shape = Enum.PartType.Cylinder
			opening.Orientation = Vector3.new(0, 0, 90)
			fixtureDetail(bathroom, "ToiletTank", Vector3.new(0.65, 1.8, 1.8), Vector3.new(58.2, 2.9, centerZ), porcelain)
			fixtureDetail(bathroom, "TankLid", Vector3.new(0.75, 0.13, 1.9), Vector3.new(58.2, 3.86, centerZ), porcelain)
			fixtureDetail(bathroom, "FlushButton", Vector3.new(0.2, 0.05, 0.3), Vector3.new(58.2, 3.95, centerZ - 0.5), Color3.fromRGB(135, 149, 151), Enum.Material.Metal)
			fixtureDetail(bathroom, "PaperHolder", Vector3.new(0.2, 0.6, 0.85), Vector3.new(59.28, 2.85, centerZ + 1.7), porcelain)
			fixtureDetail(bathroom, "GrabRail", Vector3.new(0.12, 0.12, 3.5), Vector3.new(59.25, 3.45, centerZ), Color3.fromRGB(132, 149, 151), Enum.Material.Metal)

			local sinkZ = northZ + 1.8
			local sink = detailPart({ name = "SinkCounter", size = Vector3.new(3.6, 2.2, 1.6),
				position = Vector3.new(47.4, 2.2, sinkZ), color = Color3.fromRGB(143, 158, 156), parent = bathroom })
			addPrompt(sink, "CleanSpill", "Clean", "Restroom Sink", 0.2)
			fixtureDetail(bathroom, "VanityTop", Vector3.new(3.8, 0.18, 1.8), Vector3.new(47.4, 3.4, sinkZ), porcelain)
			fixtureDetail(bathroom, "SinkBasin", Vector3.new(2.4, 0.04, 1.05), Vector3.new(47.4, 3.51, sinkZ), Color3.fromRGB(113, 143, 150))
			fixtureDetail(bathroom, "FaucetStem", Vector3.new(0.14, 0.65, 0.14), Vector3.new(47.4, 3.78, sinkZ - 0.64), Color3.fromRGB(154, 171, 178), Enum.Material.Metal)
			fixtureDetail(bathroom, "FaucetSpout", Vector3.new(0.14, 0.14, 0.45), Vector3.new(47.4, 4.1, sinkZ - 0.48), Color3.fromRGB(154, 171, 178), Enum.Material.Metal)
			fixtureDetail(bathroom, "MirrorFrame", Vector3.new(3.9, 2.9, 0.12), Vector3.new(47.4, 5.3, northZ + 0.6), Color3.fromRGB(75, 91, 95), Enum.Material.Metal)
			fixtureDetail(bathroom, "Mirror", Vector3.new(3.55, 2.55, 0.06), Vector3.new(47.4, 5.3, northZ + 0.7), Color3.fromRGB(176, 211, 221), Enum.Material.Glass)
			fixtureDetail(bathroom, "SoapDispenser", Vector3.new(0.6, 1, 0.35), Vector3.new(50.1, 4.6, northZ + 0.75), Color3.fromRGB(230, 234, 233))
			detailPart({ name = "HandDryer", size = Vector3.new(1.4, 1.6, 0.5), position = Vector3.new(53.2, 4.2, southZ - 0.85),
				color = Color3.fromRGB(226, 231, 232), material = Enum.Material.Metal, parent = bathroom })
			detailPart({ name = "WasteBin", size = Vector3.new(1.3, 2, 1.3), position = Vector3.new(44.1, 2.05, southZ - 1.4),
				color = Color3.fromRGB(64, 80, 82), material = Enum.Material.Metal, parent = bathroom })
			fixtureDetail(bathroom, "ChangingStation", Vector3.new(3.6, 1.8, 0.35), Vector3.new(56.7, 3.6, southZ - 0.75), Color3.fromRGB(208, 215, 211))
		end
	end

	local office = store:FindFirstChild("AdminNook")
	if office then
		decorFloor("AdminOfficeWorkZone", Vector3.new(9, 0.08, 8), Vector3.new(eastCx + 2.5, walkTop + 0.08, 30.5), Color3.fromRGB(146, 142, 136), office)
		decorFloor("AdminOfficeEntryMat", Vector3.new(4.5, 0.08, 5), Vector3.new(eastCx - 7, walkTop + 0.09, 30), Color3.fromRGB(112, 120, 128), office)
		wallPart({
			name = "AdminBackWall",
			size = Vector3.new(16.5, 9.5, 0.55),
			position = Vector3.new(eastCx + 0.25, floorY + 5.25, 23),
			color = Color3.fromRGB(205, 203, 198),
			material = Enum.Material.SmoothPlastic,
			parent = office,
		})
		wallPart({
			name = "AdminFrontWall",
			size = Vector3.new(16.5, 9.5, 0.55),
			position = Vector3.new(eastCx + 0.25, floorY + 5.25, 37),
			color = Color3.fromRGB(205, 203, 198),
			material = Enum.Material.SmoothPlastic,
			parent = office,
		})
		for segment, z in { South = 24.8, North = 35.2 } do
			wallPart({
				name = `AdminWestWall{segment}`,
				size = Vector3.new(0.55, 9.5, 4.4),
				position = Vector3.new(eastCx - 8, floorY + 5.25, z),
				color = Color3.fromRGB(205, 203, 198),
				material = Enum.Material.SmoothPlastic,
				parent = office,
			})
		end
		detailPart({
			name = "AdminDoorHeader",
			size = Vector3.new(0.55, 0.7, 6.1),
			position = Vector3.new(eastCx - 8, floorY + 8.1, 30),
			color = Color3.fromRGB(92, 98, 104),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = office,
		})
		for _, frameZ in { 27.1, 32.9 } do
			detailPart({
				name = `AdminDoorFrame{frameZ}`,
				size = Vector3.new(0.75, 7, 0.35),
				position = Vector3.new(eastCx - 8, floorY + 4.55, frameZ),
				color = Color3.fromRGB(92, 98, 104),
				material = Enum.Material.Metal,
				canCollide = false,
				parent = office,
			})
		end
		addSign(office, "AdminOfficeSign", eastCx - 4.5, floorY + 8.1, 36.5, 6.2, "MANAGER", Color3.fromRGB(62, 76, 84), 1.1)

		local managerDesk = storePart({
			name = "ManagerDesk",
			size = Vector3.new(7, 1.2, 3),
			position = Vector3.new(eastCx + 2.5, floorY + 1.55, 31),
			color = Color3.fromRGB(94, 70, 50),
			material = Enum.Material.Wood,
			parent = office,
		})
		addPrompt(managerDesk, "InspectTasks", "Review", "Manager Desk", 0.15)
		storePart({
			name = "DeskReturn",
			size = Vector3.new(2.2, 1.2, 3.6),
			position = Vector3.new(eastCx + 5.2, floorY + 1.55, 27.5),
			color = Color3.fromRGB(94, 70, 50),
			material = Enum.Material.Wood,
			parent = office,
		})
		storePart({
			name = "ManagerChair",
			size = Vector3.new(2, 2.2, 2),
			position = Vector3.new(48.5, floorY + 1.6, 32.5),
			color = Color3.fromRGB(52, 56, 62),
			material = Enum.Material.Plastic,
			parent = office,
		})
		for monitorIndex, x in { eastCx + 0.6, eastCx + 2.4, eastCx + 4.2 } do
			detailPart({
				name = `SecurityMonitor{monitorIndex}`,
				size = Vector3.new(1.5, 1.1, 0.2),
				position = Vector3.new(x, floorY + 3.05, 30),
				color = Color3.fromRGB(22, 26, 32),
				material = Enum.Material.SmoothPlastic,
				parent = office,
			})
			detailPart({
				name = `SecurityMonitorGlow{monitorIndex}`,
				size = Vector3.new(1.2, 0.75, 0.08),
				position = Vector3.new(x, floorY + 3.08, 29.87),
				color = Color3.fromRGB(80, 180, 210),
				material = Enum.Material.Neon,
				canCollide = false,
				parent = office,
			})
		end
		detailPart({
			name = "Keyboard",
			size = Vector3.new(2.2, 0.15, 0.65),
			position = Vector3.new(eastCx + 2.5, floorY + 2.25, 32.1),
			color = Color3.fromRGB(34, 36, 40),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = office,
		})
		detailPart({
			name = "PaperworkStack",
			size = Vector3.new(1.8, 0.18, 1.2),
			position = Vector3.new(eastCx + 5.2, floorY + 2.3, 30.8),
			color = Color3.fromRGB(236, 228, 194),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = office,
		})
		for cabinetIndex, z in { 25, 26.9 } do
			detailPart({
				name = `FilingCabinet{cabinetIndex}`,
				size = Vector3.new(2.3, 3.6, 1.5),
				position = Vector3.new(45, floorY + 2.3, z),
				color = Color3.fromRGB(110, 115, 120),
				material = Enum.Material.Metal,
				parent = office,
			})
		end
		detailPart({
			name = "OfficeSafe",
			size = Vector3.new(2.6, 3.2, 2),
			position = Vector3.new(eastCx + 5.8, floorY + 2.1, 34.5),
			color = Color3.fromRGB(64, 68, 74),
			material = Enum.Material.Metal,
			parent = office,
		})
		local officeTaskBoard = detailPart({
			name = "ManagerTaskBoard",
			size = Vector3.new(6, 3.5, 0.35),
			position = Vector3.new(eastCx - 2.5, floorY + 5.8, 23.5),
			color = Color3.fromRGB(44, 80, 70),
			material = Enum.Material.SmoothPlastic,
			parent = office,
		})
		addPrompt(officeTaskBoard, "InspectTasks", "Review", "Office Tasks", 0.1)
		detailPart({
			name = "OfficeWindow",
			size = Vector3.new(5.5, 3.5, 0.18),
			position = Vector3.new(eastCx - 3, floorY + 5.1, 36.6),
			color = Color3.fromRGB(170, 202, 218),
			material = Enum.Material.Glass,
			transparency = 0.35,
			canCollide = false,
			parent = office,
		})
	end

	local breakRoom = store:FindFirstChild("BreakRoom")
	if breakRoom then
		addSoftLight(eastCx, 8, breakRoom)
		decorFloor("BreakRoomEntryMat", Vector3.new(5, 0.08, 6), Vector3.new(eastCx - 7, walkTop + 0.08, 8), Color3.fromRGB(112, 118, 124), breakRoom)
		decorFloor("BreakRoomLoungeZone", Vector3.new(7.5, 0.08, 7), Vector3.new(eastCx + 3.2, walkTop + 0.09, 8.5), Color3.fromRGB(136, 128, 116), breakRoom)
		decorFloor("BreakRoomKitchenZone", Vector3.new(12, 0.08, 4), Vector3.new(eastCx + 1, walkTop + 0.1, 14.5), Color3.fromRGB(156, 152, 146), breakRoom)

		local timeClock = detailPart({
			name = "TimeClock",
			size = Vector3.new(1.8, 3, 0.45),
			position = Vector3.new(eastCx - 7.2, floorY + 4, -2.25),
			color = Color3.fromRGB(42, 48, 58),
			material = Enum.Material.SmoothPlastic,
			parent = breakRoom,
		})
		addPrompt(timeClock, "ClockIn", "Clock in", "Time Clock", 0.15)
		local taskBoard = detailPart({
			name = "TaskBoard",
			size = Vector3.new(6, 3.6, 0.35),
			position = Vector3.new(eastCx - 2.2, floorY + 5.2, -2.25),
			color = Color3.fromRGB(38, 88, 68),
			material = Enum.Material.SmoothPlastic,
			parent = breakRoom,
		})
		addPrompt(taskBoard, "InspectTasks", "Review", "Task Board", 0.1)
		addSign(breakRoom, "BreakRoomRulesSign", eastCx + 4.2, floorY + 6.95, -2.25, 5.2, "STAFF", Color3.fromRGB(74, 80, 86), 1.05)

		local kitchenette = detailPart({
			name = "KitchenetteCounter",
			size = Vector3.new(9.5, 2.2, 1.6),
			position = Vector3.new(eastCx + 1.8, floorY + 1.6, 15.6),
			color = Color3.fromRGB(185, 182, 178),
			material = Enum.Material.Marble,
			parent = breakRoom,
		})
		addPrompt(kitchenette, "CleanSpill", "Clean", "Break Counter", 0.2)
		detailPart({
			name = "Microwave",
			size = Vector3.new(2.2, 1.25, 1.15),
			position = Vector3.new(eastCx - 1.6, floorY + 3.25, 15.35),
			color = Color3.fromRGB(38, 42, 48),
			material = Enum.Material.SmoothPlastic,
			parent = breakRoom,
		})
		detailPart({
			name = "CoffeeMaker",
			size = Vector3.new(1.4, 1.7, 1.1),
			position = Vector3.new(eastCx + 1.2, floorY + 3.45, 15.35),
			color = Color3.fromRGB(48, 42, 36),
			material = Enum.Material.SmoothPlastic,
			parent = breakRoom,
		})
		detailPart({
			name = "BreakSink",
			size = Vector3.new(1.8, 0.35, 1.1),
			position = Vector3.new(eastCx + 4.2, floorY + 2.9, 15.35),
			color = Color3.fromRGB(214, 216, 220),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = breakRoom,
		})
		detailPart({
			name = "Fridge",
			size = Vector3.new(3, 6, 3),
			position = Vector3.new(eastCx + 6, floorY + 3.5, 3),
			color = Color3.fromRGB(225, 228, 232),
			material = Enum.Material.Metal,
			parent = breakRoom,
		})
		detailPart({
			name = "VendingMachine",
			size = Vector3.new(3, 6, 2),
			position = Vector3.new(eastCx + 6, floorY + 3.5, 7),
			color = Color3.fromRGB(40, 85, 150),
			material = Enum.Material.SmoothPlastic,
			parent = breakRoom,
		})
		detailPart({
			name = "VendingGlass",
			size = Vector3.new(0.18, 4.2, 1.5),
			position = Vector3.new(eastCx + 4.4, floorY + 4.1, 7),
			color = Color3.fromRGB(120, 186, 210),
			material = Enum.Material.Glass,
			transparency = 0.35,
			canCollide = false,
			parent = breakRoom,
		})

		local breakTable = detailPart({
			name = "CafeTable",
			size = Vector3.new(4, 0.3, 3),
			position = Vector3.new(eastCx + 1.8, 3.25, 8.8),
			color = Color3.fromRGB(105, 80, 55),
			material = Enum.Material.Wood,
			parent = breakRoom,
		})
		addPrompt(breakTable, "InspectTasks", "Review", "Staff Notes", 0.1)
		for _, x in { eastCx + 0.2, eastCx + 3.4 } do
			for _, z in { 7.7, 9.9 } do
				fixtureDetail(breakRoom, `CafeTableLeg{x}_{z}`, Vector3.new(0.18, 2.05, 0.18), Vector3.new(x, 2.075, z), Color3.fromRGB(68, 76, 80), Enum.Material.Metal)
			end
		end
		for chairName, chair in {
			North = Vector3.new(eastCx + 1.8, 2.2, 5.9),
			South = Vector3.new(eastCx + 1.8, 2.2, 11.7),
		} do
			local seat = Instance.new("Seat")
			seat.Name = `BreakChair{chairName}`
			seat.Size = Vector3.new(1.6, 0.3, 1.6)
			seat.Position = chair
			seat.Orientation = Vector3.new(0, if chairName == "North" then 180 else 0, 0)
			seat.Anchored, seat.CanCollide, seat.Transparency = true, true, 0
			seat.Color, seat.Material = Color3.fromRGB(65, 111, 117), Enum.Material.SmoothPlastic
			seat.Parent = breakRoom
			local backZ = if chairName == "North" then -0.72 else 0.72
			fixtureDetail(breakRoom, `ChairBack{chairName}`, Vector3.new(1.6, 1.35, 0.16), chair + Vector3.new(0, 0.8, backZ), seat.Color)
			for _, x in { -0.6, 0.6 } do
				for _, z in { -0.6, 0.6 } do
					fixtureDetail(breakRoom, `ChairLeg{chairName}_{x}_{z}`, Vector3.new(0.14, 1, 0.14), chair + Vector3.new(x, -0.65, z), Color3.fromRGB(78, 87, 91), Enum.Material.Metal)
				end
			end
		end
		detailPart({
			name = "BreakBench",
			size = Vector3.new(5, 1.6, 1.4),
			position = Vector3.new(eastCx - 4.5, floorY + 1.3, 13.5),
			color = Color3.fromRGB(92, 78, 68),
			material = Enum.Material.Wood,
			parent = breakRoom,
		})
		for lockerIndex, z in { 0.8, 2.6, 4.4 } do
			detailPart({
				name = `StaffLocker{lockerIndex}`,
				size = Vector3.new(1.3, 4.8, 1.2),
				position = Vector3.new(eastCx - 7.4, floorY + 3.1, z),
				color = Color3.fromRGB(94, 104, 114),
				material = Enum.Material.Metal,
				parent = breakRoom,
			})
		end
	end

	local loading = store:FindFirstChild("LoadingDock")
	if loading then
		addSoftLight(26, -37, loading)
		addSoftLight(48, -37, loading)
		decorFloor("DockReceivingLane", Vector3.new(10, 0.08, 5), Vector3.new(27, walkTop + 0.08, backZ + 7), Color3.fromRGB(186, 142, 62), loading)
		decorFloor("DockShippingLane", Vector3.new(10, 0.08, 5), Vector3.new(45, walkTop + 0.08, backZ + 7), Color3.fromRGB(86, 118, 150), loading)
		decorFloor("DockForkliftPath", Vector3.new(26, 0.08, 5), Vector3.new(36, walkTop + 0.09, backZ - 1), Color3.fromRGB(82, 84, 88), loading)
		addSign(loading, "ReceivingLaneSign", 27, 6.6, -26.8, 5.4, "RECEIVING", Color3.fromRGB(88, 78, 58), 0.9)
		addSign(loading, "ShippingLaneSign", 45, 6.6, -26.8, 5.4, "SHIPPING", Color3.fromRGB(50, 76, 104), 0.9)
		local rollDoor = detailPart({
			name = "RollDoor",
			size = Vector3.new(18, 10, 0.2),
			position = Vector3.new(36, floorY + 5.5, -halfD + 1.7),
			color = Color3.fromRGB(173, 185, 190),
			material = Enum.Material.Metal,
			parent = loading,
		})
		addPrompt(rollDoor, "OpenDock", "Open", "Roll Door", 0.2)
		for panel = 1, 5 do
			detailPart({
				name = `RollDoorPanel{panel}`,
				size = Vector3.new(17.2, 0.18, 0.08),
				position = Vector3.new(36, floorY + 1.5 + panel * 1.65, -halfD + 1.55),
				color = Color3.fromRGB(126, 130, 134),
				material = Enum.Material.Metal,
				canCollide = false,
				parent = loading,
			})
		end
		detailPart({
			name = "DockSealTop",
			size = Vector3.new(21, 1.2, 1),
			position = Vector3.new(36, floorY + 11.1, -halfD + 1.2),
			color = Color3.fromRGB(36, 38, 42),
			material = Enum.Material.Rubber,
			parent = loading,
		})
		for side, x in { Left = 25.2, Right = 46.8 } do
			detailPart({
				name = `DockSeal{side}`,
				size = Vector3.new(1.1, 9.8, 1),
				position = Vector3.new(x, floorY + 5.8, -halfD + 1.2),
				color = Color3.fromRGB(36, 38, 42),
				material = Enum.Material.Rubber,
				parent = loading,
			})
		end
		local dockPlate = storePart({
			name = "DockLevelerPlate",
			size = Vector3.new(14, 0.35, 6),
			position = Vector3.new(36, floorY + 1.05, backZ - 8),
			color = Color3.fromRGB(82, 86, 92),
			material = Enum.Material.DiamondPlate,
			parent = loading,
		})
		addPrompt(dockPlate, "OpenDock", "Set leveler", "Dock Plate", 0.2)
		for stripe = -1, 1 do
			detailPart({
				name = `DockHazardStripe{stripe}`,
				size = Vector3.new(13, 0.08, 0.28),
				position = Vector3.new(36, walkTop + 0.16, backZ - 5.4 + stripe * 2.1),
				color = if stripe == 0 then Color3.fromRGB(230, 190, 56) else Color3.fromRGB(48, 50, 54),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				parent = loading,
			})
		end
		for i = -1, 1 do
			storePart({
				name = `DockBox{i}`,
				size = Vector3.new(4, 3, 4),
				position = Vector3.new(51, floorY + 2, backZ - 5 + i * 4.5),
				color = Color3.fromRGB(150, 130, 100),
				material = Enum.Material.Cardboard,
				parent = loading,
			})
		end
		for palletIndex, pallet in {
			{ name = "ReceivingPallet", x = 27, z = backZ + 7, color = Color3.fromRGB(150, 104, 72) },
			{ name = "ShippingPallet", x = 45, z = backZ + 7, color = Color3.fromRGB(104, 122, 146) },
		} do
			local dockPallet = storePart({
				name = pallet.name,
				size = Vector3.new(5, 2, 5),
				position = Vector3.new(pallet.x, floorY + 1.8, pallet.z),
				color = pallet.color,
				material = Enum.Material.Wood,
				parent = loading,
			})
			if palletIndex == 1 then
				addPrompt(dockPallet, "CollectStock", "Grab stock", "Receiving Pallet", 0.2)
			end
			for case = 1, 3 do
				detailPart({
					name = `{pallet.name}Case{case}`,
					size = Vector3.new(3.7, 1.05, 1.35),
					position = Vector3.new(pallet.x, floorY + 2.7 + case * 0.5, pallet.z - 1.8 + case * 0.9),
					color = if case == 2 then Color3.fromRGB(188, 144, 82) else Color3.fromRGB(174, 132, 86),
					material = Enum.Material.SmoothPlastic,
					parent = loading,
				})
			end
		end
		local dockControl = storePart({
			name = "DockControl",
			size = Vector3.new(0.5, 3, 2),
			position = Vector3.new(16.9, floorY + 4, backZ + 2),
			color = Color3.fromRGB(52, 58, 66),
			material = Enum.Material.Metal,
			parent = loading,
		})
		addPrompt(dockControl, "OpenDock", "Operate", "Dock Controls", 0.2)
		local scheduleBoard = storePart({
			name = "DockScheduleBoard",
			size = Vector3.new(5, 4, 0.45),
			position = Vector3.new(21.5, floorY + 6.2, -49.2),
			color = Color3.fromRGB(38, 64, 74),
			material = Enum.Material.SmoothPlastic,
			parent = loading,
		})
		addPrompt(scheduleBoard, "InspectTasks", "Review", "Dock Schedule", 0.15)
		addSign(loading, "DockScheduleSign", 21.5, floorY + 8.95, -49.2, 5, "TRUCKS", Color3.fromRGB(50, 64, 78), 1.05)
		storePart({
			name = "PalletJack",
			size = Vector3.new(5, 1, 3),
			position = Vector3.new(19.5, floorY + 1.2, backZ + 8),
			color = Color3.fromRGB(170, 130, 45),
			material = Enum.Material.Metal,
			parent = loading,
		})
		local forkliftBase = storePart({
			name = "ForkliftBase",
			size = Vector3.new(5, 2.2, 6),
			position = Vector3.new(23, floorY + 1.9, backZ - 1),
			color = Color3.fromRGB(214, 158, 38),
			material = Enum.Material.Metal,
			parent = loading,
		})
		addPrompt(forkliftBase, "OpenDock", "Stage", "Forklift", 0.2)
		storePart({
			name = "ForkliftMast",
			size = Vector3.new(0.7, 6, 3.4),
			position = Vector3.new(20, floorY + 4.2, backZ - 4),
			color = Color3.fromRGB(50, 54, 58),
			material = Enum.Material.Metal,
			parent = loading,
		})
		for fork, x in { 19, 21 } do
			detailPart({
				name = `ForkliftFork{fork}`,
				size = Vector3.new(0.45, 0.25, 5),
				position = Vector3.new(x, floorY + 1.15, backZ - 7.5),
				color = Color3.fromRGB(56, 58, 62),
				material = Enum.Material.Metal,
				parent = loading,
			})
		end
		for cone, x in { 18.5, 57 } do
			storePart({
				name = `DockSafetyCone{cone}`,
				size = Vector3.new(1.3, 2, 1.3),
				position = Vector3.new(x, floorY + 1.5, backZ + 1),
				color = Color3.fromRGB(230, 100, 42),
				material = Enum.Material.SmoothPlastic,
				parent = loading,
			})
		end
	end

	local cooler = store:FindFirstChild("WalkInCooler")
	if cooler then
		decorFloor("CoolerColdLane", Vector3.new(8, 0.08, 17), Vector3.new(0, walkTop + 0.08, backZ - 2), Color3.fromRGB(104, 146, 170), cooler)
		decorFloor("CoolerPullZone", Vector3.new(10, 0.08, 5), Vector3.new(0, walkTop + 0.09, backZ + 7), Color3.fromRGB(136, 174, 190), cooler)
		addSign(cooler, "CoolerTempSign", 0, floorY + 9.8, backZ - 10.4, 7.5, "36 F", Color3.fromRGB(42, 82, 104), 1.15)
		for i = -1, 1 do
			storePart({
				name = `CoolerShelf{i}`,
				size = Vector3.new(5, 6.5, 2),
				position = Vector3.new(i * 8, floorY + 3.75, backZ - 7),
				color = Color3.fromRGB(190, 200, 210),
				material = Enum.Material.Metal,
				parent = cooler,
			})
			for tier = 1, 4 do
				detailPart({
					name = `CoolerShelf{i}_Wire{tier}`,
					size = Vector3.new(5.4, 0.18, 2.2),
					position = Vector3.new(i * 8, floorY + 1.5 + tier * 1.45, backZ - 7),
					color = Color3.fromRGB(150, 164, 174),
					material = Enum.Material.Metal,
					parent = cooler,
				})
			end
			for productIndex, product in {
				{ y = 2.5, z = backZ - 7.4, color = Color3.fromRGB(210, 235, 245) },
				{ y = 3.95, z = backZ - 6.5, color = Color3.fromRGB(190, 220, 240) },
				{ y = 5.4, z = backZ - 7.4, color = Color3.fromRGB(230, 238, 220) },
				{ y = 6.85, z = backZ - 6.5, color = Color3.fromRGB(220, 205, 178) },
			} do
				detailPart({
					name = `CoolerProduct{i}_{productIndex}`,
					size = Vector3.new(3.8, 0.75, 1),
					position = Vector3.new(i * 8, floorY + product.y, product.z),
					color = product.color,
					material = Enum.Material.Plastic,
					parent = cooler,
				})
			end
		end
		local coolerCase = storePart({
			name = "CoolerPullCase",
			size = Vector3.new(7, 6.5, 2),
			position = Vector3.new(9.2, floorY + 3.75, backZ + 1),
			color = Color3.fromRGB(150, 180, 196),
			material = Enum.Material.Glass,
			transparency = 0.35,
			parent = cooler,
		})
		addPrompt(coolerCase, "CheckTemperature", "Check", "Cooler Pull Case", 0.2)
		for crate, x in { -10, -7, 7, 10 } do
			local cratePart = storePart({
				name = `CoolerCrate{crate}`,
				size = Vector3.new(3, 2, 3),
				position = Vector3.new(x, floorY + 1.5, backZ + 6.5),
				color = if x < 0 then Color3.fromRGB(100, 156, 190) else Color3.fromRGB(120, 172, 136),
				material = Enum.Material.Plastic,
				parent = cooler,
			})
			if x == -10 then
				addPrompt(cratePart, "CheckTemperature", "Inspect", "Cold Crate", 0.2)
			end
		end
		local tempPanel = detailPart({
			name = "CoolerThermostat",
			size = Vector3.new(0.35, 2.8, 2.1),
			position = Vector3.new(15.2 + wingOffset, floorY + 5, backZ + 3.5),
			color = Color3.fromRGB(35, 50, 62),
			material = Enum.Material.SmoothPlastic,
			parent = cooler,
		})
		addPrompt(tempPanel, "CheckTemperature", "Check", "Thermostat", 0.2)
		detailPart({
			name = "ThermostatScreen",
			size = Vector3.new(0.12, 0.75, 1.4),
			position = Vector3.new(14.95 + wingOffset, floorY + 5.35, backZ + 3.5),
			color = Color3.fromRGB(115, 210, 235),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = cooler,
		})
		for strip = -3, 3 do
			detailPart({
				name = `CoolerDoorStrip{strip}`,
				size = Vector3.new(0.75, 6, 0.12),
				position = Vector3.new(strip * 0.85, floorY + 4.3, backZ + 10.65),
				color = Color3.fromRGB(170, 220, 238),
				material = Enum.Material.Glass,
				transparency = 0.45,
				canCollide = false,
				parent = cooler,
			})
		end
		storePart({
			name = "CoolerFloorDrain",
			size = Vector3.new(2, 0.12, 2),
			position = Vector3.new(10, walkTop + 0.15, backZ - 1),
			color = Color3.fromRGB(62, 72, 78),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = cooler,
		})
		storePart({
			name = "CoolerLight",
			size = Vector3.new(20, 0.3, 1),
			position = Vector3.new(0, floorY + 10.8, backZ + 2),
			color = Color3.fromRGB(185, 220, 255),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = cooler,
		})
		for light = -1, 1 do
			detailPart({
				name = `CoolerMistLine{light}`,
				size = Vector3.new(0.2, 0.2, 16),
				position = Vector3.new(light * 6, floorY + 9.6, backZ - 1),
				color = Color3.fromRGB(210, 238, 248),
				material = Enum.Material.Neon,
				transparency = 0.25,
				canCollide = false,
				parent = cooler,
			})
		end
	end

	-- ========== INTERIOR PROPS ==========
	local interiorProps = Instance.new("Model")
	interiorProps.Name = "InteriorProps"
	interiorProps.Parent = store

	storePart({
		name = "MagazineRack",
		size = Vector3.new(4, 4, 1.5),
		position = Vector3.new(14, floorY + 2.5, halfD - 18),
		color = Color3.fromRGB(90, 90, 95),
		material = Enum.Material.Metal,
		parent = interiorProps,
	})
	storePart({
		name = "WaterFountain",
		size = Vector3.new(2, 4, 2),
		position = Vector3.new(-14, floorY + 2.5, halfD - 18),
		color = Color3.fromRGB(200, 205, 210),
		material = Enum.Material.Metal,
		parent = interiorProps,
	})
	local wetFloorSign = storePart({
		name = "WetFloorSign",
		size = Vector3.new(2, 2.5, 0.3),
		position = Vector3.new(-8, floorY + 1.8, -6),
		color = Color3.fromRGB(220, 180, 40),
		material = Enum.Material.Plastic,
		canCollide = false,
		parent = interiorProps,
	})
	addPrompt(wetFloorSign, "CleanSpill", "Clean", "Spill Sign", 0.25)
	local spill = decorFloor(
		"FloorSpill",
		Vector3.new(5, 0.05, 4),
		Vector3.new(-5, floorY + 0.72, -6),
		Color3.fromRGB(105, 150, 190),
		interiorProps
	)
	spill.Transparency = 0.45
	addPrompt(spill, "CleanSpill", "Mop", "Floor Spill", 0.3)

	for i, x in { 16, 36 } do
		storePart({
			name = `BagHolder{i}`,
			size = Vector3.new(3, 4, 1.5),
			position = Vector3.new(x, floorY + 2.5, 24),
			color = Color3.fromRGB(70, 120, 70),
			material = Enum.Material.Plastic,
			parent = interiorProps,
		})
	end

	for i = -1, 1 do
		storePart({
			name = `BasketStack{i}`,
			size = Vector3.new(3, 2, 3),
			position = Vector3.new(-28 + i * 6, floorY + 1.5, 46),
			color = Color3.fromRGB(200, 160, 50),
			material = Enum.Material.Plastic,
			parent = interiorProps,
		})
	end

	for _, fx in { -40, 40 } do
		storePart({
			name = `FireExt_{fx}`,
			size = Vector3.new(0.8, 2.5, 0.8),
			position = Vector3.new(fx, floorY + 2, 0),
			color = Color3.fromRGB(180, 40, 40),
			material = Enum.Material.Metal,
			parent = interiorProps,
		})
	end

	-- ========== OUTDOOR ENVIRONMENT ==========
	local outdoor = Instance.new("Model")
	outdoor.Name = "Outdoor"
	outdoor.Parent = store

	local parking = Instance.new("Model")
	parking.Name = "ParkingLot"
	parking.Parent = outdoor

	local asphaltTop = walkTop - 0.08
	local sidewalkTop = walkTop + 0.06
	local paintTop = asphaltTop + 0.015
	local grassTop = asphaltTop - 0.03

	local landscaping = Instance.new("Model")
	landscaping.Name = "Landscaping"
	landscaping.Parent = outdoor

	surfaceFloor(
		"GrassField",
		Vector3.new(400, 1, 320),
		Vector3.new(0, floorY, 20),
		Color3.fromRGB(70, 126, 62),
		Enum.Material.Grass,
		landscaping,
		grassTop
	)

	local function curbPart(name: string, size: Vector3, position: Vector3, parentModel: Instance?)
		return storePart({
			name = name,
			size = size,
			position = position,
			color = Color3.fromRGB(146, 146, 142),
			material = Enum.Material.Concrete,
			canCollide = false,
			parent = parentModel or landscaping,
		})
	end

	local function curbRect(name: string, cx: number, cz: number, w: number, d: number, parentModel: Instance?)
		local y = sidewalkTop + 0.18
		curbPart(`{name}_North`, Vector3.new(w, 0.35, 0.6), Vector3.new(cx, y, cz - d / 2), parentModel)
		curbPart(`{name}_South`, Vector3.new(w, 0.35, 0.6), Vector3.new(cx, y, cz + d / 2), parentModel)
		curbPart(`{name}_West`, Vector3.new(0.6, 0.35, d), Vector3.new(cx - w / 2, y, cz), parentModel)
		curbPart(`{name}_East`, Vector3.new(0.6, 0.35, d), Vector3.new(cx + w / 2, y, cz), parentModel)
	end

	local function parkingIsland(name: string, cx: number, cz: number, w: number, d: number)
		local island = Instance.new("Model")
		island.Name = name
		island.Parent = landscaping

		surfaceFloor(
			"Grass",
			Vector3.new(w - 1.4, 1, d - 1.4),
			Vector3.new(cx, floorY, cz),
			Color3.fromRGB(72, 130, 64),
			Enum.Material.Grass,
			island,
			sidewalkTop + 0.02
		)
		curbRect("Curb", cx, cz, w, d, island)

		for offset = -1, 1, 2 do
			storePart({
				name = `Shrub{offset}`,
				size = Vector3.new(4, 2.2, 4),
				position = Vector3.new(cx, floorY + 1.7, cz + offset * (d / 4)),
				color = Color3.fromRGB(52, 108, 48),
				material = Enum.Material.Grass,
				parent = island,
			})
		end
	end

	-- Expanded parking field: entry drive, two rows of stalls, perimeter roads.
	surfaceFloor(
		"Asphalt",
		Vector3.new(W + 80, 1, 76),
		Vector3.new(0, floorY, halfD + 38),
		Color3.fromRGB(48, 50, 54),
		Enum.Material.Asphalt,
		parking,
		asphaltTop
	)

	local function stripe(name: string, size: Vector3, position: Vector3, color: Color3, parentModel: Instance?, layer: number?)
		local paintSize = Vector3.new(size.X, math.min(size.Y, 0.035), size.Z)
		detailPart({
			name = name,
			size = paintSize,
			position = Vector3.new(position.X, paintTop + paintSize.Y / 2 + (layer or 0), position.Z),
			color = color,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = parentModel or parking,
		})
	end

	local parkingBays = {}
	for _, row in {
		{ name = "Near", z = halfD + 18, xs = { -72, -56, -40, 40, 56, 72 } },
		{ name = "Far", z = halfD + 56, xs = { -72, -56, -40, -24, 24, 40, 56, 72 } },
	} do
		for _, x in row.xs do
			table.insert(parkingBays, { x = x, z = row.z })
			for _, side in { -1, 1 } do
				stripe(`ParkingLine_{row.name}_{x}_{side}`, Vector3.new(0.22, 0.06, 16), Vector3.new(x + side * 6, floorY + 0.62, row.z), Color3.fromRGB(220, 220, 215), parking)
			end
			local closedEnd = if row.name == "Near" then -8 else 8
			stripe(`ParkingBackLine_{row.name}_{x}`, Vector3.new(12, 0.06, 0.22), Vector3.new(x, floorY + 0.62, row.z + closedEnd), Color3.fromRGB(220, 220, 215), parking)
		end
	end

	-- Reserved bays sit nearest the entrance; each has a separate six-stud access aisle.
	for i, side in { -1, 1 } do
		local x, aisleX, z = side * 21, side * 12, halfD + 18
		local pad = detailPart({ name = `AccessibleSpace{i}`, size = Vector3.new(12, 0.035, 16),
			position = Vector3.new(x, paintTop + 0.0175, z), color = Color3.fromRGB(39, 100, 174), canCollide = false, parent = parking })
		pad:SetAttribute("ReservedParking", true)
		local symbol = Instance.new("SurfaceGui")
		symbol.Face = Enum.NormalId.Top
		symbol.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		symbol.PixelsPerStud = 48
		symbol.LightInfluence = 0.2
		symbol.Parent = pad
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = utf8.char(0x267F)
		label.Font = Enum.Font.SourceSansBold
		label.TextSize = 240
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Parent = symbol
		local aisle = detailPart({ name = `AccessibleAisle{i}`, size = Vector3.new(6, 0.035, 17),
			position = Vector3.new(aisleX, paintTop + 0.0175, z - 0.5), color = Color3.fromRGB(61, 66, 71), canCollide = false, parent = parking })
		aisle:SetAttribute("AccessAisle", true)
		for _, edge in { -1, 1 } do
			stripe(`AccessBorder{i}_{edge}`, Vector3.new(0.2, 0.035, 17), Vector3.new(aisleX + edge * 2.85, 0, z - 0.5), Color3.fromRGB(244, 244, 236), parking, 0.045)
		end
		for hatch = 0, 6 do
			local bar = detailPart({ name = `AccessHatch{i}_{hatch}`, size = Vector3.new(5.8, 0.035, 0.18),
				position = Vector3.new(aisleX, paintTop + 0.0625, 61.5 + hatch * 2), color = Color3.fromRGB(244, 244, 236), canCollide = false, parent = parking })
			bar.Orientation = Vector3.new(0, 25, 0)
		end
		fixtureDetail(parking, `AccessibleWheelStop{i}`, Vector3.new(8, 0.4, 0.65), Vector3.new(x, asphaltTop + 0.2, 60.6), Color3.fromRGB(195, 199, 202), Enum.Material.Concrete)
		fixtureDetail(parking, `AccessibleSignPost{i}`, Vector3.new(0.18, 5, 0.18), Vector3.new(x, asphaltTop + 2.5, 60), Color3.fromRGB(131, 143, 152), Enum.Material.Metal)
		addSign(parking, `AccessibleSign{i}`, x, asphaltTop + 5.3, 60, 3.2, "RESERVED", Color3.fromRGB(39, 100, 174), 1.2)
	end

	for i = 0, 1 do
		local cartX, cartZ = -40, 54.5 + i * 1.4
		local cart = detailPart({
			name = `NestedCart{i}`,
			size = Vector3.new(3.2, 2.5, 3.6),
			position = Vector3.new(cartX, 2.6, cartZ),
			color = Color3.fromRGB(126, 132, 138),
			material = Enum.Material.Metal,
			transparency = 1,
			parent = outdoor,
		})
		if i == 0 then
			addPrompt(cart, "ReturnCart", "Return", "Shopping Cart", 0.2)
		end
		fixtureDetail(outdoor, `CartHandle{i}`, Vector3.new(3.2, 0.22, 0.22), Vector3.new(cartX, 3.8, cartZ + 1.8), Color3.fromRGB(42, 108, 87))
		fixtureDetail(outdoor, `CartBasketFloor{i}`, Vector3.new(3, 0.12, 3.2), Vector3.new(cartX, 2.15, cartZ), Color3.fromRGB(162, 174, 181), Enum.Material.Metal)
		for _, side in { -1, 1 } do
			for level = 0, 3 do
				fixtureDetail(outdoor, `CartRail{i}_{side}_{level}`, Vector3.new(0.08, 0.08, 3.3), Vector3.new(cartX + side * 1.5, 2.25 + level * 0.42, cartZ), Color3.fromRGB(172, 180, 186), Enum.Material.Metal)
				fixtureDetail(outdoor, `CartCrossRail{i}_{side}_{level}`, Vector3.new(3, 0.08, 0.08), Vector3.new(cartX, 2.25 + level * 0.42, cartZ + side * 1.65), Color3.fromRGB(172, 180, 186), Enum.Material.Metal)
			end
			for _, endZ in { -1.4, 1.4 } do
				fixtureDetail(outdoor, `CartLeg{i}_{side}_{endZ}`, Vector3.new(0.12, 2.1, 0.12), Vector3.new(cartX + side * 1.4, 2.45, cartZ + endZ), Color3.fromRGB(115, 126, 134), Enum.Material.Metal)
				local wheel = fixtureDetail(outdoor, `CartWheel{i}_{side}_{endZ}`, Vector3.new(0.18, 0.5, 0.5), Vector3.new(cartX + side * 1.4, 1.3, cartZ + endZ), Color3.fromRGB(47, 51, 54), Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
			end
		end
	end

	-- Entrance bollards (protect storefront, not blocking door)
	for _, bx in { -12, 12 } do
		storePart({
			name = `Bollard{bx}`,
			size = Vector3.new(1.2, 3.5, 1.2),
			position = Vector3.new(bx, floorY + 2.25, halfD + 5),
			color = Color3.fromRGB(220, 180, 50),
			material = Enum.Material.Metal,
			parent = outdoor,
		})
	end

	local trashCan = detailPart({
		name = "TrashCan",
		size = Vector3.new(2, 3.5, 2),
		position = Vector3.new(22, floorY + 2.25, halfD + 5),
		color = Color3.fromRGB(45, 48, 52),
		material = Enum.Material.Metal,
		parent = outdoor,
	})
	fixtureDetail(outdoor, "TrashLid", Vector3.new(2.2, 0.18, 2.2), Vector3.new(22, 4.59, 55), Color3.fromRGB(100, 111, 116), Enum.Material.Metal)
	fixtureDetail(outdoor, "TrashOpening", Vector3.new(1.3, 0.52, 0.05), Vector3.new(22, 4.13, 56.03), Color3.fromRGB(13, 17, 21))
	for slat = -2, 2 do
		fixtureDetail(outdoor, `TrashSlat{slat}`, Vector3.new(0.08, 2.5, 0.05), Vector3.new(22 + slat * 0.35, 2.63, 56.03), Color3.fromRGB(96, 107, 111), Enum.Material.Metal)
	end
	addPrompt(trashCan, "TakeTrash", "Empty", "Trash Can", 0.25)
	detailPart({
		name = "Bench",
		size = Vector3.new(6, 0.25, 2),
		position = Vector3.new(-22, 2.45, 54.5),
		color = Color3.fromRGB(100, 75, 50),
		material = Enum.Material.Wood,
		transparency = 1,
		parent = outdoor,
	})
	for slat = 0, 3 do
		fixtureDetail(outdoor, `BenchSeatSlat{slat}`, Vector3.new(6, 0.22, 0.42), Vector3.new(-22, 2.45, 53.78 + slat * 0.48), Color3.fromRGB(160, 116, 75), Enum.Material.Wood)
	end
	for _, x in { -24.3, -19.7 } do
		for _, z in { 53.7, 55.2 } do
			fixtureDetail(outdoor, `BenchLeg{x}_{z}`, Vector3.new(0.25, 1.35, 0.25), Vector3.new(x, 1.675, z), Color3.fromRGB(58, 65, 69), Enum.Material.Metal)
		end
		fixtureDetail(outdoor, `BenchBackSupport{x}`, Vector3.new(0.22, 1.7, 0.22), Vector3.new(x, 3.2, 53.5), Color3.fromRGB(58, 65, 69), Enum.Material.Metal)
	end
	for row = 0, 2 do
		fixtureDetail(outdoor, `BenchBackSlat{row}`, Vector3.new(6, 0.3, 0.18), Vector3.new(-22, 2.9 + row * 0.4, 53.42), Color3.fromRGB(160, 116, 75), Enum.Material.Wood)
	end

	-- Sidewalks frame the store and connect the parking lot to the front door.
	for _, side in { -1, 1 } do
		surfaceFloor(`FrontSidewalk{side}`, Vector3.new(66 + wingOffset, 1, 9), Vector3.new(side * (43 + wingOffset / 2), floorY, 54.5), Color3.fromRGB(195, 193, 188), Enum.Material.Concrete, outdoor, sidewalkTop)
		surfaceFloor(`Sidewalk{side}`, Vector3.new(12, 1, 100), Vector3.new(side * (halfW + 10), floorY, 0), Color3.fromRGB(195, 193, 188), Enum.Material.Concrete, outdoor, sidewalkTop)
		surfaceFloor(`LotWalk{side}`, Vector3.new(12, 1, 59), Vector3.new(side * (halfW + 10), floorY, 88.5), Color3.fromRGB(195, 193, 188), Enum.Material.Concrete, outdoor, sidewalkTop)
	end
	surfaceFloor("EntryWalk", Vector3.new(18, 1, 23), Vector3.new(0, floorY, 70.5), Color3.fromRGB(205, 203, 198), Enum.Material.Concrete, outdoor, sidewalkTop)

	parkingIsland("IslandWest", -halfW - 26, halfD + 42, 12, 36)
	parkingIsland("IslandEast", halfW + 26, halfD + 42, 12, 36)

	surfaceFloor(
		"DrivewayApron",
		Vector3.new(28, 1, 10),
		Vector3.new(0, floorY, halfD + 78),
		Color3.fromRGB(52, 54, 58),
		Enum.Material.Asphalt,
		outdoor,
		asphaltTop + 0.005
	)

	for _, curb in {
		{ name = "LotCurbFrontWest", size = Vector3.new(79 + wingOffset, 0.35, 0.55), position = Vector3.new(-53.5 - wingOffset / 2, sidewalkTop + 0.18, halfD + 77) },
		{ name = "LotCurbFrontEast", size = Vector3.new(79 + wingOffset, 0.35, 0.55), position = Vector3.new(53.5 + wingOffset / 2, sidewalkTop + 0.18, halfD + 77) },
		{ name = "LotCurbWest", size = Vector3.new(0.55, 0.35, 75), position = Vector3.new(-halfW - 40, sidewalkTop + 0.18, halfD + 38) },
		{ name = "LotCurbEast", size = Vector3.new(0.55, 0.35, 75), position = Vector3.new(halfW + 40, sidewalkTop + 0.18, halfD + 38) },
		{ name = "RoadCurbNorthWest", size = Vector3.new(74 + wingOffset, 0.35, 0.55), position = Vector3.new(-51 - wingOffset / 2, sidewalkTop + 0.18, halfD + 78) },
		{ name = "RoadCurbNorthEast", size = Vector3.new(74 + wingOffset, 0.35, 0.55), position = Vector3.new(51 + wingOffset / 2, sidewalkTop + 0.18, halfD + 78) },
		{ name = "RoadCurbSouth", size = Vector3.new(W + 56, 0.35, 0.55), position = Vector3.new(0, sidewalkTop + 0.18, halfD + 98) },
	} do
		curbPart(curb.name, curb.size, curb.position, landscaping)
	end

	local entranceSign = storePart({
		name = "ParkingEntranceSign",
		size = Vector3.new(10, 5, 0.5),
		position = Vector3.new(-halfW - 18, floorY + 5.2, halfD + 74),
		color = Color3.fromRGB(24, 80, 145),
		material = Enum.Material.SmoothPlastic,
		parent = landscaping,
	})
	addPrompt(entranceSign, "InspectSign", "Read", "Parking Sign", 0.05)
	local signPost = storePart({
		name = "ParkingEntranceSignPost",
		size = Vector3.new(0.6, 7, 0.6),
		position = Vector3.new(-halfW - 18, floorY + 3.5, halfD + 74),
		color = Color3.fromRGB(80, 82, 86),
		material = Enum.Material.Metal,
		parent = landscaping,
	})
	signPost.CastShadow = false

	addSign(landscaping, "LotWayfinding", halfW + 18, floorY + 5.5, halfD + 74, 8, "PARKING", Color3.fromRGB(24, 80, 145))

	local pickup = Instance.new("Model")
	pickup.Name = "CurbsidePickup"
	pickup.Parent = outdoor
	local pickupX = halfW + 28
	local pickupZ = halfD + 16
	stripe("PickupPadPaint", Vector3.new(24, 0.06, 14), Vector3.new(pickupX, floorY, pickupZ), Color3.fromRGB(62, 80, 92), pickup)
	for i = 0, 2 do
		stripe(`PickupLine{i}`, Vector3.new(0.35, 0.06, 12), Vector3.new(pickupX - 12 + i * 12, floorY, pickupZ), Color3.fromRGB(245, 245, 240), pickup)
	end
	for i = 0, 1 do
		local pickupPost = storePart({
			name = `PickupPost{i}`,
			size = Vector3.new(0.8, 6, 0.8),
			position = Vector3.new(pickupX - 6 + i * 12, floorY + 3.5, pickupZ - 7),
			color = Color3.fromRGB(50, 58, 66),
			material = Enum.Material.Metal,
			parent = pickup,
		})
		local pickupSign = storePart({
			name = `PickupSign{i}`,
			size = Vector3.new(5.8, 2.2, 0.5),
			position = Vector3.new(pickupX - 6 + i * 12, floorY + 6.7, pickupZ - 7),
			color = Color3.fromRGB(20, 105, 155),
			material = Enum.Material.SmoothPlastic,
			parent = pickup,
		})
		addPrompt(pickupSign, "PickupOrder", "Load", "Pickup Order", 0.25)
		pickupPost.CastShadow = false
	end

	-- Front road and side service drives.
	surfaceFloor("FrontRoad", Vector3.new(W + 56, 1, 18), Vector3.new(0, floorY, halfD + 88), Color3.fromRGB(55, 58, 62), Enum.Material.Asphalt, outdoor, asphaltTop)
	surfaceFloor("WestDrive", Vector3.new(18, 1, 32), Vector3.new(-halfW - 26, floorY, halfD - 16), Color3.fromRGB(55, 58, 62), Enum.Material.Asphalt, outdoor, asphaltTop)
	surfaceFloor("EastDrive", Vector3.new(18, 1, 32), Vector3.new(halfW + 26, floorY, halfD - 16), Color3.fromRGB(55, 58, 62), Enum.Material.Asphalt, outdoor, asphaltTop)
	stripe("RoadLine", Vector3.new(W + 30, 0.06, 0.4), Vector3.new(0, floorY, halfD + 88), Color3.fromRGB(230, 200, 60), outdoor)

	for i = -3, 3 do
		stripe(`CrosswalkStripe{i}`, Vector3.new(8, 0.06, 1.1), Vector3.new(0, floorY, halfD + 76 + i * 2), Color3.fromRGB(235, 235, 230), outdoor)
	end

	for _, stop in {
		{ name = "StopLineWest", x = -20 },
		{ name = "StopLineEast", x = 20 },
	} do
		stripe(stop.name, Vector3.new(10, 0.06, 0.8), Vector3.new(stop.x, floorY, halfD + 76), Color3.fromRGB(235, 235, 230), outdoor)
	end

	local traffic = Instance.new("Model")
	traffic.Name = "NpcTraffic"
	traffic.Parent = outdoor

	local function trafficMarker(name: string, x: number, z: number, markerKind: string?)
		local marker = storePart({
			name = name,
			size = Vector3.new(1, 1, 1),
			position = Vector3.new(x, walkTop, z),
			color = Color3.fromRGB(255, 0, 255),
			transparency = 1,
			canCollide = false,
			parent = traffic,
		})
		if markerKind then
			marker:SetAttribute("TrafficMarkerKind", markerKind)
		end
		return marker
	end

	trafficMarker("RoadSpawn", -halfW - 26, halfD + 88, "CarPath")
	trafficMarker("RoadApproach", -24, halfD + 88, "CarPath")
	trafficMarker("DriveEntry", 0, halfD + 78, "CarPath")
	trafficMarker("DriveCenter", 0, halfD + 38, "CarPath")
	trafficMarker("StoreEntryOutside", -4, halfD + 8, "CustomerPath")
	trafficMarker("StoreEntryInside", -4, halfD - 8, "CustomerPath")
	trafficMarker("AisleHub", 0, 12, "CustomerPath")
	trafficMarker("ShopProduce", -50, -6, "Shop")
	trafficMarker("ShopDairy", 0, -6, "Shop")
	trafficMarker("ShopFrozen", 50, -6, "Shop")
	trafficMarker("ShopPantry", 0, 14, "Shop")
	trafficMarker("ShopHousehold", 50, 24, "Shop")
	trafficMarker("ShopBakery", -50 - wingOffset, 16, "Shop")
	trafficMarker("NpcRegisterQueue", 50, halfD - 15, "Register")
	trafficMarker("NpcRegisterSpot", 50, halfD - 18, "Register")
	for index = 1, 4 do
		trafficMarker(`NpcQueueSlot{index}`, 50 - (index - 1) * 4, 38, "Queue")
	end
	trafficMarker("CashierSpot", 50, halfD - 28, "Staff")
	trafficMarker("RoadExit", halfW + 26, halfD + 88, "CarPath")

	for index, spotDef in parkingBays do
		local spot = trafficMarker(`ParkingSpot{index}`, spotDef.x, spotDef.z, "Parking")
		spot:SetAttribute("ParkingIndex", index)
		spot:SetAttribute("BayWidth", 12)
		spot:SetAttribute("BayDepth", 16)
	end

	-- Keep lighting on the islands, not in the driveway or walking routes.
	for i, lamp in { { x = -86, z = 84 }, { x = -86, z = 104 }, { x = 86, z = 84 }, { x = 86, z = 104 } } do
		local lx = lamp.x + math.sign(lamp.x) * wingOffset
		storePart({
			name = `LampPost{i}`,
			size = Vector3.new(1.2, 12, 1.2),
			position = Vector3.new(lx, floorY + 6.5, lamp.z),
			color = Color3.fromRGB(50, 50, 55),
			material = Enum.Material.Metal,
			parent = outdoor,
		})
		storePart({
			name = `LampHead{i}`,
			size = Vector3.new(2.5, 1, 2.5),
			position = Vector3.new(lx, floorY + 12.5, lamp.z),
			color = Color3.fromRGB(230, 228, 210),
			material = Enum.Material.SmoothPlastic,
			parent = outdoor,
		})
	end

	-- Landscaping (sides only — clear door)
	for _, spot in {
		{ name = "ShrubL", x = -halfW - 2.25, z = halfD - 8 },
		{ name = "ShrubR", x = halfW + 2.25, z = halfD - 8 },
		{ name = "FlowerBedL", x = -halfW - 22, z = halfD + 2 },
		{ name = "FlowerBedR", x = halfW + 22, z = halfD + 2 },
		{ name = "TreeL", x = -halfW - 42, z = halfD + 8 },
		{ name = "TreeR", x = halfW + 42, z = halfD + 8 },
		{ name = "TreeFrontL", x = -halfW - 4, z = halfD + 76 },
		{ name = "TreeFrontR", x = halfW + 4, z = halfD + 76 },
	} do
		if spot.name:find("Tree") then
			storePart({
				name = spot.name,
				size = Vector3.new(5, 12, 5),
				position = Vector3.new(spot.x, floorY + 6.5, spot.z),
				color = Color3.fromRGB(50, 100, 48),
				material = Enum.Material.Grass,
				parent = outdoor,
			})
		else
			storePart({
				name = spot.name,
				size = if spot.name:find("FlowerBed") then Vector3.new(8, 1.2, 8) else Vector3.new(2.5, 2.5, 5),
				position = Vector3.new(spot.x, if spot.name:find("FlowerBed") then floorY + 1.15 else floorY + 1.8, spot.z),
				color = if spot.name:find("FlowerBed") then Color3.fromRGB(150, 72, 90) else Color3.fromRGB(55, 105, 50),
				material = if spot.name:find("FlowerBed") then Enum.Material.LeafyGrass else Enum.Material.Grass,
				parent = outdoor,
			})
		end
	end

	-- Back-of-store exterior (loading area)
	local serviceYard = Instance.new("Model")
	serviceYard.Name = "ServiceYard"
	serviceYard.Parent = outdoor

	surfaceFloor("LoadingApron", Vector3.new(64, 1, 24), Vector3.new(36, floorY, -halfD - 15), Color3.fromRGB(58, 60, 64), Enum.Material.Asphalt, serviceYard, asphaltTop)
	storePart({
		name = "Dumpster",
		size = Vector3.new(8, 5, 5),
		position = Vector3.new(18, floorY + 3, -halfD - 12),
		color = Color3.fromRGB(45, 75, 45),
		material = Enum.Material.Metal,
		parent = serviceYard,
	})
	for i = -1, 1 do
		storePart({
			name = `DockBumper{i}`,
			size = Vector3.new(2, 2, 1),
			position = Vector3.new(36 + i * 8, floorY + 1.5, -halfD - 1),
			color = Color3.fromRGB(40, 40, 40),
			material = Enum.Material.Rubber,
			parent = serviceYard,
		})
	end
	local loadingPallet = storePart({
		name = "LoadingPallet",
		size = Vector3.new(6, 4, 6),
		position = Vector3.new(48, floorY + 2.5, -halfD - 12),
		color = Color3.fromRGB(125, 95, 68),
		material = Enum.Material.Wood,
		parent = serviceYard,
	})
	addPrompt(loadingPallet, "CollectStock", "Grab stock", "Loading Pallet", 0.2)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StoreSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(-10, walkTop, halfD + 6)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.BrickColor = BrickColor.new("Dark green")
	spawn.Parent = parking

	addSign(store, "WelcomeSign", 0, floorY + 9, halfD - 3, 26, "RETAIL STORE", Color3.fromRGB(22, 85, 145))
	addSign(store, "VersionSign", 0, floorY + 9.65, halfD - 5, 4.8, `v{BLUEPRINT_VERSION} test`, Color3.fromRGB(75, 75, 80), 0.85)

	-- Translate whole fixture groups, never scale their furniture or product dimensions.
	local function relocate(group: Instance, offsetX: number)
		local offset = Vector3.new(offsetX, 0, 0)
		local items = group:GetDescendants()
		table.insert(items, group)
		for _, item in items do
			if item:IsA("BasePart") then item.Position += offset end
			for _, key in { "RoomCenter", "DoorClosedPosition", "DoorOpenPosition" } do
				local position = item:GetAttribute(key)
				if position then item:SetAttribute(key, position + offset) end
			end
		end
	end
	for _, roomName in { "StockRoom", "Pharmacy", "Bakery" } do relocate(store:FindFirstChild(roomName), -wingOffset) end
	for _, roomName in { "LoadingDock", "Restrooms", "BreakRoom", "AdminNook" } do relocate(store:FindFirstChild(roomName), wingOffset) end
	relocate(serviceYard, wingOffset)
	relocate(petKiosk, -12)
	relocate(teamStation, -12)
	relocate(endcaps, -12)
	for _, fixture in frontEnd:GetChildren() do
		if fixture:IsA("BasePart") then relocate(fixture, -wingOffset) end
	end
	for _, lane in checkout:GetChildren() do
		relocate(lane, if lane:GetAttribute("RegisterKind") == "Player" then 8 else 12)
	end
	for _, item in interiorProps:GetChildren() do
		if item.Name:match("^BasketStack") or item.Name == "WaterFountain" then relocate(item, -12)
		elseif item.Name == "BagHolder1" or item.Name == "MagazineRack" then relocate(item, 8)
		elseif item.Name == "BagHolder2" then relocate(item, 12)
		elseif item.Name:match("^FireExt_") then relocate(item, math.sign(item.Position.X) * (wingOffset + 1.05)) end
	end
	for _, sign in aisleSigns:GetChildren() do sign.Position = Vector3.new(sign.Position.X * 1.5, sign.Position.Y, sign.Position.Z) end
	for _, zoneName in { "ProduceMarker", "FrozenMarker" } do
		local zone = store:FindFirstChild(zoneName)
		zone.Position = Vector3.new(math.sign(zone.Position.X) * 42, zone.Position.Y, zone.Position.Z)
	end

	local lighting = game:GetService("Lighting")
	lighting.Brightness = 2
	lighting.Ambient = Color3.fromRGB(58, 58, 62)
	lighting.OutdoorAmbient = Color3.fromRGB(72, 74, 78)
	lighting.EnvironmentDiffuseScale = 0.45
	lighting.EnvironmentSpecularScale = 0.25

	store.PrimaryPart = floor
	if existing then
		existing:Destroy()
	end
	store.Parent = parent
	return store
end

return RetailStoreBlueprint
