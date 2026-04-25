-- Advanced Part Grabber (Multi-Selection & Precision Version)
local player = game:GetService("Players").LocalPlayer

-- Set Simulation Radius to Max
task.spawn(function()
	while task.wait() do
		pcall(function()
			player.SimulationRadius = math.huge
		end)
	end
end)

local mouse = player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

-- Setup Collision Groups
local HELD_GROUP = "HeldPartsGroup"
local PLAYER_GROUP = "PlayerGroup"

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(HELD_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
		PhysicsService:CollisionGroupSetCollidable(HELD_GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(HELD_GROUP, PLAYER_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(HELD_GROUP, HELD_GROUP, false)
	end)
end
setupCollisionGroups()

local Tool = Instance.new("Tool")
Tool.Name = "PrecisionGrabber"; Tool.RequiresHandle = true; Tool.CanBeDropped = true
local handle = Instance.new("Part", Tool); handle.Name = "Handle"; handle.Size = Vector3.new(1, 1, 1); handle.Transparency = 1; handle.CanCollide = false

-- State Variables
local heldParts, partMemory, rotationMemory = {}, {}, {}
local activeGui, rightHand = nil, nil
local extrasFrame, orbitFrame, followFrame, presetFrame
local extrasBtn, presetOpenBtn, resetBtn
local isRotationMode, keepOwnership, moveAllMode, presetRepeat, flingMode, autoReclaim, predictionEnabled = false, false, false, false, false, false, false
local autoReclaimStrength, predictionStrength = 1, 1
local flingDirection = "Look"
local playerFlingEnabled, lockOnEnabled = false, false
local lockedTargetRoot = nil
local lastLockedVelocity = Vector3.new(0, 0, 0)
local lockedHighlight = nil
local flingPower = 16000
local followHotkey, followKeepPosition, isFollowing = Enum.KeyCode.LeftControl, false, false
local highlightEnabled = false
local selectedPartIndex, currentIncrement = 1, 0.2 
local unanchoredCount, anchoredCache, unanchoredParts, statsLabel = 0, {}, {}, nil

-- Settings System
local SETTINGS_FILE = "grabber_settings.json"

local function saveSettings()
	local settings = {
		isRotationMode = isRotationMode,
		keepOwnership = keepOwnership,
		moveAllMode = moveAllMode,
		presetRepeat = presetRepeat,
		flingMode = flingMode,
		autoReclaim = autoReclaim,
		predictionEnabled = predictionEnabled,
		autoReclaimStrength = autoReclaimStrength,
		predictionStrength = predictionStrength,
		flingPower = flingPower,
		flingDirection = flingDirection,
		playerFlingEnabled = playerFlingEnabled,
		lockOnEnabled = lockOnEnabled,
		followHotkey = followHotkey.Name,
		followKeepPosition = followKeepPosition,
		highlightEnabled = highlightEnabled,
		currentIncrement = currentIncrement
	}
	pcall(function()
		if writefile then
			writefile(SETTINGS_FILE, HttpService:JSONEncode(settings))
		end
	end)
end

local function loadSettings()
	pcall(function()
		if isfile and isfile(SETTINGS_FILE) then
			local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
			if data then
				if data.isRotationMode ~= nil then isRotationMode = data.isRotationMode end
				if data.keepOwnership ~= nil then keepOwnership = data.keepOwnership end
				if data.moveAllMode ~= nil then moveAllMode = data.moveAllMode end
				if data.presetRepeat ~= nil then presetRepeat = data.presetRepeat end
				if data.flingMode ~= nil then flingMode = data.flingMode end
				if data.autoReclaim ~= nil then autoReclaim = data.autoReclaim end
				if data.predictionEnabled ~= nil then predictionEnabled = data.predictionEnabled end
				if data.autoReclaimStrength ~= nil then autoReclaimStrength = data.autoReclaimStrength end
				if data.predictionStrength ~= nil then predictionStrength = data.predictionStrength end
				if data.flingPower ~= nil then flingPower = data.flingPower end
				if data.flingDirection ~= nil then flingDirection = data.flingDirection end
				if data.playerFlingEnabled ~= nil then playerFlingEnabled = data.playerFlingEnabled end
				if data.lockOnEnabled ~= nil then lockOnEnabled = data.lockOnEnabled end
				if data.followHotkey ~= nil then followHotkey = Enum.KeyCode[data.followHotkey] or followHotkey end
				if data.followKeepPosition ~= nil then followKeepPosition = data.followKeepPosition end
				if data.highlightEnabled ~= nil then highlightEnabled = data.highlightEnabled end
				if data.currentIncrement ~= nil then currentIncrement = data.currentIncrement end
			end
		end
	end)
end
loadSettings()

-- Optimized Auto Reclaim Loop
task.spawn(function()
	while task.wait() do
		if autoReclaim then
			local lostParts = {}
			for target, _ in pairs(heldParts) do
				if target.ReceiveAge > 0 then table.insert(lostParts, target) end
			end
			
			if #lostParts > 0 then
				local char = player.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local oldCF = root.CFrame
					for _, p in ipairs(lostParts) do
						root.CFrame = p.CFrame
						for i = 1, autoReclaimStrength do RunService.Heartbeat:Wait() end
					end
					root.CFrame = oldCF
				end
			end
		end
		task.wait(math.max(0.05, 0.3 / autoReclaimStrength))
	end
end)

-- Lock Highlight Helper
local function applyLockHighlight(target, enable)
	if enable then
		if not target:FindFirstChild("LockHighlight") then
			local h = Instance.new("Highlight", target)
			h.Name = "LockHighlight"; h.FillColor = Color3.fromRGB(255, 50, 50); h.OutlineColor = Color3.fromRGB(255, 255, 255)
			lockedHighlight = h
		end
	else
		if lockedHighlight then lockedHighlight:Destroy(); lockedHighlight = nil end
		local h = target and target:FindFirstChild("LockHighlight"); if h then h:Destroy() end
	end
end

local function getClosestPlayerToMouse()
	local closest, dist = nil, 100 
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local root = p.Character.HumanoidRootPart
			local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
			if onScreen then
				local mPos = UserInputService:GetMouseLocation()
				local d = (Vector2.new(screenPos.X, screenPos.Y) - mPos).Magnitude
				if d < dist then dist = d; closest = root end
			end
		end
	end
	return closest
end

local highlightEnabled = false
local selectedPartIndex, currentIncrement = 1, 0.2 
local unanchoredCount, anchoredCache, unanchoredParts, statsLabel = 0, {}, {}, nil

-- Forward Declarations
local updateSelectionDisplay, updateSpinDisplay, updateDirDisplay, updateOrbitDisplay, updateTypeDisplay, updateMainLayout, updateToggles

-- Highlight Helper
local function applyHighlight(target, enable)
	if enable then
		if not target:FindFirstChild("GrabHighlight") then
			local h = Instance.new("Highlight", target)
			h.Name = "GrabHighlight"; h.FillColor = Color3.fromRGB(255, 255, 255); h.OutlineColor = Color3.fromRGB(0, 160, 255)
		end
	else
		local h = target:FindFirstChild("GrabHighlight"); if h then h:Destroy() end
	end
end

local function updateStatsUI()
	if statsLabel then statsLabel.Text = "UNANCHORED PARTS: " .. unanchoredCount end
end

local function isPlayerPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then return true, model end
	return false, nil
end

local function processPart(part)
	if not part:IsA("BasePart") or anchoredCache[part] or unanchoredParts[part] then return end
	local isPlayer, _ = isPlayerPart(part)
	if isPlayer then return end
	if part.Anchored then anchoredCache[part] = true
	else
		unanchoredParts[part] = true; unanchoredCount = unanchoredCount + 1
		if highlightEnabled then applyHighlight(part, true) end
		updateStatsUI()
	end
end

local function handleRemoving(part)
	if not part:IsA("BasePart") then return end
	if anchoredCache[part] then anchoredCache[part] = nil
	elseif unanchoredParts[part] then
		unanchoredParts[part] = nil; applyHighlight(part, false); unanchoredCount = math.max(0, unanchoredCount - 1)
		updateStatsUI()
	end
end

task.spawn(function()
	for _, desc in ipairs(workspace:GetDescendants()) do processPart(desc) end
	workspace.DescendantAdded:Connect(processPart); workspace.DescendantRemoving:Connect(handleRemoving)
end)

-- Draggable Utility
local function makeDraggable(frame)
	local dragging, dragInput, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = input.Position; startPos = frame.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	frame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Physics Helpers
local function getAssemblyUnanchored(targetPart)
	local connected, valid = targetPart:GetConnectedParts(true), {}
	for _, part in ipairs(connected) do if not part.Anchored then table.insert(valid, part) end end
	return valid
end

local function disablePhysics(targetPart)
	local originals, partsToModify = {}, getAssemblyUnanchored(targetPart)
	for _, part in ipairs(partsToModify) do
		originals[part] = { 
			Group = part.CollisionGroup, 
			Collide = part.CanCollide, 
			Touch = part.CanTouch, 
			Query = part.CanQuery,
			CustomPhysics = part.CustomPhysicalProperties 
		}
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		pcall(function() part.CollisionGroup = HELD_GROUP end)
		part.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
	end
	return originals, partsToModify
end

local function restorePhysics(originals)
	for part, data in pairs(originals) do
		if part and part.Parent then
			pcall(function() part.CollisionGroup = data.Group end)
			part.CanCollide = data.Collide; part.CanTouch = data.Touch; part.CanQuery = data.Query
			part.CustomPhysicalProperties = data.CustomPhysics
		end
	end
end

local function clearConstraints(part)
	if not part then return end
	for _, obj in ipairs(part:GetConnectedParts(true)) do
		for _, child in ipairs(obj:GetChildren()) do
			if (child:IsA("Attachment") or child:IsA("AlignPosition") or child:IsA("AlignOrientation")) and child.Name:find("Grab") then child:Destroy() end
		end
	end
end

local function getHeldList() local list = {}; for p, _ in pairs(heldParts) do table.insert(list, p) end return list end
local function getSelectedPart() local list = getHeldList(); return list[selectedPartIndex] end

-- GUI Logic
local function createEditGui()
	if activeGui then activeGui.Enabled = true return end
	local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui")); sg.Name = "GrabberEditor"; sg.ResetOnSpawn = false; activeGui = sg
	local mainFrame = Instance.new("Frame", sg); mainFrame.Size = UDim2.new(0, 260, 0, 660); mainFrame.Position = UDim2.new(0.8, 0, 0.5, -330); mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20); mainFrame.Active = true; makeDraggable(mainFrame); Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(70, 70, 70)

	local function createSubFrame(name, size)
		local f = Instance.new("Frame", sg); f.Name = name; f.Size = size; f.Position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2); f.BackgroundColor3 = Color3.fromRGB(25, 25, 25); f.Visible = false; f.Active = true; Instance.new("UICorner", f); Instance.new("UIStroke", f).Color = Color3.fromRGB(60, 60, 60); makeDraggable(f)
		local t = Instance.new("TextLabel", f); t.Size = UDim2.new(1, -30, 0, 30); t.Text = name:upper(); t.TextColor3 = Color3.new(1, 1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 12
		local x = Instance.new("TextButton", f); x.Size = UDim2.new(0, 25, 0, 25); x.Position = UDim2.new(1, -28, 0, 3); x.Text = "X"; x.BackgroundColor3 = Color3.fromRGB(150, 50, 50); x.TextColor3 = Color3.new(1, 1, 1); x.Font = Enum.Font.GothamBold; Instance.new("UICorner", x).CornerRadius = UDim.new(0, 5); x.MouseButton1Click:Connect(function() f.Visible = false end)
		return f
	end

	extrasFrame = createSubFrame("Extras", UDim2.new(0, 200, 0, 210))
	orbitFrame = createSubFrame("Orbit Settings", UDim2.new(0, 200, 0, 220))
	followFrame = createSubFrame("Follow Mode", UDim2.new(0, 220, 0, 420))
	presetFrame = createSubFrame("Preset Menu", UDim2.new(0, 220, 0, 230))
	local statsFrame = createSubFrame("Statistics", UDim2.new(0, 200, 0, 60)); statsFrame.Visible = true; statsFrame.Position = UDim2.new(0, 20, 0, 20)
	statsLabel = Instance.new("TextLabel", statsFrame); statsLabel.Size = UDim2.new(1, 0, 1, -30); statsLabel.Position = UDim2.new(0, 0, 0, 30); statsLabel.BackgroundTransparency = 1; statsLabel.TextColor3 = Color3.new(1, 1, 1); statsLabel.Font = Enum.Font.GothamBold; statsLabel.TextSize = 12; updateStatsUI()

	local partLabel = Instance.new("TextLabel")
	local spinToggle, speedFrame, dirFrame, updateOrbitDisplay, updateTypeDisplay

	local function createBtn(text, pos, size, parent)
		local b = Instance.new("TextButton", parent); b.Size = size; b.Position = pos; b.Text = text; b.BackgroundColor3 = Color3.fromRGB(45, 45, 45); b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBold; Instance.new("UICorner", b); return b
	end

	updateMainLayout = function()
		local cur = getSelectedPart(); local spinOn = (cur and heldParts[cur]) and heldParts[cur].Spin.Enabled or false
		speedFrame.Visible = spinOn; dirFrame.Visible = spinOn; local off = spinOn and 70 or 0
		extrasBtn.Position = UDim2.new(0.075, 0, 0, 455 + off); presetOpenBtn.Position = UDim2.new(0.075, 0, 0, 495 + off); resetBtn.Position = UDim2.new(0.075, 0, 0, 535 + off)
	end

	updateSelectionDisplay = function()
		local list = getHeldList(); if #list == 0 then partLabel.Text = "No Parts Held"; selectedPartIndex = 1
		elseif selectedPartIndex > #list then selectedPartIndex = #list end
		local cur = list[selectedPartIndex]; partLabel.Text = "["..selectedPartIndex.."/"..#list.."] " .. (cur and cur.Name or "Unknown")
		if cur and heldParts[cur] then updateSpinDisplay(); updateDirDisplay(); updateOrbitDisplay(); updateTypeDisplay() end
		updateToggles(); updateMainLayout()
	end

	local selFrame = Instance.new("Frame", mainFrame); selFrame.Size = UDim2.new(0.9, 0, 0, 40); selFrame.Position = UDim2.new(0.05, 0, 0, 20); selFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35); Instance.new("UICorner", selFrame)
	partLabel.Parent = selFrame; partLabel.Size = UDim2.new(1, 0, 1, 0); partLabel.TextColor3 = Color3.new(1, 1, 1); partLabel.BackgroundTransparency = 1; partLabel.Font = Enum.Font.GothamSemibold; partLabel.TextSize = 12
	createBtn("<", UDim2.new(0, 0, 0, 0), UDim2.new(0, 30, 1, 0), selFrame).MouseButton1Click:Connect(function() selectedPartIndex = selectedPartIndex > 1 and selectedPartIndex - 1 or #getHeldList(); updateSelectionDisplay() end)
	createBtn(">", UDim2.new(1, -30, 0, 0), UDim2.new(0, 30, 1, 0), selFrame).MouseButton1Click:Connect(function() selectedPartIndex = selectedPartIndex < #getHeldList() and selectedPartIndex + 1 or 1; updateSelectionDisplay() end)

	local incFrame = Instance.new("Frame", mainFrame); incFrame.Size = UDim2.new(0.9, 0, 0, 30); incFrame.Position = UDim2.new(0.05, 0, 0, 65); incFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Instance.new("UICorner", incFrame)
	Instance.new("TextLabel", incFrame).Size = UDim2.new(0.6, 0, 1, 0); incFrame.TextLabel.Text = "INCREMENT:"; incFrame.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200); incFrame.TextLabel.BackgroundTransparency = 1; incFrame.TextLabel.Font = Enum.Font.GothamBold; incFrame.TextLabel.TextSize = 10
	local incInput = Instance.new("TextBox", incFrame); incInput.Size = UDim2.new(0.35, 0, 0.8, 0); incInput.Position = UDim2.new(0.6, 0, 0.1, 0); incInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50); incInput.Text = tostring(currentIncrement); incInput.TextColor3 = Color3.new(1, 1, 1); incInput.Font = Enum.Font.GothamBold; incInput.TextSize = 12; Instance.new("UICorner", incInput)
	incInput.FocusLost:Connect(function() local val = tonumber(incInput.Text); if val then currentIncrement = val; saveSettings() else incInput.Text = tostring(currentIncrement) end end)

	local function applyToTarget(targetPart, axis, direction)
		local delta = currentIncrement * direction; local cur = partMemory[targetPart] or CFrame.new(0, 0, 0); local pos, x, y, z = cur.Position, cur:ToOrientation()
		if not isRotationMode then
			if axis == "X" then pos = pos + Vector3.new(delta, 0, 0) elseif axis == "Y" then pos = pos + Vector3.new(0, delta, 0) elseif axis == "Z" then pos = pos + Vector3.new(0, 0, delta) end
		else local r = math.rad(delta * 50); if axis == "X" then x = x + r elseif axis == "Y" then y = y + r elseif axis == "Z" then z = z + r end end
		partMemory[targetPart] = CFrame.new(pos) * CFrame.fromOrientation(x, y, z)
	end
	local og = 105; local function mBtn(t, x, y, ax, d) createBtn(t, UDim2.new(0.5, x, 0, og + y), UDim2.new(0, 40, 0, 40), mainFrame).MouseButton1Click:Connect(function() local list = moveAllMode and getHeldList() or {getSelectedPart()}; for _, p in ipairs(list) do applyToTarget(p, ax, d) end end) end
	mBtn("▲", -20, 0, "Z", -1); mBtn("▼", -20, 90, "Z", 1); mBtn("◄", -65, 45, "X", -1); mBtn("►", 25, 45, "X", 1)
	createBtn("FWD", UDim2.new(0.05, 0, 0, og + 45), UDim2.new(0, 42, 0, 40), mainFrame).MouseButton1Click:Connect(function() local list = moveAllMode and getHeldList() or {getSelectedPart()}; for _, p in ipairs(list) do applyToTarget(p, "Y", 1) end end)
	createBtn("BCK", UDim2.new(0.95, -42, 0, og + 45), UDim2.new(0, 42, 0, 40), mainFrame).MouseButton1Click:Connect(function() local list = moveAllMode and getHeldList() or {getSelectedPart()}; for _, p in ipairs(list) do applyToTarget(p, "Y", -1) end end)
	local flipBtn = createBtn("FLIP", UDim2.new(0.5, -20, 0, og + 45), UDim2.new(0, 40, 0, 40), mainFrame); flipBtn.TextSize = 8
	flipBtn.MouseButton1Click:Connect(function() local list = moveAllMode and getHeldList() or {getSelectedPart()}; for _, p in ipairs(list) do if p and partMemory[p] then partMemory[p] = partMemory[p] * CFrame.Angles(math.pi, 0, 0) end end end)
	flipBtn.MouseButton2Click:Connect(function() local list = moveAllMode and getHeldList() or {getSelectedPart()}; for _, p in ipairs(list) do if p and partMemory[p] then partMemory[p] = partMemory[p] * CFrame.Angles(0, 0, math.pi) end end end)

	local rotBtn = createBtn("TOGGLE ROTATION", UDim2.new(0.075, 0, 0, 245), UDim2.new(0.85, 0, 0, 30), mainFrame)
	local moveAllBtn = createBtn("MOVE ALL: OFF", UDim2.new(0.075, 0, 0, 280), UDim2.new(0.85, 0, 0, 30), mainFrame)
	local ownBtn = createBtn("KEEP OWNERSHIP: OFF", UDim2.new(0.075, 0, 0, 315), UDim2.new(0.85, 0, 0, 30), mainFrame)
	local flingBtn = createBtn("FLING MODE: OFF", UDim2.new(0.075, 0, 0, 350), UDim2.new(0.85, 0, 0, 30), mainFrame)
	local claimBtn = createBtn("AUTORECLAIM: OFF", UDim2.new(0.075, 0, 0, 385), UDim2.new(0.85, 0, 0, 30), mainFrame)
	
	rotBtn.TextSize = 10; moveAllBtn.TextSize = 10; ownBtn.TextSize = 10; flingBtn.TextSize = 10; claimBtn.TextSize = 10
	rotBtn.MouseButton1Click:Connect(function() isRotationMode = not isRotationMode; updateToggles(); saveSettings() end)
	moveAllBtn.MouseButton1Click:Connect(function() moveAllMode = not moveAllMode; updateToggles(); saveSettings() end)
	ownBtn.MouseButton1Click:Connect(function() keepOwnership = not keepOwnership; updateToggles(); saveSettings() end)
	flingBtn.MouseButton1Click:Connect(function() flingMode = not flingMode; updateToggles(); saveSettings() end)
	claimBtn.MouseButton1Click:Connect(function() autoReclaim = not autoReclaim; updateToggles(); saveSettings() end)
	
	local reclaimFrame = Instance.new("Frame", mainFrame); reclaimFrame.Size = UDim2.new(0.85, 0, 0, 30); reclaimFrame.Position = UDim2.new(0.075, 0, 0, 420); reclaimFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Instance.new("UICorner", reclaimFrame)
	Instance.new("TextLabel", reclaimFrame).Size = UDim2.new(0.6, 0, 1, 0); reclaimFrame.TextLabel.Text = "RECLAIM STR:"; reclaimFrame.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200); reclaimFrame.TextLabel.BackgroundTransparency = 1; reclaimFrame.TextLabel.Font = Enum.Font.GothamBold; reclaimFrame.TextLabel.TextSize = 9
	local rsInput = Instance.new("TextBox", reclaimFrame); rsInput.Size = UDim2.new(0.35, 0, 0.8, 0); rsInput.Position = UDim2.new(0.6, 0, 0.1, 0); rsInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50); rsInput.Text = tostring(autoReclaimStrength); rsInput.TextColor3 = Color3.new(1, 1, 1); rsInput.Font = Enum.Font.GothamBold; rsInput.TextSize = 10; Instance.new("UICorner", rsInput)
	rsInput.FocusLost:Connect(function() local val = tonumber(rsInput.Text); if val then autoReclaimStrength = math.clamp(val, 1, 10); saveSettings() else rsInput.Text = tostring(autoReclaimStrength) end end)
	
	updateToggles = function() 
		rotBtn.BackgroundColor3 = isRotationMode and Color3.fromRGB(90, 90, 50) or Color3.fromRGB(50, 50, 90); 
		moveAllBtn.Text = moveAllMode and "MOVE ALL: ON" or "MOVE ALL: OFF"; 
		moveAllBtn.BackgroundColor3 = moveAllMode and Color3.fromRGB(90, 50, 90) or Color3.fromRGB(40, 40, 40); 
		ownBtn.Text = keepOwnership and "KEEP OWNERSHIP: ON" or "KEEP OWNERSHIP: OFF"; 
		ownBtn.BackgroundColor3 = keepOwnership and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40);
		flingBtn.Text = flingMode and "FLING MODE: ON" or "FLING MODE: OFF";
		flingBtn.BackgroundColor3 = flingMode and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(40, 40, 40);
		claimBtn.Text = autoReclaim and "AUTORECLAIM: ON" or "AUTORECLAIM: OFF";
		claimBtn.BackgroundColor3 = autoReclaim and Color3.fromRGB(50, 150, 100) or Color3.fromRGB(40, 40, 40);
		reclaimFrame.Visible = autoReclaim; local off = autoReclaim and 35 or 0
		spinToggle.Position = UDim2.new(0.075, 0, 0, 420 + off); updateMainLayout()
	end

	spinToggle = createBtn("SPIN: OFF", UDim2.new(0.075, 0, 0, 420), UDim2.new(0.85, 0, 0, 30), mainFrame); spinToggle.TextSize = 10; spinToggle.MouseButton1Click:Connect(function()
		local cur = getSelectedPart(); if not cur or not heldParts[cur] then return end
		local newState = not heldParts[cur].Spin.Enabled; local list = moveAllMode and getHeldList() or {cur}
		for _, p in ipairs(list) do local d = heldParts[p]; if d and d.Spin.Enabled ~= newState then d.Spin.Enabled = newState
			if d.Spin.Enabled then rotationMemory[p] = (partMemory[p] or CFrame.new()).Rotation elseif rotationMemory[p] then partMemory[p] = CFrame.new((partMemory[p] or CFrame.new()).Position) * rotationMemory[p]; rotationMemory[p] = nil end
		end end; updateSelectionDisplay() end)
	speedFrame = Instance.new("Frame", mainFrame); speedFrame.Size = UDim2.new(0.85,0,0,30); speedFrame.Position = UDim2.new(0.075,0,0,455); speedFrame.BackgroundColor3 = Color3.fromRGB(30,30,30); Instance.new("UICorner", speedFrame); Instance.new("TextLabel", speedFrame).Size = UDim2.new(0.5,0,1,0); speedFrame.TextLabel.Text = "SPEED:"; speedFrame.TextLabel.TextColor3 = Color3.new(1,1,1); speedFrame.TextLabel.BackgroundTransparency = 1; speedFrame.TextLabel.Font = Enum.Font.GothamBold; speedFrame.TextLabel.TextSize = 10
	local si = Instance.new("TextBox", speedFrame); si.Size = UDim2.new(0.4,0,0.8,0); si.Position = UDim2.new(0.5,0,0.1,0); si.BackgroundColor3 = Color3.fromRGB(45,45,45); si.TextColor3 = Color3.new(1,1,1); si.Font = Enum.Font.GothamBold; si.TextSize = 10; Instance.new("UICorner", si); si.FocusLost:Connect(function() local v = tonumber(si.Text); if v then for _, p in ipairs(moveAllMode and getHeldList() or {getSelectedPart()}) do if heldParts[p] then heldParts[p].Spin.Speed = v end end end updateSpinDisplay() end)
	dirFrame = Instance.new("Frame", mainFrame); dirFrame.Size = UDim2.new(0.85,0,0,30); dirFrame.Position = UDim2.new(0.075,0,0,490); dirFrame.BackgroundColor3 = Color3.fromRGB(30,30,30); Instance.new("UICorner", dirFrame)
	local dtBtn = createBtn("DIRECTION: UP", UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), dirFrame); dtBtn.TextSize = 10; dtBtn.MouseButton1Click:Connect(function() local cur = getSelectedPart(); if not cur then return end
		local nt = heldParts[cur].Spin.Direction == "Up" and "Sideways" or (heldParts[cur].Spin.Direction == "Sideways" and "All" or "Up"); for _, p in ipairs(moveAllMode and getHeldList() or {cur}) do if heldParts[p] then heldParts[p].Spin.Direction = nt end end; updateDirDisplay() end)
	updateSpinDisplay = function() local cur = getSelectedPart(); if cur and heldParts[cur] then local s = heldParts[cur].Spin; spinToggle.Text = s.Enabled and "SPIN: ON" or "SPIN: OFF"; spinToggle.BackgroundColor3 = s.Enabled and Color3.fromRGB(40, 80, 80) or Color3.fromRGB(50, 50, 50); si.Text = tostring(s.Speed) end end
	updateDirDisplay = function() local cur = getSelectedPart(); if cur and heldParts[cur] then local d = heldParts[cur].Spin.Direction; dtBtn.Text = "DIRECTION: "..d:upper(); dtBtn.BackgroundColor3 = d == "Up" and Color3.fromRGB(60,60,100) or (d == "Sideways" and Color3.fromRGB(100,60,60) or Color3.fromRGB(60,100,60)) end end

	extrasBtn = createBtn("EXTRAS MENU", UDim2.new(0.075, 0, 0, 390), UDim2.new(0.85, 0, 0, 35), mainFrame); extrasBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 20); extrasBtn.MouseButton1Click:Connect(function() extrasFrame.Visible = not extrasFrame.Visible end)
	presetOpenBtn = createBtn("PRESET MENU", UDim2.new(0.075, 0, 0, 430), UDim2.new(0.85, 0, 0, 35), mainFrame); presetOpenBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 60); presetOpenBtn.MouseButton1Click:Connect(function() presetFrame.Visible = not presetFrame.Visible end)
	resetBtn = createBtn("RESET TO HAND", UDim2.new(0.075, 0, 0, 470), UDim2.new(0.85, 0, 0, 35), mainFrame); resetBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); resetBtn.MouseButton1Click:Connect(function() for _, p in ipairs(moveAllMode and getHeldList() or {getSelectedPart()}) do partMemory[p] = CFrame.new(0, 0, 0) end end)

	createBtn("ORBIT MENU", UDim2.new(0.05, 0, 0, 40), UDim2.new(0.9, 0, 0, 35), extrasFrame).MouseButton1Click:Connect(function() orbitFrame.Visible = not orbitFrame.Visible end)
	createBtn("FOLLOW MODE", UDim2.new(0.05, 0, 0, 80), UDim2.new(0.9, 0, 0, 35), extrasFrame).MouseButton1Click:Connect(function() followFrame.Visible = not followFrame.Visible end)
	createBtn("TOGGLE STATS", UDim2.new(0.05, 0, 0, 120), UDim2.new(0.9, 0, 0, 35), extrasFrame).MouseButton1Click:Connect(function() statsFrame.Visible = not statsFrame.Visible end)
	local highBtn = createBtn("HIGHLIGHT: "..(highlightEnabled and "ON" or "OFF"), UDim2.new(0.05, 0, 0, 160), UDim2.new(0.9, 0, 0, 35), extrasFrame); highBtn.BackgroundColor3 = highlightEnabled and Color3.fromRGB(40, 100, 100) or Color3.fromRGB(45, 45, 45); highBtn.MouseButton1Click:Connect(function()
		highlightEnabled = not highlightEnabled; highBtn.Text = "HIGHLIGHT: "..(highlightEnabled and "ON" or "OFF"); highBtn.BackgroundColor3 = highlightEnabled and Color3.fromRGB(40, 100, 100) or Color3.fromRGB(45, 45, 45)
		for t, _ in pairs(unanchoredParts) do applyHighlight(t, highlightEnabled) end; saveSettings() end)
	
	local otBtn = createBtn("ORBIT: OFF", UDim2.new(0.05, 0, 0, 40), UDim2.new(0.9, 0, 0, 30), orbitFrame); otBtn.MouseButton1Click:Connect(function()
		local cur = getSelectedPart(); if not cur or not heldParts[cur] then return end
		local ns = not heldParts[cur].Orbit.Enabled; for _, p in ipairs(moveAllMode and getHeldList() or {cur}) do if heldParts[p] then heldParts[p].Orbit.Enabled = ns end end; updateOrbitDisplay() end)
	local function oi(n, y, k)
		local f = Instance.new("Frame", orbitFrame); f.Size = UDim2.new(0.9,0,0,30); f.Position = UDim2.new(0.05,0,0,y); f.BackgroundTransparency = 1; local l = Instance.new("TextLabel", f); l.Size = UDim2.new(0.5,0,1,0); l.Text = n; l.TextColor3 = Color3.fromRGB(180,180,180); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 10; local i = Instance.new("TextBox", f); i.Size = UDim2.new(0.5,0,0.8,0); i.Position = UDim2.new(0.5,0,0.1,0); i.BackgroundColor3 = Color3.fromRGB(40,40,40); i.TextColor3 = Color3.new(1,1,1); i.Font = Enum.Font.GothamBold; i.TextSize = 10; Instance.new("UICorner", i); i.FocusLost:Connect(function() local v = tonumber(i.Text); if v then for _, p in ipairs(moveAllMode and getHeldList() or {getSelectedPart()}) do if heldParts[p] then heldParts[p].Orbit[k] = v end end end updateOrbitDisplay() end); return i
	end
	local osi, odi = oi("SPEED:", 80, "Speed"), oi("DIST:", 115, "Distance")
	local tyBtn = createBtn("TYPE: PROGRADE", UDim2.new(0.05, 0, 0, 150), UDim2.new(0.9, 0, 0, 30), orbitFrame); tyBtn.MouseButton1Click:Connect(function() local cur = getSelectedPart(); if cur then local nt = heldParts[cur].Orbit.Type == "Prograde" and "Retrograde" or (heldParts[cur].Orbit.Type == "Retrograde" and "Polar" or "Prograde"); for _, p in ipairs(moveAllMode and getHeldList() or {cur}) do if heldParts[p] then heldParts[p].Orbit.Type = nt end end; updateTypeDisplay() end end)
	updateOrbitDisplay = function() local cur = getSelectedPart(); if cur and heldParts[cur] then local o = heldParts[cur].Orbit; otBtn.Text = o.Enabled and "ORBIT: ON" or "ORBIT: OFF"; otBtn.BackgroundColor3 = o.Enabled and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(45, 45, 45); osi.Text = tostring(o.Speed); odi.Text = tostring(o.Distance) end end
	updateTypeDisplay = function() local cur = getSelectedPart(); if cur and heldParts[cur] then tyBtn.Text = "TYPE: "..heldParts[cur].Orbit.Type:upper() end end
	local hb = createBtn("HOTKEY: "..followHotkey.Name, UDim2.new(0.05, 0, 0, 45), UDim2.new(0.9, 0, 0, 35), followFrame); hb.MouseButton1Click:Connect(function() hb.Text = "PRESS KEY..."; local c; c = UserInputService.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Keyboard then followHotkey = i.KeyCode; hb.Text = "HOTKEY: "..followHotkey.Name; saveSettings(); c:Disconnect() end end) end)
	local kb = createBtn("KEEP POSITION: OFF", UDim2.new(0.05, 0, 0, 90), UDim2.new(0.9, 0, 0, 35), followFrame); local function updateK() kb.Text = "KEEP POSITION: "..(followKeepPosition and "ON" or "OFF"); kb.BackgroundColor3 = followKeepPosition and Color3.fromRGB(40,100,40) or Color3.fromRGB(50,50,50) end; kb.MouseButton1Click:Connect(function() followKeepPosition = not followKeepPosition; updateK(); saveSettings() end); updateK()
	
	local pfBtn = createBtn("PLAYER FLING: OFF", UDim2.new(0.05, 0, 0, 135), UDim2.new(0.9, 0, 0, 35), followFrame); pfBtn.TextSize = 10; pfBtn.MouseButton1Click:Connect(function() playerFlingEnabled = not playerFlingEnabled; pfBtn.Text = "PLAYER FLING: " .. (playerFlingEnabled and "ON" or "OFF"); pfBtn.BackgroundColor3 = playerFlingEnabled and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(50, 50, 50); saveSettings() end); pfBtn.Text = "PLAYER FLING: " .. (playerFlingEnabled and "ON" or "OFF"); pfBtn.BackgroundColor3 = playerFlingEnabled and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(50, 50, 50)
	local loBtn = createBtn("LOCK ON: OFF", UDim2.new(0.05, 0, 0, 180), UDim2.new(0.9, 0, 0, 35), followFrame); loBtn.TextSize = 10; loBtn.MouseButton1Click:Connect(function() lockOnEnabled = not lockOnEnabled; loBtn.Text = "LOCK ON: " .. (lockOnEnabled and "ON" or "OFF"); loBtn.BackgroundColor3 = lockOnEnabled and Color3.fromRGB(50, 100, 150) or Color3.fromRGB(50, 50, 50); if not lockOnEnabled then if lockedTargetRoot then applyLockHighlight(lockedTargetRoot, false) end lockedTargetRoot = nil end; saveSettings() end); loBtn.Text = "LOCK ON: " .. (lockOnEnabled and "ON" or "OFF"); loBtn.BackgroundColor3 = lockOnEnabled and Color3.fromRGB(50, 100, 150) or Color3.fromRGB(50, 50, 50)
	
	local predBtn = createBtn("PREDICTION: OFF", UDim2.new(0.05, 0, 0, 215), UDim2.new(0.9, 0, 0, 35), followFrame); predBtn.TextSize = 10; predBtn.MouseButton1Click:Connect(function() predictionEnabled = not predictionEnabled; predBtn.Text = "PREDICTION: " .. (predictionEnabled and "ON" or "OFF"); predBtn.BackgroundColor3 = predictionEnabled and Color3.fromRGB(100, 50, 150) or Color3.fromRGB(50, 50, 50); saveSettings() end)

	local psFrame = Instance.new("Frame", followFrame); psFrame.Size = UDim2.new(0.9, 0, 0, 30); psFrame.Position = UDim2.new(0.05, 0, 0, 255); psFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Instance.new("UICorner", psFrame)
	Instance.new("TextLabel", psFrame).Size = UDim2.new(0.6, 0, 1, 0); psFrame.TextLabel.Text = "PREDICT STR:"; psFrame.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200); psFrame.TextLabel.BackgroundTransparency = 1; psFrame.TextLabel.Font = Enum.Font.GothamBold; psFrame.TextLabel.TextSize = 9
	local psInput = Instance.new("TextBox", psFrame); psInput.Size = UDim2.new(0.35, 0, 0.8, 0); psInput.Position = UDim2.new(0.6, 0, 0.1, 0); psInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50); psInput.Text = tostring(predictionStrength); psInput.TextColor3 = Color3.new(1, 1, 1); psInput.Font = Enum.Font.GothamBold; psInput.TextSize = 10; Instance.new("UICorner", psInput)
	psInput.FocusLost:Connect(function() local val = tonumber(psInput.Text); if val then predictionStrength = val; saveSettings() else psInput.Text = tostring(predictionStrength) end end)

	local fpFrame = Instance.new("Frame", followFrame); fpFrame.Size = UDim2.new(0.9, 0, 0, 30); fpFrame.Position = UDim2.new(0.05, 0, 0, 295); fpFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Instance.new("UICorner", fpFrame)
	Instance.new("TextLabel", fpFrame).Size = UDim2.new(0.6, 0, 1, 0); fpFrame.TextLabel.Text = "FLING POWER:"; fpFrame.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200); fpFrame.TextLabel.BackgroundTransparency = 1; fpFrame.TextLabel.Font = Enum.Font.GothamBold; fpFrame.TextLabel.TextSize = 9
	local fpInput = Instance.new("TextBox", fpFrame); fpInput.Size = UDim2.new(0.35, 0, 0.8, 0); fpInput.Position = UDim2.new(0.6, 0, 0.1, 0); fpInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50); fpInput.Text = tostring(flingPower); fpInput.TextColor3 = Color3.new(1, 1, 1); fpInput.Font = Enum.Font.GothamBold; fpInput.TextSize = 10; Instance.new("UICorner", fpInput)
	fpInput.FocusLost:Connect(function() local val = tonumber(fpInput.Text); if val then flingPower = val; saveSettings() else fpInput.Text = tostring(flingPower) end end)

	local fdBtn = createBtn("FLING DIR: LOOK", UDim2.new(0.05, 0, 0, 335), UDim2.new(0.9, 0, 0, 35), followFrame); fdBtn.TextSize = 10; fdBtn.MouseButton1Click:Connect(function()
		if flingDirection == "Look" then flingDirection = "Right"
		elseif flingDirection == "Right" then flingDirection = "Up"
		else flingDirection = "Look" end
		fdBtn.Text = "FLING DIR: " .. flingDirection:upper(); saveSettings()
	end)
	
	local pi = Instance.new("TextBox", presetFrame); pi.Size = UDim2.new(0.9,0,0,30); pi.Position = UDim2.new(0.05,0,0,40); pi.BackgroundColor3 = Color3.fromRGB(40,40,40); pi.TextColor3 = Color3.new(1,1,1); pi.PlaceholderText = "Preset Name..."; pi.Font = Enum.Font.GothamBold; Instance.new("UICorner", pi)
	local rb = createBtn("REPEAT: OFF", UDim2.new(0.05, 0, 0, 80), UDim2.new(0.9, 0, 0, 30), presetFrame); local function updateRB() rb.Text = "REPEAT: "..(presetRepeat and "ON" or "OFF"); rb.BackgroundColor3 = presetRepeat and Color3.fromRGB(100,100,40) or Color3.fromRGB(50,50,50) end; rb.MouseButton1Click:Connect(function() presetRepeat = not presetRepeat; updateRB(); saveSettings() end); updateRB()
	local function handlePreset(m) local n = pi.Text; if n == "" then return end
		if m == "save" then local d = {}; for t, data in pairs(heldParts) do table.insert(d, {Name = t.Name, Offset = {(partMemory[t] or CFrame.new()):GetComponents()}, Spin = data.Spin, Orbit = data.Orbit}) end
			if writefile then if not isfolder("grabber_presets") then makefolder("grabber_presets") end writefile("grabber_presets/"..n..".json", HttpService:JSONEncode(d)) end
		else if readfile and isfile("grabber_presets/"..n..".json") then local success, data = pcall(function() return HttpService:JSONDecode(readfile("grabber_presets/"..n..".json")) end); if not success or #data == 0 then return end
				local hList = getHeldList(); local aH, aD = {}, {}; for i, e in ipairs(data) do for _, t in ipairs(hList) do if not aH[t] and t.Name == e.Name then partMemory[t] = CFrame.new(unpack(e.Offset)); if e.Spin then heldParts[t].Spin = e.Spin end; if e.Orbit then heldParts[t].Orbit = e.Orbit end aH[t], aD[i] = true, true; break end end end
				local dIdx = 1; for _, t in ipairs(hList) do if not aH[t] then if presetRepeat then local e = data[dIdx]; partMemory[t] = CFrame.new(unpack(e.Offset)); if e.Spin then heldParts[t].Spin = e.Spin end; if e.Orbit then heldParts[t].Orbit = e.Orbit end dIdx = (dIdx % #data) + 1 else while dIdx <= #data and aD[dIdx] do dIdx = dIdx + 1 end if dIdx <= #data then local e = data[dIdx]; partMemory[t] = CFrame.new(unpack(e.Offset)); if e.Spin then heldParts[t].Spin = e.Spin end; if e.Orbit then heldParts[t].Orbit = e.Orbit end aH[t], aD[dIdx], dIdx = true, true, dIdx + 1 end end end end; updateSelectionDisplay() end end end
	createBtn("SAVE PRESET", UDim2.new(0.05, 0, 0, 120), UDim2.new(0.9, 0, 0, 35), presetFrame).MouseButton1Click:Connect(function() handlePreset("save") end); createBtn("LOAD PRESET", UDim2.new(0.05, 0, 0, 165), UDim2.new(0.9, 0, 0, 35), presetFrame).MouseButton1Click:Connect(function() handlePreset("load") end); updateSelectionDisplay()
end

local function onActivated()
	local target = mouse.Target; if not target or target.Anchored then return end
	if heldParts[target] then
		applyHighlight(target, false); restorePhysics(heldParts[target].OriginalGroups); clearConstraints(target); if heldParts[target].TargetAtt then heldParts[target].TargetAtt:Destroy() end; heldParts[target] = nil; if activeGui then updateSelectionDisplay() end
	else
		local originals, affectedParts = disablePhysics(target); local partHandleAtt = Instance.new("Attachment", handle); partHandleAtt.Name = "GrabAtt_" .. tostring(tick()); heldParts[target] = { OriginalGroups = originals, AffectedParts = affectedParts, TargetAtt = partHandleAtt, Spin = { Enabled = false, Speed = 1, Direction = "Up" }, Orbit = { Enabled = false, Speed = 1, Distance = 5, Type = "Prograde" } }; if not partMemory[target] then partMemory[target] = CFrame.new(0, 0, 0) end
		applyHighlight(target, highlightEnabled); 
		local partAtt = Instance.new("Attachment", target); partAtt.Name = "PartGrabAtt"
		local ap = Instance.new("AlignPosition", target); ap.Name = "GrabPosition"; ap.Attachment0 = partAtt; ap.Attachment1 = partHandleAtt; ap.RigidityEnabled = true
		local ao = Instance.new("AlignOrientation", target); ao.Name = "GrabOrientation"; ao.Attachment0 = partAtt; ao.Attachment1 = partHandleAtt; ao.RigidityEnabled = true
		createEditGui(); if activeGui then updateSelectionDisplay() end 
	end
end

RunService.Heartbeat:Connect(function(dt)
	if not (Tool and Tool.Parent and (Tool.Parent:IsA("Model") or Tool.Parent:IsA("Backpack"))) then 
		if highlightEnabled then highlightEnabled = false; for t, _ in pairs(unanchoredParts) do applyHighlight(t, false) end end return 
	end
	local char = player.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"); isFollowing = UserInputService:IsKeyDown(followHotkey); local list = getHeldList()
	
	if lockOnEnabled then
		local nearPlayer = getClosestPlayerToMouse()
		if nearPlayer and nearPlayer ~= lockedTargetRoot then
			if lockedTargetRoot then applyLockHighlight(lockedTargetRoot, false) end
			lockedTargetRoot = nearPlayer
			applyLockHighlight(lockedTargetRoot, true)
		end
	else
		if lockedTargetRoot then applyLockHighlight(lockedTargetRoot, false) end
		lockedTargetRoot = nil
	end

	if lockedTargetRoot then
		local breakLock = false
		local currentVel = lockedTargetRoot.AssemblyLinearVelocity
		local velDelta = (currentVel - lastLockedVelocity).Magnitude
		lastLockedVelocity = currentVel
		if not lockedTargetRoot.Parent or not lockedTargetRoot.Parent:FindFirstChildOfClass("Humanoid") then breakLock = true end
		if lockedTargetRoot.Parent:FindFirstChildOfClass("Humanoid").Health <= 0 then breakLock = true end
		if velDelta > 25000 then breakLock = true end
		if currentVel.Magnitude > 40000 then breakLock = true end
		if breakLock then applyLockHighlight(lockedTargetRoot, false); lockedTargetRoot = nil; lastLockedVelocity = Vector3.new(0,0,0) end
	end

	local playerTargetRoot = nil
	if isFollowing and not lockedTargetRoot and mouse.Target then
		local isP, pModel = isPlayerPart(mouse.Target)
		if isP then playerTargetRoot = pModel:FindFirstChild("HumanoidRootPart") end
	end
	local finalTargetRoot = lockedTargetRoot or playerTargetRoot

	for target, data in pairs(heldParts) do
		if target and target.Parent and rightHand then
			local isFocused = false; if moveAllMode then isFocused = true else local cur = list[selectedPartIndex]; if target == cur then isFocused = true end end
			if data.Spin.Enabled then 
				local curCF = partMemory[target] or CFrame.new(0, 0, 0); local angle = math.rad(data.Spin.Speed * 100 * dt); local rot = CFrame.new()
				if data.Spin.Direction == "Up" then rot = CFrame.fromEulerAnglesXYZ(0, angle, 0) elseif data.Spin.Direction == "Sideways" then rot = CFrame.fromEulerAnglesXYZ(angle, 0, 0) else rot = CFrame.fromEulerAnglesXYZ(angle, angle, angle) end
				partMemory[target] = curCF * rot 
			end

			local baseCFrame, isOrbiting = rightHand.CFrame, false
			if data.Orbit.Enabled and root then 
				isOrbiting = true; local t = tick() * data.Orbit.Speed; local d = data.Orbit.Distance; local off = Vector3.new(0,0,0)
				if data.Orbit.Type == "Prograde" then off = Vector3.new(math.cos(t)*d, 0, math.sin(t)*d) elseif data.Orbit.Type == "Retrograde" then off = Vector3.new(math.cos(-t)*d, 0, math.sin(-t)*d) elseif data.Orbit.Type == "Polar" then off = Vector3.new(0, math.cos(t)*d, math.sin(t)*d) end
				baseCFrame = root.CFrame * CFrame.new(off) 
			end

			local offset = partMemory[target] or CFrame.new(0, 0, 0)
			local isActuallyFlinging = false

			if data.TargetAtt then 
				if isFocused and isFollowing then 
					local targetPos = mouse.Hit.Position
					local targetRoot = finalTargetRoot or (flingMode and playerTargetRoot)
					
					if (playerFlingEnabled or flingMode) and targetRoot then
						isActuallyFlinging = true
						local swing = math.sin(tick() * 60) * 6
						local targetBasePos = targetRoot.Position
						
						if predictionEnabled then
							local velocity = targetRoot.AssemblyLinearVelocity
							local dist = (targetBasePos - target.Position).Magnitude
							local predictTime = math.clamp(dist / 500, 0.01, 0.25) * predictionStrength
							targetBasePos = targetBasePos + (velocity * predictTime)
						end
						
						local dirVec = targetRoot.CFrame.LookVector
						if flingDirection == "Right" then dirVec = targetRoot.CFrame.RightVector
						elseif flingDirection == "Up" then dirVec = targetRoot.CFrame.UpVector end
						
						targetPos = targetBasePos + (dirVec * swing)
					end
					
					data.TargetAtt.WorldCFrame = CFrame.new(targetPos) * offset.Rotation
					if isActuallyFlinging then
						local direction = (targetPos - target.Position).Unit
						local speed = flingPower
						for _, p in ipairs(data.AffectedParts) do
							p.AssemblyLinearVelocity = direction * speed
							p.AssemblyAngularVelocity = Vector3.new(math.random(-800,800), math.random(-800,800), math.random(-800,800))
						end
					elseif followKeepPosition and not (playerFlingEnabled or flingMode) then
						partMemory[target] = baseCFrame:Inverse() * data.TargetAtt.WorldCFrame
					end
				else
					data.TargetAtt.WorldCFrame = isOrbiting and (CFrame.new((baseCFrame * CFrame.new(offset.Position)).Position) * offset.Rotation) or (baseCFrame * offset)
				end 
			end
			
			if not isActuallyFlinging then
				for _, p in ipairs(data.AffectedParts) do
					if keepOwnership then
						local rv = 14.4 + (math.random() * 2.1)
						p.AssemblyLinearVelocity = Vector3.new(rv, rv, rv)
					else
						p.AssemblyLinearVelocity = Vector3.new(0,0,0)
						p.AssemblyAngularVelocity = Vector3.new(0,0,0)
					end
				end
			end
		else heldParts[target] = nil end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed) if not processed and input.KeyCode == Enum.KeyCode.G then if activeGui then activeGui.Enabled = not activeGui.Enabled end end end)
Tool.Activated:Connect(onActivated); Tool.Unequipped:Connect(function() for target, data in pairs(heldParts) do restorePhysics(data.OriginalGroups); clearConstraints(target) end heldParts = {}; handle:ClearAllChildren(); if lockedTargetRoot then applyLockHighlight(lockedTargetRoot, false) end if activeGui then activeGui:Destroy(); activeGui = nil end end)
Tool.Parent = player.Backpack
