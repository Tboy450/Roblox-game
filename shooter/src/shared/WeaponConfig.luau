local WeaponConfig = {}

WeaponConfig.order = {
	"hand_cannon",
	"pulse_rifle",
	"scattergun",
}

WeaponConfig.weapons = {
	hand_cannon = {
		id = "hand_cannon",
		displayName = "Hand Cannon",
		price = 0,
		damage = 38,
		headshotMultiplier = 1.75,
		fireInterval = 0.45,
		magazineSize = 8,
		reserveAmmo = 40,
		reloadTime = 1.55,
		range = 420,
		pellets = 1,
		spreadDegrees = 0.25,
		automatic = false,
		tracerColor = Color3.fromRGB(255, 92, 118),
	},
	pulse_rifle = {
		id = "pulse_rifle",
		displayName = "Pulse Rifle",
		price = 250,
		damage = 18,
		headshotMultiplier = 1.55,
		fireInterval = 0.1,
		magazineSize = 30,
		reserveAmmo = 120,
		reloadTime = 1.8,
		range = 520,
		pellets = 1,
		spreadDegrees = 0.45,
		automatic = true,
		tracerColor = Color3.fromRGB(65, 218, 255),
	},
	scattergun = {
		id = "scattergun",
		displayName = "Scattergun",
		price = 325,
		damage = 12,
		headshotMultiplier = 1.2,
		fireInterval = 0.8,
		magazineSize = 6,
		reserveAmmo = 30,
		reloadTime = 2.3,
		range = 190,
		pellets = 8,
		spreadDegrees = 5.5,
		automatic = false,
		tracerColor = Color3.fromRGB(255, 170, 65),
	},
}

function WeaponConfig.get(weaponId: string)
	return WeaponConfig.weapons[weaponId]
end

function WeaponConfig.createTool(weaponId: string): Tool?
	local weapon = WeaponConfig.get(weaponId)
	if not weapon then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = weapon.displayName
	tool.ToolTip = `{weapon.displayName} | R to reload`
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("ShooterWeapon", true)
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Ammo", weapon.magazineSize)
	tool:SetAttribute("ReserveAmmo", weapon.reserveAmmo)
	tool:SetAttribute("Reloading", false)
	return tool
end

return WeaponConfig
