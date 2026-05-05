-- Remote Fire Hub
-- this is not a remotespy and does not require a good executor to function
local player = game:GetService("Players").LocalPlayer
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local PRESET_FILE = "remote_presets.json"
local SETTINGS_FILE = "remote_hub_settings.json"

-- Data Tables
local selectedRemote = nil
local argumentList = {} 
local fireAllByName = false
local globalSettings = {
    autoLoadPresets = false
}

-- Helper: Safe JSON Decode
local function decodeJSON(str)
    local success, data = pcall(function() return HttpService:JSONDecode(str) end)
    return success and data or {}
end

-- Settings Management
local function saveGlobalSettings()
    pcall(function()
        if writefile then
            writefile(SETTINGS_FILE, HttpService:JSONEncode(globalSettings))
        end
    end)
end

local function loadGlobalSettings()
    if not isfile or not isfile(SETTINGS_FILE) then return end
    local data = decodeJSON(readfile(SETTINGS_FILE))
    for k, v in pairs(data) do globalSettings[k] = v end
end
loadGlobalSettings()

-- Cleanup
local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("RemoteFireGui")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
ScreenGui.Name = "RemoteFireGui"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
MainFrame.Size = UDim2.new(0, 400, 0, 450)
MainFrame.ClipsDescendants = true
MainFrame.Active = true
Instance.new("UICorner", MainFrame)

-- --- TITLE BAR ---
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TitleBar.ZIndex = 2

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 40, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ANNAROBLOX'S REMOTE FIRE HUB"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.ZIndex = 3

local SettingsBtn = Instance.new("TextButton", TitleBar)
SettingsBtn.Size = UDim2.new(0, 30, 0, 30)
SettingsBtn.Position = UDim2.new(1, -35, 0, 2)
SettingsBtn.BackgroundTransparency = 1
SettingsBtn.Text = "⚙"
SettingsBtn.TextColor3 = Color3.new(1, 1, 1)
SettingsBtn.TextSize = 18
SettingsBtn.Font = Enum.Font.GothamBold
SettingsBtn.ZIndex = 3

-- --- SEARCH VIEW ---
local SearchView = Instance.new("Frame", MainFrame)
SearchView.Name = "SearchView"
SearchView.Size = UDim2.new(1, 0, 1, -35)
SearchView.Position = UDim2.new(0, 0, 0, 35)
SearchView.BackgroundTransparency = 1
SearchView.ZIndex = 1

local SearchBar = Instance.new("TextBox", SearchView)
SearchBar.Size = UDim2.new(0.9, 0, 0, 30)
SearchBar.Position = UDim2.new(0.05, 0, 0.05, 0)
SearchBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
SearchBar.PlaceholderText = "Search remotes..."
SearchBar.Text = ""
SearchBar.TextColor3 = Color3.new(1, 1, 1)
SearchBar.Font = Enum.Font.Gotham
SearchBar.ZIndex = 2
Instance.new("UICorner", SearchBar)

local ResultsScroll = Instance.new("ScrollingFrame", SearchView)
ResultsScroll.Size = UDim2.new(0.9, 0, 0.8, 0)
ResultsScroll.Position = UDim2.new(0.05, 0, 0.15, 0)
ResultsScroll.BackgroundTransparency = 1
ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsScroll.ScrollBarThickness = 4
ResultsScroll.ZIndex = 2
Instance.new("UIListLayout", ResultsScroll).Padding = UDim.new(0, 5)

-- --- FIRE VIEW ---
local FireView = Instance.new("Frame", MainFrame)
FireView.Name = "FireView"
FireView.Size = UDim2.new(1, 0, 1, -35)
FireView.Position = UDim2.new(1, 0, 0, 35)
FireView.BackgroundTransparency = 1
FireView.ZIndex = 1

local BackBtn = Instance.new("TextButton", FireView)
BackBtn.Size = UDim2.new(0, 60, 0, 25)
BackBtn.Position = UDim2.new(0.05, 0, 0.02, 0)
BackBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
BackBtn.Text = "< Back"
BackBtn.TextColor3 = Color3.new(1, 1, 1)
BackBtn.Font = Enum.Font.GothamBold
BackBtn.ZIndex = 2
Instance.new("UICorner", BackBtn)

local RemoteTitle = Instance.new("TextLabel", FireView)
RemoteTitle.Size = UDim2.new(0.6, 0, 0, 25)
RemoteTitle.Position = UDim2.new(0.25, 0, 0.02, 0)
RemoteTitle.BackgroundTransparency = 1
RemoteTitle.Text = "Target: None"
RemoteTitle.TextColor3 = Color3.new(0.8, 0.8, 0.8)
RemoteTitle.Font = Enum.Font.Gotham
RemoteTitle.TextSize = 11
RemoteTitle.ZIndex = 2

local ArgsScroll = Instance.new("ScrollingFrame", FireView)
ArgsScroll.Size = UDim2.new(0.9, 0, 0.45, 0)
ArgsScroll.Position = UDim2.new(0.05, 0, 0.1, 0)
ArgsScroll.BackgroundTransparency = 1
ArgsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ArgsScroll.ZIndex = 2
Instance.new("UIListLayout", ArgsScroll).Padding = UDim.new(0, 5)

local PresetNameInput = Instance.new("TextBox", FireView)
PresetNameInput.Size = UDim2.new(0.4, 0, 0, 25)
PresetNameInput.Position = UDim2.new(0.05, 0, 0.58, 0)
PresetNameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
PresetNameInput.PlaceholderText = "Preset Name"
PresetNameInput.Text = ""
PresetNameInput.TextColor3 = Color3.new(1, 1, 1)
PresetNameInput.Font = Enum.Font.Gotham
PresetNameInput.ZIndex = 2
Instance.new("UICorner", PresetNameInput)

local SavePresetBtn = Instance.new("TextButton", FireView)
SavePresetBtn.Size = UDim2.new(0.22, 0, 0, 25)
SavePresetBtn.Position = UDim2.new(0.47, 0, 0.58, 0)
SavePresetBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 0)
SavePresetBtn.Text = "Save"
SavePresetBtn.TextColor3 = Color3.new(1, 1, 1)
SavePresetBtn.Font = Enum.Font.GothamBold
SavePresetBtn.ZIndex = 2
Instance.new("UICorner", SavePresetBtn)

local LoadPresetBtn = Instance.new("TextButton", FireView)
LoadPresetBtn.Size = UDim2.new(0.22, 0, 0, 25)
LoadPresetBtn.Position = UDim2.new(0.71, 0, 0.58, 0)
LoadPresetBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 100)
LoadPresetBtn.Text = "Load"
LoadPresetBtn.TextColor3 = Color3.new(1, 1, 1)
LoadPresetBtn.Font = Enum.Font.GothamBold
LoadPresetBtn.ZIndex = 2
Instance.new("UICorner", LoadPresetBtn)

local FireAllToggle = Instance.new("TextButton", FireView)
FireAllToggle.Size = UDim2.new(0.9, 0, 0, 30)
FireAllToggle.Position = UDim2.new(0.05, 0, 0.67, 0)
FireAllToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
FireAllToggle.Text = "Fire All by Name: OFF"
FireAllToggle.TextColor3 = Color3.new(1, 1, 1)
FireAllToggle.Font = Enum.Font.GothamBold
FireAllToggle.TextSize = 12
FireAllToggle.ZIndex = 2
Instance.new("UICorner", FireAllToggle)

local AddArgBtn = Instance.new("TextButton", FireView)
AddArgBtn.Size = UDim2.new(0.425, 0, 0, 40)
AddArgBtn.Position = UDim2.new(0.05, 0, 0.8, 0)
AddArgBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
AddArgBtn.Text = "+ Add Argument"
AddArgBtn.TextColor3 = Color3.new(1, 1, 1)
AddArgBtn.Font = Enum.Font.GothamBold
AddArgBtn.ZIndex = 2
Instance.new("UICorner", AddArgBtn)

local FireBtn = Instance.new("TextButton", FireView)
FireBtn.Size = UDim2.new(0.425, 0, 0, 40)
FireBtn.Position = UDim2.new(0.525, 0, 0.8, 0)
FireBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
FireBtn.Text = "FIRE SERVER"
FireBtn.TextColor3 = Color3.new(1, 1, 1)
FireBtn.Font = Enum.Font.GothamBold
FireBtn.ZIndex = 2
Instance.new("UICorner", FireBtn)

-- --- SETTINGS VIEW ---
local SettingsView = Instance.new("Frame", MainFrame)
SettingsView.Name = "SettingsView"
SettingsView.Size = UDim2.new(1, 0, 1, -35)
SettingsView.Position = UDim2.new(0, 0, 1, 0) -- Start below
SettingsView.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SettingsView.ZIndex = 10
Instance.new("UICorner", SettingsView)

local CloseSettingsBtn = Instance.new("TextButton", SettingsView)
CloseSettingsBtn.Size = UDim2.new(1, 0, 0, 30)
CloseSettingsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
CloseSettingsBtn.Text = "CLOSE SETTINGS"
CloseSettingsBtn.TextColor3 = Color3.new(1, 1, 1)
CloseSettingsBtn.Font = Enum.Font.GothamBold
CloseSettingsBtn.ZIndex = 11

local AutoLoadToggle = Instance.new("TextButton", SettingsView)
AutoLoadToggle.Size = UDim2.new(0.9, 0, 0, 40)
AutoLoadToggle.Position = UDim2.new(0.05, 0, 0.15, 0)
AutoLoadToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
AutoLoadToggle.Text = "Auto Load Presets: OFF"
AutoLoadToggle.TextColor3 = Color3.new(1, 1, 1)
AutoLoadToggle.Font = Enum.Font.GothamBold
AutoLoadToggle.ZIndex = 11
Instance.new("UICorner", AutoLoadToggle)

-- --- LOGIC ---

local function updateArgsUI()
    for _, child in ipairs(ArgsScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for i, arg in ipairs(argumentList) do
        local f = Instance.new("Frame", ArgsScroll)
        f.Size = UDim2.new(1, -10, 0, 35); f.BackgroundColor3 = Color3.fromRGB(45, 45, 45); Instance.new("UICorner", f); f.ZIndex = 3
        
        local typeBtn = Instance.new("TextButton", f)
        typeBtn.Size = UDim2.new(0, 80, 0.8, 0); typeBtn.Position = UDim2.new(0.02, 0, 0.1, 0); typeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        typeBtn.Text = arg.Type; typeBtn.TextColor3 = Color3.new(0, 0.8, 1); typeBtn.Font = Enum.Font.GothamBold; typeBtn.TextSize = 10; Instance.new("UICorner", typeBtn); typeBtn.ZIndex = 4
        
        typeBtn.MouseButton1Click:Connect(function()
            local types = {"String", "Number", "Boolean", "JSON", "Iterative"}
            local current = table.find(types, arg.Type) or 1
            arg.Type = types[(current % #types) + 1]; typeBtn.Text = arg.Type
        end)
        
        local valInput = Instance.new("TextBox", f)
        valInput.Size = UDim2.new(0.55, 0, 0.8, 0); valInput.Position = UDim2.new(0.25, 0, 0.1, 0); valInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        valInput.Text = tostring(arg.Value); valInput.TextColor3 = Color3.new(1, 1, 1); valInput.PlaceholderText = "Value..."; valInput.Font = Enum.Font.Gotham; valInput.TextSize = 11; Instance.new("UICorner", valInput); valInput.ZIndex = 4
        valInput.FocusLost:Connect(function() arg.Value = valInput.Text end)
        
        local removeBtn = Instance.new("TextButton", f)
        removeBtn.Size = UDim2.new(0, 30, 0.8, 0); removeBtn.Position = UDim2.new(0.9, 0, 0.1, 0); removeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40); removeBtn.Text = "X"; removeBtn.TextColor3 = Color3.new(1, 1, 1); removeBtn.Font = Enum.Font.GothamBold; Instance.new("UICorner", removeBtn); removeBtn.ZIndex = 4
        removeBtn.MouseButton1Click:Connect(function() table.remove(argumentList, i); updateArgsUI() end)
    end
    ArgsScroll.CanvasSize = UDim2.new(0, 0, 0, #argumentList * 40)
end

local function tryAutoLoad(remoteName)
    if not globalSettings.autoLoadPresets or not isfile(PRESET_FILE) then return end
    local presets = decodeJSON(readfile(PRESET_FILE))
    for _, p in pairs(presets) do
        if p.RemoteName == remoteName then
            argumentList = p.Args or {}
            updateArgsUI()
            return true
        end
    end
end

local function showFire(remote)
    selectedRemote = remote
    RemoteTitle.Text = "Target: " .. (remote and remote.Name or "Unknown")
    argumentList = {}
    if remote then tryAutoLoad(remote.Name) end
    updateArgsUI()
    SearchView:TweenPosition(UDim2.new(-1, 0, 0, 35), "Out", "Quad", 0.3, true)
    FireView:TweenPosition(UDim2.new(0, 0, 0, 35), "Out", "Quad", 0.3, true)
end

local function updateSettingsUI()
    AutoLoadToggle.Text = "Auto Load Presets: " .. (globalSettings.autoLoadPresets and "ON" or "OFF")
    AutoLoadToggle.BackgroundColor3 = globalSettings.autoLoadPresets and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(60, 60, 60)
end

-- --- EVENTS ---

SettingsBtn.MouseButton1Click:Connect(function()
    SettingsView:TweenPosition(UDim2.new(0, 0, 0, 35), "Out", "Quad", 0.3, true)
end)

CloseSettingsBtn.MouseButton1Click:Connect(function()
    SettingsView:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.3, true)
end)

AutoLoadToggle.MouseButton1Click:Connect(function()
    globalSettings.autoLoadPresets = not globalSettings.autoLoadPresets
    updateSettingsUI()
    saveGlobalSettings()
end)

FireAllToggle.MouseButton1Click:Connect(function()
    fireAllByName = not fireAllByName
    FireAllToggle.Text = "Fire All by Name: " .. (fireAllByName and "ON" or "OFF")
    FireAllToggle.BackgroundColor3 = fireAllByName and Color3.fromRGB(0, 100, 150) or Color3.fromRGB(60, 60, 60)
end)

BackBtn.MouseButton1Click:Connect(function()
    FireView:TweenPosition(UDim2.new(1, 0, 0, 35), "Out", "Quad", 0.3, true)
    SearchView:TweenPosition(UDim2.new(0, 0, 0, 35), "Out", "Quad", 0.3, true)
end)

AddArgBtn.MouseButton1Click:Connect(function()
    table.insert(argumentList, {Type = "String", Value = ""})
    updateArgsUI()
end)

SavePresetBtn.MouseButton1Click:Connect(function()
    local name = PresetNameInput.Text; if name == "" or not selectedRemote then return end
    local presets = isfile(PRESET_FILE) and decodeJSON(readfile(PRESET_FILE)) or {}
    presets[name] = {RemoteName = selectedRemote.Name, Args = argumentList}
    writefile(PRESET_FILE, HttpService:JSONEncode(presets))
    SavePresetBtn.Text = "SAVED"; task.wait(0.5); SavePresetBtn.Text = "Save"
end)

LoadPresetBtn.MouseButton1Click:Connect(function()
    local name = PresetNameInput.Text; if name == "" or not isfile(PRESET_FILE) then return end
    local presets = decodeJSON(readfile(PRESET_FILE))
    local p = presets[name]; if p then argumentList = p.Args or {}; updateArgsUI(); LoadPresetBtn.Text = "LOADED"; task.wait(0.5); LoadPresetBtn.Text = "Load" end
end)

FireBtn.MouseButton1Click:Connect(function()
    if not selectedRemote then return end
    
    local expandedArgs = {}
    for i, arg in ipairs(argumentList) do
        if arg.Type == "Iterative" then
            local list = {}
            local parts = arg.Value:split(",")
            for _, p in ipairs(parts) do
                local count = 1
                local delayVal = 0
                local valPart = p
                
                -- Extract count [n] if it exists
                local c = valPart:match("%[(%d+)%]$")
                if c then
                    count = tonumber(c) or 1
                    valPart = valPart:sub(1, #valPart - (#c + 2))
                end
                
                -- Extract delay (n) if it exists
                local d = valPart:match("%(([%d%.]+)%)$")
                if d then
                    delayVal = tonumber(d) or 0
                    valPart = valPart:sub(1, #valPart - (#d + 2))
                end
                
                -- Secondary check for count if it was inside the delay bracket or vice versa
                if not c then
                    c = valPart:match("%[(%d+)%]$")
                    if c then
                        count = tonumber(c) or 1
                        valPart = valPart:sub(1, #valPart - (#c + 2))
                    end
                end

                for _ = 1, count do
                    table.insert(list, {Value = valPart, Delay = delayVal})
                end
            end
            if #list == 0 then table.insert(list, {Value = "", Delay = 0}) end
            expandedArgs[i] = list
        end
    end

    local function getArgs(idx)
        local args = {}; local stepDelay = 0; local batch = false
        for i, arg in ipairs(argumentList) do
            local val = arg.Value
            if arg.Type == "Iterative" then
                local list = expandedArgs[i]
                local entry = list[((idx - 1) % #list) + 1]
                val = entry.Value
                stepDelay = math.max(stepDelay, entry.Delay)
                -- If delay is 0 and it's part of a set, treat as batch
                if entry.Delay == 0 then batch = true end
            end
            if arg.Type == "Number" then val = tonumber(val) or 0
            elseif arg.Type == "Boolean" then val = (val:lower() == "true")
            elseif arg.Type == "JSON" then val = decodeJSON(val) end
            table.insert(args, val)
        end
        return args, stepDelay, batch
    end

    if fireAllByName then
        local remotes = {}; local name = selectedRemote.Name
        local function scan(p) for _, o in ipairs(p:GetChildren()) do if o:IsA("RemoteEvent") and o.Name == name then table.insert(remotes, o) end if not o:IsA("BasePart") then pcall(scan, o) end end end
        scan(game:GetService("ReplicatedStorage")); scan(game:GetService("Workspace"))
        task.spawn(function() 
            for i, o in ipairs(remotes) do 
                local a, d, isBatch = getArgs(i)
                if isBatch and d == 0 then
                    -- Fire in parallel for batch sets with no delay
                    task.spawn(function() pcall(function() o:FireServer(unpack(a)) end) end)
                else
                    -- Fire sequentially if delay is set or not a batch
                    pcall(function() o:FireServer(unpack(a)) end) 
                    if d and d > 0 then task.wait(d) end 
                end
            end 
        end)
    else 
        local a, _ = getArgs(1)
        pcall(function() selectedRemote:FireServer(unpack(a)) end) 
    end
    FireBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0); task.wait(0.2); FireBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
end)

-- Search Logic
local function updateResults()
    for _, child in ipairs(ResultsScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local q = SearchBar.Text:lower(); local c = 0
    local function scan(p)
        for _, o in ipairs(p:GetChildren()) do
            if o:IsA("RemoteEvent") and (q == "" or o.Name:lower():find(q)) then
                local b = Instance.new("TextButton", ResultsScroll)
                b.Size = UDim2.new(1, -10, 0, 30); b.BackgroundColor3 = Color3.fromRGB(50, 50, 50); b.Text = o.Name .. " (" .. o.Parent.Name .. ")"; b.TextColor3 = Color3.new(0.9, 0.9, 0.9); b.Font = Enum.Font.Gotham; b.TextSize = 11; Instance.new("UICorner", b); b.ZIndex = 3
                b.MouseButton1Click:Connect(function() showFire(o) end); c = c + 1
            end
            if not o:IsA("BasePart") then pcall(scan, o) end
        end
    end
    scan(game:GetService("ReplicatedStorage")); scan(game:GetService("Workspace")); ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, c * 35)
end
SearchBar:GetPropertyChangedSignal("Text"):Connect(updateResults); updateResults()

-- Draggable
local d, di, ds, sp
MainFrame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true; ds = i.Position; sp = MainFrame.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end) end end)
MainFrame.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then di = i end end)
UserInputService.InputChanged:Connect(function(i) if i == di and d then local dl = i.Position - ds; MainFrame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dl.X, sp.Y.Scale, sp.Y.Offset + dl.Y) end end)

-- Keybind to toggle visibility (B)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.B then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

updateSettingsUI()
