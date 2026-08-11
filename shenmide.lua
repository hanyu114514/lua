--[[
    飞行测试脚本 v5 – 修复点击与拖动冲突
    - 按钮可拖动（鼠标/触摸），默认居中
    - 点击（无拖动）切换飞行/着陆，并显示状态
    - 飞行方向基于相机视野（WASD 空格 Shift）
    - 穿墙 + 第三人称锁定
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
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global  -- 确保置顶

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
statusLabel.ZIndex = 100

-- ===== 飞行按钮 =====
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
button.ZIndex = 100
button.Selectable = true

-- 黑色边框 + 圆角
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 3
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 12)

-- ===== 拖动与点击分离逻辑 =====
local isDragging = false
local dragStartPos = nil
local dragStartMouse = nil

local function startDrag(input)
    isDragging = false  -- 重置
    dragStartMouse = input.Position
    dragStartPos = button.Position
end

local function updateDrag(input)
    if not dragStartMouse then return end
    local delta = input.Position - dragStartMouse
    -- 如果移动距离超过 5 像素，视为拖动
    if delta.Magnitude > 5 then
        isDragging = true
        local newX = dragStartPos.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
        local newY = dragStartPos.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
        button.Position = UDim2.new(newX, 0, newY, 0)
    end
end

local function endDrag(input)
    -- 不在这里触发点击，由点击事件单独处理
    dragStartMouse = nil
    dragStartPos = nil
end

-- 鼠标事件
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
        endDrag(input)
        -- 如果未拖动，则触发点击
        if not isDragging then
            toggleFly()
        end
        isDragging = false
    end
end)

-- 触摸事件
button.TouchBegan:Connect(function(input)
    startDrag(input)
end)
button.TouchMoved:Connect(function(input)
    updateDrag(input)
end)
button.TouchEnded:Connect(function(input)
    endDrag(input)
    if not isDragging then
        toggleFly()
    end
    isDragging = false
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
    showStatus("✅ 已开启功能", true)
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
    showStatus("❌ 已关闭功能", false)
end

function toggleFly()
    if flying then
        disableFly()
    else
        enableFly()
    end
end

-- ===== 第三人称 & 飞行方向（基于相机） =====
runService.RenderStepped:Connect(function()
    if not flying or not root or not hum then return end

    -- 第三人称
    camera.CameraType = Enum.CameraType.Custom
    local camPos = root.Position + Vector3.new(0, 3, 0) - camera.CFrame.LookVector * 12
    camera.CFrame = CFrame.lookAt(camPos, root.Position + Vector3.new(0, 2, 0))

    -- 角色朝相机前方
    local lookDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
    root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)

    -- 基于相机方向的移动速度
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

    if inputVec.Magnitude > 0 then
        bodyVelocity.Velocity = inputVec.Unit * FLY_SPEED
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
print("[飞行测试] 加载成功。按钮可拖动，点击（不拖动）切换飞行。WASD 方向，空格上升，Shift下降。")
