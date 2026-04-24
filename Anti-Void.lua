-- Enhanced Anti-Fall / Anti-Void Script (put in autoexec)
-- Teleports player back to the last known solid ground when falling
Game.Workspace.FallenPartsDestroyHeight = 0/0
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Configuration
local VOID_HEIGHT = -300 -- The Y level that triggers a teleport
local CHECK_INTERVAL = 0.5 -- How often to check for safe ground (seconds)
local lastSafeCFrame = rootPart.CFrame

-- Function to check if the current position is "Safe" (Solid ground below)
local function isPositionSafe()
    if not rootPart then return false end
    
    -- Cast a ray downward from the character to check for floor
    local rayOrigin = rootPart.Position
    local rayDirection = Vector3.new(0, -10, 0) -- Check 10 studs down
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    -- If we hit something and it's not "deadly" (you could add more checks here)
    if result and result.Instance then
        return true
    end
    
    return false
end

-- Core logic loop
local function startMonitoring()
    task.spawn(function()
        while character and character:IsDescendantOf(Workspace) do
            local currentPos = rootPart.Position
            
            -- 1. Check if we hit the void
            if currentPos.Y <= VOID_HEIGHT then
                print("Void detected! Returning to last safe ground.")
                character:SetPrimaryPartCFrame(lastSafeCFrame + Vector3.new(0, 3, 0))
                -- Reset velocity to prevent carrying momentum from the fall
                rootPart.AssemblyLinearVelocity = Vector3.zero
            end
            
            -- 2. Update safe position if standing on something
            if isPositionSafe() then
                lastSafeCFrame = rootPart.CFrame
            end
            
            task.wait(CHECK_INTERVAL)
        end
    end)
end

-- Handle Respawning
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
    lastSafeCFrame = rootPart.CFrame
    startMonitoring()
end)

-- Initial Start
startMonitoring()

print("Safe-Ground Anti-Void system active.")
