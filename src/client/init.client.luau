print("[Client] roblox-game loaded")

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldBootGui = playerGui:FindFirstChild("RetailHudBoot")
if oldBootGui then
	oldBootGui:Destroy()
end

local bootGui = Instance.new("ScreenGui")
bootGui.Name = "RetailHudBoot"
bootGui.ResetOnSpawn = false
bootGui.DisplayOrder = 49
bootGui.Parent = playerGui

local bootLabel = Instance.new("TextLabel")
bootLabel.Name = "Status"
bootLabel.Size = UDim2.fromOffset(220, 32)
bootLabel.Position = UDim2.fromOffset(18, 18)
bootLabel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
bootLabel.BackgroundTransparency = 0.08
bootLabel.BorderSizePixel = 0
bootLabel.Font = Enum.Font.GothamBold
bootLabel.Text = "Retail HUD loading..."
bootLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
bootLabel.TextSize = 13
bootLabel.Parent = bootGui

bootLabel.Text = "Retail HUD: waiting for Shared"
local Shared = ReplicatedStorage:WaitForChild("Shared", 15)
if not Shared then
	bootLabel.Text = "Retail HUD missing ReplicatedStorage.Shared"
	error("[Client] ReplicatedStorage.Shared did not replicate.")
end

local function requireSharedModule(name: string)
	bootLabel.Text = `Retail HUD: loading {name}`
	local module = Shared:WaitForChild(name, 15)
	if not module then
		bootLabel.Text = `Retail HUD missing {name}`
		error(`[Client] ReplicatedStorage.Shared.{name} did not replicate.`)
	end

	local ok, result = pcall(require, module)
	if not ok then
		bootLabel.Text = `Retail HUD error in {name}`
		error(result)
	end
	return result
end

local Hello = requireSharedModule("Hello")
local RetailAssets = requireSharedModule("RetailAssets")
local RetailCatalog = requireSharedModule("RetailCatalog")
local RetailCurrency = requireSharedModule("RetailCurrency")
bootLabel.Text = "Retail HUD building..."

local REMOTE_WAIT_SECONDS = 5

local function findRetailRemotes(timeoutSeconds: number?): Instance?
	local retailRemotes = ReplicatedStorage:FindFirstChild("RetailRemotes")
	if retailRemotes then
		return retailRemotes
	end

	return ReplicatedStorage:WaitForChild("RetailRemotes", timeoutSeconds or 0)
end

local function resolveRemoteEvent(name: string, timeoutSeconds: number?): RemoteEvent?
	local retailRemotes = findRetailRemotes(timeoutSeconds)
	if not retailRemotes then
		return nil
	end

	local remote = retailRemotes:FindFirstChild(name)
	if not remote then
		remote = retailRemotes:WaitForChild(name, timeoutSeconds or 0)
	end
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		warn(`[Client] RetailRemotes.{name} is a {remote.ClassName}, not a RemoteEvent.`)
	end
	return nil
end

local function fireServerRemote(name: string, ...)
	local remote = resolveRemoteEvent(name, REMOTE_WAIT_SECONDS)
	if not remote then
		warn(`[Client] RetailRemotes.{name} is unavailable; action was not sent.`)
		return
	end

	remote:FireServer(...)
end

local function connectClientRemote(name: string, callback)
	task.spawn(function()
		local remote = resolveRemoteEvent(name, REMOTE_WAIT_SECONDS)
		while not remote do
			warn(`[Client] Waiting for RetailRemotes.{name}; related menu may not open yet.`)
			task.wait(1)
			remote = resolveRemoteEvent(name, REMOTE_WAIT_SECONDS)
		end

		remote.OnClientEvent:Connect(callback)
	end)
end

print(Hello.greet("player"))

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
gui.DisplayOrder = 50
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

local closeHudButton = Instance.new("TextButton")
closeHudButton.Name = "CloseHud"
closeHudButton.Size = UDim2.fromOffset(26, 24)
closeHudButton.Position = UDim2.new(1, -34, 0, 8)
closeHudButton.BackgroundColor3 = Color3.fromRGB(52, 56, 64)
closeHudButton.BorderSizePixel = 0
closeHudButton.Font = Enum.Font.GothamBold
closeHudButton.Text = "X"
closeHudButton.TextColor3 = Color3.fromRGB(235, 235, 235)
closeHudButton.TextSize = 13
closeHudButton.Parent = panel
styleButton(closeHudButton, 5)

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "Stats"
statsLabel.Size = UDim2.new(1, -54, 0, 26)
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

local shelfPanelScale = Instance.new("UIScale")
shelfPanelScale.Parent = shelfPanel

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

local registerPanelScale = Instance.new("UIScale")
registerPanelScale.Parent = registerPanel

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
actionDock.Size = UDim2.fromOffset(298, 78)
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

local actionButtons: { ImageButton } = {}
local actionButtonLabels: { TextLabel } = {}

local function createActionDockButton(name: string, labelText: string, image: string, color: Color3): (ImageButton, TextLabel)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.Size = UDim2.fromOffset(58, 58)
	button.Parent = actionDock
	styleResourceButton(button, image, 10, color)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.new(0, 0, 1, -17)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 10
	label.Parent = button

	table.insert(actionButtons, button)
	table.insert(actionButtonLabels, label)
	return button, label
end

local hudButton, hudButtonLabel = createActionDockButton("HudButton", "HUD", RetailAssets.buttons.Hud, Color3.fromRGB(54, 68, 86))
local menuButton, menuButtonLabel =
	createActionDockButton("PlayerMenuButton", "MENU", RetailAssets.buttons.Menu, Color3.fromRGB(34, 42, 52))
local controlsButton, controlsButtonLabel =
	createActionDockButton("ControlsButton", "HELP", RetailAssets.buttons.Controls, Color3.fromRGB(66, 78, 98))
local petsButton, petsButtonLabel = createActionDockButton("PetsButton", "PETS", RetailAssets.buttons.Pets, Color3.fromRGB(68, 58, 116))
local stockButton, stockButtonLabel =
	createActionDockButton("StockButton", "STOCK", RetailAssets.buttons.Stock, Color3.fromRGB(88, 112, 78))
local storeButton, storeButtonLabel =
	createActionDockButton("StoreButton", "CLOSE", RetailAssets.buttons.StoreOpen, Color3.fromRGB(56, 116, 74))
local cashButton, cashButtonLabel = createActionDockButton("CashButton", "CASH", RetailAssets.buttons.Cash, Color3.fromRGB(104, 88, 58))

local quickPanel = Instance.new("Frame")
quickPanel.Name = "QuickPanel"
quickPanel.Size = UDim2.fromOffset(298, 150)
quickPanel.Position = UDim2.fromOffset(18, 226)
quickPanel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
quickPanel.BackgroundTransparency = 0.06
quickPanel.BorderSizePixel = 0
quickPanel.Visible = false
quickPanel.Parent = gui
stylePanel(quickPanel)

local quickPanelAccent = Instance.new("Frame")
quickPanelAccent.Name = "Accent"
quickPanelAccent.Size = UDim2.new(1, -20, 0, 4)
quickPanelAccent.Position = UDim2.fromOffset(10, 5)
quickPanelAccent.BackgroundColor3 = Color3.fromRGB(88, 190, 146)
quickPanelAccent.BorderSizePixel = 0
quickPanelAccent.Parent = quickPanel
addCorner(quickPanelAccent, 3)

local quickPanelTitle = Instance.new("TextLabel")
quickPanelTitle.Name = "Title"
quickPanelTitle.Size = UDim2.new(1, -58, 0, 24)
quickPanelTitle.Position = UDim2.fromOffset(14, 14)
quickPanelTitle.BackgroundTransparency = 1
quickPanelTitle.Font = Enum.Font.GothamBold
quickPanelTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
quickPanelTitle.TextSize = 15
quickPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
quickPanelTitle.Parent = quickPanel

local quickPanelClose = Instance.new("ImageButton")
quickPanelClose.Name = "Close"
quickPanelClose.Size = UDim2.fromOffset(30, 30)
quickPanelClose.Position = UDim2.new(1, -42, 0, 10)
quickPanelClose.Parent = quickPanel
styleResourceButton(quickPanelClose, RetailAssets.buttons.Close, 7, Color3.fromRGB(58, 62, 70))

local quickPanelBody = Instance.new("TextLabel")
quickPanelBody.Name = "Body"
quickPanelBody.Size = UDim2.new(1, -28, 0, 52)
quickPanelBody.Position = UDim2.fromOffset(14, 44)
quickPanelBody.BackgroundTransparency = 1
quickPanelBody.Font = Enum.Font.Gotham
quickPanelBody.TextColor3 = Color3.fromRGB(210, 222, 236)
quickPanelBody.TextSize = 13
quickPanelBody.TextWrapped = true
quickPanelBody.TextXAlignment = Enum.TextXAlignment.Left
quickPanelBody.TextYAlignment = Enum.TextYAlignment.Top
quickPanelBody.Parent = quickPanel

local quickPanelAction = Instance.new("ImageButton")
quickPanelAction.Name = "Action"
quickPanelAction.Size = UDim2.new(1, -28, 0, 34)
quickPanelAction.Position = UDim2.fromOffset(14, 104)
quickPanelAction.Parent = quickPanel
styleResourceButton(quickPanelAction, RetailAssets.buttons.OrderStock, 7, Color3.fromRGB(88, 112, 78))

local quickPanelActionLabel = Instance.new("TextLabel")
quickPanelActionLabel.Name = "Label"
quickPanelActionLabel.Size = UDim2.new(1, -44, 1, 0)
quickPanelActionLabel.Position = UDim2.fromOffset(40, 0)
quickPanelActionLabel.BackgroundTransparency = 1
quickPanelActionLabel.Font = Enum.Font.GothamBold
quickPanelActionLabel.Text = "Order Stock"
quickPanelActionLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
quickPanelActionLabel.TextSize = 13
quickPanelActionLabel.TextXAlignment = Enum.TextXAlignment.Left
quickPanelActionLabel.Parent = quickPanelAction

local quickPanelMode: string? = nil

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

local playerMenuAccent = Instance.new("Frame")
playerMenuAccent.Name = "Accent"
playerMenuAccent.Size = UDim2.new(1, -20, 0, 4)
playerMenuAccent.Position = UDim2.fromOffset(10, 5)
playerMenuAccent.BackgroundColor3 = Color3.fromRGB(88, 190, 146)
playerMenuAccent.BorderSizePixel = 0
playerMenuAccent.Parent = playerMenu
addCorner(playerMenuAccent, 3)

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

local lotteryAccent = Instance.new("Frame")
lotteryAccent.Name = "Accent"
lotteryAccent.Size = UDim2.fromOffset(5, 96)
lotteryAccent.Position = UDim2.fromOffset(0, 18)
lotteryAccent.BackgroundColor3 = Color3.fromRGB(245, 205, 88)
lotteryAccent.BorderSizePixel = 0
lotteryAccent.Parent = lotteryPanel
addCorner(lotteryAccent, 4)

local lotteryIcon = Instance.new("ImageLabel")
lotteryIcon.Name = "Icon"
lotteryIcon.Size = UDim2.fromOffset(64, 64)
lotteryIcon.Position = UDim2.fromOffset(12, 14)
lotteryIcon.BackgroundTransparency = 0
lotteryIcon.Image = ""
lotteryIcon.ScaleType = Enum.ScaleType.Fit
lotteryIcon.Parent = lotteryPanel
addCorner(lotteryIcon, 10)
addStroke(lotteryIcon, Color3.fromRGB(255, 255, 255), 0.82)

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

local carePetButton = Instance.new("ImageButton")
carePetButton.Name = "CarePet"
carePetButton.Size = UDim2.fromOffset(104, 38)
carePetButton.Position = UDim2.fromOffset(248, 82)
carePetButton.Parent = lotteryPanel
styleResourceButton(carePetButton, RetailAssets.buttons.Care, 8, Color3.fromRGB(94, 112, 142))

local carePetButtonLabel = Instance.new("TextLabel")
carePetButtonLabel.Name = "Label"
carePetButtonLabel.Size = UDim2.new(1, -36, 1, 0)
carePetButtonLabel.Position = UDim2.fromOffset(34, 0)
carePetButtonLabel.BackgroundTransparency = 1
carePetButtonLabel.Font = Enum.Font.GothamBold
carePetButtonLabel.Text = "Care"
carePetButtonLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
carePetButtonLabel.TextSize = 13
carePetButtonLabel.TextXAlignment = Enum.TextXAlignment.Left
carePetButtonLabel.Parent = carePetButton

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

local petGrid = Instance.new("ScrollingFrame")
petGrid.Name = "PetGrid"
petGrid.Size = UDim2.new(1, -28, 0, 112)
petGrid.Position = UDim2.fromOffset(14, 264)
petGrid.BackgroundTransparency = 1
petGrid.BorderSizePixel = 0
petGrid.CanvasSize = UDim2.fromOffset(0, 0)
petGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
petGrid.ScrollingDirection = Enum.ScrollingDirection.Y
petGrid.ScrollBarThickness = 4
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
local renderQuickPanel: (() -> ())? = nil

local function fitPanelScale(baseWidth: number, baseHeight: number, viewport: Vector2, xPad: number, yPad: number): number
	local widthScale = (viewport.X - xPad * 2) / baseWidth
	local heightScale = (viewport.Y - yPad * 2) / baseHeight
	return math.clamp(math.min(widthScale, heightScale, 1), 0.72, 1)
end

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local topInset = GuiService:GetGuiInset()
	local compact = viewport.X < 900 or viewport.Y < 720
	local xPad = if viewport.X < 700 then 12 else 18
	local yPad = if viewport.Y < 620 or topInset.Y > 48 then 12 else 18
	local availableWidth = math.max(260, viewport.X - xPad * 2)

	local panelWidth = math.min(760, availableWidth)
	panel.Position = UDim2.fromOffset(xPad, yPad)
	panel.Size = UDim2.fromOffset(panelWidth, 112)
	closeHudButton.Position = UDim2.new(1, -34, 0, 8)

	local dockPadding = if compact then 5 else 7
	local maxDockButtonSize = if compact then 42 else 58
	local dockButtonSize = math.clamp(
		math.floor((availableWidth - 20 - dockPadding * math.max(0, #actionButtons - 1)) / #actionButtons),
		36,
		maxDockButtonSize
	)
	local dockHeight = dockButtonSize + 16
	local dockWidth = dockButtonSize * #actionButtons + dockPadding * math.max(0, #actionButtons - 1) + 20
	actionDock.Position = UDim2.fromOffset(xPad, yPad + 120)
	actionDock.Size = UDim2.fromOffset(dockWidth, dockHeight)
	actionDockLayout.Padding = UDim.new(0, dockPadding)
	for _, button in actionButtons do
		button.Size = UDim2.fromOffset(dockButtonSize, dockButtonSize)
	end
	for _, label in actionButtonLabels do
		label.Position = UDim2.new(0, 0, 1, -17)
		label.TextSize = if compact then 9 else 10
	end

	local menuTop = yPad + 120 + dockHeight + 10
	local quickPanelHeight = if quickPanelMode == "controls" then if compact then 232 else 260 else if compact then 142 else 150
	local quickBodyHeight = if quickPanelMode == "controls" then quickPanelHeight - 62 else if compact then 46 else 52
	quickPanel.Position = UDim2.fromOffset(xPad, menuTop)
	quickPanel.Size = UDim2.fromOffset(math.min(360, availableWidth), quickPanelHeight)
	quickPanelAccent.Size = UDim2.new(1, -20, 0, 4)
	quickPanelTitle.TextSize = if compact then 14 else 15
	quickPanelClose.Position = UDim2.new(1, -42, 0, 10)
	quickPanelBody.Size = UDim2.new(1, -28, 0, quickBodyHeight)
	quickPanelBody.TextSize = if compact then 12 else 13
	quickPanelAction.Position = UDim2.fromOffset(14, if compact then 98 else 104)
	quickPanelAction.Size = UDim2.new(1, -28, 0, 34)
	quickPanelActionLabel.TextSize = if compact then 12 else 13

	local menuWidth = math.min(if compact then 360 else 408, availableWidth)
	local menuHeight = math.min(if compact then 430 else 448, math.max(320, viewport.Y - menuTop - yPad))
	playerMenu.Position = UDim2.fromOffset(xPad, menuTop)
	playerMenu.Size = UDim2.fromOffset(menuWidth, menuHeight)
	playerMenuAccent.Size = UDim2.new(1, -20, 0, 4)
	playerMenuTitle.TextSize = if compact then 16 else 17
	closePlayerMenuButton.Position = UDim2.new(1, -44, 0, 10)
	playerMenuStats.Position = UDim2.fromOffset(14, if compact then 44 else 48)
	playerMenuStats.Size = UDim2.new(1, -28, 0, if compact then 34 else 40)
	playerMenuStats.TextSize = if compact then 12 else 13

	local lotteryTop = if compact then 84 else 94
	local lotteryHeight = if compact then 108 else 132
	local lotteryIconSize = if compact then 50 else 64
	local lotteryTextX = if compact then 74 else 88
	lotteryPanel.Position = UDim2.fromOffset(14, lotteryTop)
	lotteryPanel.Size = UDim2.new(1, -28, 0, lotteryHeight)
	lotteryAccent.Size = UDim2.fromOffset(5, math.max(64, lotteryHeight - 34))
	lotteryAccent.Position = UDim2.fromOffset(0, 17)
	lotteryIcon.Size = UDim2.fromOffset(lotteryIconSize, lotteryIconSize)
	lotteryIcon.Position = UDim2.fromOffset(12, if compact then 12 else 14)
	lotteryTitle.Position = UDim2.fromOffset(lotteryTextX, 12)
	lotteryTitle.Size = UDim2.new(1, -(lotteryTextX + 10), 0, 22)
	lotteryTitle.TextSize = if compact then 15 else 16
	lotteryResult.Position = UDim2.fromOffset(lotteryTextX, if compact then 34 else 40)
	lotteryResult.Size = UDim2.new(1, -(lotteryTextX + 12), 0, if compact then 30 else 36)
	lotteryResult.TextSize = if compact then 12 else 13
	local lotteryButtonWidth = math.min(if compact then 118 else 140, math.max(96, (menuWidth - lotteryTextX - 38) / 2))
	rollPetButton.Position = UDim2.fromOffset(lotteryTextX, lotteryHeight - 42)
	rollPetButton.Size = UDim2.fromOffset(lotteryButtonWidth, 34)
	rollPetButtonLabel.TextSize = if compact then 12 else 13
	carePetButton.Position = UDim2.fromOffset(lotteryTextX + lotteryButtonWidth + 8, lotteryHeight - 42)
	carePetButton.Size = UDim2.fromOffset(lotteryButtonWidth, 34)
	carePetButtonLabel.TextSize = if compact then 12 else 13

	local petHeaderTop = lotteryTop + lotteryHeight + 8
	local petGridTop = petHeaderTop + 24
	local equipTop = menuHeight - (if compact then 48 else 56)
	petHeader.Position = UDim2.fromOffset(14, petHeaderTop)
	petHeader.TextSize = if compact then 13 else 14
	petGrid.Position = UDim2.fromOffset(14, petGridTop)
	petGrid.Size = UDim2.new(1, -28, 0, math.max(28, equipTop - petGridTop - 8))
	petGridLayout.CellPadding = UDim2.fromOffset(if compact then 6 else 8, if compact then 6 else 8)
	petGridLayout.CellSize = UDim2.fromOffset(if compact then 58 else 64, if compact then 88 else 104)
	equipPetButton.Position = UDim2.fromOffset(14, equipTop)
	equipPetButton.Size = UDim2.new(1, -28, 0, 40)
	equipPetButtonLabel.TextSize = if compact then 13 else 14

	local shelfScale = fitPanelScale(390, 322, viewport, xPad, yPad)
	shelfPanelScale.Scale = shelfScale
	shelfPanel.Position = UDim2.fromOffset(math.max(xPad, viewport.X - 390 * shelfScale - xPad), yPad)

	local registerScale = fitPanelScale(420, 420, viewport, xPad, yPad)
	registerPanelScale.Scale = registerScale
	registerPanel.Position = UDim2.fromOffset(
		math.max(xPad, viewport.X - 420 * registerScale - xPad),
		math.max(yPad, math.min(250, viewport.Y - 420 * registerScale - yPad))
	)

	if playerMenu.Visible and renderPlayerMenu then
		renderPlayerMenu()
	end
end

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

local function setQuickPanelAction(label: string, image: string, color: Color3, visible: boolean, enabled: boolean)
	quickPanelAction.Visible = visible
	quickPanelAction.Active = enabled
	quickPanelAction.AutoButtonColor = enabled
	quickPanelAction.Image = image
	quickPanelAction.ImageTransparency = if enabled then 0 else 0.45
	quickPanelAction.BackgroundColor3 = if enabled then color else Color3.fromRGB(60, 62, 66)
	quickPanelAction.BackgroundTransparency = if enabled then 0 else 0.35
	quickPanelActionLabel.Text = label
	quickPanelActionLabel.TextTransparency = if enabled then 0 else 0.4
end

renderQuickPanel = function()
	local store = Workspace:FindFirstChild("RetailStore")
	local lowStock = readStoreAttribute(store, "LowStockShelves")
	local emptyShelves = readStoreAttribute(store, "EmptyShelves")
	local storeCash = readStoreAttribute(store, "StoreCashCents")
	local openingTill = readStoreAttribute(store, "StoreStartingTillCents")
	local tenderReceived = readStoreAttribute(store, "StoreTenderReceivedCents")
	local changePaid = readStoreAttribute(store, "StoreChangePaidCents")
	local netSales = readStoreAttribute(store, "StoreNetSalesCents")
	local storeCustomers = readStoreAttribute(store, "StoreCustomers")
	local serviceBags = readStoreAttribute(store, "ServiceBags")
	local stockOrders = readStat("StockOrders")
	local storeOpen = readStoreOpen(store)
	local storeStatus = if storeOpen then "Open" else "Closed"
	local onShift = readStat("Shift") == 1

	if quickPanelMode == "stock" then
		quickPanelAccent.BackgroundColor3 = Color3.fromRGB(104, 142, 112)
		quickPanelTitle.Text = "Stock"
		quickPanelBody.Text =
			`Carried {readStat("Stock")} | Low shelves {lowStock} | Empty shelves {emptyShelves}`
			.. "\n"
			.. `Service bags {serviceBags}/12 | Orders {stockOrders} | Tasks {readStat("Tasks")}`
		setQuickPanelAction(
			if onShift then "Order Stock $3" else "Clock In First",
			RetailAssets.buttons.OrderStock,
			Color3.fromRGB(88, 112, 78),
			true,
			onShift and readStat("Cash") >= 300
		)
	elseif quickPanelMode == "cash" then
		quickPanelAccent.BackgroundColor3 = Color3.fromRGB(190, 150, 82)
		quickPanelTitle.Text = "Cash"
		quickPanelBody.Text =
			`Cash {RetailCurrency.formatCents(readStat("Cash"))} | Basket {RetailCurrency.formatCents(readStat("BasketValue"))}`
			.. "\n"
			.. `Till {RetailCurrency.formatCents(storeCash)} | Start {RetailCurrency.formatCents(openingTill)} | Sales {RetailCurrency.formatCents(netSales)}`
			.. "\n"
			.. `Tender {RetailCurrency.formatCents(tenderReceived)} | Change {RetailCurrency.formatCents(changePaid)} | Customers {storeCustomers}`
		setQuickPanelAction("Run Register", RetailAssets.buttons.Register, Color3.fromRGB(104, 88, 58), false, false)
	elseif quickPanelMode == "store" then
		quickPanelAccent.BackgroundColor3 = if storeOpen then Color3.fromRGB(88, 190, 146) else Color3.fromRGB(210, 116, 92)
		quickPanelTitle.Text = "Store"
		quickPanelBody.Text =
			`Status {storeStatus} | Shoppers {readStoreAttribute(store, "ActiveShoppers")} | Parking {readStoreAttribute(store, "OccupiedParkingSpots")}`
			.. "\n"
			.. `Traffic accepting customers: {if storeOpen then "yes" else "no"}`
		setQuickPanelAction(if storeOpen then "Close Store" else "Open Store", if storeOpen then RetailAssets.buttons.StoreClosed else RetailAssets.buttons.StoreOpen, if storeOpen then Color3.fromRGB(132, 72, 62) else Color3.fromRGB(56, 116, 74), true, true)
	elseif quickPanelMode == "controls" then
		quickPanelAccent.BackgroundColor3 = Color3.fromRGB(112, 132, 170)
		quickPanelTitle.Text = "Controls"
		quickPanelBody.Text =
			"Move: WASD or thumbstick\n"
			.. "Jump: Space or controller jump\n"
			.. "Use prompts: E, tap, or controller interact\n"
			.. "Clock in before paid store tasks\n"
			.. "HUD: Pets, Stock, Store, Cash, Help\n"
			.. "Stock: order stock, then restock shelves\n"
			.. "Register: start with opening till, give exact change, print receipt\n"
			.. "Pets: roll, care, select a pet, then equip or unequip"
		setQuickPanelAction("Controls", RetailAssets.buttons.Controls, Color3.fromRGB(66, 78, 98), false, false)
	else
		quickPanelTitle.Text = "Quick Status"
		quickPanelBody.Text = `Store {storeStatus} | Cash {RetailCurrency.formatCents(readStat("Cash"))}`
		setQuickPanelAction("Action", RetailAssets.buttons.Menu, Color3.fromRGB(60, 62, 66), false, false)
	end
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
	local netSales = readStoreAttribute(store, "StoreNetSalesCents")
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
		`Store {storeStatus} | Till {RetailCurrency.formatCents(storeCash)} | Sales {RetailCurrency.formatCents(netSales)} | Customers {storeCustomers} | Shoppers {activeShoppers} | Service Q{serviceQueue}/R{serviceReturns}/S{serviceSatisfaction}`
	taskLabel.Text = getTaskHint(shift, stock, lowStock, emptyShelves, basket, storeOpen, serviceQueue, serviceReturns)
	storeButton.Image = if storeOpen then RetailAssets.buttons.StoreOpen else RetailAssets.buttons.StoreClosed
	storeButton.BackgroundColor3 = if storeOpen then Color3.fromRGB(56, 116, 74) else Color3.fromRGB(132, 72, 62)
	storeButtonLabel.Text = if storeOpen then "CLOSE" else "OPEN"
	if quickPanel.Visible and renderQuickPanel then
		renderQuickPanel()
	end
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
local pendingPetSelectionId: string? = nil
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
			assetId = pet.assetId,
			sourceName = pet.sourceName,
			color = pet.color,
			accentColor = pet.accentColor,
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

local function getEquippedPetId(): string?
	if petInventory and typeof(petInventory.equippedPetId) == "string" and petInventory.equippedPetId ~= "" then
		return petInventory.equippedPetId
	end

	local attributePetId = player:GetAttribute("EquippedPetId")
	return if typeof(attributePetId) == "string" and attributePetId ~= "" then attributePetId else nil
end

local function petIsEquipped(pet): boolean
	if not pet then
		return false
	end

	return pet.equipped == true or pet.id == getEquippedPetId()
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

local function petInitials(name: string?): string
	local initials = ""
	for word in string.gmatch(name or "Pet", "%w+") do
		initials ..= string.sub(word, 1, 1)
		if string.len(initials) >= 2 then
			break
		end
	end

	if initials == "" then
		return "?"
	end
	return string.upper(initials)
end

local function petBaseColor(pet): Color3
	if pet and typeof(pet.color) == "Color3" then
		return pet.color
	end
	return rarityColor(if pet then pet.rarity else nil)
end

local function petAccentColor(pet): Color3
	if pet and typeof(pet.accentColor) == "Color3" then
		return pet.accentColor
	end
	return petBaseColor(pet):Lerp(Color3.fromRGB(20, 22, 26), 0.58)
end

local function clearPetPortrait(container: GuiObject)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function renderPetPortrait(container: GuiObject, pet, owned: boolean, compact: boolean?, showRarityTag: boolean?)
	clearPetPortrait(container)
	if container:IsA("ImageButton") or container:IsA("ImageLabel") then
		container.Image = ""
	end

	local baseColor = petBaseColor(pet)
	local accentColor = petAccentColor(pet)
	container.BackgroundColor3 = if owned then baseColor:Lerp(Color3.fromRGB(20, 22, 26), 0.2) else Color3.fromRGB(46, 48, 54)
	container.BackgroundTransparency = if owned then 0 else 0.08

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, -12, 0, if compact then 14 else 18)
	shine.Position = UDim2.fromOffset(6, 6)
	shine.BackgroundColor3 = baseColor:Lerp(Color3.fromRGB(255, 255, 255), 0.38)
	shine.BackgroundTransparency = if owned then 0.28 else 0.64
	shine.BorderSizePixel = 0
	shine.Parent = container
	addCorner(shine, 8)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Size = UDim2.new(0.68, 0, 0, if compact then 34 else 42)
	face.Position = UDim2.new(0.5, 0, 0, if compact then 16 else 19)
	face.BackgroundColor3 = if owned then baseColor else baseColor:Lerp(Color3.fromRGB(60, 62, 68), 0.55)
	face.BorderSizePixel = 0
	face.Parent = container
	addCorner(face, 18)
	addStroke(face, accentColor, if owned then 0.3 else 0.72)

	local earLeft = Instance.new("Frame")
	earLeft.Name = "EarLeft"
	earLeft.Size = UDim2.fromOffset(if compact then 12 else 15, if compact then 12 else 15)
	earLeft.Position = UDim2.new(0.2, 0, 0, if compact then 12 else 15)
	earLeft.BackgroundColor3 = accentColor
	earLeft.BackgroundTransparency = if owned then 0.08 else 0.48
	earLeft.BorderSizePixel = 0
	earLeft.Parent = container
	addCorner(earLeft, 8)

	local earRight = earLeft:Clone()
	earRight.Name = "EarRight"
	earRight.Position = UDim2.new(0.68, 0, 0, if compact then 12 else 15)
	earRight.Parent = container

	local initialsLabel = Instance.new("TextLabel")
	initialsLabel.Name = "Initials"
	initialsLabel.Size = UDim2.new(1, 0, 0, if compact then 28 else 34)
	initialsLabel.Position = UDim2.new(0, 0, 0, if compact then 22 else 27)
	initialsLabel.BackgroundTransparency = 1
	initialsLabel.Font = Enum.Font.GothamBlack
	initialsLabel.Text = petInitials(if pet then pet.name else "Pet")
	initialsLabel.TextColor3 = if owned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(168, 172, 180)
	initialsLabel.TextSize = if compact then 18 else 23
	initialsLabel.Parent = container

	if pet and typeof(pet.image) == "string" and pet.image ~= "" then
		local assetImage = Instance.new("ImageLabel")
		assetImage.Name = "AssetImage"
		assetImage.Size = UDim2.new(1, -10, 1, if showRarityTag ~= false then -22 else -10)
		assetImage.Position = UDim2.fromOffset(5, 5)
		assetImage.BackgroundTransparency = 1
		assetImage.Image = pet.image
		assetImage.ImageColor3 = if owned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 154, 162)
		assetImage.ImageTransparency = if owned then 0 else 0.28
		assetImage.ScaleType = Enum.ScaleType.Fit
		assetImage.Parent = container
	end

	if showRarityTag ~= false then
		local rarityTag = Instance.new("TextLabel")
		rarityTag.Name = "Rarity"
		rarityTag.AnchorPoint = Vector2.new(0.5, 1)
		rarityTag.Size = UDim2.new(1, -10, 0, if compact then 14 else 16)
		rarityTag.Position = UDim2.new(0.5, 0, 1, -5)
		rarityTag.BackgroundColor3 = rarityColor(if pet then pet.rarity else nil):Lerp(Color3.fromRGB(18, 20, 24), 0.22)
		rarityTag.BackgroundTransparency = if owned then 0.08 else 0.38
		rarityTag.BorderSizePixel = 0
		rarityTag.Font = Enum.Font.GothamBold
		rarityTag.Text = string.upper(if pet and pet.rarity then pet.rarity else "PET")
		rarityTag.TextColor3 = if owned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(170, 174, 182)
		rarityTag.TextSize = if compact then 8 else 9
		rarityTag.Parent = container
		addCorner(rarityTag, 5)
	end
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

local function getPetOddsSummary(): string
	local weights = {
		Common = 0,
		Rare = 0,
		Epic = 0,
		Legendary = 0,
	}
	local totalWeight = 0
	for _, pet in RetailAssets.pets do
		local weight = math.max(0, math.floor(pet.weight or 0))
		weights[pet.rarity or "Common"] = (weights[pet.rarity or "Common"] or 0) + weight
		totalWeight += weight
	end

	if totalWeight <= 0 then
		return "Odds loading"
	end

	return string.format(
		"C %.0f%% | R %.0f%% | E %.0f%% | L %.0f%%",
		weights.Common / totalWeight * 100,
		weights.Rare / totalWeight * 100,
		weights.Epic / totalWeight * 100,
		weights.Legendary / totalWeight * 100
	)
end

local function createPetSlot(pet)
	local owned = math.max(0, math.floor(pet.count or 0))
	local selected = selectedPetId == pet.id
	local equipped = petIsEquipped(pet)
	local button = Instance.new("ImageButton")
	button.Name = pet.id
	button.Image = ""
	button.BackgroundColor3 = if selected then rarityColor(pet.rarity) else Color3.fromRGB(38, 42, 50)
	button.BorderSizePixel = 0
	button.ScaleType = Enum.ScaleType.Fit
	button.Parent = petGrid
	addCorner(button, 8)
	addStroke(button, if selected then rarityColor(pet.rarity) else Color3.fromRGB(255, 255, 255), if selected then 0.2 else 0.78)
	renderPetPortrait(button, pet, owned > 0, petGridLayout.CellSize.X.Offset <= 60, false)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -6, 0, 24)
	nameLabel.Position = UDim2.new(0, 3, 1, -28)
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

	if equipped then
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
		pendingPetSelectionId = pet.id
		if equipped then
			fireServerRemote("RequestEquipPet", pet.id, "unequip")
		else
			fireServerRemote("RequestEquipPet", pet.id, "equip")
		end
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
		`Cash {RetailCurrency.formatCents(readStat("Cash"))} | Pets {readStat("Pets")}`
		.. "\n"
		.. `Roll {RetailCurrency.formatCents(cost)}{discountText} | Rare safety in {rollsUntilRare} | {perkText}`

	rollPetButtonLabel.Text = `Roll {RetailCurrency.formatCents(cost)}`
	setResourceButtonEnabled(rollPetButton, readStat("Cash") >= cost, Color3.fromRGB(70, 116, 82))
	local canCarePet = readStat("Shift") == 1
	carePetButtonLabel.Text = if canCarePet then "Care" else "Clock in"
	setResourceButtonEnabled(carePetButton, canCarePet, Color3.fromRGB(94, 112, 142))

	if lastPetResult then
		renderPetPortrait(lotteryIcon, lastPetResult, true, false, true)
		local refundText = if lastPetResult.duplicateRefundCents and lastPetResult.duplicateRefundCents > 0
			then ` | Refund {RetailCurrency.formatCents(lastPetResult.duplicateRefundCents)}`
			else ""
		local safetyText = if lastPetResult.guaranteedRare then "Safety roll hit" else lastPetResult.perk or "Companion unlocked"
		lotteryResult.Text =
			`{lastPetResult.rarity} | {lastPetResult.name} | Owned x{lastPetResult.count}{refundText}` .. "\n" .. safetyText
		lotteryResult.TextColor3 = rarityColor(lastPetResult.rarity)
	else
		renderPetPortrait(lotteryIcon, {
			name = "Pet Roll",
			rarity = "Rare",
			image = RetailAssets.petLottery.image,
			assetId = RetailAssets.petLottery.assetId,
			color = Color3.fromRGB(70, 116, 82),
			accentColor = Color3.fromRGB(36, 72, 54),
		}, true, false, true)
		lotteryResult.Text = getPetOddsSummary() .. "\n" .. `Rare safety in {rollsUntilRare}`
		lotteryResult.TextColor3 = Color3.fromRGB(208, 220, 234)
	end

	clearImageButtons(petGrid)
	local firstOwnedId: string? = nil
	local equippedPetId: string? = getEquippedPetId()
	for _, pet in getPetEntries() do
		if (pet.count or 0) > 0 and not firstOwnedId then
			firstOwnedId = pet.id
		end
		if pet.equipped then
			equippedPetId = pet.id
		end
	end

	if not selectedPetId then
		selectedPetId = equippedPetId or firstOwnedId
	end
	local activeSelection = findPetEntry(selectedPetId)
	if not activeSelection or (activeSelection.count or 0) <= 0 then
		if not (lastPetResult and selectedPetId == lastPetResult.id) then
			selectedPetId = equippedPetId or firstOwnedId
		end
	end

	for _, pet in getPetEntries() do
		createPetSlot(pet)
	end

	local selectedPet = findPetEntry(selectedPetId)
	local canEquip = selectedPet ~= nil and (selectedPet.count or 0) > 0
	if not selectedPet then
		equipPetButtonLabel.Text = "Select a pet"
	elseif petIsEquipped(selectedPet) then
		equipPetButtonLabel.Text = `Unequip {selectedPet.name}`
	elseif canEquip then
		equipPetButtonLabel.Text = `Equip {selectedPet.name}`
	else
		equipPetButtonLabel.Text = "Pet not owned"
	end
	setResourceButtonEnabled(equipPetButton, canEquip, Color3.fromRGB(68, 94, 132))
end

local viewportLayoutConnection = nil
local function bindResponsiveLayout()
	if viewportLayoutConnection then
		viewportLayoutConnection:Disconnect()
		viewportLayoutConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportLayoutConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindResponsiveLayout)
bindResponsiveLayout()

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

			fireServerRemote("AdjustRegisterChange", currentRegisterId, denomination.cents)
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
	local tillText = ""
	if typeof(state.tillCashCents) == "number" then
		tillText =
			"\n"
			.. `Drawer {RetailCurrency.formatCents(state.tillCashCents)} | After sale {RetailCurrency.formatCents(state.drawerPreviewCents or state.tillCashCents)}`
	end
	registerSummary.Text = `Items {state.itemCount} | Total {RetailCurrency.formatCents(state.totalCents)}`
		.. "\n"
		.. `Customer paid {RetailCurrency.formatCents(state.paidCents)} | Change due {RetailCurrency.formatCents(state.changeDueCents)}`
		.. "\n"
		.. `Change given {RetailCurrency.formatCents(state.changeGivenCents)}`
		.. tillText
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
		"StoreStartingTillCents",
		"StoreCashCents",
		"StoreTenderReceivedCents",
		"StoreChangePaidCents",
		"StoreNetSalesCents",
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
player:GetAttributeChangedSignal("EquippedPetId"):Connect(function()
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
if bootGui.Parent then
	bootGui:Destroy()
end

local function setHudPanelVisible(visible: boolean)
	panel.Visible = visible
	hudButtonLabel.Text = if visible then "HIDE" else "HUD"
end

closeHudButton.Activated:Connect(function()
	setHudPanelVisible(false)
end)

hudButton.Activated:Connect(function()
	setHudPanelVisible(not panel.Visible)
end)

closeShelfButton.Activated:Connect(function()
	shelfPanel.Visible = false
end)

connectClientRemote("OpenShelfEditor", function(shelfId: number, departmentIndex: number, productIndex: number, shelfStock: number?, shelfCapacity: number?)
	currentShelfId = shelfId
	currentShelfStock = math.max(0, math.floor(shelfStock or 0))
	currentShelfCapacity = math.max(0, math.floor(shelfCapacity or 0))
	appliedDepartmentIndex = RetailCatalog.wrapDepartmentIndex(departmentIndex)
	appliedProductIndex = RetailCatalog.wrapProductIndex(appliedDepartmentIndex, productIndex)
	selectedDepartmentIndex = appliedDepartmentIndex
	selectedProductIndex = appliedProductIndex
	shelfPanel.Visible = true
	updateResponsiveLayout()
	renderShelfEditor()
end)

applyShelfButton.Activated:Connect(function()
	if not currentShelfId then
		return
	end
	if selectedDepartmentIndex == appliedDepartmentIndex and selectedProductIndex == appliedProductIndex then
		return
	end

	fireServerRemote("SelectShelfProduct", currentShelfId, selectedDepartmentIndex, selectedProductIndex)
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
		fireServerRemote("ResetRegisterChange", currentRegisterId)
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

		fireServerRemote("FinishRegisterSale", currentRegisterId)
	end
end)

connectClientRemote("OpenRegisterPanel", function(state)
	registerPanel.Visible = true
	updateResponsiveLayout()
	renderRegisterPanel(state)
end)

connectClientRemote("UpdateRegisterPanel", function(state)
	if currentRegisterId == state.registerId then
		renderRegisterPanel(state)
	end
end)

local function showPlayerMenu(focus: string?)
	quickPanel.Visible = false
	quickPanelMode = nil
	playerMenu.Visible = true
	playerMenuTitle.Text = if focus == "pets" then "Pet Lottery" else "Player Menu"
	updateResponsiveLayout()
	if renderPlayerMenu then
		renderPlayerMenu()
	end
end

local function showQuickPanel(mode: string)
	quickPanelMode = mode
	quickPanel.Visible = true
	playerMenu.Visible = false
	updateResponsiveLayout()
	if renderQuickPanel then
		renderQuickPanel()
	end
end

menuButton.Activated:Connect(function()
	playerMenu.Visible = not playerMenu.Visible
	if playerMenu.Visible then
		showPlayerMenu()
	end
end)

controlsButton.Activated:Connect(function()
	showQuickPanel("controls")
end)

petsButton.Activated:Connect(function()
	showPlayerMenu("pets")
end)

stockButton.Activated:Connect(function()
	showQuickPanel("stock")
end)

storeButton.Activated:Connect(function()
	showQuickPanel("store")
	fireServerRemote("RequestStoreToggle")
end)

cashButton.Activated:Connect(function()
	showQuickPanel("cash")
end)

quickPanelClose.Activated:Connect(function()
	quickPanel.Visible = false
	quickPanelMode = nil
end)

quickPanelAction.Activated:Connect(function()
	if quickPanelMode == "stock" then
		fireServerRemote("RequestStockDelivery")
	elseif quickPanelMode == "store" then
		fireServerRemote("RequestStoreToggle")
	end
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
	fireServerRemote("RequestPetLottery")
end

rollPetButton.Activated:Connect(function()
	requestPetRoll()
end)

carePetButton.Activated:Connect(function()
	if readStat("Shift") ~= 1 then
		lotteryResult.Text = "Clock in before pet care"
		lotteryResult.TextColor3 = Color3.fromRGB(244, 140, 118)
		return
	end
	showPlayerMenu("pets")
	fireServerRemote("RequestPetCare")
end)

equipPetButton.Activated:Connect(function()
	local selectedPet = findPetEntry(selectedPetId)
	if not selectedPet or (selectedPet.count or 0) <= 0 then
		return
	end

	pendingPetSelectionId = selectedPet.id
	if petIsEquipped(selectedPet) then
		fireServerRemote("RequestEquipPet", selectedPet.id, "unequip")
	else
		fireServerRemote("RequestEquipPet", selectedPet.id, "equip")
	end
end)

connectClientRemote("PetInventoryUpdate", function(payload)
	petInventory = payload
	if pendingPetSelectionId then
		local pendingPet = findPetEntry(pendingPetSelectionId)
		if pendingPet and (pendingPet.count or 0) > 0 then
			selectedPetId = pendingPetSelectionId
		end
		pendingPetSelectionId = nil
	end
	if playerMenu.Visible and renderPlayerMenu then
		renderPlayerMenu()
	end
	updateHud()
end)

connectClientRemote("PetLotteryResult", function(result)
	lastPetResult = result
	selectedPetId = result.id
	pendingPetSelectionId = result.id
	showPlayerMenu("pets")
end)

connectClientRemote("OpenPlayerMenu", function(focus: string?)
	showPlayerMenu(focus)
end)
