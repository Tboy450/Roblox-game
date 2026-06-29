local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")
local mouse = player:GetMouse()

local shared = ReplicatedStorage:WaitForChild("ShooterShared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))
local remotes = ReplicatedStorage:WaitForChild("ShooterRemotes")
local fireWeapon = remotes:WaitForChild("FireWeapon") :: RemoteEvent
local reloadWeapon = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local weaponEffect = remotes:WaitForChild("WeaponEffect") :: RemoteEvent
local openShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent
local purchaseItem = remotes:WaitForChild("PurchaseItem") :: RemoteEvent
local shopFeedback = remotes:WaitForChild("ShopFeedback") :: RemoteEvent
local getShopCatalog = remotes:WaitForChild("GetShopCatalog") :: RemoteFunction

local oldGui = playerGui:FindFirstChild("ShooterHUD")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShooterHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(parent: GuiObject, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function stroke(parent: GuiObject, color: Color3, thickness: number)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = thickness
	value.Transparency = 0.25
	value.Parent = parent
end

local statusPanel = Instance.new("Frame")
statusPanel.Name = "StatusPanel"
statusPanel.AnchorPoint = Vector2.new(1, 1)
statusPanel.Position = UDim2.new(1, -22, 1, -24)
statusPanel.Size = UDim2.fromOffset(280, 88)
statusPanel.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
statusPanel.BackgroundTransparency = 0.08
statusPanel.BorderSizePixel = 0
statusPanel.Parent = gui
corner(statusPanel, 10)
stroke(statusPanel, Color3.fromRGB(57, 210, 236), 1.5)

local weaponLabel = Instance.new("TextLabel")
weaponLabel.BackgroundTransparency = 1
weaponLabel.Position = UDim2.fromOffset(14, 9)
weaponLabel.Size = UDim2.new(1, -28, 0, 28)
weaponLabel.Font = Enum.Font.GothamBold
weaponLabel.Text = "NO WEAPON EQUIPPED"
weaponLabel.TextColor3 = Color3.fromRGB(225, 234, 243)
weaponLabel.TextSize = 18
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Parent = statusPanel

local ammoLabel = Instance.new("TextLabel")
ammoLabel.BackgroundTransparency = 1
ammoLabel.Position = UDim2.fromOffset(14, 37)
ammoLabel.Size = UDim2.new(1, -28, 0, 34)
ammoLabel.Font = Enum.Font.GothamBlack
ammoLabel.Text = "-- / --"
ammoLabel.TextColor3 = Color3.fromRGB(74, 221, 242)
ammoLabel.TextSize = 28
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.Parent = statusPanel

local hintLabel = Instance.new("TextLabel")
hintLabel.BackgroundTransparency = 1
hintLabel.AnchorPoint = Vector2.new(1, 1)
hintLabel.Position = UDim2.new(1, -12, 1, -8)
hintLabel.Size = UDim2.fromOffset(130, 20)
hintLabel.Font = Enum.Font.Gotham
hintLabel.Text = "FIRE • R RELOAD"
hintLabel.TextColor3 = Color3.fromRGB(145, 157, 170)
hintLabel.TextSize = 11
hintLabel.TextXAlignment = Enum.TextXAlignment.Right
hintLabel.Parent = statusPanel

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Name = "Credits"
creditsLabel.Position = UDim2.fromOffset(20, 18)
creditsLabel.Size = UDim2.fromOffset(190, 42)
creditsLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
creditsLabel.BackgroundTransparency = 0.08
creditsLabel.BorderSizePixel = 0
creditsLabel.Font = Enum.Font.GothamBold
creditsLabel.Text = "CREDITS  --"
creditsLabel.TextColor3 = Color3.fromRGB(255, 205, 79)
creditsLabel.TextSize = 18
creditsLabel.Parent = gui
corner(creditsLabel, 10)
stroke(creditsLabel, Color3.fromRGB(255, 192, 62), 1.2)

local crosshair = Instance.new("TextLabel")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(34, 34)
crosshair.BackgroundTransparency = 1
crosshair.Font = Enum.Font.GothamBold
crosshair.Text = "+"
crosshair.TextColor3 = Color3.fromRGB(235, 242, 248)
crosshair.TextSize = 28
crosshair.TextStrokeTransparency = 0.45
crosshair.Parent = gui

local shopShade = Instance.new("Frame")
shopShade.Name = "ShopShade"
shopShade.Size = UDim2.fromScale(1, 1)
shopShade.BackgroundColor3 = Color3.new(0, 0, 0)
shopShade.BackgroundTransparency = 0.38
shopShade.BorderSizePixel = 0
shopShade.Visible = false
shopShade.Parent = gui

local shopFrame = Instance.new("Frame")
shopFrame.Name = "Shop"
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.Position = UDim2.fromScale(0.5, 0.5)
shopFrame.Size = UDim2.fromOffset(560, 510)
shopFrame.BackgroundColor3 = Color3.fromRGB(17, 23, 31)
shopFrame.BorderSizePixel = 0
shopFrame.Parent = shopShade
corner(shopFrame, 14)
stroke(shopFrame, Color3.fromRGB(58, 216, 239), 2)

local shopTitle = Instance.new("TextLabel")
shopTitle.BackgroundTransparency = 1
shopTitle.Position = UDim2.fromOffset(20, 12)
shopTitle.Size = UDim2.new(1, -80, 0, 40)
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.Text = "SHOOTER LOADOUT SHOP"
shopTitle.TextColor3 = Color3.fromRGB(77, 222, 242)
shopTitle.TextSize = 23
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Parent = shopFrame

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.fromOffset(40, 40)
closeButton.BackgroundColor3 = Color3.fromRGB(47, 57, 69)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(235, 240, 245)
closeButton.TextSize = 28
closeButton.Parent = shopFrame
corner(closeButton, 8)

local shopCredits = Instance.new("TextLabel")
shopCredits.BackgroundTransparency = 1
shopCredits.Position = UDim2.fromOffset(20, 53)
shopCredits.Size = UDim2.new(1, -40, 0, 25)
shopCredits.Font = Enum.Font.GothamBold
shopCredits.Text = "Available: -- Credits"
shopCredits.TextColor3 = Color3.fromRGB(255, 205, 79)
shopCredits.TextSize = 15
shopCredits.TextXAlignment = Enum.TextXAlignment.Left
shopCredits.Parent = shopFrame

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.Position = UDim2.fromOffset(18, 84)
list.Size = UDim2.new(1, -36, 1, -139)
list.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
list.BackgroundTransparency = 0.25
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Color3.fromRGB(63, 201, 224)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = shopFrame
corner(list, 9)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = list

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.AnchorPoint = Vector2.new(0.5, 1)
feedbackLabel.Position = UDim2.new(0.5, 0, 1, -10)
feedbackLabel.Size = UDim2.new(1, -36, 0, 34)
feedbackLabel.Font = Enum.Font.GothamBold
feedbackLabel.Text = "Walk to the shop terminal to buy or refill weapons."
feedbackLabel.TextColor3 = Color3.fromRGB(169, 181, 194)
feedbackLabel.TextSize = 13
feedbackLabel.TextWrapped = true
feedbackLabel.Parent = shopFrame

local activeTool: Tool? = nil
local firing = false
local registeredTools = setmetatable({}, { __mode = "k" })

local function updateWeaponHud()
	if not activeTool or not activeTool.Parent then
		weaponLabel.Text = "NO WEAPON EQUIPPED"
		ammoLabel.Text = "-- / --"
		return
	end
	local weaponId = activeTool:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then WeaponConfig.get(weaponId) else nil
	weaponLabel.Text = if weapon then string.upper(weapon.displayName) else string.upper(activeTool.Name)
	local ammo = activeTool:GetAttribute("Ammo")
	local reserve = activeTool:GetAttribute("ReserveAmmo")
	if typeof(ammo) == "number" and typeof(reserve) == "number" then
		ammoLabel.Text = `{ammo} / {reserve}`
	else
		ammoLabel.Text = "READY"
	end
	if activeTool:GetAttribute("Reloading") == true then
		ammoLabel.Text = "RELOADING..."
	end
end

local function aimPosition(): Vector3
	if mouse and mouse.Hit then
		return mouse.Hit.Position
	end
	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position + camera.CFrame.LookVector * 500
	end
	return Vector3.zero
end

local function fireOnce(tool: Tool)
	if tool ~= activeTool or tool.Parent ~= player.Character then
		return
	end
	local weaponId = tool:GetAttribute("WeaponId")
	if typeof(weaponId) ~= "string" then
		return
	end
	local ammo = tool:GetAttribute("Ammo")
	if typeof(ammo) == "number" and ammo <= 0 then
		reloadWeapon:FireServer(weaponId)
		return
	end
	fireWeapon:FireServer(weaponId, aimPosition())
end

local function registerTool(tool: Tool)
	if registeredTools[tool] or tool:GetAttribute("ShooterWeapon") ~= true then
		return
	end
	registeredTools[tool] = true

	tool.Equipped:Connect(function()
		activeTool = tool
		updateWeaponHud()
	end)
	tool.Unequipped:Connect(function()
		firing = false
		if activeTool == tool then
			activeTool = nil
		end
		updateWeaponHud()
	end)
	tool.Activated:Connect(function()
		if activeTool ~= tool or firing then
			return
		end
		local weaponId = tool:GetAttribute("WeaponId")
		local weapon = if typeof(weaponId) == "string" then WeaponConfig.get(weaponId) else nil
		if not weapon then
			return
		end
		firing = true
		task.spawn(function()
			repeat
				fireOnce(tool)
				task.wait(weapon.fireInterval)
			until not firing or not weapon.automatic or activeTool ~= tool
			if not weapon.automatic then
				firing = false
			end
		end)
	end)
	tool.Deactivated:Connect(function()
		firing = false
	end)
	tool:GetAttributeChangedSignal("Ammo"):Connect(updateWeaponHud)
	tool:GetAttributeChangedSignal("ReserveAmmo"):Connect(updateWeaponHud)
	tool:GetAttributeChangedSignal("Reloading"):Connect(updateWeaponHud)
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			registerTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			registerTool(child)
		end
	end)
end

watchContainer(backpack)
player.CharacterAdded:Connect(function(character)
	activeTool = nil
	firing = false
	watchContainer(character)
	updateWeaponHud()
end)
if player.Character then
	watchContainer(player.Character)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R and activeTool then
		local weaponId = activeTool:GetAttribute("WeaponId")
		if typeof(weaponId) == "string" then
			reloadWeapon:FireServer(weaponId)
		end
	elseif input.KeyCode == Enum.KeyCode.Escape and shopShade.Visible then
		shopShade.Visible = false
	end
end)

local function clearRows()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addShopRow(item, order: number)
	local row = Instance.new("Frame")
	row.Name = item.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -2, 0, 66)
	row.BackgroundColor3 = Color3.fromRGB(30, 39, 50)
	row.BorderSizePixel = 0
	row.Parent = list
	corner(row, 8)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(14, 7)
	name.Size = UDim2.new(1, -160, 0, 26)
	name.Font = Enum.Font.GothamBold
	name.Text = item.displayName
	name.TextColor3 = Color3.fromRGB(231, 238, 245)
	name.TextSize = 17
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local kind = Instance.new("TextLabel")
	kind.BackgroundTransparency = 1
	kind.Position = UDim2.fromOffset(14, 34)
	kind.Size = UDim2.new(1, -160, 0, 20)
	kind.Font = Enum.Font.Gotham
	kind.Text = if item.kind == "LegacyTool" then "CLASSIC ARENA WEAPON" else "SHOOTER WEAPON • REFILLS AVAILABLE"
	kind.TextColor3 = Color3.fromRGB(139, 153, 168)
	kind.TextSize = 11
	kind.TextXAlignment = Enum.TextXAlignment.Left
	kind.Parent = row

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)
	buy.Size = UDim2.fromOffset(126, 44)
	buy.BackgroundColor3 = Color3.fromRGB(41, 156, 181)
	buy.BorderSizePixel = 0
	buy.Font = Enum.Font.GothamBold
	buy.Text = if item.price <= 0 then "FREE" else `{item.price} CREDITS`
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.TextSize = 13
	buy.Parent = row
	corner(buy, 7)
	buy.Activated:Connect(function()
		buy.Text = "WORKING..."
		purchaseItem:FireServer(item.id)
		task.delay(0.8, function()
			if buy.Parent then
				buy.Text = if item.price <= 0 then "FREE" else `{item.price} CREDITS`
			end
		end)
	end)
end

local function refreshShop()
	local ok, data = pcall(function()
		return getShopCatalog:InvokeServer()
	end)
	if not ok or typeof(data) ~= "table" then
		feedbackLabel.Text = "Shop server did not respond. Try again."
		feedbackLabel.TextColor3 = Color3.fromRGB(255, 119, 119)
		return
	end
	clearRows()
	shopCredits.Text = `Available: {data.credits or 0} Credits`
	for index, item in data.items or {} do
		addShopRow(item, index)
	end
end

local function showShop()
	shopShade.Visible = true
	feedbackLabel.Text = "Choose a weapon. Buying an owned Shooter weapon refills its ammo."
	feedbackLabel.TextColor3 = Color3.fromRGB(169, 181, 194)
	refreshShop()
end

closeButton.Activated:Connect(function()
	shopShade.Visible = false
end)
openShopRemote.OnClientEvent:Connect(showShop)
shopFeedback.OnClientEvent:Connect(function(success, message, newCredits)
	feedbackLabel.Text = tostring(message)
	feedbackLabel.TextColor3 = if success then Color3.fromRGB(112, 236, 157) else Color3.fromRGB(255, 119, 119)
	if typeof(newCredits) == "number" then
		shopCredits.Text = `Available: {newCredits} Credits`
	end
end)

local function bindCredits()
	local leaderstats = player:WaitForChild("leaderstats", 20)
	local credits = leaderstats and leaderstats:WaitForChild("Credits", 20)
	if not credits or not credits:IsA("IntValue") then
		return
	end
	local function update()
		creditsLabel.Text = `CREDITS  {credits.Value}`
	end
	update()
	credits:GetPropertyChangedSignal("Value"):Connect(update)
end
task.spawn(bindCredits)

weaponEffect.OnClientEvent:Connect(function(origin, finish, color, shooterUserId, didHit)
	if typeof(origin) ~= "Vector3" or typeof(finish) ~= "Vector3" then
		return
	end
	local distance = (finish - origin).Magnitude
	if distance > 0.05 then
		local tracer = Instance.new("Part")
		tracer.Name = "ShooterTracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.CanTouch = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
		tracer.Size = Vector3.new(0.08, 0.08, distance)
		tracer.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
		tracer.Parent = workspace
		Debris:AddItem(tracer, 0.08)
	end
	if shooterUserId == player.UserId and didHit == true then
		crosshair.TextColor3 = Color3.fromRGB(255, 91, 91)
		task.delay(0.09, function()
			if crosshair.Parent then
				crosshair.TextColor3 = Color3.fromRGB(235, 242, 248)
			end
		end)
	end
end)

print("[Shooter] HUD, weapon controls, and shop interface connected.")
