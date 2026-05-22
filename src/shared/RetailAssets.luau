local RetailAssets = {}

local function assetThumbnail(assetId: number): string
	return `rbxthumb://type=Asset&id={assetId}&w=150&h=150`
end

RetailAssets.buttons = {
	Menu = "rbxassetid://6031280882",
	Pets = "rbxassetid://6031075938",
	Lottery = "rbxassetid://6031094678",
	Roll = "rbxassetid://6031075938",
	Equip = "rbxassetid://6031091002",
	Close = "rbxassetid://6031094678",
	Receipt = "rbxassetid://6031075938",
	Register = "rbxassetid://6031091002",
}

RetailAssets.petLottery = {
	rollCostCents = 500,
	rarePityRolls = 8,
	image = assetThumbnail(11974475905),
	assetId = 11974475905,
	duplicateRefundCents = {
		Common = 75,
		Rare = 175,
		Epic = 350,
		Legendary = 900,
	},
}

RetailAssets.pets = {
	{
		id = "bag_buddy",
		name = "Bag Buddy",
		rarity = "Common",
		weight = 48,
		image = assetThumbnail(9071524795),
		assetId = 9071524795,
		sourceName = "Pet Asset Pack [Free to use]",
		color = Color3.fromRGB(225, 190, 92),
		accentColor = Color3.fromRGB(94, 72, 42),
		size = Vector3.new(2.2, 2.2, 2.2),
		perk = "Checkout tips +$0.25",
		checkoutBonusCents = 25,
	},
	{
		id = "cart_kit",
		name = "Cart Kit",
		rarity = "Common",
		weight = 28,
		image = assetThumbnail(11638468811),
		assetId = 11638468811,
		sourceName = "Basic Pets",
		color = Color3.fromRGB(126, 154, 176),
		accentColor = Color3.fromRGB(54, 78, 98),
		size = Vector3.new(2.3, 2.0, 2.3),
		perk = "Grab +2 stock from pallets",
		stockBonusUnits = 2,
	},
	{
		id = "scanner_sprite",
		name = "Scanner Sprite",
		rarity = "Rare",
		weight = 15,
		image = assetThumbnail(16758792155),
		assetId = 16758792155,
		sourceName = "Pets asset pack",
		color = Color3.fromRGB(88, 190, 146),
		accentColor = Color3.fromRGB(35, 86, 70),
		size = Vector3.new(2.4, 2.4, 2.4),
		perk = "Checkout tips +$0.75",
		checkoutBonusCents = 75,
	},
	{
		id = "coupon_glow",
		name = "Coupon Glow",
		rarity = "Epic",
		weight = 7,
		image = assetThumbnail(4537799968),
		assetId = 4537799968,
		sourceName = "Pet Pack",
		color = Color3.fromRGB(184, 122, 226),
		accentColor = Color3.fromRGB(86, 52, 112),
		size = Vector3.new(2.6, 2.6, 2.6),
		perk = "Duplicate refunds are boosted",
		duplicateRefundBonusCents = 150,
	},
	{
		id = "golden_receipt",
		name = "Golden Receipt",
		rarity = "Legendary",
		weight = 2,
		image = assetThumbnail(11974475905),
		assetId = 11974475905,
		sourceName = "Pet Clicker egg model",
		color = Color3.fromRGB(245, 205, 88),
		accentColor = Color3.fromRGB(160, 92, 34),
		size = Vector3.new(2.8, 2.8, 2.8),
		perk = "Checkout tips +$1.50",
		checkoutBonusCents = 150,
	},
}

local petsById = {}
local totalWeight = 0
local rarityRanks = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
}
for _, pet in RetailAssets.pets do
	petsById[pet.id] = pet
	totalWeight += pet.weight
end

RetailAssets.totalPetWeight = totalWeight

function RetailAssets.getPet(petId: string)
	return petsById[petId]
end

function RetailAssets.getRarityRank(rarity: string?): number
	return rarityRanks[rarity or "Common"] or 1
end

function RetailAssets.getDuplicateRefundCents(rarity: string?): number
	local refunds = RetailAssets.petLottery.duplicateRefundCents
	return refunds[rarity or "Common"] or refunds.Common
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

function RetailAssets.rollPetAtLeast(rarity: string, random: Random?)
	local minimumRank = RetailAssets.getRarityRank(rarity)
	local eligible = {}
	local eligibleWeight = 0
	for _, pet in RetailAssets.pets do
		if RetailAssets.getRarityRank(pet.rarity) >= minimumRank then
			table.insert(eligible, pet)
			eligibleWeight += pet.weight
		end
	end

	if #eligible == 0 then
		return RetailAssets.rollPet(random)
	end

	local rng = random or Random.new()
	local roll = rng:NextNumber(0, eligibleWeight)
	local running = 0
	for _, pet in eligible do
		running += pet.weight
		if roll <= running then
			return pet
		end
	end

	return eligible[#eligible]
end

return RetailAssets
