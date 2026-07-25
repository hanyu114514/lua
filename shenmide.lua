local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

local textLabel = Instance.new("TextLabel")
textLabel.Parent = screenGui
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.Text = "给coco的一个脚本作者他爹韩羽🤓"
textLabel.TextSize = 80
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.BackgroundTransparency = 1
textLabel.ZIndex = 10
