local MergeEffects = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RunnersFolder = ReplicatedStorage.Assets.Entities

local INPUT_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RESULT_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPARK_TWEEN = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MAX_OPERATIONS_PER_BATCH = 4
local OPERATION_STAGGER = 0.44

local function getEffectContainer(plotId: number): Folder?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild(tostring(plotId)) else nil
	if not plotModel or not plotModel:IsA("Model") then
		return nil
	end

	local container = plotModel:FindFirstChild("_TEMP")
	if container and container:IsA("Folder") then
		return container
	end

	return nil
end

local function getMergeCFrame(plotId: number): CFrame?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild(tostring(plotId)) else nil
	if not plotModel or not plotModel:IsA("Model") then
		return nil
	end

	local buttons = plotModel:FindFirstChild("Buttons")
	local mergeFolder = if buttons then buttons:FindFirstChild("Merge") else nil
	local mergeButton = if mergeFolder then mergeFolder:FindFirstChildWhichIsA("Model") else nil

	return if mergeButton then mergeButton:GetPivot() * CFrame.new(0, 3.5, 0) else plotModel:GetPivot() * CFrame.new(0, 4, 0)
end

local function prepareGhost(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function createGhost(container: Folder, level: number, cframe: CFrame): Model?
	local template = RunnersFolder:FindFirstChild(tostring(math.min(40, level)))
	if not template or not template:IsA("Model") then
		return nil
	end

	local ghost = template:Clone()
	prepareGhost(ghost)
	ghost:PivotTo(cframe)
	ghost.Parent = container

	return ghost
end

local function tweenModelPivot(model: Model, target: CFrame, tweenInfo: TweenInfo)
	local pivot = Instance.new("CFrameValue")
	pivot.Value = model:GetPivot()

	local connection = pivot:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(pivot.Value)
		end
	end)

	local tween = TweenService:Create(pivot, tweenInfo, { Value = target })
	tween.Completed:Connect(function()
		connection:Disconnect()
		pivot:Destroy()
	end)
	tween:Play()
end

local function tweenModelScale(model: Model, fromScale: number, toScale: number, tweenInfo: TweenInfo)
	model:ScaleTo(fromScale)

	local scale = Instance.new("NumberValue")
	scale.Value = fromScale

	local connection = scale:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:ScaleTo(scale.Value)
		end
	end)

	local tween = TweenService:Create(scale, tweenInfo, { Value = toScale })
	tween.Completed:Connect(function()
		connection:Disconnect()
		scale:Destroy()
	end)
	tween:Play()
end

local function makeWhite(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, INPUT_TWEEN, { Color = Color3.new(1, 1, 1) }):Play()
		elseif descendant:IsA("Decal") then
			TweenService:Create(descendant, INPUT_TWEEN, { Color3 = Color3.new(1, 1, 1) }):Play()
		end
	end
end

local function addGlow(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineColor = Color3.fromRGB(255, 228, 110)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	return highlight
end

local function createBurst(container: Folder, cframe: CFrame)
	for index = 1, 14 do
		local angle = math.pi * 2 * index / 14
		local direction = Vector3.new(math.cos(angle), math.random(2, 8) / 10, math.sin(angle)).Unit
		local shard = Instance.new("Part")
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = if index % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 221, 89)
		shard.Size = Vector3.new(0.28, 0.28, 0.28)
		shard.CFrame = cframe * CFrame.new(0, 0.25, 0)
		shard.Parent = container

		TweenService:Create(shard, SPARK_TWEEN, {
			CFrame = shard.CFrame + direction * math.random(20, 38) / 10,
			Size = Vector3.zero,
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, SPARK_TWEEN.Time + 0.05)
	end

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 238, 132)
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.12, 1.5, 1.5)
	ring.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = container

	TweenService:Create(ring, SPARK_TWEEN, {
		Size = Vector3.new(0.08, 6, 6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, SPARK_TWEEN.Time + 0.05)
end

local function playOperation(plotId: number, sourceLevel: number, resultLevel: number)
	local container = getEffectContainer(plotId)
	local center = getMergeCFrame(plotId)
	if not container or not center then
		return
	end

	local leftInput = createGhost(container, sourceLevel, center * CFrame.new(-3, 0, 0))
	local rightInput = createGhost(container, sourceLevel, center * CFrame.new(3, 0, 0))
	if not leftInput or not rightInput then
		if leftInput then
			leftInput:Destroy()
		end
		if rightInput then
			rightInput:Destroy()
		end
		return
	end

	local leftGlow = addGlow(leftInput)
	local rightGlow = addGlow(rightInput)
	makeWhite(leftInput)
	makeWhite(rightInput)
	tweenModelScale(leftInput, 0.72, 1.2, INPUT_TWEEN)
	tweenModelScale(rightInput, 0.72, 1.2, INPUT_TWEEN)
	tweenModelPivot(leftInput, center * CFrame.new(-0.35, 0, 0), INPUT_TWEEN)
	tweenModelPivot(rightInput, center * CFrame.new(0.35, 0, 0), INPUT_TWEEN)

	task.delay(INPUT_TWEEN.Time, function()
		if leftInput.Parent then
			leftInput:Destroy()
		end
		if rightInput.Parent then
			rightInput:Destroy()
		end
		leftGlow:Destroy()
		rightGlow:Destroy()

		createBurst(container, center)

		local result = createGhost(container, resultLevel, center)
		if not result then
			return
		end

		local resultGlow = addGlow(result)
		resultGlow.FillTransparency = 0.15
		tweenModelScale(result, 0.2, 1, RESULT_TWEEN)
		task.delay(RESULT_TWEEN.Time * 0.45, function()
			if resultGlow.Parent then
				TweenService:Create(resultGlow, TweenInfo.new(RESULT_TWEEN.Time * 0.55), {
					FillTransparency = 1,
					OutlineTransparency = 1,
				}):Play()
			end
		end)
		Debris:AddItem(result, RESULT_TWEEN.Time + 0.12)
	end)
end

function MergeEffects.play(plotId: number, operations: { { sourceLevel: number, resultLevel: number } })
	local operationCount = #operations
	if operationCount == 0 then
		return
	end

	local selectedOperations = operations
	if operationCount > MAX_OPERATIONS_PER_BATCH then
		selectedOperations = {}
		for index = 1, MAX_OPERATIONS_PER_BATCH - 1 do
			selectedOperations[index] = operations[index]
		end
		selectedOperations[MAX_OPERATIONS_PER_BATCH] = operations[operationCount]
	end

	for index, operation in ipairs(selectedOperations) do
		task.delay((index - 1) * OPERATION_STAGGER, function()
			playOperation(plotId, operation.sourceLevel, operation.resultLevel)
		end)
	end
end

return MergeEffects
