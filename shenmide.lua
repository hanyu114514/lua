--[[
    手机飞行脚本 – 使用全局触摸事件，确保点击与拖动可靠
    - 按钮大小 100x40，白底黑字圆角，居中，可拖动
    - 点击切换飞行，显示状态
    - 飞行方向使用摇杆（Humanoid.MoveDirection）
    - 第三人称锁定，穿墙
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
button.Active = true                    -- 确保可交互
button.Visible = true
button.Selectable = true

local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 2.5
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 10)

-- ===== 全局触摸状态 =====
local isDragging = false
local dragStartPos = nil
local dragStartMouse = nil
local buttonAbsPos = nil

-- 获取按钮绝对位置
local function getButtonAbs()
    return button.AbsolutePosition, button.AbsoluteSize
end

-- 判断点是否在按钮内
local function isPointInButton(pos)
    local absPos, absSize = getButtonAbs()
    if not absPos or not absSize then return false end
    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
           pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

-- 更新按钮位置（基于屏幕比例）
local function updateButtonPosition(delta)
    if not dragStartPos then return end
    local newX = dragStartPos.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
    local newY = dragStartPos.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
    newX = math.clamp(newX, 0.05, 0.85)
    newY = math.clamp(newY, 0.05, 0.85)
    button.Position = UDim2.new(newX, 0, newY, 0)
end

-- ===== 触摸事件处理（使用 UserInputService） =====
uis.TouchBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not isPointInButton(input.Position) then return end

    -- 开始在按钮上触摸
    isDragging = false
    dragStartMouse = input.Position
    dragStartPos = button.Position
    print("[飞行] 触摸开始")
end)

uis.TouchMoved:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStartMouse then return end

    local delta = input.Position - dragStartMouse
    if delta.Magnitude > 8 then
        isDragging = true
        updateButtonPosition(delta)
        print("[飞行] 拖动中")
    end
end)

uis.TouchEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStartMouse then return end

    if not isDragging then
        -- 这是一个点击（没有拖动）
        print("[飞行] 点击触发")
        toggleFly()
    else
        print("[飞行] 拖动结束")
    end

    -- 重置状态
    isDragging = false
    dragStartMouse = nil
    dragStartPos = nil
end)

-- 同时支持鼠标（PC测试）
uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isPointInButton(input.Position) then
            isDragging = false
            dragStartMouse = input.Position
            dragStartPos = button.Position
        end
    end
end)
uis.InputMoved:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if dragStartMouse then
            local delta = input.Position - dragStartMouse
            if delta.Magnitude > 8 then
                isDragging = true
                updateButtonPosition(delta)
            end
        end
    end
end)
uis.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragStartMouse then
            if not isDragging then
                toggleFly()
            end
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

    -- 第三人称
    camera.CameraType = Enum.CameraType.Custom
    local camOffset = Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 10
    camera.CFrame = CFrame.lookAt(root.Position + camOffset, root.Position + Vector3.new(0, 2, 0))

    -- 角色面朝相机前方（水平）
    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    if lookDir.Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)
    end

    -- 摇杆移动
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0.01 then
        -- 转换为世界空间（因为角色朝向已与相机一致，所以直接使用角色朝向）
        local forward = root.CFrame.LookVector
        local right = root.CFrame.RightVector
        -- MoveDirection 的 X 对应左右，Z 对应前后（相对于角色）
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
print("[飞行测试] 手机终极版加载成功，使用全局触摸事件，点击/拖动应可靠。")
