-- Studio plugin: "link" sends a note to Cursor via local bridge (port 8765).

local HttpService = game:GetService("HttpService")

local BRIDGE_HOSTS = { "http://127.0.0.1:8765", "http://localhost:8765" }

local toolbar = plugin:CreateToolbar("Cursor")
local linkButton = toolbar:CreateButton("Link", "Send a message to Cursor AI", "rbxassetid://6031075938")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,
	false,
	false,
	440,
	200,
	340,
	160
)

local widget = plugin:CreateDockWidgetPluginGui("CursorLinkWidget", widgetInfo)
widget.Title = "Link to Cursor"

local root = Instance.new("Frame")
root.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(8, 6)
hint.Size = UDim2.new(1, -16, 0, 32)
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.TextColor3 = Color3.fromRGB(180, 180, 180)
hint.Text = "1) Cursor: .\\scripts\\fix-link.ps1  2) Allow plugin access to 127.0.0.1  3) Type below + link"
hint.Parent = root

local input = Instance.new("TextBox")
input.Position = UDim2.fromOffset(8, 42)
input.Size = UDim2.new(1, -16, 0, 32)
input.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
input.TextColor3 = Color3.fromRGB(255, 255, 255)
input.ClearTextOnFocus = false
input.Font = Enum.Font.Code
input.TextSize = 14
input.PlaceholderText = "what should the AI build or fix?"
input.Parent = root

local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Position = UDim2.fromOffset(8, 80)
buttonRow.Size = UDim2.new(1, -16, 0, 28)
buttonRow.Parent = root

local sendButton = Instance.new("TextButton")
sendButton.Size = UDim2.new(0.48, 0, 1, 0)
sendButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sendButton.Font = Enum.Font.GothamBold
sendButton.TextSize = 14
sendButton.Text = "link"
sendButton.Parent = buttonRow

local testButton = Instance.new("TextButton")
testButton.Position = UDim2.new(0.52, 0, 0, 0)
testButton.Size = UDim2.new(0.48, 0, 1, 0)
testButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
testButton.TextColor3 = Color3.fromRGB(255, 255, 255)
testButton.Font = Enum.Font.Gotham
testButton.TextSize = 14
testButton.Text = "test"
testButton.Parent = buttonRow

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(8, 114)
status.Size = UDim2.new(1, -16, 0, 70)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextColor3 = Color3.fromRGB(140, 220, 140)
status.Text = "Click test to check bridge."
status.Parent = root

local function setStatus(text: string, isError: boolean?)
	status.TextColor3 = if isError then Color3.fromRGB(255, 140, 140) else Color3.fromRGB(140, 220, 140)
	status.Text = text
end

local function normalizeMessage(raw: string): string?
	local trimmed = string.gsub(raw, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	if trimmed == "" then
		return nil
	end
	local lower = string.lower(trimmed)
	if string.sub(lower, 1, 5) == "link " then
		return string.sub(trimmed, 6)
	end
	if lower == "link" then
		return nil
	end
	return trimmed
end

local function postToBridge(path: string, payload: string): (boolean, string)
	local lastError = "unknown error"

	for _, host in BRIDGE_HOSTS do
		local url = host .. path
		local ok, result = pcall(function()
			return HttpService:RequestAsync({
				Url = url,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = payload,
			})
		end)

		if ok then
			if result.Success then
				return true, result.Body
			end
			lastError = `HTTP {result.StatusCode}: {result.Body}`
		else
			lastError = tostring(result)
		end
	end

	return false, lastError
end

local function getHealth(): (boolean, string)
	for _, host in BRIDGE_HOSTS do
		local url = host .. "/health"
		local ok, result = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if ok then
			return true, result
		end
	end
	return false, "Bridge not reachable. Run .\\scripts\\fix-link.ps1 in Cursor."
end

local function testBridge()
	setStatus("Testing bridge...", false)
	local ok, body = getHealth()
	if ok then
		setStatus("Bridge OK. You can use link now.")
	else
		setStatus(body, true)
	end
end

local function sendLink()
	local message = normalizeMessage(input.Text)
	if not message then
		setStatus('Type a message first.', true)
		return
	end

	local payload = HttpService:JSONEncode({
		message = message,
		source = "Studio",
	})

	local ok, result = postToBridge("/link", payload)
	if not ok then
		setStatus(
			"Failed: " .. result .. " | Fix: Cursor .\\scripts\\fix-link.ps1 | Studio: Plugins -> Manage Plugins -> allow 127.0.0.1",
			true
		)
		warn("[LinkToCursor]", result)
		return
	end

	input.Text = ""
	setStatus("Sent! In Cursor chat say: read inbox")
end

testButton.MouseButton1Click:Connect(testBridge)
sendButton.MouseButton1Click:Connect(sendLink)
input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendLink()
	end
end)

linkButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	if widget.Enabled then
		testBridge()
		input:CaptureFocus()
	end
end)
