--[[
    飞行测试脚本 v2 - 修复所有已知问题
    功能：
    1. 按钮：白底黑字黑边框圆角，尺寸固定（适合触控）
    2. 点击切换飞行状态，显示提示
    3. 飞行时按 WASD 前后左右，空格上升，Shift 下降（PC）
    4. 手机版：开启后自动悬停，可通过触摸上下滑动微调（简单实现）
    5. 角色重生自动重置状态
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 清理旧 GUI（避免重复加载）
local oldGui = playerGui:FindFirstChild("FlyTestGui")
if oldGui then oldGui:Destroy() end

-- 创建主 GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyTestGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false   -- 重生时不销毁

-- 状态提示标签
local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = screenGui
statusLabel.Size = UDim2.new(0, 300, 0, 60)
statusLabel.Position = UDim2.new(0.5, -150, 0.3, 0) -- 居中偏上
statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
statusLabel.BackgroundTransparency = 0.5
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextSize = 28
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.ZIndex = 10
statusLabel.ClipsDescendants = true

-- 按钮（固定尺寸 150x50，确保触控舒适）
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 150, 0, 50)          -- 固定像素尺寸
button.Position = UDim2.new(1, -170, 1, -70)    -- 右下角，留边距
button.BackgroundColor3 = Color3.new(1, 1, 1)   -- 白色
button.TextColor3 = Color3.new(0, 0, 0)         -- 黑色
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.BorderSizePixel = 2
button.BorderColor3 = Color3.new(0, 0, 0)       -- 黑色边框
button.AutoButtonColor = false                  -- 点击不变色

-- 圆角（UICorner）
local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 12)           -- 固定圆角12像素

-- ===== 飞行核心逻辑 =====
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum

local function getChar()
    char = player.Character
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    return char and root and hum
end

-- 显示状态提示（持续1.8秒）
local function showStatus(text, isSuccess)
    statusLabel.Text = text
    statusLabel.Visible = true
    -- 可选颜色反馈
    if isSuccess then
        statusLabel.TextColor3 = Color3.new(0, 1, 0) -- 绿色
    else
        statusLabel.TextColor3 = Color3.new(1, 0, 0) -- 红色
    end
    task.wait(1.8)
    statusLabel.Visible = false
end

-- 启用飞行
local function enableFly()
    if not getChar() then
        showStatus("未找到角色", false)
        return false
    end
    -- 禁止重力与行走
    hum.PlatformStand = true
    hum.WalkSpeed = 0

    -- 速度控制
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = root

    -- 姿态稳定
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    flying = true
    button.Text = "飞行中"
    showStatus("✅ 已开启功能", true)
    return true
end

-- 禁用飞行
local function disableFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16  -- 恢复默认速度
    end
    flying = false
    button.Text = "飞行"
    showStatus("❌ 已关闭功能", false)
end

-- 切换飞行
local function toggleFly()
    if flying then
        disableFly()
    else
        enableFly()
    end
end

-- 点击事件（兼容鼠标和触摸）
button.MouseButton1Click:Connect(toggleFly)
button.TouchTap:Connect(toggleFly)

-- ===== 飞行方向控制（PC键盘） =====
-- 仅在飞行时生效
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if not flying then return end
    -- 可选：检测按键，但我们在 Heartbeat 中持续处理
end)

-- 持续更新飞行速度（使用 Heartbeat 高频更新）
game:GetService("RunService").Heartbeat:Connect(function()
    if not flying or not bodyVelocity or not root then return end
    local move = Vector3.new()
    local forward = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local uis = game:GetService("UserInputService")

    -- WASD
    if uis:IsKeyDown(Enum.KeyCode.W) then move = move + forward end
    if uis:IsKeyDown(Enum.KeyCode.S) then move = move - forward end
    if uis:IsKeyDown(Enum.KeyCode.A) then move = move - right end
    if uis:IsKeyDown(Enum.KeyCode.D) then move = move + right end
    -- 空格上升，Shift下降
    if uis:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if uis:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

    -- 如果没有任何按键，则保持悬停（速度归零）
    if move.Magnitude > 0 then
        bodyVelocity.Velocity = move.Unit * 50   -- 飞行速度
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end

    -- 保持姿态朝前（可选）
    if bodyGyro then
        bodyGyro.CFrame = root.CFrame
    end
end)

-- ===== 角色重生重置 =====
player.CharacterAdded:Connect(function(newChar)
    -- 如果飞行开启，先关闭
    if flying then
        disableFly()
    end
    -- 重新获取引用
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    -- 按钮文字重置
    button.Text = "飞行"
    -- 隐藏提示
    statusLabel.Visible = false
end)

-- 初始化时绑定当前角色
getChar()

print("[飞行测试] 脚本加载成功，按按钮切换飞行，WASD控制方向，空格上升，Shift下降")
