local store = Instance.new("Model")
store.Name, store.Parent = "RetailStore", workspace
local door = Instance.new("Part")
door.Parent = store
door:SetAttribute("RoomDoor", true)
door:SetAttribute("DoorOpen", true)
door:SetAttribute("DoorClosedPosition", Vector3.new(58, 4.95, -20.25))
door:SetAttribute("DoorOpenPosition", Vector3.new(61, 4.95, -23.15))
door.Position = door:GetAttribute("DoorOpenPosition")
door.Orientation = Vector3.new(0, 90, 0)
door.CanCollide = true
local prompt = Instance.new("ProximityPrompt")
prompt.Parent = door
prompt.Enabled = true
local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name, root.Parent = "HumanoidRootPart", character
root.Position = Vector3.new(54, 4.95, -20.25)
local player = { Character = character }
visitors = { player }
triggerDoor(prompt, player)
assert(door:GetAttribute("DoorMoving") and not door.CanCollide and not prompt.Enabled)
local pending = activeTween
triggerDoor(prompt, player)
assert(activeTween == pending, "Repeated triggers cannot start overlapping animations")
activeTween.finish(Enum.PlaybackState.Completed)
assert(door:GetAttribute("DoorOpen") == false and prompt.ActionText == "Open" and prompt.Enabled and door.CanCollide)
assert(door.Position.X == 58 and door.Orientation.Y == 0)
triggerDoor(prompt, player)
activeTween.finish(Enum.PlaybackState.Completed)
assert(door:GetAttribute("DoorOpen") and door.Position.X == 61 and prompt.ActionText == "Close")
root.Position = door:GetAttribute("DoorClosedPosition")
triggerDoor(prompt, player)
assert(not door:GetAttribute("DoorMoving"), "A player in the doorway must block closing")
root.Position = Vector3.new(200, 4.95, -20.25)
triggerDoor(prompt, player)
assert(not door:GetAttribute("DoorMoving"), "Remote players cannot operate room doors")
root.Position = Vector3.new(54, 4.95, -20.25)
triggerDoor(prompt, player)
activeTween.finish(Enum.PlaybackState.Cancelled)
assert(door:GetAttribute("DoorOpen") and door.Position.X == 61 and door.CanCollide and prompt.Enabled, "Cancelled animation must restore a usable door")
triggerDoor(prompt, player)
root.Position = door:GetAttribute("DoorClosedPosition")
activeTween.finish(Enum.PlaybackState.Completed)
assert(door:GetAttribute("DoorOpen") and door.Position.X == 61, "A player entering during closing must leave the door open")
root.Position = Vector3.new(54, 4.95, -20.25)
door.Parent = workspace
triggerDoor(prompt, player)
assert(not door:GetAttribute("DoorMoving"), "Ignore doors outside the active retail store")
print("PASS: private doors, proximity validation, moving guard, occupied doorway, and cancellation recovery")
