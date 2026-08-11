--[[
    稳定版飞行脚本 – 解决按钮点击和地板滑动问题
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
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

-- ===== 状态提示 =====
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

-- ===== 飞行按钮 =====
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 100, 0, 40)
button.Position = UDim2.new(0.5, -50, 0.5, -20)
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.TextColor3 = Color3.new(0, 0, 0)
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.AutoButtonColor = false
button.ZIndex = 100
button.Active = true
button.Visible = true
button.Selectable = true

-- 边框 + 圆角
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 2.5
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 10)

-- ===== 拖动功能（简单版） =====
local function onDrag(input)
    local startPos = button.Position
    local startMouse = input.Position
    local moveConn
    moveConn = uis.InputChanged:Connect(function(input2)
        if input2.UserInputType == Enum.UserInputType.Touch or input2.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input2.Position - startMouse
            if delta.Magnitude > 10 then
                local newX = startPos.X.Scale + delta.X / screenGui.AbsoluteSize.X
                local newY = startPos.Y.Scale + delta.Y / screenGui.AbsoluteSize.Y
                button.Position = UDim2.new(math.clamp(newX, 0.05, 0.85), 0, math.clamp(newY, 0.05, 0.85), 0)
            end
        end
    end)
    local endConn
    endConn = uis.InputEnded:Connect(function(input2)
        if input2 == input then
            moveConn:Disconnect()
            endConn:Disconnect()
        end
    end)
end

button.TouchBegan:Connect(function(input)
    -- 仅当触摸在按钮上时启动拖动
    onDrag(input)
end)
button.MouseButton1Down:Connect(function(input)
    onDrag({Position = input.Position, UserInputType = Enum.UserInputType.MouseButton1})
end)

-- ===== 点击切换飞行 =====
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
    -- 彻底禁用物理影响
    root.CanCollide = false
    hum.PlatformStand = true
    hum.WalkSpeed = 0  -- 禁止行走

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
    -- 彻底清除所有物理物件
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if root then root.CanCollide = true end
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16  -- 恢复正常行走速度
        -- 强制重置所有速度（防止残留）
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp) -- 重置状态
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

-- 使用按钮自身的点击事件（触摸和鼠标）
button.TouchTap:Connect(toggleFly)
button.MouseButton1Click:Connect(toggleFly)

-- 额外：如果 TouchTap 被拦截，则用 MouseButton1Down 作为备选
button.MouseButton1Down:Connect(function()
    -- 但 MouseButton1Down 会与拖动冲突，所以我们在这里判断是否发生了拖动
    -- 但简单起见，我们可以直接用 TouchTap，它只在触摸结束时触发，且不响应拖动（若拖动距离大可能不触发）
    -- 这里我们使用一个简单的防误触：在 TouchEnded 时检查是否移动了很多
    -- 但为了稳定，我们直接绑定 TouchTap 和 MouseButton1Click，它们是标准的点击事件。
end)

-- 由于 TouchTap 可能在某些设备上不触发，我们还可以添加一个带防误触的 TouchEnded 处理：
button.TouchEnded:Connect(function(input)
    -- 如果触摸开始和结束位置距离小于阈值，则视为点击
    -- 但拖动已经由 TouchBegan 启动，这里我们不处理，避免冲突
end)

-- ===== 飞行控制（第三人称 + 摇杆） =====
runService.RenderStepped:Connect(function()
    if not flying or not root or not hum then return end

    -- 第三人称
    camera.CameraType = Enum.CameraType.Custom
    local camOffset = Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 10
    camera.CFrame = CFrame.lookAt(root.Position + camOffset, root.Position + Vector3.new(0, 2, 0))

    -- 角色面朝相机前方
    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    if lookDir.Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)
    end

    -- 摇杆移动
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0.01 then
        local forward = root.CFrame.LookVector
        local right = root.CFrame.RightVector
        -- MoveDirection: X左右, Z前后（相对于角色朝向）
        local velocity = (forward * -moveDir.Z + right * moveDir.X) * FLY_SPEED
        bodyVelocity.Velocity = velocity
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end

    if bodyGyro then
        bodyGyro.CFrame = root.CFrame
    end
end)

-- ===== 角色重生重置 =====
player.CharacterAdded:Connect(function(newChar)
    if flying then disableFly() end
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    statusLabel.Visible = false
    button.Text = "飞行"
end)

-- 初始化
getChar()
print("[飞行测试] 稳定版加载，点击按钮切换飞行，拖动按钮移动位置。")
