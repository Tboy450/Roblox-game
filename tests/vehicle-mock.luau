-- Reuse the construction doubles; these checks cover local model geometry, not motion.
local CFrame = { new = function(x, y, z)
	return { Position = Vector3.new(x or 0, y or 0, z or 0) }
end }
function methods:PivotTo(cframe) self.pivot = cframe end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing fixture " .. name) end
workspace.ChildAdded = { Connect = function() end }
local replicated = Instance.new("Folder")
local remotes = Instance.new("Folder")
remotes.Name = "RetailRemotes"
remotes.Parent = replicated
for _, name in { "ProcessNpcCheckout", "CreateNpcOrder", "CancelNpcOrder" } do
	local remote = Instance.new("BindableFunction")
	remote.Name = name
	remote.Parent = remotes
end
game.GetService = function(_, name)
	if name == "Workspace" then return workspace end
	if name == "ReplicatedStorage" then return replicated end
	return {}
end
