--[[
    飞行测试脚本 v4 - 终极版
    - 飞行方向：相机视野方向（W前，A左，D右，空格上，Shift下）
    - 穿墙：飞行时无碰撞
    - 第三人称锁定，角色面朝相机前方
    - 按钮可拖动，默认居中
    - 状态显示“已开启/已关闭”
]]

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")

-- 清理旧GUI
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

-- ===== 飞行按钮（可拖动） =====
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 140, 0, 50)
button.Position = UDim2.new(0.5, -70, 0.5, -25)  -- 居中
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.TextColor3 = Color3.new(0, 0, 0)
button.Text = "飞行"
button.TextSize = 28
button.TextScaled = true
button.AutoButtonColor = false

-- 黑色边框 (UIStroke)
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 3
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- 圆角
local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 12)

-- ===== 拖动功能 =====
local dragging = false
local dragStartMouse, dragStartPos

local function startDrag(input)
    dragging = true
    dragStartMouse = input.Position
    dragStartPos = button.Position
end

local function updateDrag(input)
    if not dragging then return end
    local delta = input.Position - dragStartMouse
    local newX = dragStartPos.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
    local newY = dragStartPos.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
    button.Position = UDim2.new(newX, 0, newY, 0)
end

local function stopDrag()
    dragging = false
end

-- 鼠标拖动
button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        startDrag(input)
    end
end)
button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)
button.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        stopDrag()
    end
end)

-- 触摸拖动
button.TouchBegan:Connect(function(input)
    startDrag(input)
end)
button.TouchMoved:Connect(function(input)
    updateDrag(input)
end)
button.TouchEnded:Connect(function(input)
    stopDrag()
end)

-- ===== 飞行核心逻辑 =====
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum
local FLY_SPEED = 50

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
    task.wait(1.5)
    statusLabel.Visible = false
end

-- 开启飞行
local function enableFly()
    if not getChar() then
        showStatus("角色未找到", false)
        return false
    end
    -- 取消碰撞（穿墙）
    root.CanCollide = false
    -- 禁用重力
    hum.PlatformStand = true

    -- 速度控制器
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = root

    -- 姿态控制器
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    flying = true
    button.Text = "飞行中"
    showStatus("✅ 已开启功能", true)
    return true
end

-- 关闭飞行
local function disableFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if root then root.CanCollide = true end
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
    end
    flying = false
    button.Text = "飞行"
    showStatus("❌ 已关闭功能", false)
end

-- 切换
local function toggleFly()
    if flying then
        disableFly()
    else
        enableFly()
    end
end

button.Activated:Connect(toggleFly)

-- ===== 第三人称锁定 + 飞行方向控制 =====
local function updateCameraAndMovement()
    if not flying or not root or not hum then return end

    -- 1. 强制第三人称
    camera.CameraType = Enum.CameraType.Custom
    local camPos = root.Position + Vector3.new(0, 3, 0) - camera.CFrame.LookVector * 12
    camera.CFrame = CFrame.lookAt(camPos, root.Position + Vector3.new(0, 2, 0))

    -- 2. 让角色面朝相机前方（水平方向）
    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit  -- 只保留水平
    root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)

    -- 3. 读取移动输入（键盘/摇杆），映射到相机空间
    local moveDir = hum.MoveDirection  -- 基于角色朝向的相对方向，但我们希望是相机空间
    -- 因为 MoveDirection 是相对于角色朝向的，但如果我们希望 W 是相机前方，我们需要获取相机空间的方向。
    -- 更好的方法是直接读取按键，然后构造相机空间速度。
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    local up = Vector3.new(0, 1, 0)

    local inputVec = Vector3.new()
    if uis:IsKeyDown(Enum.KeyCode.W) then inputVec = inputVec + forward end
    if uis:IsKeyDown(Enum.KeyCode.S) then inputVec = inputVec - forward end
    if uis:IsKeyDown(Enum.KeyCode.A) then inputVec = inputVec - right end
    if uis:IsKeyDown(Enum.KeyCode.D) then inputVec = inputVec + right end
    if uis:IsKeyDown(Enum.KeyCode.Space) then inputVec = inputVec + up end
    if uis:IsKeyDown(Enum.KeyCode.LeftShift) then inputVec = inputVec - up end

    -- 如果有摇杆（手机），摇杆输入会通过 MoveDirection 提供，但我们混合使用
    -- 为了支持摇杆，我们可以叠加 MoveDirection 但方向要转换到相机空间？
    -- 这里简化：如果检测到摇杆输入，用 MoveDirection 代替（但很多手机摇杆会与键盘冲突）
    -- 为了兼容，我们优先键盘，若没有键盘输入则使用 MoveDirection（但 MoveDirection 是相对于角色朝向的，不可用）
    -- 稳妥：我们直接使用键盘输入，手机用户可以使用触摸摇杆，但为了完整，我们可以添加摇杆支持，但为了简化，我们仅使用键盘。
    -- 因为用户主要用 PC 测试，所以键盘足够。

    if inputVec.Magnitude > 0 then
        bodyVelocity.Velocity = inputVec.Unit * FLY_SPEED
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end

    -- 保持姿态稳定（可无）
    if bodyGyro then
        bodyGyro.CFrame = root.CFrame
    end
end

-- 每帧更新
runService.RenderStepped:Connect(updateCameraAndMovement)

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
print("[飞行测试] 加载成功。按钮可拖动，点击切换飞行。WASD 控制方向（基于视角），空格上升，Shift下降。")
