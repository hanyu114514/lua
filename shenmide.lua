--[[
    飞行测试脚本 – 最终稳定版
    功能：
    - 点击按钮切换飞行/着陆，显示状态
    - 拖动按钮可移动位置（长按拖动）
    - 飞行时穿墙、第三人称锁定、摇杆控制方向
    - 完全使用 UserInputService 全局监听，忽略 gameProcessed
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")

-- 清理旧 GUI
local oldGui = playerGui:FindFirstChild("FlyTestGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyTestGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

-- ===== 状态提示标签 =====
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

-- ===== 飞行按钮（纯视觉元素，无交互事件） =====
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 110, 0, 44)
button.Position = UDim2.new(0.5, -55, 0.5, -22)
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.TextColor3 = Color3.new(0, 0, 0)
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.AutoButtonColor = false
button.ZIndex = 100
button.Active = false      -- 禁止默认交互
button.Selectable = false  -- 禁止选中

-- 边框 + 圆角
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 2.5
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 10)

-- ===== 全局触摸状态 =====
local isPointerDown = false
local isDragging = false
local dragStartPos = nil
local dragStartMouse = nil

-- 判断点是否在按钮内
local function isPointInButton(pos)
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    if not absPos or not absSize then return false end
    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
           pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

-- 更新按钮位置
local function updateButtonPosition(delta)
    if not dragStartPos then return end
    local newX = dragStartPos.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
    local newY = dragStartPos.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
    newX = math.clamp(newX, 0.05, 0.85)
    newY = math.clamp(newY, 0.05, 0.85)
    button.Position = UDim2.new(newX, 0, newY, 0)
end

-- ===== 使用 UserInputService 捕获所有触摸/鼠标事件 =====
-- 触摸开始
uis.TouchBegan:Connect(function(input, gameProcessed)
    -- 忽略 gameProcessed，确保所有触摸都被捕获
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if isPointInButton(input.Position) then
        isPointerDown = true
        isDragging = false
        dragStartMouse = input.Position
        dragStartPos = button.Position
    end
end)

-- 触摸移动
uis.TouchMoved:Connect(function(input, gameProcessed)
    if not isPointerDown then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStartMouse then return end
    local delta = input.Position - dragStartMouse
    if delta.Magnitude > 10 then
        isDragging = true
        updateButtonPosition(delta)
    end
end)

-- 触摸结束
uis.TouchEnded:Connect(function(input, gameProcessed)
    if not isPointerDown then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not isDragging then
        -- 点击（未拖动）
        toggleFly()
    end
    isPointerDown = false
    isDragging = false
    dragStartMouse = nil
    dragStartPos = nil
end)

-- 鼠标按下（兼容 PC 测试）
uis.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isPointInButton(input.Position) then
            isPointerDown = true
            isDragging = false
            dragStartMouse = input.Position
            dragStartPos = button.Position
        end
    end
end)

-- 鼠标移动
uis.InputMoved:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if isPointerDown and dragStartMouse then
            local delta = input.Position - dragStartMouse
            if delta.Magnitude > 10 then
                isDragging = true
                updateButtonPosition(delta)
            end
        end
    end
end)

-- 鼠标松开
uis.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isPointerDown then
            if not isDragging then
                toggleFly()
            end
            isPointerDown = false
            isDragging = false
            dragStartMouse = nil
            dragStartPos = nil
        end
    end
end)

-- ===== 飞行核心逻辑 =====
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
