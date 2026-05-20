print("[Client] roblox-game loaded")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hello = require(Shared:WaitForChild("Hello"))
local RetailAssets = require(Shared:WaitForChild("RetailAssets"))
local RetailCatalog = require(Shared:WaitForChild("RetailCatalog"))
local RetailCurrency = require(Shared:WaitForChild("RetailCurrency"))
local player = Players.LocalPlayer

local retailRemotes = ReplicatedStorage:WaitForChild("RetailRemotes", 3)
local usingFallbackRemotes = false
if not retailRemotes then
	warn("[Client] RetailRemotes did not replicate yet; HUD will still load with local fallback remotes.")
	retailRemotes = Instance.new("Folder")
	retailRemotes.Name = "RetailRemotes"
	usingFallbackRemotes = true
end

local function getRemoteEvent(name: string): RemoteEvent
	local remote = if usingFallbackRemotes then nil else retailRemotes:FindFirstChild(name) or retailRemotes:WaitForChild(name, 0.35)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	warn(`[Client] Missing RetailRemotes.{name}; UI will stay visible but this action needs server sync.`)
	local fallback = Instance.new("RemoteEvent")
	fallback.Name = name
	return fallback
end

local openShelfEditor = getRemoteEvent("OpenShelfEditor")
local selectShelfProduct = getRemoteEvent("SelectShelfProduct")
local openRegisterPanel = getRemoteEvent("OpenRegisterPanel")
local updateRegisterPanel = getRemoteEvent("UpdateRegisterPanel")
local adjustRegisterChange = getRemoteEvent("AdjustRegisterChange")
local resetRegisterChange = getRemoteEvent("ResetRegisterChange")
local finishRegisterSale = getRemoteEvent("FinishRegisterSale")
local openPlayerMenu = getRemoteEvent("OpenPlayerMenu")
local requestPetLottery = getRemoteEvent("RequestPetLottery")
local requestEquipPet = getRemoteEvent("RequestEquipPet")
local petInventoryUpdate = getRemoteEvent("PetInventoryUpdate")
local petLotteryResult = getRemoteEvent("PetLotteryResult")

print(Hello.greet("player"))

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("RetailHud")
if oldGui then
	oldGui:Destroy()
end

local function addCorner(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, color: Color3?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(86, 92, 104)
	stroke.Transparency = transparency or 0.35
	stroke.Thickness = 1
	stroke.Parent = instance
end

local function stylePanel(frame: Frame)
	addCorner(frame, 8)
	addStroke(frame)
end

local function styleButton(button: TextButton, radius: number?)
	addCorner(button, radius or 6)
	addStroke(button, Color3.fromRGB(255, 255, 255), 0.82)
	button.AutoButtonColor = true
end

local function styleResourceButton(button: ImageButton, image: string, radius: number?, backgroundColor: Color3?)
	addCorner(button, radius or 8)
	addStroke(button, Color3.fromRGB(255, 255, 255), 0.78)
	button.AutoButtonColor = true
	button.BackgroundColor3 = backgroundColor or Color3.fromRGB(42, 46, 54)
	button.BorderSizePixel = 0
	button.Image = image
	button.ImageColor3 = Color3.fromRGB(245, 245, 245)
	button.ScaleType = Enum.ScaleType.Fit
end

local gui = Instance.new("ScreenGui")
gui.Name = "RetailHud"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(1, -36, 0, 112)
panel.Position = UDim2.fromOffset(18, 18)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui
stylePanel(panel)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MaxSize = Vector2.new(760, 112)
panelSize.MinSize = Vector2.new(280, 112)
panelSize.Parent = panel

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "Stats"
statsLabel.Size = UDim2.new(1, -18, 0, 26)
statsLabel.Position = UDim2.fromOffset(9, 8)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
statsLabel.TextSize = 16
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Parent = panel

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.Size = UDim2.new(1, -18, 0, 24)
messageLabel.Position = UDim2.fromOffset(9, 36)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextColor3 = Color3.fromRGB(205, 218, 232)
messageLabel.TextSize = 14
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
messageLabel.Parent = panel

local storeLabel = messageLabel:Clone()
storeLabel.Name = "Store"
storeLabel.Position = UDim2.fromOffset(9, 60)
storeLabel.TextColor3 = Color3.fromRGB(184, 198, 214)
storeLabel.Parent = panel

local taskLabel = messageLabel:Clone()
taskLabel.Name = "TaskHint"
taskLabel.Position = UDim2.fromOffset(9, 84)
taskLabel.Font = Enum.Font.GothamBold
taskLabel.TextColor3 = Color3.fromRGB(245, 214, 142)
taskLabel.Parent = panel

local shelfPanel = Instance.new("Frame")
shelfPanel.Name = "ShelfPanel"
shelfPanel.Size = UDim2.fromOffset(390, 322)
shelfPanel.Position = UDim2.new(1, -408, 0, 18)
shelfPanel.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
shelfPanel.BackgroundTransparency = 0.08
shelfPanel.BorderSizePixel = 0
shelfPanel.Visible = false
shelfPanel.Parent = gui
stylePanel(shelfPanel)

local shelfTitle = Instance.new("TextLabel")
shelfTitle.Name = "Title"
shelfTitle.Size = UDim2.new(1, -44, 0, 28)
shelfTitle.Position = UDim2.fromOffset(14, 10)
shelfTitle.BackgroundTransparency = 1
shelfTitle.Font = Enum.Font.GothamBold
shelfTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
shelfTitle.TextSize = 16
shelfTitle.TextXAlignment = Enum.TextXAlignment.Left
shelfTitle.Parent = shelfPanel

local closeShelfButton = Instance.new("TextButton")
closeShelfButton.Name = "Close"
closeShelfButton.Size = UDim2.fromOffset(24, 24)
closeShelfButton.Position = UDim2.new(1, -34, 0, 10)
closeShelfButton.BackgroundColor3 = Color3.fromRGB(52, 56, 64)
closeShelfButton.BorderSizePixel = 0
closeShelfButton.Font = Enum.Font.GothamBold
closeShelfButton.Text = "X"
closeShelfButton.TextColor3 = Color3.fromRGB(235, 235, 235)
closeShelfButton.TextSize = 14
closeShelfButton.Parent = shelfPanel
styleButton(closeShelfButton, 5)

local departmentHeader = Instance.new("TextLabel")
departmentHeader.Name = "DepartmentHeader"
departmentHeader.Size = UDim2.fromOffset(158, 20)
departmentHeader.Position = UDim2.fromOffset(14, 48)
departmentHeader.BackgroundTransparency = 1
departmentHeader.Font = Enum.Font.GothamBold
departmentHeader.Text = "Department"
departmentHeader.TextColor3 = Color3.fromRGB(205, 218, 232)
departmentHeader.TextSize = 13
departmentHeader.TextXAlignment = Enum.TextXAlignment.Left
departmentHeader.Parent = shelfPanel

local productHeader = departmentHeader:Clone()
productHeader.Name = "ProductHeader"
productHeader.Position = UDim2.fromOffset(186, 48)
productHeader.Text = "Product"
productHeader.Parent = shelfPanel

local departmentList = Instance.new("Frame")
departmentList.Name = "DepartmentList"
departmentList.Size = UDim2.fromOffset(158, 176)
departmentList.Position = UDim2.fromOffset(14, 74)
departmentList.BackgroundTransparency = 1
departmentList.Parent = shelfPanel

local departmentLayout = Instance.new("UIListLayout")
departmentLayout.Padding = UDim.new(0, 6)
departmentLayout.Parent = departmentList

local productList = departmentList:Clone()
productList.Name = "ProductList"
productList.Position = UDim2.fromOffset(186, 74)
productList.Parent = shelfPanel

local productLayout = productList:FindFirstChildOfClass("UIListLayout")
if productLayout then
	productLayout.Parent = productList
end

local shelfInfo = Instance.new("TextLabel")
shelfInfo.Name = "ShelfInfo"
shelfInfo.Size = UDim2.new(1, -28, 0, 24)
shelfInfo.Position = UDim2.fromOffset(14, 256)
shelfInfo.BackgroundTransparency = 1
shelfInfo.Font = Enum.Font.Gotham
shelfInfo.TextColor3 = Color3.fromRGB(205, 218, 232)
shelfInfo.TextSize = 13
shelfInfo.TextXAlignment = Enum.TextXAlignment.Left
shelfInfo.TextTruncate = Enum.TextTruncate.AtEnd
shelfInfo.Parent = shelfPanel

local applyShelfButton = Instance.new("TextButton")
applyShelfButton.Name = "ApplyShelfProduct"
applyShelfButton.Size = UDim2.new(1, -28, 0, 34)
applyShelfButton.Position = UDim2.fromOffset(14, 282)
applyShelfButton.BackgroundColor3 = Color3.fromRGB(68, 124, 82)
applyShelfButton.BorderSizePixel = 0
applyShelfButton.Font = Enum.Font.GothamBold
applyShelfButton.Text = "Apply Product"
applyShelfButton.TextColor3 = Color3.fromRGB(245, 245, 245)
applyShelfButton.TextSize = 14
applyShelfButton.Parent = shelfPanel
styleButton(applyShelfButton, 7)

local registerPanel = Instance.new("Frame")
registerPanel.Name = "RegisterPanel"
registerPanel.Size = UDim2.fromOffset(420, 420)
registerPanel.Position = UDim2.new(1, -438, 0, 250)
registerPanel.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
registerPanel.BackgroundTransparency = 0.08
registerPanel.BorderSizePixel = 0
registerPanel.Visible = false
registerPanel.Parent = gui
stylePanel(registerPanel)

local registerTitle = Instance.new("TextLabel")
registerTitle.Name = "Title"
registerTitle.Size = UDim2.new(1, -44, 0, 28)
registerTitle.Position = UDim2.fromOffset(14, 10)
registerTitle.BackgroundTransparency = 1
registerTitle.Font = Enum.Font.GothamBold
registerTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
registerTitle.TextSize = 16
registerTitle.TextXAlignment = Enum.TextXAlignment.Left
registerTitle.Parent = registerPanel

local closeRegisterButton = closeShelfButton:Clone()
closeRegisterButton.Name = "Close"
closeRegisterButton.Parent = registerPanel

local registerSummary = Instance.new("TextLabel")
registerSummary.Name = "Summary"
registerSummary.Size = UDim2.new(1, -28, 0, 64)
registerSummary.Position = UDim2.fromOffset(14, 44)
registerSummary.BackgroundTransparency = 1
registerSummary.Font = Enum.Font.Gotham
registerSummary.TextColor3 = Color3.fromRGB(218, 226, 236)
registerSummary.TextSize = 14
registerSummary.TextWrapped = true
registerSummary.TextXAlignment = Enum.TextXAlignment.Left
registerSummary.TextYAlignment = Enum.TextYAlignment.Top
registerSummary.Parent = registerPanel

local changeHint = Instance.new("TextLabel")
changeHint.Name = "ChangeHint"
changeHint.Size = UDim2.new(1, -28, 0, 24)
changeHint.Position = UDim2.fromOffset(14, 110)
changeHint.BackgroundTransparency = 1
changeHint.Font = Enum.Font.GothamBold
changeHint.TextColor3 = Color3.fromRGB(245, 214, 142)
changeHint.TextSize = 13
changeHint.TextXAlignment = Enum.TextXAlignment.Left
changeHint.TextTruncate = Enum.TextTruncate.AtEnd
changeHint.Parent = registerPanel

local billHeader = Instance.new("TextLabel")
billHeader.Name = "BillHeader"
billHeader.Size = UDim2.fromOffset(184, 20)
billHeader.Position = UDim2.fromOffset(14, 226)
billHeader.BackgroundTransparency = 1
billHeader.Font = Enum.Font.GothamBold
billHeader.Text = "Bills"
billHeader.TextColor3 = Color3.fromRGB(205, 218, 232)
billHeader.TextSize = 13
billHeader.TextXAlignment = Enum.TextXAlignment.Left
billHeader.Parent = registerPanel

local coinHeader = billHeader:Clone()
coinHeader.Name = "CoinHeader"
coinHeader.Position = UDim2.fromOffset(220, 226)
coinHeader.Text = "Coins"
coinHeader.Parent = registerPanel

local receiptPreview = Instance.new("Frame")
receiptPreview.Name = "ReceiptPreview"
receiptPreview.Size = UDim2.new(1, -28, 0, 76)
receiptPreview.Position = UDim2.fromOffset(14, 140)
receiptPreview.BackgroundColor3 = Color3.fromRGB(236, 232, 218)
receiptPreview.BorderSizePixel = 0
receiptPreview.Parent = registerPanel
addCorner(receiptPreview, 6)
addStroke(receiptPreview, Color3.fromRGB(90, 88, 80), 0.72)

local receiptPreviewText = Instance.new("TextLabel")
receiptPreviewText.Name = "Text"
receiptPreviewText.Size = UDim2.new(1, -16, 1, -10)
receiptPreviewText.Position = UDim2.fromOffset(8, 5)
receiptPreviewText.BackgroundTransparency = 1
receiptPreviewText.Font = Enum.Font.Code
receiptPreviewText.Text = "Open a register to start a receipt."
receiptPreviewText.TextColor3 = Color3.fromRGB(38, 36, 30)
receiptPreviewText.TextSize = 12
receiptPreviewText.TextWrapped = true
receiptPreviewText.TextXAlignment = Enum.TextXAlignment.Left
receiptPreviewText.TextYAlignment = Enum.TextYAlignment.Top
receiptPreviewText.Parent = receiptPreview

local billGrid = Instance.new("Frame")
billGrid.Name = "BillGrid"
billGrid.Size = UDim2.fromOffset(184, 80)
billGrid.Position = UDim2.fromOffset(14, 252)
billGrid.BackgroundTransparency = 1
billGrid.Parent = registerPanel

local billLayout = Instance.new("UIGridLayout")
billLayout.CellPadding = UDim2.fromOffset(6, 6)
billLayout.CellSize = UDim2.fromOffset(89, 36)
billLayout.Parent = billGrid

local coinGrid = billGrid:Clone()
coinGrid.Name = "CoinGrid"
coinGrid.Position = UDim2.fromOffset(220, 252)
coinGrid.Parent = registerPanel

local registerButtons = Instance.new("Frame")
registerButtons.Name = "Actions"
registerButtons.Size = UDim2.new(1, -28, 0, 42)
registerButtons.Position = UDim2.fromOffset(14, 362)
registerButtons.BackgroundTransparency = 1
registerButtons.Parent = registerPanel

local registerButtonLayout = Instance.new("UIListLayout")
registerButtonLayout.FillDirection = Enum.FillDirection.Horizontal
registerButtonLayout.Padding = UDim.new(0, 8)
registerButtonLayout.Parent = registerButtons

local finishSaleButton = Instance.new("TextButton")
finishSaleButton.Name = "FinishSale"
finishSaleButton.Size = UDim2.fromOffset(180, 42)
finishSaleButton.BackgroundColor3 = Color3.fromRGB(68, 124, 82)
finishSaleButton.BorderSizePixel = 0
finishSaleButton.Font = Enum.Font.GothamBold
finishSaleButton.Text = "Finish Sale"
finishSaleButton.TextColor3 = Color3.fromRGB(245, 245, 245)
finishSaleButton.TextSize = 15
finishSaleButton.Parent = registerButtons
styleButton(finishSaleButton, 7)

local clearChangeButton = finishSaleButton:Clone()
clearChangeButton.Name = "ClearChange"
clearChangeButton.Size = UDim2.fromOffset(180, 42)
clearChangeButton.BackgroundColor3 = Color3.fromRGB(76, 80, 88)
clearChangeButton.Text = "Clear Change"
clearChangeButton.Parent = registerButtons

local actionDock = Instance.new("Frame")
actionDock.Name = "ActionDock"
actionDock.Size = UDim2.fromOffset(228, 78)
actionDock.Position = UDim2.fromOffset(18, 138)
actionDock.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
actionDock.BackgroundTransparency = 0.08
actionDock.BorderSizePixel = 0
actionDock.Parent = gui
stylePanel(actionDock)

local actionDockLayout = Instance.new("UIListLayout")
actionDockLayout.FillDirection = Enum.FillDirection.Horizontal
actionDockLayout.Padding = UDim.new(0, 8)
actionDockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionDockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionDockLayout.Parent = actionDock

local menuButton = Instance.new("ImageButton")
menuButton.Name = "PlayerMenuButton"
menuButton.Size = UDim2.fromOffset(62, 62)
menuButton.Parent = actionDock
styleResourceButton(menuButton, RetailAssets.buttons.Menu, 10, Color3.fromRGB(34, 42, 52))

local menuButtonLabel = Instance.new("TextLabel")
menuButtonLabel.Name = "Label"
menuButtonLabel.Size = UDim2.new(1, 0, 0, 16)
menuButtonLabel.Position = UDim2.new(0, 0, 1, -17)
menuButtonLabel.BackgroundTransparency = 1
menuButtonLabel.Font = Enum.Font.GothamBold
menuButtonLabel.Text = "MENU"
menuButtonLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
menuButtonLabel.TextSize = 10
menuButtonLabel.Parent = menuButton

local petsButton = Instance.new("ImageButton")
petsButton.Name = "PetsButton"
petsButton.Size = UDim2.fromOffset(62, 62)
petsButton.Parent = actionDock
styleResourceButton(petsButton, RetailAssets.buttons.Pets, 10, Color3.fromRGB(68, 58, 116))

local petsButtonLabel = menuButtonLabel:Clone()
petsButtonLabel.Text = "PETS"
petsButtonLabel.Parent = petsButton

local quickRollButton = Instance.new("ImageButton")
quickRollButton.Name = "QuickRollButton"
quickRollButton.Size = UDim2.fromOffset(62, 62)
quickRollButton.Parent = actionDock
styleResourceButton(quickRollButton, RetailAssets.buttons.Lottery, 10, Color3.fromRGB(70, 116, 82))

local quickRollButtonLabel = menuButtonLabel:Clone()
quickRollButtonLabel.Text = "ROLL"
quickRollButtonLabel.Parent = quickRollButton

local playerMenu = Instance.new("Frame")
playerMenu.Name = "PlayerMenu"
playerMenu.Size = UDim2.fromOffset(378, 448)
playerMenu.Position = UDim2.fromOffset(18, 226)
playerMenu.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
playerMenu.BackgroundTransparency = 0.06
playerMenu.BorderSizePixel = 0
playerMenu.Visible = false
playerMenu.Parent = gui
stylePanel(playerMenu)

local playerMenuTitle = Instance.new("TextLabel")
playerMenuTitle.Name = "Title"
playerMenuTitle.Size = UDim2.new(1, -58, 0, 28)
playerMenuTitle.Position = UDim2.fromOffset(14, 12)
playerMenuTitle.BackgroundTransparency = 1
playerMenuTitle.Font = Enum.Font.GothamBold
playerMenuTitle.Text = "Player Menu"
playerMenuTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
playerMenuTitle.TextSize = 17
playerMenuTitle.TextXAlignment = Enum.TextXAlignment.Left
playerMenuTitle.Parent = playerMenu

local closePlayerMenuButton = Instance.new("ImageButton")
closePlayerMenuButton.Name = "Close"
closePlayerMenuButton.Size = UDim2.fromOffset(32, 32)
closePlayerMenuButton.Position = UDim2.new(1, -44, 0, 10)
closePlayerMenuButton.Parent = playerMenu
styleResourceButton(closePlayerMenuButton, RetailAssets.buttons.Close, 7, Color3.fromRGB(58, 62, 70))

local playerMenuStats = Instance.new("TextLabel")
playerMenuStats.Name = "Stats"
playerMenuStats.Size = UDim2.new(1, -28, 0, 40)
playerMenuStats.Position = UDim2.fromOffset(14, 48)
playerMenuStats.BackgroundTransparency = 1
playerMenuStats.Font = Enum.Font.Gotham
playerMenuStats.TextColor3 = Color3.fromRGB(210, 222, 236)
playerMenuStats.TextSize = 13
playerMenuStats.TextWrapped = true
playerMenuStats.TextXAlignment = Enum.TextXAlignment.Left
playerMenuStats.TextYAlignment = Enum.TextYAlignment.Top
playerMenuStats.Parent = playerMenu

local lotteryPanel = Instance.new("Frame")
lotteryPanel.Name = "PetLottery"
lotteryPanel.Size = UDim2.new(1, -28, 0, 132)
lotteryPanel.Position = UDim2.fromOffset(14, 94)
lotteryPanel.BackgroundColor3 = Color3.fromRGB(31, 35, 42)
lotteryPanel.BorderSizePixel = 0
lotteryPanel.Parent = playerMenu
stylePanel(lotteryPanel)

local lotteryIcon = Instance.new("ImageLabel")
lotteryIcon.Name = "Icon"
lotteryIcon.Size = UDim2.fromOffset(64, 64)
lotteryIcon.Position = UDim2.fromOffset(12, 14)
lotteryIcon.BackgroundTransparency = 1
lotteryIcon.Image = RetailAssets.buttons.Lottery
lotteryIcon.ScaleType = Enum.ScaleType.Fit
lotteryIcon.Parent = lotteryPanel

local lotteryTitle = Instance.new("TextLabel")
lotteryTitle.Name = "Title"
lotteryTitle.Size = UDim2.new(1, -96, 0, 24)
lotteryTitle.Position = UDim2.fromOffset(88, 14)
lotteryTitle.BackgroundTransparency = 1
lotteryTitle.Font = Enum.Font.GothamBold
lotteryTitle.Text = "Pet Lottery"
lotteryTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
lotteryTitle.TextSize = 16
lotteryTitle.TextXAlignment = Enum.TextXAlignment.Left
lotteryTitle.Parent = lotteryPanel

local lotteryResult = lotteryTitle:Clone()
lotteryResult.Name = "Result"
lotteryResult.Position = UDim2.fromOffset(88, 40)
lotteryResult.Size = UDim2.new(1, -100, 0, 36)
lotteryResult.Font = Enum.Font.Gotham
lotteryResult.Text = "Roll to discover a pet"
lotteryResult.TextColor3 = Color3.fromRGB(208, 220, 234)
lotteryResult.TextSize = 13
lotteryResult.TextWrapped = true
lotteryResult.TextYAlignment = Enum.TextYAlignment.Top
lotteryResult.Parent = lotteryPanel

local rollPetButton = Instance.new("ImageButton")
rollPetButton.Name = "RollPet"
rollPetButton.Size = UDim2.fromOffset(152, 38)
rollPetButton.Position = UDim2.fromOffset(88, 82)
rollPetButton.Parent = lotteryPanel
styleResourceButton(rollPetButton, RetailAssets.buttons.Roll, 8, Color3.fromRGB(70, 116, 82))

local rollPetButtonLabel = Instance.new("TextLabel")
rollPetButtonLabel.Name = "Label"
rollPetButtonLabel.Size = UDim2.new(1, -42, 1, 0)
rollPetButtonLabel.Position = UDim2.fromOffset(36, 0)
rollPetButtonLabel.BackgroundTransparency = 1
rollPetButtonLabel.Font = Enum.Font.GothamBold
rollPetButtonLabel.Text = "Roll"
rollPetButtonLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
rollPetButtonLabel.TextSize = 13
rollPetButtonLabel.TextXAlignment = Enum.TextXAlignment.Left
rollPetButtonLabel.Parent = rollPetButton

local petHeader = Instance.new("TextLabel")
petHeader.Name = "PetHeader"
petHeader.Size = UDim2.new(1, -28, 0, 22)
petHeader.Position = UDim2.fromOffset(14, 238)
petHeader.BackgroundTransparency = 1
petHeader.Font = Enum.Font.GothamBold
petHeader.Text = "Pets"
petHeader.TextColor3 = Color3.fromRGB(205, 218, 232)
petHeader.TextSize = 14
petHeader.TextXAlignment = Enum.TextXAlignment.Left
petHeader.Parent = playerMenu

local petGrid = Instance.new("Frame")
petGrid.Name = "PetGrid"
petGrid.Size = UDim2.new(1, -28, 0, 112)
petGrid.Position = UDim2.fromOffset(14, 264)
petGrid.BackgroundTransparency = 1
petGrid.Parent = playerMenu

local petGridLayout = Instance.new("UIGridLayout")
petGridLayout.CellPadding = UDim2.fromOffset(8, 8)
petGridLayout.CellSize = UDim2.fromOffset(64, 104)
petGridLayout.Parent = petGrid

local equipPetButton = Instance.new("ImageButton")
equipPetButton.Name = "EquipPet"
equipPetButton.Size = UDim2.new(1, -28, 0, 40)
equipPetButton.Position = UDim2.fromOffset(14, 392)
equipPetButton.Parent = playerMenu
styleResourceButton(equipPetButton, RetailAssets.buttons.Equip, 8, Color3.fromRGB(68, 94, 132))

local equipPetButtonLabel = Instance.new("TextLabel")
equipPetButtonLabel.Name = "Label"
equipPetButtonLabel.Size = UDim2.new(1, -48, 1, 0)
equipPetButtonLabel.Position = UDim2.fromOffset(42, 0)
equipPetButtonLabel.BackgroundTransparency = 1
equipPetButtonLabel.Font = Enum.Font.GothamBold
equipPetButtonLabel.Text = "Select a pet"
equipPetButtonLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
equipPetButtonLabel.TextSize = 14
equipPetButtonLabel.TextXAlignment = Enum.TextXAlignment.Left
equipPetButtonLabel.Parent = equipPetButton

local renderPlayerMenu: (() -> ())? = nil

local function readStat(name: string): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	return if stat and stat:IsA("IntValue") then stat.Value else 0
end

local function readStoreAttribute(store: Instance?, name: string): number
	if not store then
		return 0
	end

	local value = store:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function readStoreOpen(store: Instance?): boolean
	if not store then
		return true
	end

	return store:GetAttribute("StoreOpen") ~= false
end

local function getTaskHint(shift: number, stock: number, lowStock: number, emptyShelves: number, basket: number, storeOpen: boolean, serviceQueue: number, serviceReturns: number): string
	if shift == 0 then
		return "Next: clock in at a time clock"
	end
	if not storeOpen then
		return "Next: open the store when shelves and register are ready"
	end
	if serviceQueue > 0 then
		return `Next: help {serviceQueue} service desk customers`
	end
	if serviceReturns > 0 then
		return `Next: process {serviceReturns} service returns`
	end
	if stock == 0 and lowStock > 0 then
		return "Next: grab stock from the stock room or loading pallet"
	end
	if emptyShelves > 0 then
		return `Next: restock {emptyShelves} empty shelves`
	end
	if lowStock > 0 then
		return `Next: top up {lowStock} low shelves`
	end
	if basket > 0 then
		return "Next: scan the basket at the player register"
	end
	return "Next: help shoppers, check departments, or run register"
end

local function updateHud()
	local shift = readStat("Shift")
	local shiftText = if shift == 1 then "On" else "Off"
	local store = Workspace:FindFirstChild("RetailStore")
	local lowStock = readStoreAttribute(store, "LowStockShelves")
	local emptyShelves = readStoreAttribute(store, "EmptyShelves")
	local activeShoppers = readStoreAttribute(store, "ActiveShoppers")
	local occupiedParking = readStoreAttribute(store, "OccupiedParkingSpots")
	local storeCash = readStoreAttribute(store, "StoreCashCents")
	local storeCustomers = readStoreAttribute(store, "StoreCustomers")
	local storeOpen = readStoreOpen(store)
	local storeStatus = if storeOpen then "Open" else "Closed"
	local serviceQueue = readStoreAttribute(store, "ServiceQueue")
	local serviceReturns = readStoreAttribute(store, "ServiceReturns")
	local serviceSatisfaction = readStoreAttribute(store, "ServiceSatisfaction")
	local basket = readStat("Basket")
	local stock = readStat("Stock")
	statsLabel.Text =
		`Cash {RetailCurrency.formatCents(readStat("Cash"))} | Basket {basket} ({RetailCurrency.formatCents(readStat("BasketValue"))}) | Stock {stock} | Shift {shiftText}`
	messageLabel.Text = player:GetAttribute("RetailMessage") or "Ready for work"
	storeLabel.Text =
		`Store {storeStatus} | Till {RetailCurrency.formatCents(storeCash)} | Customers {storeCustomers} | Shoppers {activeShoppers} | Service Q{serviceQueue}/R{serviceReturns}/S{serviceSatisfaction}`
	taskLabel.Text = getTaskHint(shift, stock, lowStock, emptyShelves, basket, storeOpen, serviceQueue, serviceReturns)
	if playerMenu.Visible and renderPlayerMenu then
		renderPlayerMenu()
	end
end

local currentShelfId: number? = nil
local selectedDepartmentIndex = 1
local selectedProductIndex = 1
local appliedDepartmentIndex = 1
local appliedProductIndex = 1
local currentShelfStock = 0
local currentShelfCapacity = 0
local currentRegisterId: string? = nil
local currentRegisterState = nil
local tenderButtons: { { button: TextButton, cents: number, color: Color3 } } = {}
local petInventory = nil
local selectedPetId: string? = nil
local lastPetResult = nil

local function clearButtons(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function clearImageButtons(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
end

local function createChoiceButton(parent: Instance, text: string, color: Color3, selected: boolean, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = if selected then color else Color3.fromRGB(48, 52, 58)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextSize = 14
	button.Parent = parent
	styleButton(button, 6)
	button.Activated:Connect(onClick)
end

local function setButtonEnabled(button: TextButton, enabled: boolean, baseColor: Color3?)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.TextTransparency = if enabled then 0 else 0.38
	button.BackgroundTransparency = if enabled then 0 else 0.42
	if baseColor then
		button.BackgroundColor3 = if enabled then baseColor else Color3.fromRGB(60, 62, 66)
	end
end

local function setResourceButtonEnabled(button: ImageButton, enabled: boolean, baseColor: Color3?)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.ImageTransparency = if enabled then 0 else 0.45
	button.BackgroundTransparency = if enabled then 0 else 0.35
	if baseColor then
		button.BackgroundColor3 = if enabled then baseColor else Color3.fromRGB(60, 62, 66)
	end
	for _, child in button:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextTransparency = if enabled then 0 else 0.4
		end
	end
end

local function getPetEntries()
	if petInventory and typeof(petInventory) == "table" and typeof(petInventory.pets) == "table" then
		return petInventory.pets
	end

	local pets = {}
	for _, pet in RetailAssets.pets do
		table.insert(pets, {
			id = pet.id,
			name = pet.name,
			rarity = pet.rarity,
			image = pet.image,
			color = pet.color,
			perk = pet.perk,
			count = 0,
			equipped = false,
		})
	end
	return pets
end

local function findPetEntry(petId: string?)
	if not petId then
		return nil
	end

	for _, pet in getPetEntries() do
		if pet.id == petId then
			return pet
		end
	end

	return nil
end

local function rarityColor(rarity: string?): Color3
	if rarity == "Legendary" then
		return Color3.fromRGB(245, 205, 88)
	elseif rarity == "Epic" then
		return Color3.fromRGB(184, 122, 226)
	elseif rarity == "Rare" then
		return Color3.fromRGB(88, 190, 146)
	end
	return Color3.fromRGB(205, 218, 232)
end

local function getPetRollDiscountCents(): number
	local attributeDiscount = player:GetAttribute("PetRollDiscountCents")
	if typeof(attributeDiscount) == "number" and attributeDiscount > 0 then
		return math.max(0, math.floor(attributeDiscount))
	end
	if petInventory and petInventory.rollDiscountCents then
		return math.max(0, math.floor(petInventory.rollDiscountCents))
	end
	return 0
end

local function getPetRollCostCents(): number
	local discount = getPetRollDiscountCents()
	if discount > 0 then
		return math.max(100, RetailAssets.petLottery.rollCostCents - discount)
	end
	return if petInventory and petInventory.rollCostCents then petInventory.rollCostCents else RetailAssets.petLottery.rollCostCents
end

local function createPetSlot(pet)
	local owned = math.max(0, math.floor(pet.count or 0))
	local selected = selectedPetId == pet.id
	local button = Instance.new("ImageButton")
	button.Name = pet.id
	button.Image = pet.image
	button.ImageColor3 = if owned > 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(92, 96, 104)
	button.ImageTransparency = if owned > 0 then 0 else 0.35
	button.BackgroundColor3 = if selected then rarityColor(pet.rarity) else Color3.fromRGB(38, 42, 50)
	button.BorderSizePixel = 0
	button.ScaleType = Enum.ScaleType.Fit
	button.Parent = petGrid
	addCorner(button, 8)
	addStroke(button, if selected then rarityColor(pet.rarity) else Color3.fromRGB(255, 255, 255), if selected then 0.2 else 0.78)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -6, 0, 30)
	nameLabel.Position = UDim2.new(0, 3, 1, -34)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = pet.name
	nameLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	nameLabel.TextSize = 10
	nameLabel.TextWrapped = true
	nameLabel.Parent = button

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.fromOffset(28, 18)
	countLabel.Position = UDim2.new(1, -30, 0, 3)
	countLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	countLabel.BorderSizePixel = 0
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Text = `x{owned}`
	countLabel.TextColor3 = if owned > 0 then rarityColor(pet.rarity) else Color3.fromRGB(150, 154, 162)
	countLabel.TextSize = 10
	countLabel.Parent = button
	addCorner(countLabel, 5)

	if pet.equipped then
		local equippedLabel = Instance.new("TextLabel")
		equippedLabel.Name = "Equipped"
		equippedLabel.Size = UDim2.fromOffset(46, 18)
		equippedLabel.Position = UDim2.fromOffset(3, 3)
		equippedLabel.BackgroundColor3 = Color3.fromRGB(54, 120, 76)
		equippedLabel.BorderSizePixel = 0
		equippedLabel.Font = Enum.Font.GothamBold
		equippedLabel.Text = "ON"
		equippedLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
		equippedLabel.TextSize = 10
		equippedLabel.Parent = button
		addCorner(equippedLabel, 5)
	end

	button.Activated:Connect(function()
		if owned <= 0 then
			return
		end
		selectedPetId = pet.id
		if renderPlayerMenu then
			renderPlayerMenu()
		end
	end)
end

renderPlayerMenu = function()
	local cost = getPetRollCostCents()
	local discount = getPetRollDiscountCents()
	local rollsUntilRare = if petInventory and petInventory.rollsUntilRare then petInventory.rollsUntilRare else RetailAssets.petLottery.rarePityRolls
	local perkText = if petInventory and petInventory.equippedPerk then petInventory.equippedPerk else "No pet equipped"
	local discountText = if discount > 0 then ` | Care discount {RetailCurrency.formatCents(discount)}` else ""
	playerMenuStats.Text =
		`Cash {RetailCurrency.formatCents(readStat("Cash"))} | Pets {readStat("Pets")}
Roll {RetailCurrency.formatCents(cost)}{discountText} | Rare safety in {rollsUntilRare} | {perkText}`

	rollPetButtonLabel.Text = `Roll {RetailCurrency.formatCents(cost)}`
	setResourceButtonEnabled(rollPetButton, readStat("Cash") >= cost, Color3.fromRGB(70, 116, 82))

	if lastPetResult then
		lotteryIcon.Image = lastPetResult.image
		local refundText = if lastPetResult.duplicateRefundCents and lastPetResult.duplicateRefundCents > 0
			then ` | Refund {RetailCurrency.formatCents(lastPetResult.duplicateRefundCents)}`
			else ""
		local safetyText = if lastPetResult.guaranteedRare then "Safety roll hit" else lastPetResult.perk or "Companion unlocked"
		lotteryResult.Text = `{lastPetResult.rarity} | {lastPetResult.name} | Owned x{lastPetResult.count}{refundText}
{safetyText}`
		lotteryResult.TextColor3 = rarityColor(lastPetResult.rarity)
	else
		lotteryIcon.Image = RetailAssets.buttons.Lottery
		lotteryResult.Text = `Roll to discover a pet
Rare safety in {rollsUntilRare}`
		lotteryResult.TextColor3 = Color3.fromRGB(208, 220, 234)
	end

	clearImageButtons(petGrid)
	local firstOwnedId: string? = nil
	for _, pet in getPetEntries() do
		if (pet.count or 0) > 0 and not firstOwnedId then
			firstOwnedId = pet.id
		end
		if pet.equipped then
			selectedPetId = pet.id
		end
	end

	if not selectedPetId then
		selectedPetId = firstOwnedId
	end
	local activeSelection = findPetEntry(selectedPetId)
	if not activeSelection or (activeSelection.count or 0) <= 0 then
		selectedPetId = firstOwnedId
	end

	for _, pet in getPetEntries() do
		createPetSlot(pet)
	end

	local selectedPet = findPetEntry(selectedPetId)
	local canEquip = selectedPet ~= nil and (selectedPet.count or 0) > 0
	if not selectedPet then
		equipPetButtonLabel.Text = "Select a pet"
	elseif selectedPet.equipped then
		equipPetButtonLabel.Text = `Unequip {selectedPet.name}`
	elseif canEquip then
		equipPetButtonLabel.Text = `Equip {selectedPet.name}`
	else
		equipPetButtonLabel.Text = "Pet not owned"
	end
	setResourceButtonEnabled(equipPetButton, canEquip, Color3.fromRGB(68, 94, 132))
end

local function createTenderButton(parent: Instance, denomination)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = denomination.color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = denomination.name
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextSize = 15
	button.Parent = parent
	styleButton(button, 6)
	table.insert(tenderButtons, {
		button = button,
		cents = denomination.cents,
		color = denomination.color,
	})
	button.Activated:Connect(function()
		if currentRegisterId and currentRegisterState then
			if currentRegisterState.completed then
				return
			end

			local remaining = currentRegisterState.changeRemainingCents
				or math.max(0, currentRegisterState.changeDueCents - currentRegisterState.changeGivenCents)
			if denomination.cents > remaining then
				return
			end

			adjustRegisterChange:FireServer(currentRegisterId, denomination.cents)
		end
	end)
end

for _, denomination in RetailCurrency.denominations do
	if denomination.kind == "bill" then
		createTenderButton(billGrid, denomination)
	else
		createTenderButton(coinGrid, denomination)
	end
end

local function refreshTenderButtons(state)
	local remaining = state.changeRemainingCents or math.max(0, state.changeDueCents - state.changeGivenCents)
	for _, tender in tenderButtons do
		setButtonEnabled(tender.button, tender.cents <= remaining and state.completed ~= true, tender.color)
	end
end

local function buildRegisterReceiptPreview(state): string
	if typeof(state.receiptText) == "string" then
		return state.receiptText
	end

	local lines = {
		`Receipt #{state.receiptNumber or "--"}`,
	}
	if typeof(state.items) == "table" then
		for index, itemLine in state.items do
			if index <= 4 then
				table.insert(lines, tostring(itemLine))
			end
		end
		if #state.items > 4 then
			table.insert(lines, `+{#state.items - 4} more items`)
		end
	end
	table.insert(lines, `Total {RetailCurrency.formatCents(state.totalCents)}`)
	table.insert(lines, `Paid {RetailCurrency.formatCents(state.paidCents)} | Change {RetailCurrency.formatCents(state.changeDueCents)}`)
	return table.concat(lines, "\n")
end

local function renderRegisterPanel(state)
	currentRegisterState = state
	currentRegisterId = state.registerId
	registerTitle.Text = if state.completed then "Receipt Printed" else `Player Register #{state.receiptNumber or "--"}`
	registerSummary.Text = `Items {state.itemCount} | Total {RetailCurrency.formatCents(state.totalCents)}
Customer paid {RetailCurrency.formatCents(state.paidCents)} | Change due {RetailCurrency.formatCents(state.changeDueCents)}
Change given {RetailCurrency.formatCents(state.changeGivenCents)}`
	receiptPreviewText.Text = buildRegisterReceiptPreview(state)

	local remaining = state.changeRemainingCents or math.max(0, state.changeDueCents - state.changeGivenCents)
	local over = state.changeOverCents or math.max(0, state.changeGivenCents - state.changeDueCents)
	if state.completed then
		changeHint.Text = "Receipt printed. Next customer loading..."
		changeHint.TextColor3 = Color3.fromRGB(160, 226, 168)
	elseif over > 0 then
		changeHint.Text = `Over by {RetailCurrency.formatCents(over)} | Clear change and try again`
		changeHint.TextColor3 = Color3.fromRGB(244, 140, 118)
	elseif remaining == 0 then
		changeHint.Text = "Exact change ready | Print receipt"
		changeHint.TextColor3 = Color3.fromRGB(160, 226, 168)
	else
		changeHint.Text = `Remaining {RetailCurrency.formatCents(remaining)} | Try {state.suggestedTender or "smallest change"}`
		changeHint.TextColor3 = Color3.fromRGB(245, 214, 142)
	end

	local canFinish = remaining == 0 and over == 0 and state.completed ~= true
	finishSaleButton.Text = if state.completed then "Receipt Printed" elseif canFinish then "Print Receipt" else `Need {RetailCurrency.formatCents(remaining)}`
	setButtonEnabled(finishSaleButton, canFinish, Color3.fromRGB(68, 124, 82))
	setButtonEnabled(clearChangeButton, state.completed ~= true and (state.changeGivenCents or 0) > 0, Color3.fromRGB(76, 80, 88))
	refreshTenderButtons(state)
end

local function renderShelfEditor()
	local department = RetailCatalog.getDepartment(selectedDepartmentIndex)
	local product = RetailCatalog.getProduct(selectedDepartmentIndex, selectedProductIndex)
	local changed = selectedDepartmentIndex ~= appliedDepartmentIndex or selectedProductIndex ~= appliedProductIndex
	local stockText = if currentShelfCapacity > 0 then `Stock {currentShelfStock}/{currentShelfCapacity} | ` else ""
	shelfTitle.Text = `Shelf {currentShelfId or "-"} | {department.name}: {product.name}`
	shelfInfo.Text = `{stockText}{RetailCurrency.formatCents(product.priceCents)} each | {if changed then "Apply product, then restock" else "Current shelf assignment"}`
	applyShelfButton.Text = if changed then `Assign {product.name}` else "Current Shelf Product"
	setButtonEnabled(applyShelfButton, changed and currentShelfId ~= nil, product.color)

	clearButtons(departmentList)
	for departmentIndex, departmentOption in RetailCatalog.departments do
		createChoiceButton(
			departmentList,
			departmentOption.name,
			departmentOption.signColor,
			departmentIndex == selectedDepartmentIndex,
			function()
				selectedDepartmentIndex = departmentIndex
				selectedProductIndex = 1
				renderShelfEditor()
			end
		)
	end

	clearButtons(productList)
	for productIndex, productOption in department.products do
		createChoiceButton(productList, productOption.name, productOption.color, productIndex == selectedProductIndex, function()
			selectedProductIndex = productIndex
			renderShelfEditor()
		end)
	end
end

local function connectStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	for _, stat in leaderstats:GetChildren() do
		if stat:IsA("IntValue") then
			stat.Changed:Connect(updateHud)
		end
	end

	leaderstats.ChildAdded:Connect(function(stat)
		if stat:IsA("IntValue") then
			stat.Changed:Connect(updateHud)
			updateHud()
		end
	end)
end

local storeConnections: { RBXScriptConnection } = {}
local function connectStoreStatus(store: Instance)
	for _, connection in storeConnections do
		connection:Disconnect()
	end
	table.clear(storeConnections)

	for _, attributeName in {
		"LowStockShelves",
		"EmptyShelves",
		"ActiveShoppers",
		"OccupiedParkingSpots",
		"StoreCashCents",
		"StoreCustomers",
		"StoreOpen",
		"ServiceQueue",
		"ServiceReturns",
		"ServicePickupOrders",
		"ServiceBags",
		"ServiceSatisfaction",
	} do
		table.insert(storeConnections, store:GetAttributeChangedSignal(attributeName):Connect(updateHud))
	end
	updateHud()
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		connectStats()
		updateHud()
	end
end)
player:GetAttributeChangedSignal("RetailMessage"):Connect(updateHud)
player:GetAttributeChangedSignal("PetRollDiscountCents"):Connect(function()
	if playerMenu.Visible and renderPlayerMenu then
		renderPlayerMenu()
	end
	updateHud()
end)
local existingStore = Workspace:FindFirstChild("RetailStore")
if existingStore then
	connectStoreStatus(existingStore)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "RetailStore" then
		connectStoreStatus(child)
	end
end)
connectStats()
updateHud()

closeShelfButton.Activated:Connect(function()
	shelfPanel.Visible = false
end)

openShelfEditor.OnClientEvent:Connect(function(shelfId: number, departmentIndex: number, productIndex: number, shelfStock: number?, shelfCapacity: number?)
	currentShelfId = shelfId
	currentShelfStock = math.max(0, math.floor(shelfStock or 0))
	currentShelfCapacity = math.max(0, math.floor(shelfCapacity or 0))
	appliedDepartmentIndex = RetailCatalog.wrapDepartmentIndex(departmentIndex)
	appliedProductIndex = RetailCatalog.wrapProductIndex(appliedDepartmentIndex, productIndex)
	selectedDepartmentIndex = appliedDepartmentIndex
	selectedProductIndex = appliedProductIndex
	shelfPanel.Visible = true
	renderShelfEditor()
end)

applyShelfButton.Activated:Connect(function()
	if not currentShelfId then
		return
	end
	if selectedDepartmentIndex == appliedDepartmentIndex and selectedProductIndex == appliedProductIndex then
		return
	end

	selectShelfProduct:FireServer(currentShelfId, selectedDepartmentIndex, selectedProductIndex)
	appliedDepartmentIndex = selectedDepartmentIndex
	appliedProductIndex = selectedProductIndex
	currentShelfStock = 0
	shelfInfo.Text = "Applied. Restock this shelf to put items out."
	renderShelfEditor()
end)

closeRegisterButton.Activated:Connect(function()
	registerPanel.Visible = false
	currentRegisterState = nil
end)

clearChangeButton.Activated:Connect(function()
	if currentRegisterState and currentRegisterState.completed then
		return
	end
	if currentRegisterId then
		resetRegisterChange:FireServer(currentRegisterId)
	end
end)

finishSaleButton.Activated:Connect(function()
	if currentRegisterId and currentRegisterState then
		if currentRegisterState.completed then
			return
		end

		local remaining = currentRegisterState.changeRemainingCents
			or math.max(0, currentRegisterState.changeDueCents - currentRegisterState.changeGivenCents)
		local over = currentRegisterState.changeOverCents
			or math.max(0, currentRegisterState.changeGivenCents - currentRegisterState.changeDueCents)
		if remaining ~= 0 or over ~= 0 then
			return
		end

		finishRegisterSale:FireServer(currentRegisterId)
	end
end)

openRegisterPanel.OnClientEvent:Connect(function(state)
	registerPanel.Visible = true
	renderRegisterPanel(state)
end)

updateRegisterPanel.OnClientEvent:Connect(function(state)
	if currentRegisterId == state.registerId then
		renderRegisterPanel(state)
	end
end)

local function showPlayerMenu(focus: string?)
	playerMenu.Visible = true
	playerMenuTitle.Text = if focus == "pets" then "Pet Lottery" else "Player Menu"
	if renderPlayerMenu then
		renderPlayerMenu()
	end
end

menuButton.Activated:Connect(function()
	playerMenu.Visible = not playerMenu.Visible
	if playerMenu.Visible then
		showPlayerMenu()
	end
end)

petsButton.Activated:Connect(function()
	showPlayerMenu("pets")
end)

closePlayerMenuButton.Activated:Connect(function()
	playerMenu.Visible = false
end)

local function requestPetRoll()
	local cost = getPetRollCostCents()
	showPlayerMenu("pets")
	if readStat("Cash") < cost then
		lotteryResult.Text = `Need {RetailCurrency.formatCents(cost)} to roll`
		lotteryResult.TextColor3 = Color3.fromRGB(244, 140, 118)
		return
	end
	requestPetLottery:FireServer()
end

rollPetButton.Activated:Connect(function()
	requestPetRoll()
end)

quickRollButton.Activated:Connect(function()
	requestPetRoll()
end)

equipPetButton.Activated:Connect(function()
	local selectedPet = findPetEntry(selectedPetId)
	if not selectedPet or (selectedPet.count or 0) <= 0 then
		return
	end

	if selectedPet.equipped then
		requestEquipPet:FireServer("")
	else
		requestEquipPet:FireServer(selectedPet.id)
	end
end)

petInventoryUpdate.OnClientEvent:Connect(function(payload)
	petInventory = payload
	if playerMenu.Visible and renderPlayerMenu then
		renderPlayerMenu()
	end
	updateHud()
end)

petLotteryResult.OnClientEvent:Connect(function(result)
	lastPetResult = result
	selectedPetId = result.id
	showPlayerMenu("pets")
end)

openPlayerMenu.OnClientEvent:Connect(function(focus: string?)
	showPlayerMenu(focus)
end)
