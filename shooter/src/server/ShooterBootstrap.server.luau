local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Shooter] Rojo server code connected. Existing Workspace arena preserved.")

local shared = ReplicatedStorage:WaitForChild("ShooterShared")

-- Stop the broken legacy touch handlers before they can spam errors. The
-- replacement pair is connected by the world service below.
for _, portalName in { "p1", "p2" } do
	local portal = workspace:FindFirstChild(portalName)
	if portal then
		for _, descendant in portal:GetDescendants() do
			if descendant:IsA("BaseScript") then
				descendant:Destroy()
			end
		end
	end
end

if workspace:GetAttribute("ShooterInspectOnPlay") == true then
	local inspector = require(shared:WaitForChild("StudioInspector"))

	task.defer(function()
		local ok, result = pcall(inspector.run)
		if ok then
			print(`[Shooter] Existing place snapshot complete: {result.itemCount} instances.`)
		else
			warn(`[Shooter] Existing place snapshot failed: {tostring(result)}`)
		end
	end)
end

do
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("ShooterShared")
local ArenaExpansion = require(shared:WaitForChild("ArenaExpansion"))

local TELEPORT_COOLDOWN = 1.5
local characterCooldowns: { [Model]: number } = {}

local function disableLegacyPortalScripts(container: Instance?)
	if not container then
		return
	end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
end

local function findCharacter(hit: BasePart): (Model?, Humanoid?, BasePart?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function flash(part: BasePart)
	local light = part:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = 18
		light.Brightness = 0
		light.Parent = part
	end
	light.Brightness = 5
	task.delay(0.18, function()
		if light.Parent then
			light.Brightness = 1.2
		end
	end)
end

local function teleportCharacter(character: Model, root: BasePart, destination: BasePart)
	local now = os.clock()
	if (characterCooldowns[character] or 0) > now then
		return
	end
	characterCooldowns[character] = now + TELEPORT_COOLDOWN

	local currentPivot = character:GetPivot()
	local rotation = currentPivot - currentPivot.Position
	local verticalOffset = destination.Size.Y / 2 + 4
	character:PivotTo(CFrame.new(destination.Position + Vector3.new(0, verticalOffset, 0)) * rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	flash(destination)
end

local function connectPair(first: BasePart, second: BasePart, label: string)
	first.CanTouch = true
	second.CanTouch = true
	first:SetAttribute("ShooterTeleporterPair", label)
	second:SetAttribute("ShooterTeleporterPair", label)

	first.Touched:Connect(function(hit)
		local character, _, root = findCharacter(hit)
		if character and root then
			flash(first)
			teleportCharacter(character, root, second)
		end
	end)

	second.Touched:Connect(function(hit)
		local character, _, root = findCharacter(hit)
		if character and root then
			flash(second)
			teleportCharacter(character, root, first)
		end
	end)

	print(`[Shooter] Teleporter pair ready: {label} ({first:GetFullName()} <-> {second:GetFullName()})`)
end

local function choosePad(container: Instance): BasePart?
	if container:IsA("BasePart") then
		return container
	end

	local best: BasePart? = nil
	local bestScore = -math.huge
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			local lowerName = string.lower(descendant.Name)
			local score = descendant.Size.X * descendant.Size.Z
			if string.find(lowerName, "pad") or string.find(lowerName, "tele") or string.find(lowerName, "portal") then
				score += 10000
			end
			if descendant.CanTouch then
				score += 100
			end
			if descendant.Transparency >= 1 then
				score -= 25
			end
			if score > bestScore then
				best = descendant
				bestScore = score
			end
		end
	end
	return best
end

local function repairSimplePair()
	local p1 = workspace:FindFirstChild("p1")
	local p2 = workspace:FindFirstChild("p2")
	if not p1 or not p1:IsA("BasePart") or not p2 or not p2:IsA("BasePart") then
		warn("[Shooter] Legacy p1/p2 teleporter pair was not found.")
		return
	end

	disableLegacyPortalScripts(p1)
	disableLegacyPortalScripts(p2)
	connectPair(p1, p2, "Legacy-p1-p2")
end

local function repairTeleporterModels()
	local folder = workspace:FindFirstChild("Teleporters")
	if not folder then
		return
	end

	local groups = {}
	for _, child in folder:GetChildren() do
		local pad = choosePad(child)
		if pad then
			table.insert(groups, { container = child, pad = pad })
		end
	end
	table.sort(groups, function(a, b)
		return a.container.Name < b.container.Name
	end)

	for index = 1, #groups - 1, 2 do
		local first = groups[index]
		local second = groups[index + 1]
		connectPair(first.pad, second.pad, `Model-{first.container.Name}-{second.container.Name}`)
	end
end

repairSimplePair()
repairTeleporterModels()

local ok, expansionOrError = pcall(function()
	return ArenaExpansion.build({ parent = workspace, forceRebuild = true })
end)
if ok then
	print(`[Shooter] Arena expansion v{ArenaExpansion.VERSION} ready beside the existing map.`)
else
	warn(`[Shooter] Arena expansion failed: {tostring(expansionOrError)}`)
end

end

do
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("ShooterShared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

local function ensureContainer(parent: Instance, className: string, name: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

local remotes = ensureContainer(ReplicatedStorage, "Folder", "ShooterRemotes") :: Folder
local fireWeapon = ensureContainer(remotes, "RemoteEvent", "FireWeapon") :: RemoteEvent
local reloadWeapon = ensureContainer(remotes, "RemoteEvent", "ReloadWeapon") :: RemoteEvent
local weaponEffect = ensureContainer(remotes, "RemoteEvent", "WeaponEffect") :: RemoteEvent

local random = Random.new()
local lastShotByTool = setmetatable({}, { __mode = "k" })
local reloadTokens = setmetatable({}, { __mode = "k" })
local lastDamager = setmetatable({}, { __mode = "k" })

local function ensureStat(parent: Instance, name: string, initialValue: number): IntValue
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Value = initialValue
	value.Parent = parent
	return value
end

local function ensureCombatStats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	ensureStat(leaderstats, "KOs", 0)
	ensureStat(leaderstats, "Deaths", 0)
end

local function equippedWeapon(player: Player, weaponId: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ShooterWeapon") == true and child:GetAttribute("WeaponId") == weaponId then
			return child
		end
	end
	return nil
end

local function humanoidFromPart(part: BasePart): Humanoid?
	local current: Instance? = part
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return humanoid
			end
		end
		current = current.Parent
	end
	return nil
end

local function spreadDirection(direction: Vector3, spreadDegrees: number): Vector3
	if spreadDegrees <= 0 then
		return direction.Unit
	end
	local spread = math.tan(math.rad(spreadDegrees))
	local localDirection = Vector3.new(random:NextNumber(-spread, spread), random:NextNumber(-spread, spread), -1).Unit
	return CFrame.lookAt(Vector3.zero, direction):VectorToWorldSpace(localDirection).Unit
end

local function registerDamage(attacker: Player, humanoid: Humanoid, damage: number)
	if humanoid.Health <= 0 then
		return
	end
	local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victimPlayer == attacker then
		return
	end
	lastDamager[humanoid] = { player = attacker, time = os.clock() }
	humanoid:TakeDamage(damage)
end

fireWeapon.OnServerEvent:Connect(function(player, weaponId, aimPosition)
	if typeof(weaponId) ~= "string" or typeof(aimPosition) ~= "Vector3" then
		return
	end

	local weapon = WeaponConfig.get(weaponId)
	local tool = equippedWeapon(player, weaponId)
	local character = player.Character
	if not weapon or not tool or not character then
		return
	end
	if tool:GetAttribute("Reloading") == true then
		return
	end

	local now = os.clock()
	if now - (lastShotByTool[tool] or 0) < weapon.fireInterval * 0.82 then
		return
	end
	lastShotByTool[tool] = now

	local ammo = tool:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" or ammo <= 0 then
		return
	end
	tool:SetAttribute("Ammo", ammo - 1)

	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local originPart = if head and head:IsA("BasePart") then head elseif root and root:IsA("BasePart") then root else nil
	if not originPart then
		return
	end

	local rawDirection = aimPosition - originPart.Position
	if rawDirection.Magnitude < 1 then
		return
	end
	local origin = originPart.Position + rawDirection.Unit * 1.5
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local hitSomething = false
	for _ = 1, weapon.pellets do
		local direction = spreadDirection(rawDirection.Unit, weapon.spreadDegrees)
		local result = Workspace:Raycast(origin, direction * weapon.range, raycastParams)
		local endPosition = origin + direction * weapon.range
		if result then
			endPosition = result.Position
			local humanoid = humanoidFromPart(result.Instance)
			if humanoid then
				local damage = weapon.damage
				if result.Instance.Name == "Head" then
					damage *= weapon.headshotMultiplier
				end
				registerDamage(player, humanoid, damage)
				hitSomething = true
			end
		end
		weaponEffect:FireAllClients(origin, endPosition, weapon.tracerColor, player.UserId, hitSomething)
	end
end)

reloadWeapon.OnServerEvent:Connect(function(player, weaponId)
	if typeof(weaponId) ~= "string" then
		return
	end
	local weapon = WeaponConfig.get(weaponId)
	local tool = equippedWeapon(player, weaponId)
	if not weapon or not tool or tool:GetAttribute("Reloading") == true then
		return
	end

	local ammo = tool:GetAttribute("Ammo")
	local reserve = tool:GetAttribute("ReserveAmmo")
	if typeof(ammo) ~= "number" or typeof(reserve) ~= "number" or ammo >= weapon.magazineSize or reserve <= 0 then
		return
	end

	local token = (reloadTokens[tool] or 0) + 1
	reloadTokens[tool] = token
	tool:SetAttribute("Reloading", true)
	task.delay(weapon.reloadTime, function()
		if not tool.Parent or reloadTokens[tool] ~= token then
			return
		end
		local currentAmmo = tool:GetAttribute("Ammo")
		local currentReserve = tool:GetAttribute("ReserveAmmo")
		if typeof(currentAmmo) ~= "number" or typeof(currentReserve) ~= "number" then
			return
		end
		local needed = weapon.magazineSize - currentAmmo
		local loaded = math.min(needed, currentReserve)
		tool:SetAttribute("Ammo", currentAmmo + loaded)
		tool:SetAttribute("ReserveAmmo", currentReserve - loaded)
		tool:SetAttribute("Reloading", false)
	end)
end)

local function connectCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local deaths = stats:FindFirstChild("Deaths")
			if deaths and deaths:IsA("IntValue") then
				deaths.Value += 1
			end
		end
		local credit = lastDamager[humanoid]
		if credit and os.clock() - credit.time <= 10 and credit.player ~= player then
			local killerStats = credit.player:FindFirstChild("leaderstats")
			local kos = killerStats and killerStats:FindFirstChild("KOs")
			if kos and kos:IsA("IntValue") then
				kos.Value += 1
			end
		end
	end)
end

local function onPlayer(player: Player)
	ensureCombatStats(player)
	player.CharacterAdded:Connect(function(character)
		connectCharacter(player, character)
	end)
	if player.Character then
		connectCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

print("[Shooter] Server-authoritative weapon service ready.")

end

do
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local shared = ReplicatedStorage:WaitForChild("ShooterShared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

local STARTING_CREDITS = 650

local function ensureContainer(parent: Instance, className: string, name: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

local remotes = ensureContainer(ReplicatedStorage, "Folder", "ShooterRemotes") :: Folder
local openShop = ensureContainer(remotes, "RemoteEvent", "OpenShop") :: RemoteEvent
local purchaseItem = ensureContainer(remotes, "RemoteEvent", "PurchaseItem") :: RemoteEvent
local shopFeedback = ensureContainer(remotes, "RemoteEvent", "ShopFeedback") :: RemoteEvent
local getShopCatalog = ensureContainer(remotes, "RemoteFunction", "GetShopCatalog") :: RemoteFunction

local stock = ensureContainer(ServerStorage, "Folder", "ShooterShopStock") :: Folder
stock:ClearAllChildren()

local catalog = {}
local catalogById = {}

local function addCatalogEntry(id: string, displayName: string, price: number, kind: string, template: Tool)
	if catalogById[id] then
		return
	end
	local entry = {
		id = id,
		displayName = displayName,
		price = price,
		kind = kind,
		template = template,
	}
	table.insert(catalog, entry)
	catalogById[id] = entry
	template.Name = id
	template.Parent = stock
end

for _, weaponId in WeaponConfig.order do
	local weapon = WeaponConfig.get(weaponId)
	local tool = WeaponConfig.createTool(weaponId)
	if weapon and tool then
		addCatalogEntry(weaponId, weapon.displayName, weapon.price, "ShooterWeapon", tool)
	end
end

local legacyPrices = {
	["knife"] = 100,
	["colt python"] = 175,
	["trenchgun"] = 225,
}

local function legacyId(name: string): string
	local normalized = string.lower(name):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return `legacy_{normalized}`
end

for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("Tool") and descendant:GetAttribute("ShooterWeapon") ~= true then
		local id = legacyId(descendant.Name)
		local price = legacyPrices[string.lower(descendant.Name)] or 200
		addCatalogEntry(id, descendant.Name, price, "LegacyTool", descendant:Clone())
	end
end

table.sort(catalog, function(a, b)
	if a.price == b.price then
		return a.displayName < b.displayName
	end
	return a.price < b.price
end)

local function publicCatalog()
	local result = {}
	for _, entry in catalog do
		table.insert(result, {
			id = entry.id,
			displayName = entry.displayName,
			price = entry.price,
			kind = entry.kind,
		})
	end
	return result
end

local function ensureCredits(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local existing = leaderstats:FindFirstChild("Credits")
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local credits = Instance.new("IntValue")
	credits.Name = "Credits"
	credits.Value = STARTING_CREDITS
	credits.Parent = leaderstats
	return credits
end

local function ownsItem(player: Player, entry): Tool?
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					if entry.kind == "ShooterWeapon" and child:GetAttribute("WeaponId") == entry.id then
						return child
					elseif entry.kind == "LegacyTool" and child.Name == entry.displayName then
						return child
					end
				end
			end
		end
	end
	return nil
end

local function grantItem(player: Player, entry): (boolean, string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false, "Backpack is not ready yet."
	end

	local owned = ownsItem(player, entry)
	if owned then
		if entry.kind == "ShooterWeapon" then
			local weapon = WeaponConfig.get(entry.id)
			if weapon then
				owned:SetAttribute("Ammo", weapon.magazineSize)
				owned:SetAttribute("ReserveAmmo", weapon.reserveAmmo)
				owned:SetAttribute("Reloading", false)
				return true, `{entry.displayName} ammo refilled.`
			end
		end
		return false, `You already own {entry.displayName}.`
	end

	local clone = entry.template:Clone()
	clone.Name = entry.displayName
	clone.Parent = backpack
	return true, `{entry.displayName} added to your Backpack.`
end

getShopCatalog.OnServerInvoke = function(player)
	local credits = ensureCredits(player)
	return {
		credits = credits.Value,
		items = publicCatalog(),
	}
end

purchaseItem.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then
		return
	end
	local entry = catalogById[itemId]
	if not entry then
		shopFeedback:FireClient(player, false, "That item is no longer available.")
		return
	end

	local credits = ensureCredits(player)
	local owned = ownsItem(player, entry)
	local refill = owned and entry.kind == "ShooterWeapon"
	local price = if refill then math.max(25, math.floor(entry.price * 0.2)) else entry.price
	if credits.Value < price then
		shopFeedback:FireClient(player, false, `Need {price - credits.Value} more Credits.`)
		return
	end

	local granted, message = grantItem(player, entry)
	if granted then
		credits.Value -= price
	end
	shopFeedback:FireClient(player, granted, message, credits.Value)
end)

local function shopPosition(): Vector3
	local shop = workspace:FindFirstChild("Shop")
	if shop then
		if shop:IsA("Model") then
			local cframe, size = shop:GetBoundingBox()
			return cframe.Position + Vector3.new(size.X / 2 + 4, math.max(2.5, -size.Y / 2 + 2.5), 0)
		elseif shop:IsA("BasePart") then
			return shop.Position + Vector3.new(shop.Size.X / 2 + 4, 2.5, 0)
		end
	end
	local p1 = workspace:FindFirstChild("p1")
	if p1 and p1:IsA("BasePart") then
		return p1.Position + Vector3.new(-12, 2.5, 0)
	end
	return Vector3.new(0, 2.5, 0)
end

local previousRuntime = workspace:FindFirstChild("ShooterShopRuntime")
	if previousRuntime then
		previousRuntime:Destroy()
	end
local runtime = Instance.new("Model")
runtime.Name = "ShooterShopRuntime"
runtime.Parent = workspace

local terminal = Instance.new("Part")
terminal.Name = "WeaponShopTerminal"
terminal.Anchored = true
terminal.Size = Vector3.new(4, 5, 3)
terminal.Position = shopPosition()
terminal.Color = Color3.fromRGB(38, 52, 65)
terminal.Material = Enum.Material.Metal
terminal.Parent = runtime

local screen = Instance.new("Part")
screen.Name = "Screen"
screen.Anchored = true
screen.CanCollide = false
screen.Size = Vector3.new(3.2, 2.2, 0.25)
screen.CFrame = terminal.CFrame * CFrame.new(0, 0.5, -1.63)
screen.Color = Color3.fromRGB(49, 218, 240)
screen.Material = Enum.Material.Neon
screen.Parent = runtime

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "OpenWeaponShop"
prompt.ActionText = "OPEN SHOP"
prompt.ObjectText = "Shooter Loadout"
prompt.MaxActivationDistance = 12
prompt.HoldDuration = 0.15
prompt.RequiresLineOfSight = false
prompt.Parent = terminal
prompt.Triggered:Connect(function(player)
	openShop:FireClient(player)
end)

local billboard = Instance.new("BillboardGui")
billboard.Name = "ShopLabel"
billboard.AlwaysOnTop = true
billboard.Size = UDim2.fromOffset(230, 55)
billboard.StudsOffset = Vector3.new(0, 3.5, 0)
billboard.Parent = terminal

local label = Instance.new("TextLabel")
label.BackgroundColor3 = Color3.fromRGB(16, 20, 27)
label.BackgroundTransparency = 0.15
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.GothamBold
label.Text = "WEAPON SHOP"
label.TextColor3 = Color3.fromRGB(75, 226, 245)
label.TextScaled = true
label.Parent = billboard

local function giveStarter(player: Player)
	ensureCredits(player)
	task.delay(0.75, function()
		local entry = catalogById.hand_cannon
		if player.Parent and entry and not ownsItem(player, entry) then
			grantItem(player, entry)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	ensureCredits(player)
	player.CharacterAdded:Connect(function()
		giveStarter(player)
	end)
	if player.Character then
		giveStarter(player)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		ensureCredits(player)
		if player.Character then
			giveStarter(player)
		end
	end)
end

print(`[Shooter] Weapon shop ready with {#catalog} items beside Workspace.Shop.`)

end
