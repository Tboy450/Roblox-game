-- Minimal construction-only Roblox doubles. Physics/navigation are tested in Studio.
local Vector = {}
Vector.__index = Vector
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, Vector) end }
function Vector.__add(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function Vector.__sub(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function Vector.__mul(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
function Vector.__div(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
Color3.new = function(r, g, b) return { R = r, G = g, B = b } end
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, value) return group .. "." .. value end })
end })
local UDim2 = { fromScale = function(x, y) return { x, y } end, new = function(...) return { ... } end }
local BrickColor = { new = function(value) return value end }
local methods = {}
function methods:IsA(class)
	return self.ClassName == class or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation" or self.ClassName == "Seat"))
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
	local result = {}
	for _, child in self.children do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do table.insert(result, descendant) end
	end
	return result
end
function methods:FindFirstChild(name)
	for _, child in self.children do if child.Name == name then return child end end
	return nil
end
function methods:SetAttribute(name, value) self.attributes[name] = value end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy()
	for _, child in self:GetChildren() do child:Destroy() end
	self.Parent = nil
	self.destroyed = true
end
local Instance = { new = function(class)
	return setmetatable({ props = { ClassName = class, Name = class }, children = {}, attributes = {} }, {
		__index = function(self, key) return methods[key] or self.props[key] end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local oldParent = self.props.Parent
				if oldParent then
					local index = table.find(oldParent.children, self)
					if index then table.remove(oldParent.children, index) end
				end
				if value then table.insert(value.children, self) end
			end
			self.props[key] = value
		end,
	})
end }
local workspace = Instance.new("Workspace")
local game = { GetService = function() return {} end }
local script = { Parent = { WaitForChild = function(_, name) return name end } }
