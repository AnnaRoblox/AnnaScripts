---- simple chat bypass script custom chat games
----- you need to change your language to use this recomendend: Қазақ Тілі*
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local SAVE_FILE = "ChatRemoteConfig.json"
local GUI_NAME = "ChatBypass"
local FAKE_SPACE = "\27" 

-- Cleanup existing GUI
if CoreGui:FindFirstChild(GUI_NAME) then
    CoreGui:FindFirstChild(GUI_NAME):Destroy()
end

local selectedRemote = nil

-- Character mapping
local replacements = {
    ["s"] = "ธ", ["u"] = "ıɹ", ["l"] = "ӏ", ["z"] = "ⴭ",
    ["b"] = "lɔ", ["r"] = "ꞅ", ["a"] = "α", ["o"] = "ჿ",
    ["c"] = "ჺ", ["n"] = "ıา", ["h"] = "lา", ["m"] = "ıาา",
    ["w"] = "ıɹɹ", ["i"] = "ὶ", ["g"] = "ⴒ", ["e"] = "ɐ", ["k"] = "ı‹", ["."] = ".", [" "] = FAKE_SPACE
}

-- Persistence Logic
local function saveSelection(name)
    local data = {selected = name}
    pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(data)) end)
end

local function loadSelection()
    local success, content = pcall(function() return readfile(SAVE_FILE) end)
    if success then
        local data = HttpService:JSONDecode(content)
        return data.selected
    end
    return nil
end

-- Transformation Logic
local function transformText(input)
    local cleaned = input:gsub("chatbypass", "")
    local output = ""
    for i = 1, #cleaned do
        local char = cleaned:sub(i, i):lower()
        output = output .. (replacements[char] or char)
    end
    return output
end

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local Frame = Instance.new("Frame")
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Frame.Position = UDim2.new(0.5, -150, 0.5, -100)
Frame.Size = UDim2.new(0, 300, 0, 220)
Frame.BorderSizePixel = 0

-- Dragging Logic
local dragging, dragStart, startPos
Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Frame.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local TextBox = Instance.new("TextBox")
TextBox.Parent = Frame
TextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TextBox.Position = UDim2.new(0.05, 0, 0.05, 0)
TextBox.Size = UDim2.new(0.9, 0, 0.25, 0)
TextBox.PlaceholderText = "Enter text here (Press / to focus)"
TextBox.Text = ""
TextBox.TextColor3 = Color3.fromRGB(0, 255, 0)
TextBox.ClearTextOnFocus = false
TextBox.TextSize = 14

-- Selectable Preview Box (TextBox instead of Label)
local OutputBox = Instance.new("TextBox")
OutputBox.Parent = Frame
OutputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
OutputBox.Position = UDim2.new(0.05, 0, 0.35, 0)
OutputBox.Size = UDim2.new(0.9, 0, 0.25, 0)
OutputBox.Text = "Preview..."
OutputBox.TextColor3 = Color3.fromRGB(0, 255, 0)
OutputBox.TextSize = 14
OutputBox.ClearTextOnFocus = false
OutputBox.TextEditable = false -- Makes it selectable but not editable
OutputBox.TextWrapped = true

local ChatButton = Instance.new("TextButton")
ChatButton.Parent = Frame
ChatButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
ChatButton.Position = UDim2.new(0.05, 0, 0.65, 0)
ChatButton.Size = UDim2.new(0.65, 0, 0.15, 0)
ChatButton.Text = "CHAT" -- Renamed as requested
ChatButton.TextColor3 = Color3.new(1, 1, 1)

local RemoteToggle = Instance.new("TextButton")
RemoteToggle.Parent = Frame
RemoteToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
RemoteToggle.Position = UDim2.new(0.75, 0, 0.65, 0)
RemoteToggle.Size = UDim2.new(0.2, 0, 0.15, 0)
RemoteToggle.Text = "⚙"
RemoteToggle.TextColor3 = Color3.new(1, 1, 1)

-- Remote Menu
local RemoteFrame = Instance.new("Frame")
RemoteFrame.Size = UDim2.new(1, 0, 1, 0)
RemoteFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RemoteFrame.Visible = false
RemoteFrame.ZIndex = 10
RemoteFrame.Parent = Frame

local RemoteScroll = Instance.new("ScrollingFrame")
RemoteScroll.Size = UDim2.new(0.9, 0, 0.8, 0)
RemoteScroll.Position = UDim2.new(0.05, 0, 0.05, 0)
RemoteScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
RemoteScroll.ZIndex = 11
RemoteScroll.Parent = RemoteFrame

local UIList = Instance.new("UIListLayout")
UIList.Parent = RemoteScroll

local BackBtn = Instance.new("TextButton")
BackBtn.Size = UDim2.new(1, 0, 0.15, 0)
BackBtn.Position = UDim2.new(0, 0, 0.85, 0)
BackBtn.Text = "Back"
BackBtn.ZIndex = 11
BackBtn.Parent = RemoteFrame

-- Logic
local function sendMessage()
    if selectedRemote and TextBox.Text ~= "" then
        local msg = transformText(TextBox.Text)
        selectedRemote:FireServer(msg, "All")
        TextBox.Text = ""
    end
end

TextBox:GetPropertyChangedSignal("Text"):Connect(function()
    OutputBox.Text = transformText(TextBox.Text)
end)

TextBox.FocusLost:Connect(function(enter)
    if enter then sendMessage() end
end)

ChatButton.MouseButton1Click:Connect(sendMessage)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.Slash then
            task.wait()
            TextBox:CaptureFocus()
            TextBox.Text = ""
        elseif input.KeyCode == Enum.KeyCode.RightControl then
            Frame.Visible = not Frame.Visible
        end
    end
end)

local savedName = loadSelection()
local function refreshRemotes()
    for _, c in pairs(RemoteScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name:lower():find("chat") then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 30)
            b.Text = v.Name
            b.BackgroundColor3 = (savedName == v.Name) and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            b.TextColor3 = Color3.new(1, 1, 1)
            b.ZIndex = 12
            b.Parent = RemoteScroll
            if savedName == v.Name then selectedRemote = v end
            b.MouseButton1Click:Connect(function()
                selectedRemote = v
                saveSelection(v.Name)
                RemoteFrame.Visible = false
            end)
        end
    end
end

RemoteToggle.MouseButton1Click:Connect(function()
    refreshRemotes()
    RemoteFrame.Visible = true
end)

BackBtn.MouseButton1Click:Connect(function()
    RemoteFrame.Visible = false
end)

refreshRemotes()
