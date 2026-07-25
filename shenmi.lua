-- 这是放在 GitHub 上的 hello.lua 文件内容
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false  -- 角色重生文字也不消失

local textLabel = Instance.new("TextLabel")
textLabel.Parent = screenGui
textLabel.Size = UDim2.new(1, 0, 1, 0)  -- 铺满屏幕
textLabel.Text = "Hello World from GitHub!"
textLabel.TextSize = 80
textLabel.TextColor3 = Color3.new(1, 1, 1)  -- 白色
textLabel.BackgroundTransparency = 1  -- 透明背景只留文字
textLabel.ZIndex = 10  -- 保证在最上层显示
