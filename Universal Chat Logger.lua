--- universal chat logger (works for games with custom chat systems)
local Players = game:GetService("Players")
				local UserInputService = game:GetService("UserInputService")
				local Player = Players.LocalPlayer
				local PlayerGui = Player:WaitForChild("PlayerGui")

				local seen = {}
				local fullLogTable = {}

				-- Cleanup old GUI
				if PlayerGui:FindFirstChild("AnnaRoblox_UniversalLogger") then
					PlayerGui["AnnaRoblox_UniversalLogger"]:Destroy()
				end

				local sg = Instance.new("ScreenGui")
				sg.Name = "AnnaRoblox_UniversalLogger"
				sg.ResetOnSpawn = false
				sg.IgnoreGuiInset = true
				sg.Parent = PlayerGui

				local f = Instance.new("Frame")
				f.Name = "MainFrame"
				f.Size = UDim2.new(0, 400, 0, 450)
				f.Position = UDim2.new(0.5, -200, 0.5, -225)
				f.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
				f.BorderSizePixel = 0
				f.Active = true
				f.Parent = sg

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = f

				-- Titlebar
				local titlebar = Instance.new("Frame")
				titlebar.Size = UDim2.new(1, 0, 0, 35)
				titlebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
				titlebar.BorderSizePixel = 0
				titlebar.Parent = f

				local tbCorner = Instance.new("UICorner")
				tbCorner.CornerRadius = UDim.new(0, 8)
				tbCorner.Parent = titlebar

				local cover = Instance.new("Frame")
				cover.Size = UDim2.new(1, 0, 0, 5)
				cover.Position = UDim2.new(0, 0, 1, -5)
				cover.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
				cover.BorderSizePixel = 0
				cover.Parent = titlebar

				local titlelbl = Instance.new("TextLabel")
				titlelbl.Size = UDim2.new(1, -80, 1, 0)
				titlelbl.Position = UDim2.new(0, 12, 0, 0)
				titlelbl.BackgroundTransparency = 1
				titlelbl.Text = "Universal Chat Logger"
				titlelbl.TextColor3 = Color3.fromRGB(220, 220, 230)
				titlelbl.TextSize = 16
				titlelbl.Font = Enum.Font.SourceSansBold
				titlelbl.TextXAlignment = Enum.TextXAlignment.Left
				titlelbl.Parent = titlebar

				local close = Instance.new("TextButton")
				close.Size = UDim2.new(0, 35, 0, 35)
				close.Position = UDim2.new(1, -35, 0, 0)
				close.BackgroundTransparency = 1
				close.Text = "✕"
				close.TextColor3 = Color3.fromRGB(255, 100, 100)
				close.TextSize = 18
				close.Font = Enum.Font.SourceSansBold
				close.Parent = titlebar

				-- Save to Workspace Button
				local saveBtn = Instance.new("TextButton")
				saveBtn.Size = UDim2.new(0, 35, 0, 35)
				saveBtn.Position = UDim2.new(1, -70, 0, 0)
				saveBtn.BackgroundTransparency = 1
				saveBtn.Text = "💾"
				saveBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
				saveBtn.TextSize = 18
				saveBtn.Font = Enum.Font.SourceSansBold
				saveBtn.Parent = titlebar

				saveBtn.MouseButton1Click:Connect(function()
					local content = table.concat(fullLogTable, "\n")
					local fileName = "ChatLog_" .. game.PlaceId .. "_" .. os.time() .. ".txt"
					if writefile then
						writefile(fileName, content)
						saveBtn.Text = "✔"
						task.wait(1)
						saveBtn.Text = "💾"
					else
						warn("Executor does not support writefile")
					end
				end)

				close.MouseButton1Click:Connect(function()
					sg:Destroy()
				end)

				-- Dragging Logic
				local dragging, dragStart, startPos
				titlebar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						dragStart = input.Position
						startPos = f.Position
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						local delta = input.Position - dragStart
						f.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)

				-- ScrollingFrame Setup
				local scroll = Instance.new("ScrollingFrame")
				scroll.Name = "LogContainer"
				scroll.Size = UDim2.new(1, -12, 1, -45)
				scroll.Position = UDim2.new(0, 6, 0, 40)
				scroll.BackgroundTransparency = 1
				scroll.BorderSizePixel = 0
				scroll.ScrollBarThickness = 4
				scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
				scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y 
				scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
				scroll.Parent = f

				local listLayout = Instance.new("UIListLayout")
				listLayout.Parent = scroll
				listLayout.SortOrder = Enum.SortOrder.LayoutOrder
				listLayout.Padding = UDim.new(0, 6)

				local padding = Instance.new("UIPadding")
				padding.Parent = scroll
				padding.PaddingLeft = UDim.new(0, 5)
				padding.PaddingRight = UDim.new(0, 8)
				padding.PaddingTop = UDim.new(0, 5)
				padding.PaddingBottom = UDim.new(0, 5)

				-- Log Function
				local function log(raw)
					if not raw or raw == "" or seen[raw] then return end
					
					-- Filter out strings that are just numbers separated by colons (e.g. 12:00, 1:05:01)
					local clean = raw:gsub("<[^>]*>", "") -- Strip RichText tags for regex check
					if clean:match("^[%d:]+$") then return end
					
					seen[raw] = true
					table.insert(fullLogTable, clean)
					
					local msgBox = Instance.new("TextBox")
					msgBox.Size = UDim2.new(1, 0, 0, 0)
					msgBox.AutomaticSize = Enum.AutomaticSize.Y
					msgBox.BackgroundTransparency = 1
					msgBox.Text = raw
					msgBox.TextColor3 = Color3.fromRGB(240, 240, 245)
					msgBox.TextSize = 14
					msgBox.Font = Enum.Font.Code
					msgBox.TextXAlignment = Enum.TextXAlignment.Left
					msgBox.TextWrapped = true
					msgBox.RichText = true
					msgBox.TextEditable = false
					msgBox.ClearTextOnFocus = false
					msgBox.Parent = scroll
					
					-- Auto-Scroll Logic: Only scroll if we are near the bottom
					local isAtBottom = scroll.CanvasPosition.Y >= (scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y) - 20
					if isAtBottom then
						task.defer(function()
							scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
						end)
					end
				end

				-- Monitoring Logic
				local function tryHook(obj)
					if obj:IsDescendantOf(sg) then return end
					if not (obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton")) then return end
					
					if obj.Text and obj.Text ~= "" then
						log(obj.Text)
					end
					
					obj:GetPropertyChangedSignal("Text"):Connect(function()
						if obj.Text and obj.Text ~= "" then
							log(obj.Text)
						end
					end)
				end

				-- Scan existing and new UI
				for _, obj in ipairs(PlayerGui:GetDescendants()) do
					tryHook(obj)
				end

				PlayerGui.DescendantAdded:Connect(function(new)
					tryHook(new)
					for _, deep in ipairs(new:GetDescendants()) do
						tryHook(deep)
					end
				end)

				log("<b>[SYSTEM]</b> Logger initialized.")
				log("<b>[INFO]</b> Files save to workspace folder.")
				log("<font color='#FF5555'>Author:</font> <b>AnnaRoblox</b>")
