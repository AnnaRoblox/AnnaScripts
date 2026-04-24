-- annaroblox's richtext bypasser
-- this isnt made for the real chat its made for games with custom chat or ui elements that support richtext
-- Features include auto chat remote detector + custom remote finder for when it fails. 
--multiple diffrent modes + automode. 
-- if you dont enable any mode you can send normal text using the ui no need to switch to the normal chat
-- auto removes itself if you reexecute no need to rejoin if something breaks
-- attempts to save custom remotes per game if your executor supports it
-- allows you to do changes to text in the messagebox ex !redtext!red would make it red !btext!b bold !size(35)text!size makes it bigger etc

-- ChatBypass richtext edition 
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. RICH TEXT CHECKER ON LOAD
task.spawn(function()
    task.wait(1) -- Wait a moment for game to settle
    local richTextFound = false
    
    -- Check PlayerGui as that is where chat usually resides
    local player = Players.LocalPlayer
    if player then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            for _, v in ipairs(playerGui:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
                    if v.RichText == true then
                        richTextFound = true
                        break
                    end
                end
            end
        end
    end

    if richTextFound then
        print("richtext found it should work here")
    else
        print("richtext not enabled might not work here")
    end
end)

if CoreGui:FindFirstChild("ChatBypass") then
     print("AnnaRoblox's universal richtext bypasser already loaded")
     CoreGui.ChatBypass:Destroy()
end

print("AnnaRoblox's universal RichText Bypasser loaded")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatBypass"
ScreenGui.Parent = CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 340, 0, 500)
Frame.Position = UDim2.new(0.5, -170, 0.5, -250)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 2
Frame.BorderColor3 = Color3.fromRGB(0, 255, 0)
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local CustomChatRemote = nil
local CustomArgsString = "" -- Stores the raw JSON string for args

-- Save/Load Custom Remote per game
local PlaceId = game.PlaceId
local saveFolder = "ChatBypassRemotes"
if not isfolder(saveFolder) then
    makefolder(saveFolder)
end
local saveFile = saveFolder .. "/" .. PlaceId .. ".json" -- Changed to JSON for more data

-- Function to get instance from full path
local function getInstanceFromPath(path)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    local curr = game
    for _, p in ipairs(parts) do
        curr = curr:FindFirstChild(p)
        if not curr then return nil end
    end
    return curr
end

-- Load saved remote if exists
if isfile(saveFile) then
    local content = readfile(saveFile)
    -- Try to parse as JSON first (New Format)
    local success, data = pcall(function() return HttpService:JSONDecode(content) end)
    
    if success and data.Path then
        local remote = getInstanceFromPath(data.Path)
        if remote then
            CustomChatRemote = remote
            if data.Args then
                CustomArgsString = data.Args
            end
        end
    elseif not success then
        -- Legacy support (Old text file format)
        local remote = getInstanceFromPath(content)
        if remote then CustomChatRemote = remote end
    end
end

-- Dragging logic
local dragging = false
Frame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        local start = inp.Position
        local startPos = Frame.Position
        local conn = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = i.Position - start
                Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                dragging = false
                conn:Disconnect()
            end
        end)
    end
end)

-- UI Elements
local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(0.9, 0, 0.20, 0)
InputBox.Position = UDim2.new(0.05, 0, 0.08, 0)
InputBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
InputBox.TextColor3 = Color3.fromRGB(0, 255, 0)
InputBox.PlaceholderText = "Type here... Support: !b, !i, !u, !s, !size45, !ffArial, !red..."
InputBox.Text = ""
InputBox.ClearTextOnFocus = true
InputBox.RichText = true
InputBox.Font = Enum.Font.Code
InputBox.TextSize = 16
InputBox.TextWrapped = true
InputBox.Parent = Frame

local TagBox = Instance.new("TextBox")
TagBox.Size = UDim2.new(0.44, 0, 0.08, 0)
TagBox.Position = UDim2.new(0.05, 0, 0.35, 0)
TagBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TagBox.Text = "font"
TagBox.PlaceholderText = "Tag or !red, !size40..."
TagBox.TextColor3 = Color3.new(1,1,1)
TagBox.Font = Enum.Font.Code
TagBox.Parent = Frame

local CustomIntervalBox = Instance.new("TextBox")
CustomIntervalBox.Size = UDim2.new(0.4, 0, 0.08, 0)
CustomIntervalBox.Position = UDim2.new(0.55, 0, 0.35, 0)
CustomIntervalBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
CustomIntervalBox.Text = "2"
CustomIntervalBox.TextColor3 = Color3.fromRGB(255, 255, 0)
CustomIntervalBox.Font = Enum.Font.Code
CustomIntervalBox.Parent = Frame

-- Toggles
local AllLetters = false
local CustomMode = false
local SmartMode = false
local AutoMode = false
local HexMode = false
local HexAntiSpam = false
local FilterReset = true

local AllLettersToggle = Instance.new("TextButton")
AllLettersToggle.Size = UDim2.new(0.3, 0, 0.08, 0)
AllLettersToggle.Position = UDim2.new(0.05, 0, 0.46, 0)
AllLettersToggle.Text = "All Letters: OFF"
AllLettersToggle.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
AllLettersToggle.Parent = Frame

local CustomModeToggle = Instance.new("TextButton")
CustomModeToggle.Size = UDim2.new(0.3, 0, 0.08, 0)
CustomModeToggle.Position = UDim2.new(0.36, 0, 0.46, 0)
CustomModeToggle.Text = "Custom Mode: OFF"
CustomModeToggle.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
CustomModeToggle.Parent = Frame

local SmartModeToggle = Instance.new("TextButton")
SmartModeToggle.Size = UDim2.new(0.3, 0, 0.08, 0)
SmartModeToggle.Position = UDim2.new(0.67, 0, 0.46, 0)
SmartModeToggle.Text = "Smart Mode: OFF"
SmartModeToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
SmartModeToggle.Parent = Frame

local AutoModeToggle = Instance.new("TextButton")
AutoModeToggle.Size = UDim2.new(0.44, 0, 0.08, 0)
AutoModeToggle.Position = UDim2.new(0.05, 0, 0.56, 0)
AutoModeToggle.Text = "Auto Mode: OFF"
AutoModeToggle.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
AutoModeToggle.Font = Enum.Font.Code
AutoModeToggle.TextColor3 = Color3.new(1,1,1)
AutoModeToggle.Parent = Frame

local HexModeToggle = Instance.new("TextButton")
HexModeToggle.Size = UDim2.new(0.44, 0, 0.08, 0)
HexModeToggle.Position = UDim2.new(0.53, 0, 0.56, 0)
HexModeToggle.Text = "Hex Mode: OFF"
HexModeToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
HexModeToggle.Font = Enum.Font.Code
HexModeToggle.TextColor3 = Color3.new(1,1,1)
HexModeToggle.Parent = Frame

local FilterResetToggle = Instance.new("TextButton")
FilterResetToggle.Size = UDim2.new(0.9, 0, 0.08, 0)
FilterResetToggle.Position = UDim2.new(0.05, 0, 0.66, 0)
FilterResetToggle.Text = "Filter Reset: ON"
FilterResetToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 0)
FilterResetToggle.Parent = Frame

local CustomRemoteButton = Instance.new("TextButton")
CustomRemoteButton.Size = UDim2.new(0.9, 0, 0.08, 0)
CustomRemoteButton.Position = UDim2.new(0.05, 0, 0.76, 0)
CustomRemoteButton.Text = "Set Custom Remote"
CustomRemoteButton.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
CustomRemoteButton.Font = Enum.Font.Code
CustomRemoteButton.TextColor3 = Color3.new(1,1,1)
CustomRemoteButton.Parent = Frame

local SendButton = Instance.new("TextButton")
SendButton.Size = UDim2.new(0.57, 0, 0.09, 0)
SendButton.Position = UDim2.new(0.05, 0, 0.86, 0)
SendButton.Text = "SEND"
SendButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
SendButton.Font = Enum.Font.GothamBold
SendButton.Parent = Frame

local ClearButton = Instance.new("TextButton")
ClearButton.Size = UDim2.new(0.28, 0, 0.09, 0)
ClearButton.Position = UDim2.new(0.67, 0, 0.86, 0)
ClearButton.Text = "Clear"
ClearButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
ClearButton.Parent = Frame

local PreviewLabel = Instance.new("TextBox")
PreviewLabel.Size = UDim2.new(0.9, 0, 0.05, 0)
PreviewLabel.Position = UDim2.new(0.05, 0, 0.94, 0)
PreviewLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PreviewLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
PreviewLabel.Font = Enum.Font.Code
PreviewLabel.RichText = true
PreviewLabel.TextSize = 13
PreviewLabel.TextWrapped = true
PreviewLabel.TextXAlignment = Enum.TextXAlignment.Left
PreviewLabel.Text = "Preview here"
PreviewLabel.Selectable = true
PreviewLabel.ClearTextOnFocus = false
PreviewLabel.TextEditable = false
PreviewLabel.Parent = Frame

-- ==========================================
-- IMPROVED REMOTE SELECTOR (With Advanced Args)
-- ==========================================

local RemoteSelector = Instance.new("Frame")
RemoteSelector.Size = UDim2.new(0, 400, 0, 500)
RemoteSelector.Position = UDim2.new(0.5, -200, 0.5, -250)
RemoteSelector.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RemoteSelector.BorderSizePixel = 2
RemoteSelector.BorderColor3 = Color3.fromRGB(0, 160, 255)
RemoteSelector.Active = true
RemoteSelector.Draggable = true
RemoteSelector.Visible = false
RemoteSelector.Parent = ScreenGui

local SelectorTitle = Instance.new("TextLabel")
SelectorTitle.Size = UDim2.new(1, 0, 0.06, 0)
SelectorTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SelectorTitle.Text = "Remote Selector & Args"
SelectorTitle.TextColor3 = Color3.fromRGB(0, 160, 255)
SelectorTitle.Font = Enum.Font.GothamBold
SelectorTitle.Parent = RemoteSelector

local CloseSelector = Instance.new("TextButton")
CloseSelector.Size = UDim2.new(0.1, 0, 0.06, 0)
CloseSelector.Position = UDim2.new(0.9, 0, 0, 0)
CloseSelector.Text = "X"
CloseSelector.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
CloseSelector.TextColor3 = Color3.new(1,1,1)
CloseSelector.Parent = RemoteSelector

local SearchRemoteBox = Instance.new("TextBox")
SearchRemoteBox.Size = UDim2.new(0.92, 0, 0.06, 0)
SearchRemoteBox.Position = UDim2.new(0.04, 0, 0.08, 0)
SearchRemoteBox.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
SearchRemoteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchRemoteBox.PlaceholderText = "Search Remote Name..."
SearchRemoteBox.Text = ""
SearchRemoteBox.Font = Enum.Font.Code
SearchRemoteBox.TextSize = 14
SearchRemoteBox.Parent = RemoteSelector

local RemoteScroll = Instance.new("ScrollingFrame")
RemoteScroll.Size = UDim2.new(0.92, 0, 0.50, 0) -- Adjusted height to fit arg editor
RemoteScroll.Position = UDim2.new(0.04, 0, 0.16, 0)
RemoteScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
RemoteScroll.ScrollBarThickness = 6
RemoteScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
RemoteScroll.CanvasSize = UDim2.new(0,0,0,0)
RemoteScroll.Parent = RemoteSelector

local RemoteLayout = Instance.new("UIListLayout")
RemoteLayout.FillDirection = Enum.FillDirection.Vertical
RemoteLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
RemoteLayout.VerticalAlignment = Enum.VerticalAlignment.Top
RemoteLayout.Padding = UDim.new(0, 2)
RemoteLayout.Parent = RemoteScroll

-- Advanced Argument Section
local ArgsLabel = Instance.new("TextLabel")
ArgsLabel.Size = UDim2.new(0.92, 0, 0.04, 0)
ArgsLabel.Position = UDim2.new(0.04, 0, 0.68, 0)
ArgsLabel.BackgroundTransparency = 1
ArgsLabel.Text = "Advanced Arguments (JSON Array):"
ArgsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
ArgsLabel.Font = Enum.Font.Code
ArgsLabel.TextXAlignment = Enum.TextXAlignment.Left
ArgsLabel.Parent = RemoteSelector

local ArgsHelp = Instance.new("TextLabel")
ArgsHelp.Size = UDim2.new(0.92, 0, 0.04, 0)
ArgsHelp.Position = UDim2.new(0.04, 0, 0.72, 0)
ArgsHelp.BackgroundTransparency = 1
ArgsHelp.Text = "Use '!message' for processed text."
ArgsHelp.TextColor3 = Color3.fromRGB(180, 180, 180)
ArgsHelp.Font = Enum.Font.Code
ArgsHelp.TextSize = 12
ArgsHelp.TextXAlignment = Enum.TextXAlignment.Left
ArgsHelp.Parent = RemoteSelector

local ArgsInput = Instance.new("TextBox")
ArgsInput.Size = UDim2.new(0.92, 0, 0.10, 0)
ArgsInput.Position = UDim2.new(0.04, 0, 0.77, 0)
ArgsInput.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
ArgsInput.TextColor3 = Color3.fromRGB(0, 255, 100)
ArgsInput.PlaceholderText = 'Example: ["!message", "All"]'
ArgsInput.Text = "" -- Default empty
ArgsInput.Font = Enum.Font.Code
ArgsInput.TextSize = 12
ArgsInput.TextWrapped = true
ArgsInput.ClearTextOnFocus = false
ArgsInput.TextYAlignment = Enum.TextYAlignment.Top
ArgsInput.Parent = RemoteSelector

-- Helper function to save
local function saveConfig()
    if CustomChatRemote then
        local data = {
            Path = CustomChatRemote:GetFullName(),
            Args = ArgsInput.Text
        }
        writefile(saveFile, HttpService:JSONEncode(data))
    end
end

ArgsInput.FocusLost:Connect(function()
    CustomArgsString = ArgsInput.Text
    saveConfig()
end)

local ClearCustomRemote = Instance.new("TextButton")
ClearCustomRemote.Size = UDim2.new(0.92, 0, 0.08, 0)
ClearCustomRemote.Position = UDim2.new(0.04, 0, 0.89, 0)
ClearCustomRemote.Text = "Clear Custom Remote"
ClearCustomRemote.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
ClearCustomRemote.TextColor3 = Color3.new(1,1,1)
ClearCustomRemote.Font = Enum.Font.Code
ClearCustomRemote.Parent = RemoteSelector

local cachedRemotes = {}

local function updateRemoteList(filter)
    for _, btn in ipairs(RemoteScroll:GetChildren()) do
        if btn:IsA("TextButton") then btn:Destroy() end
    end
    for _, remote in ipairs(cachedRemotes) do
        local remoteName = remote.Name
        local match = true
        if filter and filter ~= "" then
            if not string.find(string.lower(remoteName), string.lower(filter)) then
                match = false
            end
        end
        if match then
            local remoteBtn = Instance.new("TextButton")
            remoteBtn.Size = UDim2.new(1, 0, 0, 30)
            if remote:IsA("RemoteFunction") then
                remoteBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
            else
                remoteBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            end
            local typeLabel = remote:IsA("RemoteFunction") and "[Func] " or "[Event] "
            remoteBtn.Text = typeLabel .. remote:GetFullName()
            remoteBtn.TextColor3 = Color3.new(1,1,1)
            remoteBtn.Font = Enum.Font.Code
            remoteBtn.TextSize = 12
            remoteBtn.TextWrapped = true
            remoteBtn.TextXAlignment = Enum.TextXAlignment.Left
            remoteBtn.AutoButtonColor = true
            remoteBtn.Parent = RemoteScroll
            remoteBtn.MouseButton1Click:Connect(function()
                CustomChatRemote = remote
                CustomRemoteButton.Text = "Custom: " .. remote.Name
                saveConfig()
                RemoteSelector.Visible = false
            end)
        end
    end
end

local function cacheAndPopulate()
    cachedRemotes = {}
    for _, descendant in ipairs(game:GetDescendants()) do
        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            table.insert(cachedRemotes, descendant)
        end
    end
    updateRemoteList(SearchRemoteBox.Text)
end

SearchRemoteBox:GetPropertyChangedSignal("Text"):Connect(function()
    updateRemoteList(SearchRemoteBox.Text)
end)

local selDragging = false
RemoteSelector.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        selDragging = true
        local start = inp.Position
        local startPos = RemoteSelector.Position
        local conn = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement and selDragging then
                local delta = i.Position - start
                RemoteSelector.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                selDragging = false
                conn:Disconnect()
            end
        end)
    end
end)

CustomRemoteButton.MouseButton1Click:Connect(function()
    RemoteSelector.Visible = not RemoteSelector.Visible
    if RemoteSelector.Visible then
        cacheAndPopulate()
        -- Load args into box if loaded
        ArgsInput.Text = CustomArgsString
    end
end)

CloseSelector.MouseButton1Click:Connect(function() RemoteSelector.Visible = false end)
ClearCustomRemote.MouseButton1Click:Connect(function()
    CustomChatRemote = nil
    CustomArgsString = ""
    ArgsInput.Text = ""
    CustomRemoteButton.Text = "Set Custom Remote"
    if isfile(saveFile) then delfile(saveFile) end
    RemoteSelector.Visible = false
end)


if CustomChatRemote then
    CustomRemoteButton.Text = "Custom: " .. CustomChatRemote.Name
end



-- Helper to check if a codepoint is an emoji
local function isEmoji(cp)
    return (cp >= 0x231A and cp <= 0x231B) or
           (cp >= 0x23E9 and cp <= 0x23F3) or
           (cp >= 0x23F8 and cp <= 0x23FA) or
           (cp == 0x24C2) or
           (cp >= 0x2600 and cp <= 0x26FF) or
           (cp >= 0x2700 and cp <= 0x27BF) or
           (cp >= 0x1F000 and cp <= 0x1F9FF) or
           (cp >= 0x1FA70 and cp <= 0x1FAFF)
end

local function getProcessedText(forPreview)
    local text = InputBox.Text
    if text == "" then return text end

    -- 1. Determine Main Tags (from TagBox)
    local rawTag = TagBox.Text ~= "" and TagBox.Text or "font"
    rawTag = rawTag:gsub("^%s*(.-)%s*$", "%1") -- Trim
    
    local open, close
    local lowerTag = rawTag:lower()
    
    -- Parse TagBox shortcuts (!size, !ff, colors)
    if lowerTag:match("^!size%d+$") then
        local val = lowerTag:match("%d+")
        open = '<font size="'..val..'">'
        close = '</font>'
    elseif lowerTag:match("^!ff.+$") then
        local val = rawTag:sub(4) -- Keep case for font name
        open = '<font face="'..val..'">'
        close = '</font>'
    elseif lowerTag == "!red" then
        open = '<font color="rgb(255,0,0)">'
        close = '</font>'
    elseif lowerTag == "!green" then
        open = '<font color="rgb(0,255,0)">'
        close = '</font>'
    elseif lowerTag == "!blue" then
        open = '<font color="rgb(0,0,255)">'
        close = '</font>'
    elseif lowerTag == "!yellow" then
        open = '<font color="rgb(255,255,0)">'
        close = '</font>'
    elseif lowerTag == "!white" then
        open = '<font color="rgb(255,255,255)">'
        close = '</font>'
    elseif lowerTag == "!black" then
        open = '<font color="rgb(0,0,0)">'
        close = '</font>'
    else
        -- Standard Tag Logic
        if rawTag == "" then rawTag = "font" end
        local tagName = rawTag:match("^%S+") or "font"
        open = "<" .. rawTag .. ">"
        close = "</" .. tagName .. ">"
    end

    -- 2. Core Obfuscator
    local function coreObfuscate(segment)
        if segment == "" then return "" end
        
        -- Hex Mode (Priority)
        if HexMode then
            local result = {}
            for first, last in utf8.graphemes(segment) do
                local char = segment:sub(first, last)
                local isEmo = false
                local codes = {utf8.codepoint(char, 1, -1)}
                
                for _, cp in ipairs(codes) do
                    if isEmoji(cp) or cp == 0x200D or cp == 0xFE0F then
                        isEmo = true
                        break
                    end
                end

                if isEmo or #codes > 1 then
                    table.insert(result, char)
                else
                    table.insert(result, "&#" .. codes[1] .. ";")
                end
            end
            return table.concat(result, "")
        end

        -- Auto Mode
        if AutoMode then
             local safeLetters = {"a","c","d","e","f","g","h","j","k","l","m","n","o","p","q","r","t","v","w","x","y","z"}
             local result = {}
             for first, last in utf8.graphemes(segment) do
                local char = segment:sub(first, last)
                local randLetter = safeLetters[math.random(1, #safeLetters)]
                table.insert(result, "<" .. randLetter .. ">" .. char .. "</" .. randLetter .. ">")
             end
             return table.concat(result, "")
        end

        -- Custom Mode
        if CustomMode then
            local interval = math.clamp(tonumber(CustomIntervalBox.Text) or 2, 1, 50)
            local result = {}
            local current = ""
            local count = 0
            for first, last in utf8.graphemes(segment) do
                local char = segment:sub(first, last)
                if count == 0 then current = open end
                current = current .. char
                count = count + 1
                if count == interval then
                    current = current .. close
                    table.insert(result, current)
                    count = 0
                    current = ""
                end
            end
            if count > 0 then
                current = current .. close
                table.insert(result, current)
            end
            return table.concat(result, "")

        -- Smart Mode
        elseif SmartMode then
             local words = {}
             for word in segment:gmatch("%S+") do
                if #word <= 2 then
                    table.insert(words, word)
                else
                    local insertions = math.floor(#word / 2)
                    if insertions == 0 then
                        table.insert(words, word)
                    else
                        local positions = {}
                        for j = 1, insertions do
                            local pos = math.floor(j * #word / (insertions + 1))
                            table.insert(positions, pos)
                        end
                        table.sort(positions)
                        local parts = {}
                        local start = 1
                        for _, pos in ipairs(positions) do
                            local seg = word:sub(start, pos)
                            if #seg > 0 then table.insert(parts, open .. seg .. close) end
                            start = pos + 1
                        end
                        local last = word:sub(start)
                        if #last > 0 then table.insert(parts, open .. last .. close) end
                        table.insert(words, table.concat(parts, ""))
                    end
                end
             end
             return table.concat(words, " ")

        -- All Letters
        elseif AllLetters then
            local result = {}
            for first, last in utf8.graphemes(segment) do
                local char = segment:sub(first, last)
                table.insert(result, open .. char .. close)
            end
            return table.concat(result, "")

        -- Default (No Obfuscation)
        else
            return segment
        end
    end

    -- 3. Recursive Rich Text Parser
    -- Handles unlimited nesting and priorities (e.g. !blue over !b)
    
   local function parseRichText(str)
    if str == "" then return "" end
    local result = ""
    local cursor = 1
    local len = #str
    -- Rules: paired with (value) first, then simple tags
    local pairedRules = {
        -- !size(35)text!size
        {
            opener = "!size(",
            closer = "!size",
            openTag = function(value) return '<font size="' .. value .. '">' end,
            closeTag = "</font>"
        },
        -- !ff(Arial Black)text!ff
        {
            opener = "!ff(",
            closer = "!ff",
            openTag = function(value) return '<font family="' .. value .. '">' end,
            closeTag = "</font>"
        }
    }
    local simpleRules = {
        -- Colors
        {tag="!red", open='<font color="rgb(255,0,0)">', close='</font>'},
        {tag="!green", open='<font color="rgb(0,255,0)">', close='</font>'},
        {tag="!blue", open='<font color="rgb(0,0,255)">', close='</font>'},
        {tag="!yellow", open='<font color="rgb(255,255,0)">', close='</font>'},
        {tag="!white", open='<font color="rgb(255,255,255)">', close='</font>'},
        {tag="!black", open='<font color="rgb(0,0,0)">', close='</font>'},
        -- Formatting (!s AFTER size handling)
        {tag="!b", open="<b>", close="</b>"},
        {tag="!i", open="<i>", close="</i>"},
        {tag="!u", open="<u>", close="</u>"},
        {tag="!s", open="<s>", close="</s>"},
        -- Newlines
        {tag="!nl", replace="\n"},
        {tag="!newline", replace="\n"}
    }
    while cursor <= len do
        local start = str:find("!", cursor)
        if not start then
            result = result .. coreObfuscate(str:sub(cursor))
            break
        end
        -- Text before !
        if start > cursor then
            result = result .. coreObfuscate(str:sub(cursor, start - 1))
        end
        local matched = false
        -- 1. Check PAIRED rules first (!size(, !ff()
        for _, rule in ipairs(pairedRules) do
            if str:sub(start, start + #rule.opener - 1) == rule.opener then
                -- Find closing ) for value extraction
                local closeParen = str:find("%)", start + #rule.opener)
                if closeParen then
                    -- Extract value: everything between ( and ) , trimmed
                    local rawValue = str:sub(start + #rule.opener, closeParen - 1)
                    local value = rawValue:match("^%s*(.-)%s*$") -- trim whitespace
                   
                    -- Find closer tag after )
                    local closePos = str:find(rule.closer, closeParen + 1, true)
                    if closePos then
                        local innerStart = closeParen + 1
                        local inner = str:sub(innerStart, closePos - 1)
                        result = result .. rule.openTag(value) .. parseRichText(inner) .. rule.closeTag
                        cursor = closePos + #rule.closer
                        matched = true
                        break
                    end
                end
            end
        end
        -- 2. If no paired match, check simple rules
        if not matched then
            for _, rule in ipairs(simpleRules) do
                if rule.replace then
                    if str:sub(start, start + #rule.tag - 1) == rule.tag then
                        result = result .. rule.replace
                        cursor = start + #rule.tag
                        matched = true
                        break
                    end
                else
                    -- Simple paired tag like !red ... !red
                    if str:sub(start, start + #rule.tag - 1) == rule.tag then
                        local closePos = str:find(rule.tag, start + #rule.tag, true)
                        if closePos then
                            local inner = str:sub(start + #rule.tag, closePos - 1)
                            result = result .. rule.open .. parseRichText(inner) .. rule.close
                            cursor = closePos + #rule.tag
                            matched = true
                            break
                        end
                    end
                end
            end
        end
        -- No match = literal !
        if not matched then
            result = result .. coreObfuscate("!")
            cursor = start + 1
        end
    end
    return result
end
    local workText = text:gsub("!newline", "\n"):gsub("!nl", "\n")
    local processed = parseRichText(workText)
    
    if HexMode and HexAntiSpam and not forPreview then
        local antiSpam = "&#0;"
        local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for i = 1, math.random(3, 5) do
            local r = math.random(1, #chars)
            antiSpam = antiSpam .. chars:sub(r, r)
        end
        processed = processed .. antiSpam
    end
    
    return processed
end

local function updatePreview()
    PreviewLabel.Text = getProcessedText(true) ~= "" and getProcessedText(true) or "Preview here"
end

InputBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
TagBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
CustomIntervalBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)

HexModeToggle.MouseButton1Click:Connect(function()
    HexMode = not HexMode
    HexModeToggle.Text = "Hex Mode: " .. (HexMode and "ON" or "OFF")
    if HexMode and HexAntiSpam then
        HexModeToggle.Text = HexModeToggle.Text .. " (AS)"
    end
    HexModeToggle.BackgroundColor3 = HexMode and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(60, 60, 60)
    if HexMode then
        AllLetters = false; AllLettersToggle.Text = "All Letters: OFF"; AllLettersToggle.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
        CustomMode = false; CustomModeToggle.Text = "Custom Mode: OFF"; CustomModeToggle.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
    end
    updatePreview()
end)

HexModeToggle.MouseButton2Click:Connect(function()
    if HexMode then
        HexAntiSpam = not HexAntiSpam
        HexModeToggle.Text = "Hex Mode: ON" .. (HexAntiSpam and " (AS)" or "")
    end
end)

AllLettersToggle.MouseButton1Click:Connect(function()
    AllLetters = not AllLetters
    AllLettersToggle.Text = "All Letters: " .. (AllLetters and "ON" or "OFF")
    AllLettersToggle.BackgroundColor3 = AllLetters and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(140, 0, 0)
    if AllLetters then
        CustomMode = false; CustomModeToggle.Text = "Custom Mode: OFF"; CustomModeToggle.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
        SmartMode = false; SmartModeToggle.Text = "Smart Mode: OFF"; SmartModeToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
        HexMode = false; HexModeToggle.Text = "Hex Mode: OFF"; HexModeToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    updatePreview()
end)

AutoModeToggle.MouseButton1Click:Connect(function()
    AutoMode = not AutoMode
    AutoModeToggle.Text = "Auto Mode: " .. (AutoMode and "ON" or "OFF")
    AutoModeToggle.BackgroundColor3 = AutoMode and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(0, 120, 180)
    if AutoMode then
        AllLetters = false; AllLettersToggle.Text = "All Letters: OFF"; AllLettersToggle.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
        CustomMode = false; CustomModeToggle.Text = "Custom Mode: OFF"; CustomModeToggle.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
    end
    updatePreview()
end)

CustomModeToggle.MouseButton1Click:Connect(function()
    CustomMode = not CustomMode
    CustomModeToggle.Text = "Custom Mode: " .. (CustomMode and "ON" or "OFF")
    CustomModeToggle.BackgroundColor3 = CustomMode and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(120, 0, 160)
    if CustomMode then
        AllLetters = false; AllLettersToggle.Text = "All Letters: OFF"; AllLettersToggle.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
        SmartMode = false; SmartModeToggle.Text = "Smart Mode: OFF"; SmartModeToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
        AutoMode = false; AutoModeToggle.Text = "Auto Mode: OFF"; AutoModeToggle.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
        HexMode = false; HexModeToggle.Text = "Hex Mode: OFF"; HexModeToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    updatePreview()
end)

SmartModeToggle.MouseButton1Click:Connect(function()
    SmartMode = not SmartMode
    SmartModeToggle.Text = "Smart Mode: " .. (SmartMode and "ON" or "OFF")
    SmartModeToggle.BackgroundColor3 = SmartMode and Color3.fromRGB(200, 200, 0) or Color3.fromRGB(100, 100, 0)
    if SmartMode then
        AllLetters = false; AllLettersToggle.Text = "All Letters: OFF"; AllLettersToggle.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
        CustomMode = false; CustomModeToggle.Text = "Custom Mode: OFF"; CustomModeToggle.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
    end
    updatePreview()
end)

FilterResetToggle.MouseButton1Click:Connect(function()
    FilterReset = not FilterReset
    FilterResetToggle.Text = "Filter Reset: " .. (FilterReset and "ON" or "OFF")
    FilterResetToggle.BackgroundColor3 = FilterReset and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
end)

-- SEND
local function send()
    local msg = InputBox.Text
    if msg == "" then return end
    local final = getProcessedText(false)
    
    task.spawn(function()
        local channel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        local remote = nil

        if not CustomChatRemote then
            local maxSearchTime = 10
            local startTime = os.clock()
            while os.clock() - startTime < maxSearchTime and not remote do
                for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
                    local nameLower = string.lower(descendant.Name)
                  if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and
                    (nameLower:find("chat") or nameLower:find("message")) then
                        remote = descendant
                        break
                    end
                end
                task.wait(0.2)
            end
        end

        if FilterReset and channel then
            pcall(function() channel:SendAsync("/e " .. string.rep("‎", 100)) end)
            task.wait(0.15)
        end

        if CustomChatRemote then
            -- Prepare Arguments
            local args = {final} -- Default to just the message
            
            -- Check for advanced args in JSON format
            if CustomArgsString and CustomArgsString ~= "" then
                local s, parsed = pcall(function() return HttpService:JSONDecode(CustomArgsString) end)
                if s and type(parsed) == "table" then
                    args = {}
                    for _, v in ipairs(parsed) do
                        if v == "!message" then
                            table.insert(args, final)
                        else
                            table.insert(args, v)
                        end
                    end
                else
                    warn("ChatBypass: Failed to parse advanced arguments JSON.")
                end
            end

            if CustomChatRemote:IsA("RemoteFunction") then
                pcall(function() CustomChatRemote:InvokeServer(unpack(args)) end)
            else
                pcall(function() CustomChatRemote:FireServer(unpack(args)) end)
            end
        elseif remote then
            if remote:IsA("RemoteFunction") then
                 pcall(function() remote:InvokeServer(final) end)
            else
                 pcall(function() remote:FireServer(final) end)
            end
        elseif channel then
            channel:SendAsync(final)
        end

        if FilterReset and channel then
            task.wait(0.15)
            pcall(function() channel:SendAsync("/e " .. string.rep("‎", 100)) end)
        end
    end)
end

SendButton.MouseButton1Click:Connect(send)
InputBox.FocusLost:Connect(function(enter) if enter then send() end end)
ClearButton.MouseButton1Click:Connect(function() InputBox.Text = "" updatePreview() end)

UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        Frame.Visible = not Frame.Visible
    elseif i.KeyCode == Enum.KeyCode.Slash or i.KeyCode == Enum.KeyCode.Backslash then
        task.wait()
        InputBox:CaptureFocus()
    end
end)

updatePreview()
