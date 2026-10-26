-- Canonical Roblox-space metadata. One unit is one stud; Y is up.
-- Checkout authored in Blender, mapped (x, y, z) -> (x, z, -y).
return {
	checkout_01 = {
		version = 1,
		boundsMin = Vector3.new(-2.3, 0, -4.5),
		boundsMax = Vector3.new(5.55, 6.155, 4.5),
		anchors = {
			Scanner = Vector3.new(0, 3.7, -1.45),
			CashDrawer = Vector3.new(-0.8, 3.94, -1.9),
			MonitorScreen = Vector3.new(-0.8, 5.26, -2.667),
			ReceiptPaper = Vector3.new(1.1, 4.12, -2.92),
		},
		collisions = {
			{ center = Vector3.new(0, 1.75, 0), size = Vector3.new(4.2, 3.5, 8.6) },
			{ center = Vector3.new(3.95, 3.23, -2.2), size = Vector3.new(3.2, 0.28, 4.2) },
		},
	},
	gondola_01 = {
		version = 1,
		boundsMin = Vector3.new(-6.065, 0, -1.99),
		boundsMax = Vector3.new(6.065, 8.5, 1.99),
		collisions = {
			{ center = Vector3.new(0, 4.25, 0), size = Vector3.new(12.13, 8.5, 3.98) },
		},
	},
}
