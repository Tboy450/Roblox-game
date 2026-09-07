local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RetailAssets = require(Shared:WaitForChild("RetailAssets"))
local RetailCurrency = require(Shared:WaitForChild("RetailCurrency"))

local retailRemotes = ReplicatedStorage:FindFirstChild("RetailRemotes")
if not retailRemotes then
	retailRemotes = Instance.new("Folder")
	retailRemotes.Name = "RetailRemotes"
	retailRemotes.Parent = ReplicatedStorage
end

local function getRemoteEvent(name: string): RemoteEvent
	local remote = retailRemotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = retailRemotes
	end

	return remote :: RemoteEvent
end

local requestPetLottery = getRemoteEvent("RequestPetLottery")
local requestEquipPet = getRemoteEvent("RequestEquipPet")
local petInventoryUpdate = getRemoteEvent("PetInventoryUpdate")
local petLotteryResult = getRemoteEvent("PetLotteryResult")

local petFolder = Workspace:FindFirstChild("PlayerPets")
if not petFolder then
	petFolder = Instance.new("Folder")
	petFolder.Name = "PlayerPets"
	petFolder.Parent = Workspace
end

type PetState = {
	owned: { [string]: number },
	equippedPetId: string?,
	totalRolls: number,
	rollsSinceRare: number,
}

local petStates: { [Player]: PetState } = {}
local random = Random.new()

local function getStat(player: Player, name: string): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local stat = leaderstats:FindFirstChild(name)
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end

	return stat :: IntValue
end

local function message(player: Player, text: string)
	player:SetAttribute("RetailMessage", text)
	print(`[RetailPets] {player.Name}: {text}`)
end

local function getState(player: Player): PetState
	local state = petStates[player]
	if not state then
		state = {
			owned = {},
			equippedPetId = nil,
			totalRolls = 0,
			rollsSinceRare = 0,
		}
		petStates[player] = state
	end

	return state
end

local function applyPetAttributes(player: Player)
	local state = getState(player)
	local pet = if state.equippedPetId then RetailAssets.getPet(state.equippedPetId) else nil
	player:SetAttribute("EquippedPetId", if pet then pet.id else nil)
	player:SetAttribute("EquippedPetName", if pet then pet.name else nil)
	player:SetAttribute("EquippedPetPerk", if pet then pet.perk else nil)
	player:SetAttribute("PetStockBonusUnits", if pet and pet.stockBonusUnits then pet.stockBonusUnits else 0)
	player:SetAttribute("PetCheckoutBonusCents", if pet and pet.checkoutBonusCents then pet.checkoutBonusCents else 0)
	player:SetAttribute("PetDuplicateRefundBonusCents", if pet and pet.duplicateRefundBonusCents then pet.duplicateRefundBonusCents else 0)
	player:SetAttribute("PetCareBonusCents", if pet and pet.careBonusCents then pet.careBonusCents else 0)
end

local function setPetCountStat(player: Player)
	local state = getState(player)
	local total = 0
	for _, count in state.owned do
		total += count
	end
	getStat(player, "Pets").Value = total
end

local function getPetRollDiscountCents(player: Player): number
	return math.clamp(math.floor(player:GetAttribute("PetRollDiscountCents") or 0), 0, 300)
end

local function getPetRollCostCents(player: Player): number
	return math.max(100, RetailAssets.petLottery.rollCostCents - getPetRollDiscountCents(player))
end

local function buildInventoryPayload(player: Player)
	local state = getState(player)
	local pets = {}
	for _, pet in RetailAssets.pets do
		table.insert(pets, {
			id = pet.id,
			name = pet.name,
			rarity = pet.rarity,
			image = pet.image,
			assetId = pet.assetId,
			sourceName = pet.sourceName,
			color = pet.color,
			accentColor = pet.accentColor,
			detailColor = pet.detailColor,
			species = pet.species,
			perk = pet.perk,
			count = state.owned[pet.id] or 0,
			equipped = state.equippedPetId == pet.id,
		})
	end

	local pityTarget = RetailAssets.petLottery.rarePityRolls
	return {
		rollCostCents = getPetRollCostCents(player),
		rollDiscountCents = getPetRollDiscountCents(player),
		rarePityRolls = pityTarget,
		rollsSinceRare = state.rollsSinceRare,
		rollsUntilRare = math.max(0, pityTarget - state.rollsSinceRare),
		totalRolls = state.totalRolls,
		equippedPetId = state.equippedPetId,
		equippedPerk = player:GetAttribute("EquippedPetPerk"),
		pets = pets,
	}
end

local function sendInventory(player: Player)
	setPetCountStat(player)
	petInventoryUpdate:FireClient(player, buildInventoryPayload(player))
end

local function clearPetModel(player: Player)
	local existing = petFolder:FindFirstChild(`Pet_{player.UserId}`)
	if existing then
		existing:Destroy()
	end
end

local function colorOr(value, fallback: Color3): Color3
	return if typeof(value) == "Color3" then value else fallback
end

local function petPart(model: Model, props: {
	name: string,
	shape: Enum.PartType?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
}): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Shape = props.shape or Enum.PartType.Block
	part.Size = props.size
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = props.cframe
	part.Parent = model
	return part
end

local function weldTo(rootPart: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.Parent = part
end

local function addPetFace(model: Model, head: BasePart, pet)
	local detailColor = colorOr(pet.detailColor, Color3.fromRGB(255, 238, 204))
	for _, eyeOffset in { -0.22, 0.22 } do
		local eye = petPart(model, {
			name = if eyeOffset < 0 then "LeftEye" else "RightEye",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.18, 0.18, 0.08),
			cframe = head.CFrame * CFrame.new(eyeOffset, 0.16, -0.58),
			color = Color3.fromRGB(22, 24, 28),
			material = Enum.Material.SmoothPlastic,
		})
		weldTo(head, eye)
		local highlight = petPart(model, {
			name = if eyeOffset < 0 then "LeftEyeHighlight" else "RightEyeHighlight",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.065, 0.065, 0.025),
			cframe = eye.CFrame * CFrame.new(-0.035, 0.04, -0.04),
			color = Color3.fromRGB(255, 255, 250),
		})
		weldTo(head, highlight)
	end

	local nose = petPart(model, {
		name = "Nose",
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.18, 0.14, 0.1),
		cframe = head.CFrame * CFrame.new(0, -0.06, -0.66),
		color = detailColor:Lerp(Color3.fromRGB(24, 20, 18), 0.65),
		material = Enum.Material.SmoothPlastic,
	})
	weldTo(head, nose)
end

local function addPetEars(model: Model, head: BasePart, pet, species: string)
	local accentColor = colorOr(pet.accentColor, Color3.fromRGB(80, 80, 88))
	local earSize = if species == "bunny" then Vector3.new(0.34, 1.05, 0.18) else Vector3.new(0.34, 0.62, 0.22)
	local yOffset = if species == "bunny" then 0.68 else 0.48
	local rotation = if species == "dog" then math.rad(22) else math.rad(0)
	for _, side in { -1, 1 } do
		local ear = petPart(model, {
			name = if side < 0 then "LeftEar" else "RightEar",
			shape = if species == "dog" or species == "bunny" then Enum.PartType.Ball else Enum.PartType.Block,
			size = earSize,
			cframe = head.CFrame * CFrame.new(side * 0.42, yOffset, -0.02) * CFrame.Angles(0, 0, side * rotation),
			color = accentColor,
			material = Enum.Material.SmoothPlastic,
		})
		weldTo(head, ear)
		local innerEar = petPart(model, {
			name = if side < 0 then "LeftInnerEar" else "RightInnerEar",
			shape = Enum.PartType.Ball,
			size = Vector3.new(earSize.X * 0.55, earSize.Y * 0.68, 0.035),
			cframe = ear.CFrame * CFrame.new(0, 0.02, -earSize.Z / 2),
			color = colorOr(pet.detailColor, Color3.fromRGB(236, 176, 166)),
		})
		weldTo(head, innerEar)
	end
end

local function addPetTail(model: Model, body: BasePart, pet, species: string)
	local accentColor = colorOr(pet.accentColor, pet.color)
	local length = if species == "cat" then 1.35 else 0.98
	local size = Vector3.new(length, 0.27, 0.27)
	local tail = petPart(model, {
		name = "Tail",
		shape = Enum.PartType.Cylinder,
		size = size,
		cframe = body.CFrame * CFrame.new(0, 0.18, 0.98) * CFrame.Angles(math.rad(74), 0, math.rad(90)),
		color = accentColor,
		material = Enum.Material.SmoothPlastic,
	})
	weldTo(body, tail)
	local tailTip = petPart(model, {
		name = "TailTip", shape = Enum.PartType.Ball,
		size = Vector3.new(0.32, 0.32, 0.32),
		cframe = tail.CFrame * CFrame.new(length / 2, 0, 0),
		color = colorOr(pet.detailColor, accentColor),
	})
	weldTo(body, tailTip)
end

local function addPetPaws(model: Model, body: BasePart, pet)
	local detailColor = colorOr(pet.detailColor, pet.color)
	for _, offset in {
		Vector3.new(-0.42, -0.72, -0.38),
		Vector3.new(0.42, -0.72, -0.38),
		Vector3.new(-0.42, -0.72, 0.42),
		Vector3.new(0.42, -0.72, 0.42),
	} do
		local paw = petPart(model, {
			name = "Paw",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.34, 0.22, 0.34),
			cframe = body.CFrame * CFrame.new(offset),
			color = detailColor,
			material = Enum.Material.SmoothPlastic,
		})
		weldTo(body, paw)
	end
end

local function addDragonDetails(model: Model, body: BasePart, head: BasePart, pet)
	local accentColor = colorOr(pet.accentColor, Color3.fromRGB(80, 120, 100))
	local detailColor = colorOr(pet.detailColor, Color3.fromRGB(255, 220, 110))
	for _, side in { -1, 1 } do
		local wing = Instance.new("WedgePart")
		wing.Name = if side < 0 then "LeftWing" else "RightWing"
		wing.Size = Vector3.new(0.28, 1.05, 1.35)
		wing.Color = accentColor
		wing.Material = Enum.Material.SmoothPlastic
		wing.Anchored = false
		wing.CanCollide = false
		wing.Massless = true
		wing.CFrame = body.CFrame * CFrame.new(side * 0.92, 0.22, 0.08) * CFrame.Angles(0, side * math.rad(28), side * math.rad(22))
		wing.Parent = model
		weldTo(body, wing)

		local horn = petPart(model, {
			name = if side < 0 then "LeftHorn" else "RightHorn",
			size = Vector3.new(0.2, 0.5, 0.2),
			cframe = head.CFrame * CFrame.new(side * 0.25, 0.62, -0.18) * CFrame.Angles(side * math.rad(10), 0, side * math.rad(18)),
			color = detailColor,
			material = Enum.Material.SmoothPlastic,
		})
		weldTo(head, horn)
	end

	for index = 1, 3 do
		local spine = petPart(model, {
			name = `BackSpine{index}`,
			size = Vector3.new(0.18, 0.34, 0.18),
			cframe = body.CFrame * CFrame.new(0, 0.78, -0.42 + index * 0.36) * CFrame.Angles(0, 0, math.rad(45)),
			color = detailColor,
			material = Enum.Material.Neon,
		})
		weldTo(body, spine)
	end
end

local function attachPetToCharacter(player: Player)
	clearPetModel(player)

	local state = getState(player)
	if not state.equippedPetId then
		return
	end

	local pet = RetailAssets.getPet(state.equippedPetId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pet or not root or not root:IsA("BasePart") then
		return
	end

	local model = Instance.new("Model")
	model.Name = `Pet_{player.UserId}`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PetId", pet.id)
	model:SetAttribute("PetName", pet.name)
	model.Parent = petFolder

	local species = if typeof(pet.species) == "string" then pet.species else "sprite"
	local petSize = if typeof(pet.size) == "Vector3" then pet.size else Vector3.new(2.25, 2.25, 2.25)
	local baseCFrame = root.CFrame * CFrame.new(3.5, 1.8, 2.6)
	local body = petPart(model, {
		name = "Body",
		shape = Enum.PartType.Ball,
		size = petSize,
		cframe = baseCFrame,
		color = pet.color,
		material = Enum.Material.SmoothPlastic,
	})
	model.PrimaryPart = body

	local head = petPart(model, {
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.new(petSize.X * 0.58, petSize.Y * 0.58, petSize.Z * 0.58),
		cframe = body.CFrame * CFrame.new(0, petSize.Y * 0.28, -petSize.Z * 0.52),
		color = pet.color:Lerp(colorOr(pet.detailColor, pet.color), 0.12),
		material = Enum.Material.SmoothPlastic,
	})
	weldTo(body, head)

	local cheek = petPart(model, {
		name = "Cheek",
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.56, 0.34, 0.24),
		cframe = head.CFrame * CFrame.new(0, -0.12, -0.48),
		color = colorOr(pet.detailColor, pet.color),
		material = Enum.Material.SmoothPlastic,
	})
	weldTo(head, cheek)

	local accent = petPart(model, {
		name = "ChestPatch",
		shape = Enum.PartType.Ball,
		size = Vector3.new(petSize.X * 0.45, petSize.Y * 0.45, 0.15),
		cframe = body.CFrame * CFrame.new(0, -petSize.Y * 0.1, -petSize.Z * 0.48),
		color = colorOr(pet.detailColor, pet.color),
		material = Enum.Material.SmoothPlastic,
	})
	weldTo(body, accent)

	addPetFace(model, head, pet)
	addPetEars(model, head, pet, species)
	addPetTail(model, body, pet, species)
	addPetPaws(model, body, pet)
	if species == "dragon" then
		addDragonDetails(model, body, head, pet)
	end

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Face = face
		decal.Texture = pet.image
		decal.Transparency = 0.08
		decal.Parent = body
	end

	local glow = Instance.new("PointLight")
	glow.Color = pet.color
	glow.Brightness = 0.65
	glow.Range = 8
	glow.Parent = body

	local badge = Instance.new("BillboardGui")
	badge.Name = "PetBadge"
	badge.Size = UDim2.fromOffset(54, 54)
	badge.StudsOffset = Vector3.new(0, 2.1, 0)
	badge.AlwaysOnTop = true
	badge.Parent = body

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = pet.image
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.Parent = badge

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
end

local function awardPet(player: Player)
	local state = getState(player)
	local guaranteedRare = state.rollsSinceRare >= RetailAssets.petLottery.rarePityRolls - 1
	local pet = if guaranteedRare then RetailAssets.rollPetAtLeast("Rare", random) else RetailAssets.rollPet(random)
	local ownedBefore = state.owned[pet.id] or 0
	state.owned[pet.id] = (state.owned[pet.id] or 0) + 1
	state.totalRolls += 1
	if RetailAssets.getRarityRank(pet.rarity) >= RetailAssets.getRarityRank("Rare") then
		state.rollsSinceRare = 0
	else
		state.rollsSinceRare += 1
	end
	if not state.equippedPetId then
		state.equippedPetId = pet.id
		applyPetAttributes(player)
		attachPetToCharacter(player)
	end

	local duplicateRefund = 0
	if ownedBefore > 0 then
		duplicateRefund = RetailAssets.getDuplicateRefundCents(pet.rarity)
			+ math.max(0, math.floor(player:GetAttribute("PetDuplicateRefundBonusCents") or 0))
		getStat(player, "Cash").Value += duplicateRefund
	end

	local suffix = if duplicateRefund > 0 then ` duplicate refund {RetailCurrency.formatCents(duplicateRefund)}` else ""
	message(player, `Won {pet.rarity} pet: {pet.name}{suffix}`)
	petLotteryResult:FireClient(player, {
		id = pet.id,
		name = pet.name,
		rarity = pet.rarity,
		image = pet.image,
		assetId = pet.assetId,
		sourceName = pet.sourceName,
		color = pet.color,
		accentColor = pet.accentColor,
		detailColor = pet.detailColor,
		species = pet.species,
		perk = pet.perk,
		count = state.owned[pet.id],
		duplicate = ownedBefore > 0,
		duplicateRefundCents = duplicateRefund,
		guaranteedRare = guaranteedRare,
		rollsSinceRare = state.rollsSinceRare,
		rollsUntilRare = math.max(0, RetailAssets.petLottery.rarePityRolls - state.rollsSinceRare),
	})
	sendInventory(player)
end

requestPetLottery.OnServerEvent:Connect(function(player)
	local cash = getStat(player, "Cash")
	local cost = getPetRollCostCents(player)
	if cash.Value < cost then
		message(player, `Need {RetailCurrency.formatCents(cost)} to roll the pet lottery`)
		sendInventory(player)
		return
	end

	cash.Value -= cost
	player:SetAttribute("PetRollDiscountCents", 0)
	awardPet(player)
end)

requestEquipPet.OnServerEvent:Connect(function(player, petId, action)
	if typeof(petId) ~= "string" then
		return
	end

	local requestedAction = if typeof(action) == "string" then string.lower(action) else "toggle"
	local state = getState(player)
	if petId == "" or requestedAction == "unequip" then
		if petId ~= "" and state.equippedPetId ~= petId then
			message(player, "That pet is not equipped")
			sendInventory(player)
			return
		end

		state.equippedPetId = nil
		applyPetAttributes(player)
		clearPetModel(player)
		message(player, "Pet unequipped")
		sendInventory(player)
		return
	end

	if (state.owned[petId] or 0) <= 0 then
		return
	end

	local pet = RetailAssets.getPet(petId)
	if not pet then
		return
	end

	if state.equippedPetId == petId then
		if requestedAction == "equip" then
			message(player, `{pet.name} is already equipped`)
			sendInventory(player)
			return
		end

		state.equippedPetId = nil
		applyPetAttributes(player)
		clearPetModel(player)
		message(player, `{pet.name} unequipped`)
		sendInventory(player)
		return
	end

	state.equippedPetId = petId
	applyPetAttributes(player)
	attachPetToCharacter(player)
	message(player, `Equipped {pet.name}: {pet.perk or "Companion active"}`)
	sendInventory(player)
end)

Players.PlayerAdded:Connect(function(player)
	getState(player)
	applyPetAttributes(player)
	player:SetAttribute("PetRollDiscountCents", math.max(0, math.floor(player:GetAttribute("PetRollDiscountCents") or 0)))
	getStat(player, "Pets").Value = 0

	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		attachPetToCharacter(player)
	end)

	task.defer(function()
		sendInventory(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	clearPetModel(player)
	petStates[player] = nil
end)

for _, player in Players:GetPlayers() do
	getState(player)
	applyPetAttributes(player)
	player:SetAttribute("PetRollDiscountCents", math.max(0, math.floor(player:GetAttribute("PetRollDiscountCents") or 0)))
	sendInventory(player)
	if player.Character then
		attachPetToCharacter(player)
	end
end
