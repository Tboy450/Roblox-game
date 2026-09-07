Vector.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z) end
	return Vector[key]
end
local nativeTypeof = typeof
local function typeof(value) return if getmetatable(value) == Vector then "Vector3" else nativeTypeof(value) end
function methods:IsDescendantOf(parent)
	local current = self.Parent
	while current do
		if current == parent then return true end
		current = current.Parent
	end
	return false
end
local triggerDoor, activeTween
local visitors = {}
local TweenInfo = { new = function(...) return { ... } end }
game = { GetService = function(_, service)
	if service == "Workspace" then return workspace end
	if service == "Players" then return { GetPlayers = function() return visitors end } end
	if service == "ProximityPromptService" then return { PromptTriggered = { Connect = function(_, fn) triggerDoor = fn end } } end
	if service == "TweenService" then return { Create = function(_, target, _, goals)
		local completion
		activeTween = {
			Completed = { Connect = function(_, fn) completion = fn end },
			Play = function() end,
			finish = function(state)
				if state == Enum.PlaybackState.Completed then
					for key, value in goals do target[key] = value end
				end
				completion(state)
			end,
		}
		return activeTween
	end } end
	error("Unexpected service " .. service)
end }
