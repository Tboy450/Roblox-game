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
end

local function setPetCountStat(player: Player)
	local state = getState(player)
	local total = 0
	for _, count in state.owned do
		total += count
	end
	getStat(player, "Pets").Value = total
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
			color = pet.color,
			perk = pet.perk,
			count = state.owned[pet.id] or 0,
			equipped = state.equippedPetId == pet.id,
		})
	end

	local pityTarget = RetailAssets.petLottery.rarePityRolls
	return {
		rollCostCents = RetailAssets.petLottery.rollCostCents,
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

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = pet.size
	body.Color = pet.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = false
	body.CanCollide = false
	body.Massless = true
	body.CFrame = root.CFrame * CFrame.new(3.5, 1.8, 2.6)
	body.Parent = model
	model.PrimaryPart = body

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Shape = Enum.PartType.Ball
	accent.Size = Vector3.new(0.75, 0.75, 0.75)
	accent.Color = pet.accentColor
	accent.Material = Enum.Material.Neon
	accent.Anchored = false
	accent.CanCollide = false
	accent.Massless = true
	accent.CFrame = body.CFrame * CFrame.new(0.7, 0.55, -0.7)
	accent.Parent = model

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

	local accentWeld = Instance.new("WeldConstraint")
	accentWeld.Part0 = body
	accentWeld.Part1 = accent
	accentWeld.Parent = accent
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
		color = pet.color,
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
	local cost = RetailAssets.petLottery.rollCostCents
	if cash.Value < cost then
		message(player, `Need {RetailCurrency.formatCents(cost)} to roll the pet lottery`)
		sendInventory(player)
		return
	end

	cash.Value -= cost
	awardPet(player)
end)

requestEquipPet.OnServerEvent:Connect(function(player, petId)
	if typeof(petId) ~= "string" then
		return
	end

	local state = getState(player)
	if petId == "" then
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

	state.equippedPetId = petId
	applyPetAttributes(player)
	attachPetToCharacter(player)
	message(player, `Equipped {pet.name}: {pet.perk or "Companion active"}`)
	sendInventory(player)
end)

Players.PlayerAdded:Connect(function(player)
	getState(player)
	applyPetAttributes(player)
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
	sendInventory(player)
	if player.Character then
		attachPetToCharacter(player)
	end
end
