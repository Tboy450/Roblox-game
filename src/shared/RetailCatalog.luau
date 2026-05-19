local RetailCatalog = {}

export type ProductDefinition = {
	name: string,
	color: Color3,
	material: Enum.Material,
	size: Vector3,
	priceCents: number,
}

export type DepartmentDefinition = {
	name: string,
	signColor: Color3,
	products: { ProductDefinition },
}

RetailCatalog.departments = {
	{
		name = "Produce",
		signColor = Color3.fromRGB(72, 112, 68),
		products = {
			{ name = "Apples", color = Color3.fromRGB(182, 56, 54), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.5, 1.3, 1.5), priceCents = 149 },
			{ name = "Bananas", color = Color3.fromRGB(225, 196, 72), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.9, 1.1, 1.3), priceCents = 129 },
			{ name = "Tomatoes", color = Color3.fromRGB(200, 72, 58), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.4, 1.2, 1.4), priceCents = 179 },
			{ name = "Lettuce", color = Color3.fromRGB(106, 154, 78), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.6, 1.3, 1.6), priceCents = 199 },
		},
	},
	{
		name = "Dairy",
		signColor = Color3.fromRGB(72, 92, 122),
		products = {
			{ name = "Milk", color = Color3.fromRGB(236, 238, 232), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.4, 2.1, 1.2), priceCents = 349 },
			{ name = "Yogurt", color = Color3.fromRGB(166, 202, 232), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.4, 1.3, 1.4), priceCents = 229 },
			{ name = "Cheese", color = Color3.fromRGB(235, 188, 70), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.8, 1.0, 1.4), priceCents = 449 },
			{ name = "Butter", color = Color3.fromRGB(244, 216, 118), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.8, 0.9, 1.2), priceCents = 299 },
		},
	},
	{
		name = "Frozen",
		signColor = Color3.fromRGB(62, 102, 126),
		products = {
			{ name = "Pizza", color = Color3.fromRGB(188, 92, 68), material = Enum.Material.SmoothPlastic, size = Vector3.new(2.2, 0.8, 1.6), priceCents = 699 },
			{ name = "Ice Cream", color = Color3.fromRGB(196, 220, 238), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.4, 1.8, 1.4), priceCents = 549 },
			{ name = "Vegetables", color = Color3.fromRGB(96, 154, 120), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.8, 1.1, 1.4), priceCents = 399 },
			{ name = "Meals", color = Color3.fromRGB(126, 144, 180), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.9, 0.9, 1.5), priceCents = 799 },
		},
	},
	{
		name = "Pantry",
		signColor = Color3.fromRGB(132, 92, 58),
		products = {
			{ name = "Cereal", color = Color3.fromRGB(210, 138, 72), material = Enum.Material.Cardboard, size = Vector3.new(1.6, 2.2, 1.0), priceCents = 449 },
			{ name = "Pasta", color = Color3.fromRGB(214, 188, 118), material = Enum.Material.Cardboard, size = Vector3.new(1.4, 1.9, 1.0), priceCents = 249 },
			{ name = "Soup", color = Color3.fromRGB(184, 90, 72), material = Enum.Material.Metal, size = Vector3.new(1.3, 1.4, 1.3), priceCents = 199 },
			{ name = "Snacks", color = Color3.fromRGB(172, 122, 84), material = Enum.Material.Cardboard, size = Vector3.new(1.8, 1.4, 1.1), priceCents = 379 },
		},
	},
	{
		name = "Household",
		signColor = Color3.fromRGB(92, 88, 112),
		products = {
			{ name = "Detergent", color = Color3.fromRGB(94, 146, 196), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.5, 2.2, 1.2), priceCents = 899 },
			{ name = "Paper Towels", color = Color3.fromRGB(230, 228, 220), material = Enum.Material.SmoothPlastic, size = Vector3.new(2.2, 1.7, 1.5), priceCents = 699 },
			{ name = "Soap", color = Color3.fromRGB(148, 198, 182), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.5, 1.2, 1.1), priceCents = 329 },
			{ name = "Cleaners", color = Color3.fromRGB(188, 210, 92), material = Enum.Material.SmoothPlastic, size = Vector3.new(1.4, 2.0, 1.0), priceCents = 579 },
		},
	},
}

local function wrapIndex(index: number, count: number): number
	return ((math.floor(index) - 1) % count) + 1
end

function RetailCatalog.wrapDepartmentIndex(index: number): number
	return wrapIndex(index, #RetailCatalog.departments)
end

function RetailCatalog.getDepartment(index: number): DepartmentDefinition
	return RetailCatalog.departments[RetailCatalog.wrapDepartmentIndex(index)]
end

function RetailCatalog.wrapProductIndex(departmentIndex: number, index: number): number
	local department = RetailCatalog.getDepartment(departmentIndex)
	return wrapIndex(index, #department.products)
end

function RetailCatalog.getProduct(departmentIndex: number, productIndex: number): ProductDefinition
	local department = RetailCatalog.getDepartment(departmentIndex)
	return department.products[RetailCatalog.wrapProductIndex(departmentIndex, productIndex)]
end

return RetailCatalog
