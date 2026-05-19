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
		}
		petStates[player] = state
	end

	return state
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
			count = state.owned[pet.id] or 0,
			equipped = state.equippedPetId == pet.id,
		})
	end

	return {
		rollCostCents = RetailAssets.petLottery.rollCostCents,
		equippedPetId = state.equippedPetId,
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
	local pet = RetailAssets.rollPet(random)
	local state = getState(player)
	state.owned[pet.id] = (state.owned[pet.id] or 0) + 1
	if not state.equippedPetId then
		state.equippedPetId = pet.id
		attachPetToCharacter(player)
	end

	message(player, `Won {pet.rarity} pet: {pet.name}`)
	petLotteryResult:FireClient(player, {
		id = pet.id,
		name = pet.name,
		rarity = pet.rarity,
		image = pet.image,
		color = pet.color,
		count = state.owned[pet.id],
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
	attachPetToCharacter(player)
	message(player, `Equipped {pet.name}`)
	sendInventory(player)
end)

Players.PlayerAdded:Connect(function(player)
	getState(player)
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
	sendInventory(player)
	if player.Character then
		attachPetToCharacter(player)
	end
end
