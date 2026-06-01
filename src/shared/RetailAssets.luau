local RetailAssets = {}

local function assetThumbnail(assetId: number): string
	return `rbxthumb://type=Asset&id={assetId}&w=150&h=150`
end

RetailAssets.buttons = {
	Hud = "rbxassetid://6031280882",
	Menu = "rbxassetid://6031280882",
	Controls = "rbxassetid://6031280882",
	Pets = "rbxassetid://6031075938",
	Lottery = "rbxassetid://6031094678",
	Roll = "rbxassetid://6031075938",
	Care = "rbxassetid://6031075938",
	Stock = "rbxassetid://6031075938",
	OrderStock = "rbxassetid://6031091002",
	StoreOpen = "rbxassetid://6031091002",
	StoreClosed = "rbxassetid://6031094678",
	Cash = "rbxassetid://6031091002",
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
		detailColor = Color3.fromRGB(252, 226, 152),
		species = "dog",
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
		detailColor = Color3.fromRGB(202, 222, 232),
		species = "cat",
		size = Vector3.new(2.3, 2.0, 2.3),
		perk = "Grab +2 stock from pallets",
		stockBonusUnits = 2,
	},
	{
		id = "snack_pup",
		name = "Snack Pup",
		rarity = "Common",
		weight = 20,
		image = assetThumbnail(9071524795),
		assetId = 9071524795,
		sourceName = "Pet Asset Pack [Free to use]",
		color = Color3.fromRGB(236, 154, 112),
		accentColor = Color3.fromRGB(112, 68, 50),
		detailColor = Color3.fromRGB(255, 218, 166),
		species = "dog",
		size = Vector3.new(2.25, 2.1, 2.25),
		perk = "Pet care discount +$0.50",
		careBonusCents = 50,
	},
	{
		id = "checkout_corgi",
		name = "Checkout Corgi",
		rarity = "Common",
		weight = 18,
		image = assetThumbnail(9071524795),
		assetId = 9071524795,
		sourceName = "Pet Asset Pack [Free to use]",
		color = Color3.fromRGB(226, 156, 82),
		accentColor = Color3.fromRGB(106, 64, 38),
		detailColor = Color3.fromRGB(255, 232, 178),
		species = "dog",
		size = Vector3.new(2.45, 1.95, 2.2),
		perk = "Checkout tips +$0.35",
		checkoutBonusCents = 35,
	},
	{
		id = "register_tabby",
		name = "Register Tabby",
		rarity = "Common",
		weight = 16,
		image = assetThumbnail(11638468811),
		assetId = 11638468811,
		sourceName = "Basic Pets",
		color = Color3.fromRGB(178, 144, 104),
		accentColor = Color3.fromRGB(82, 66, 54),
		detailColor = Color3.fromRGB(236, 210, 174),
		species = "cat",
		size = Vector3.new(2.15, 2.15, 2.05),
		perk = "Checkout tips +$0.25 and care +$0.25",
		checkoutBonusCents = 25,
		careBonusCents = 25,
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
		detailColor = Color3.fromRGB(176, 248, 218),
		species = "sprite",
		size = Vector3.new(2.4, 2.4, 2.4),
		perk = "Checkout tips +$0.75",
		checkoutBonusCents = 75,
	},
	{
		id = "cooler_cub",
		name = "Cooler Cub",
		rarity = "Rare",
		weight = 11,
		image = assetThumbnail(11638468811),
		assetId = 11638468811,
		sourceName = "Basic Pets",
		color = Color3.fromRGB(116, 186, 214),
		accentColor = Color3.fromRGB(38, 82, 104),
		detailColor = Color3.fromRGB(218, 246, 255),
		species = "cat",
		size = Vector3.new(2.5, 2.35, 2.5),
		perk = "Grab +1 stock and care +$0.25",
		stockBonusUnits = 1,
		careBonusCents = 25,
	},
	{
		id = "shelf_siamese",
		name = "Shelf Siamese",
		rarity = "Rare",
		weight = 9,
		image = assetThumbnail(11638468811),
		assetId = 11638468811,
		sourceName = "Basic Pets",
		color = Color3.fromRGB(232, 218, 184),
		accentColor = Color3.fromRGB(92, 74, 68),
		detailColor = Color3.fromRGB(116, 172, 220),
		species = "cat",
		size = Vector3.new(2.35, 2.25, 2.35),
		perk = "Grab +2 stock and care +$0.25",
		stockBonusUnits = 2,
		careBonusCents = 25,
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
		detailColor = Color3.fromRGB(238, 204, 255),
		species = "dragon",
		size = Vector3.new(2.6, 2.6, 2.6),
		perk = "Duplicate refunds are boosted",
		duplicateRefundBonusCents = 150,
	},
	{
		id = "receipt_bunny",
		name = "Receipt Bunny",
		rarity = "Epic",
		weight = 5,
		image = assetThumbnail(4537799968),
		assetId = 4537799968,
		sourceName = "Pet Pack",
		color = Color3.fromRGB(238, 178, 216),
		accentColor = Color3.fromRGB(124, 62, 104),
		detailColor = Color3.fromRGB(255, 228, 244),
		species = "bunny",
		size = Vector3.new(2.55, 2.7, 2.55),
		perk = "Checkout tips +$1.00 and care +$0.50",
		checkoutBonusCents = 100,
		careBonusCents = 50,
	},
	{
		id = "stockroom_drake",
		name = "Stockroom Drake",
		rarity = "Epic",
		weight = 4,
		image = assetThumbnail(11974475905),
		assetId = 11974475905,
		sourceName = "Pet Clicker egg model",
		color = Color3.fromRGB(92, 170, 132),
		accentColor = Color3.fromRGB(34, 84, 70),
		detailColor = Color3.fromRGB(255, 208, 96),
		species = "dragon",
		size = Vector3.new(2.7, 2.35, 2.9),
		perk = "Grab +2 stock and checkout tips +$0.75",
		stockBonusUnits = 2,
		checkoutBonusCents = 75,
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
		detailColor = Color3.fromRGB(255, 246, 176),
		species = "dragon",
		size = Vector3.new(2.8, 2.8, 2.8),
		perk = "Checkout tips +$1.50",
		checkoutBonusCents = 150,
	},
	{
		id = "golden_dragon",
		name = "Golden Dragon",
		rarity = "Legendary",
		weight = 1,
		image = assetThumbnail(11974475905),
		assetId = 11974475905,
		sourceName = "Pet Clicker egg model",
		color = Color3.fromRGB(255, 176, 70),
		accentColor = Color3.fromRGB(150, 56, 42),
		detailColor = Color3.fromRGB(255, 238, 120),
		species = "dragon",
		size = Vector3.new(3.0, 2.8, 3.2),
		perk = "Checkout tips +$1.75 and care +$0.75",
		checkoutBonusCents = 175,
		careBonusCents = 75,
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
