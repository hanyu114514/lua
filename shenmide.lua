--[[
    飞行测试脚本 - 用于测试反作弊检测
    上传到 GitHub，使用 loadstring 加载
    按钮：白色背景、黑色文字、黑色边框、圆角
    点击切换飞行，显示状态提示
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. 创建主 GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = true   -- 角色重生时重置界面

-- 2. 状态提示标签（显示开启/关闭信息）
local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = screenGui
statusLabel.Size = UDim2.new(0.5, 0, 0.1, 0)
statusLabel.Position = UDim2.new(0.25, 0, 0.4, 0)
statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
statusLabel.BackgroundTransparency = 0.5
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextSize = 30
statusLabel.TextScaled = true
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.ZIndex = 10

-- 3. 飞行按钮（符合你的样式要求）
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0.2, 0, 0.08, 0)          -- 宽度20%，高度8%（适合手机）
button.Position = UDim2.new(0.75, 0, 0.85, 0)     -- 右下角
button.BackgroundColor3 = Color3.new(1, 1, 1)     -- 白色背景
button.TextColor3 = Color3.new(0, 0, 0)           -- 黑色文字
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.BorderSizePixel = 2
button.BorderColor3 = Color3.new(0, 0, 0)         -- 黑色边框
button.AutoButtonColor = false                     -- 点击时不改变颜色

-- 圆角（用 UICorner）
local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0.3, 0)             -- 圆角半径

-- 4. 飞行逻辑（客户端）
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char = player.Character
local root, hum

local function getChar()
    char = player.Character
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
    end
end
getChar()

-- 显示提示信息（1.5秒后消失）
local function showStatus(text)
    statusLabel.Text = text
    statusLabel.Visible = true
    task.wait(1.5)
    statusLabel.Visible = false
end

-- 切换飞行状态
local function toggleFly()
    if not root or not hum then
        getChar()
        if not root or not hum then
            showStatus("⚠️ 未找到角色")
            return
        end
    end

    flying = not flying
    if flying then
        -- 开启飞行
        hum.PlatformStand = true
        hum.WalkSpeed = 0

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = root

        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bodyGyro.CFrame = root.CFrame
        bodyGyro.Parent = root

        button.Text = "飞行中..."
        showStatus("✅ 已开启功能")
    else
        -- 关闭飞行
        hum.PlatformStand = false
        hum.WalkSpeed = 16   -- 默认速度

        if bodyVelocity then bodyVelocity:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end

        button.Text = "飞行"
        showStatus("❌ 已关闭功能")
    end
end

-- 绑定点击事件（PC 和手机触控都支持）
button.MouseButton1Click:Connect(toggleFly)
button.TouchTap:Connect(toggleFly)

-- 角色重生时重置飞行状态
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    if flying then
        flying = false
        if bodyVelocity then bodyVelocity:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        button.Text = "飞行"
        statusLabel.Visible = false
    end
end)

print("飞行测试脚本已加载，点击按钮切换飞行")
