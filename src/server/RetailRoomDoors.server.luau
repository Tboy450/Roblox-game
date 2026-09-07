local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local function doorwayOccupied(position: Vector3): boolean
	for _, visitor in Players:GetPlayers() do
		local root = visitor.Character and visitor.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local delta = root.Position - position
			if math.abs(delta.X) < 2.3 and math.abs(delta.Z) < 4.2 and math.abs(delta.Y) < 5 then return true end
		end
	end
	return false
end

local function onDoorPrompt(prompt: ProximityPrompt, player: Player)
	local door = prompt.Parent
	local store = Workspace:FindFirstChild("RetailStore")
	if not door or not door:IsA("BasePart") or not store or not door:IsDescendantOf(store)
		or door:GetAttribute("RoomDoor") ~= true or door:GetAttribute("DoorMoving") then return end
	local closedPosition = door:GetAttribute("DoorClosedPosition")
	local openPosition = door:GetAttribute("DoorOpenPosition")
	if typeof(closedPosition) ~= "Vector3" or typeof(openPosition) ~= "Vector3" then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - closedPosition).Magnitude > 10 then return end
	local wasOpen = door:GetAttribute("DoorOpen") == true
	if wasOpen and doorwayOccupied(closedPosition) then return end
	local oldPosition, oldOrientation = door.Position, door.Orientation
	door:SetAttribute("DoorMoving", true)
	prompt.Enabled = false
	door.CanCollide = false
	local tween = TweenService:Create(door, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Position = if wasOpen then closedPosition else openPosition,
		Orientation = Vector3.new(0, if wasOpen then 0 else 90, 0),
	})
	tween.Completed:Connect(function(playbackState)
		if not door.Parent then return end
		-- Recheck after the animation in case somebody entered the doorway while it moved.
		local completed = playbackState == Enum.PlaybackState.Completed and (not wasOpen or not doorwayOccupied(closedPosition))
		local isOpen = if completed then not wasOpen else wasOpen
		if not completed then
			door.Position, door.Orientation = oldPosition, oldOrientation
		end
		door:SetAttribute("DoorOpen", isOpen)
		door:SetAttribute("DoorMoving", false)
		door.CanCollide = true
		prompt.ActionText = if isOpen then "Close" else "Open"
		prompt.Enabled = true
	end)
	tween:Play()
end

ProximityPromptService.PromptTriggered:Connect(onDoorPrompt)
