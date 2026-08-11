--[[
    纯点击飞行脚本 – 无拖动，只响应点击
    按钮样式：白底黑字黑边框圆角
    功能：点击切换飞行/着陆，显示状态，第三人称，穿墙，摇杆控制方向
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")

-- 清理旧GUI
local oldGui = playerGui:FindFirstChild("FlyTestGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyTestGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

-- 状态提示
local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = screenGui
statusLabel.Size = UDim2.new(0, 260, 0, 50)
statusLabel.Position = UDim2.new(0.5, -130, 0.35, 0)
statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
statusLabel.BackgroundTransparency = 0.6
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextSize = 24
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.ZIndex = 100

-- 按钮（大小适中，无拖动）
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 110, 0, 44)
button.Position = UDim2.new(0.5, -55, 0.5, -22)  -- 居中，固定
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.TextColor3 = Color3.new(0, 0, 0)
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.AutoButtonColor = false
button.ZIndex = 100

-- 边框 + 圆角
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 2.5
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 10)

-- ===== 飞行逻辑（与之前相同） =====
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum
local FLY_SPEED = 40

local function getChar()
    char = player.Character
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    return char and root and hum
end

local function showStatus(text, isSuccess)
    statusLabel.Text = text
    statusLabel.Visible = true
    statusLabel.TextColor3 = isSuccess and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    task.wait(1.2)
    statusLabel.Visible = false
end

function enableFly()
    if not getChar() then
        showStatus("角色未找到", false)
        return false
    end
    root.CanCollide = false
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

    flying = true
    button.Text = "飞行中"
    showStatus("✅ 已开启", true)
    return true
end

function disableFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if root then root.CanCollide = true end
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    flying = false
    button.Text = "飞行"
    showStatus("❌ 已关闭", false)
end

function toggleFly()
    if flying then
        disableFly()
    else
        enableFly()
    end
end

-- ===== 关键：使用最原始的事件绑定（确保可点击） =====
button.MouseButton1Click:Connect(toggleFly)   -- PC
button.TouchTap:Connect(toggleFly)            -- 手机

-- 额外：如果 TouchTap 在某些设备不触发，用 TouchEnded 作为后备（但不用它防止双击）
-- 但我们只用上面两个，它们是最稳定的。

-- ===== 飞行控制（第三人称 + 摇杆） =====
runService.RenderStepped:Connect(function()
    if not flying or not root or not hum then return end

    camera.CameraType = Enum.CameraType.Custom
    local camOffset = Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 10
    camera.CFrame = CFrame.lookAt(root.Position + camOffset, root.Position + Vector3.new(0, 2, 0))

    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    if lookDir.Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)
    end

    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0.01 then
        local forward = root.CFrame.LookVector
        local right = root.CFrame.RightVector
        local velocity = (forward * -moveDir.Z + right * moveDir.X) * FLY_SPEED
        bodyVelocity.Velocity = velocity
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end

    if bodyGyro then
        bodyGyro.CFrame = root.CFrame
    end
end)

player.CharacterAdded:Connect(function(newChar)
    if flying then disableFly() end
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    statusLabel.Visible = false
    button.Text = "飞行"
end)

getChar()
