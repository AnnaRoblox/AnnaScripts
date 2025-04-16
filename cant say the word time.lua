-- for cant say the word dont spam lol
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

local function fireEvent()
    for i = 1, 1000 do
        LocalPlayer.PlayerGui.LocalScript.RemoteEvent:FireServer() -- this one makes u lose time  game:GetService("Players").LocalPlayer.PlayerGui.Main.Frame.Amogus.Amogus.LocalScript.RemoteEvent:FireServer() 
        --task.wait(0) -- Optional: add a small delay between fires
    end
end

fireEvent()
