-- Runs after the construction doubles, catalog, and actual blueprint.
local function quote(value)
	local s = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
	return '"' .. s .. '"'
end
local function json(value)
	if type(value) == "string" then return quote(value) end
	if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
	if type(value) ~= "table" then return "null" end
	local keys = {}
	for key in value do table.insert(keys, key) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local result = {}
	for _, key in keys do table.insert(result, quote(key) .. ':' .. json(value[key])) end
	return '{' .. table.concat(result, ',') .. '}'
end
local store = Blueprint.build({ parent = workspace })
local nodes = { store }
for _, node in store:GetDescendants() do table.insert(nodes, node) end
local ids = {}
for index, node in nodes do ids[node] = index end
for index, node in nodes do
	local record = { id = index, parentId = ids[node.Parent] or 0, name = node.Name, class = node.ClassName, attributes = node.attributes }
	if node:IsA("BasePart") then
		record.position = node.Position
		record.size = node.Size
		record.orientation = node.Orientation or Vector3.new(0, 0, 0)
		record.color = node.Color
		record.material = node.Material
		record.shape = node.Shape or "PartType.Block"
		record.transparency = node.Transparency or 0
		record.canCollide = node.CanCollide
	end
	for _, field in { "Text", "ActionText", "ObjectText", "MaxActivationDistance", "Brightness", "Range", "Enabled", "Face" } do
		if node[field] ~= nil then record[field] = node[field] end
	end
	print(json(record))
end
