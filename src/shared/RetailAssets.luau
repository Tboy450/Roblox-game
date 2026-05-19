local RetailAssets = {}

RetailAssets.buttons = {
	Menu = "rbxassetid://6031280882",
	Pets = "rbxassetid://6031075938",
	Lottery = "rbxassetid://6031094678",
	Roll = "rbxassetid://6031075938",
	Equip = "rbxassetid://6031091002",
	Close = "rbxassetid://6031094678",
}

RetailAssets.petLottery = {
	rollCostCents = 500,
}

RetailAssets.pets = {
	{
		id = "bag_buddy",
		name = "Bag Buddy",
		rarity = "Common",
		weight = 48,
		image = "rbxassetid://6031075938",
		color = Color3.fromRGB(225, 190, 92),
		accentColor = Color3.fromRGB(94, 72, 42),
		size = Vector3.new(2.2, 2.2, 2.2),
	},
	{
		id = "cart_kit",
		name = "Cart Kit",
		rarity = "Common",
		weight = 28,
		image = "rbxassetid://6031091002",
		color = Color3.fromRGB(126, 154, 176),
		accentColor = Color3.fromRGB(54, 78, 98),
		size = Vector3.new(2.3, 2.0, 2.3),
	},
	{
		id = "scanner_sprite",
		name = "Scanner Sprite",
		rarity = "Rare",
		weight = 15,
		image = "rbxassetid://6031280882",
		color = Color3.fromRGB(88, 190, 146),
		accentColor = Color3.fromRGB(35, 86, 70),
		size = Vector3.new(2.4, 2.4, 2.4),
	},
	{
		id = "coupon_glow",
		name = "Coupon Glow",
		rarity = "Epic",
		weight = 7,
		image = "rbxassetid://6031094678",
		color = Color3.fromRGB(184, 122, 226),
		accentColor = Color3.fromRGB(86, 52, 112),
		size = Vector3.new(2.6, 2.6, 2.6),
	},
	{
		id = "golden_receipt",
		name = "Golden Receipt",
		rarity = "Legendary",
		weight = 2,
		image = "rbxassetid://6031079152",
		color = Color3.fromRGB(245, 205, 88),
		accentColor = Color3.fromRGB(160, 92, 34),
		size = Vector3.new(2.8, 2.8, 2.8),
	},
}

local petsById = {}
local totalWeight = 0
for _, pet in RetailAssets.pets do
	petsById[pet.id] = pet
	totalWeight += pet.weight
end

RetailAssets.totalPetWeight = totalWeight

function RetailAssets.getPet(petId: string)
	return petsById[petId]
end

function RetailAssets.rollPet(random: Random?)
	local rng = random or Random.new()
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, pet in RetailAssets.pets do
		running += pet.weight
		if roll <= running then
			return pet
		end
	end

	return RetailAssets.pets[#RetailAssets.pets]
end

return RetailAssets
