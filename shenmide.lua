--[[
    飞行测试脚本 v3 - 最终修复版
    功能：点击按钮切换飞行/着陆，飞行时可用原有移动方式（键盘/摇杆）自由移动
    按钮样式：白底、黑字、黑色粗边框、圆角
    状态提示：显示开启/关闭
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 清理旧GUI，避免重复
local oldGui = playerGui:FindFirstChild("FlyTestGui")
if oldGui then oldGui:Destroy() end

-- 创建主GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyTestGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- ===== 状态提示标签 =====
local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = screenGui
statusLabel.Size = UDim2.new(0, 300, 0, 60)
statusLabel.Position = UDim2.new(0.5, -150, 0.3, 0)
statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
statusLabel.BackgroundTransparency = 0.6
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextSize = 28
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.ZIndex = 10

-- ===== 飞行按钮 =====
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 140, 0, 50)          -- 固定尺寸，适合手指
button.Position = UDim2.new(1, -160, 1, -70)    -- 右下角
button.BackgroundColor3 = Color3.new(1, 1, 1)   -- 白色
button.TextColor3 = Color3.new(0, 0, 0)         -- 黑色
button.Text = "飞行"
button.TextSize = 28
button.TextScaled = true
button.AutoButtonColor = false                  -- 点击不变色

-- 黑色边框（使用 UIStroke 实现粗边框，确保明显）
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 3                           -- 粗边框
stroke.Color = Color3.new(0, 0, 0)             -- 黑色
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- 圆角（UICorner）
local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 12)          -- 圆角半径12像素

-- ===== 飞行核心逻辑 =====
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum
local FLY_SPEED = 50  -- 飞行速度

local function getChar()
    char = player.Character
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    return char and root and hum
end

-- 显示提示（持续1.5秒）
local function showStatus(text, isSuccess)
    statusLabel.Text = text
    statusLabel.Visible = true
    statusLabel.TextColor3 = isSuccess and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    task.wait(1.5)
    statusLabel.Visible = false
end

-- 开启飞行
local function enableFly()
    if not getChar() then
        showStatus("角色未找到", false)
        return false
    end
    -- 禁用地心引力，但保留移动能力
    hum.PlatformStand = true
    -- 不要将 WalkSpeed 设为 0，这样 MoveDirection 仍可用
    -- 但为了保险，我们使用 BodyVelocity 覆盖速度

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    flying = true
    button.Text = "降落"
    showStatus("✅ 已开启功能", true)
    return true
end

-- 关闭飞行
local function disableFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if hum then
        hum.PlatformStand = false
        -- WalkSpeed 恢复默认（如果之前被修改过）
        hum.WalkSpeed = 16
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

-- 使用 Activated 事件（鼠标点击/触摸松开均可触发）
button.Activated:Connect(toggleFly)

-- ===== 飞行方向控制（兼容键盘和手机摇杆） =====
game:GetService("RunService").Heartbeat:Connect(function()
    if not flying or not bodyVelocity or not hum or not root then return end

    -- 获取移动方向（来自键盘 WASD 或手机摇杆）
    local moveDir = hum.MoveDirection  -- 单位向量
    -- 获取垂直输入：空格上升，Shift下降（PC）；手机用户可忽略，或通过触摸按钮另行添加
    local vertical = 0
    local uis = game:GetService("UserInputService")
    if uis:IsKeyDown(Enum.KeyCode.Space) then
        vertical = 1
    elseif uis:IsKeyDown(Enum.KeyCode.LeftShift) then
        vertical = -1
    end

    -- 合成速度向量
    local velocity = moveDir * FLY_SPEED + Vector3.new(0, vertical * FLY_SPEED, 0)
    bodyVelocity.Velocity = velocity

    -- 保持角色朝向（可选）
    if bodyGyro and moveDir.Magnitude > 0.01 then
        bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + moveDir)
    end
end)

-- ===== 角色重生重置 =====
player.CharacterAdded:Connect(function(newChar)
    if flying then
        disableFly()
    end
    -- 重新获取引用
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    statusLabel.Visible = false
    button.Text = "飞行"
end)

-- 初始化
getChar()
print("[飞行测试] 脚本加载成功，点击按钮切换飞行/着陆，使用原有移动方式控制方向")
