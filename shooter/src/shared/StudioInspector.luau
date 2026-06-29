local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local StudioInspector = {}

local function vector3(value: Vector3)
	return { value.X, value.Y, value.Z }
end

local function color3(value: Color3)
	return {
		math.round(value.R * 255),
		math.round(value.G * 255),
		math.round(value.B * 255),
	}
end

local function cframe(value: CFrame)
	return { value:GetComponents() }
end

local function safeAttributes(instance: Instance)
	local result = {}
	for name, value in instance:GetAttributes() do
		local valueType = typeof(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			result[name] = value
		elseif valueType == "Vector3" then
			result[name] = { type = "Vector3", value = vector3(value) }
		elseif valueType == "Color3" then
			result[name] = { type = "Color3", value = color3(value) }
		end
	end
	return result
end

local function inspect(instance: Instance)
	local data = {
		path = instance:GetFullName(),
		name = instance.Name,
		className = instance.ClassName,
		attributes = safeAttributes(instance),
		tags = CollectionService:GetTags(instance),
	}

	if instance:IsA("BasePart") then
		data.cframe = cframe(instance.CFrame)
		data.size = vector3(instance.Size)
		data.color = color3(instance.Color)
		data.material = instance.Material.Name
		data.anchored = instance.Anchored
		data.canCollide = instance.CanCollide
		data.canTouch = instance.CanTouch
		data.transparency = instance.Transparency
	elseif instance:IsA("ProximityPrompt") then
		data.actionText = instance.ActionText
		data.objectText = instance.ObjectText
		data.holdDuration = instance.HoldDuration
		data.maxActivationDistance = instance.MaxActivationDistance
	elseif instance:IsA("ObjectValue") then
		data.valuePath = if instance.Value then instance.Value:GetFullName() else nil
	elseif instance:IsA("StringValue") or instance:IsA("NumberValue") or instance:IsA("BoolValue") then
		data.value = instance.Value
	end

	return data
end

function StudioInspector.run()
	local services = {
		workspace,
		game:GetService("ReplicatedStorage"),
		game:GetService("ServerScriptService"),
		game:GetService("StarterGui"),
		game:GetService("StarterPack"),
		game:GetService("StarterPlayer"),
	}
	local items = {}
	local classCounts = {}

	for _, service in services do
		for _, descendant in service:GetDescendants() do
			if descendant ~= script and not descendant:IsDescendantOf(script) then
				table.insert(items, inspect(descendant))
				classCounts[descendant.ClassName] = (classCounts[descendant.ClassName] or 0) + 1
			end
		end
	end

	local sessionId = HttpService:GenerateGUID(false)
	-- Studio truncates very long Output lines. One instance per line keeps every
	-- path and geometry record intact in the local Studio log.
	local batchSize = 1
	local totalBatches = math.max(1, math.ceil(#items / batchSize))
	print(
		"[SHOOTER_SNAPSHOT_BEGIN]"
			.. HttpService:JSONEncode({
				id = sessionId,
				placeId = game.PlaceId,
				gameId = game.GameId,
				itemCount = #items,
				classCounts = classCounts,
				totalBatches = totalBatches,
			})
	)

	for batchIndex = 1, totalBatches do
		local batch = {}
		local firstIndex = (batchIndex - 1) * batchSize + 1
		local lastIndex = math.min(#items, batchIndex * batchSize)
		for itemIndex = firstIndex, lastIndex do
			table.insert(batch, items[itemIndex])
		end
		print(
			"[SHOOTER_SNAPSHOT_BATCH]"
				.. HttpService:JSONEncode({
					id = sessionId,
					index = batchIndex,
					total = totalBatches,
					items = batch,
				})
		)
	end

	print("[SHOOTER_SNAPSHOT_END]" .. sessionId)
	return {
		id = sessionId,
		itemCount = #items,
		classCounts = classCounts,
	}
end

return StudioInspector
