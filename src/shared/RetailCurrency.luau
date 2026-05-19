local RetailCurrency = {}

export type Denomination = {
	name: string,
	cents: number,
	kind: "bill" | "coin",
	color: Color3,
}

RetailCurrency.denominations = {
	{ name = "$20", cents = 2000, kind = "bill", color = Color3.fromRGB(104, 156, 112) },
	{ name = "$10", cents = 1000, kind = "bill", color = Color3.fromRGB(92, 138, 102) },
	{ name = "$5", cents = 500, kind = "bill", color = Color3.fromRGB(84, 124, 94) },
	{ name = "$1", cents = 100, kind = "bill", color = Color3.fromRGB(74, 110, 84) },
	{ name = "25c", cents = 25, kind = "coin", color = Color3.fromRGB(180, 182, 184) },
	{ name = "10c", cents = 10, kind = "coin", color = Color3.fromRGB(168, 170, 174) },
	{ name = "5c", cents = 5, kind = "coin", color = Color3.fromRGB(146, 148, 152) },
	{ name = "1c", cents = 1, kind = "coin", color = Color3.fromRGB(170, 108, 74) },
}

function RetailCurrency.formatCents(cents: number): string
	local safeCents = math.max(0, math.floor(cents))
	local dollars = math.floor(safeCents / 100)
	local remainder = safeCents % 100
	return string.format("$%d.%02d", dollars, remainder)
end

return RetailCurrency
