--[[
    极简飞行脚本 – 只使用按钮自身事件，无调试输出
    点击切换飞行，拖动移动按钮
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

-- 按钮（稍大，方便触摸）
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 120, 0, 50)
button.Position = UDim2.new(0.5, -60, 0.5, -25)
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

-- 拖动逻辑（不影响点击）
local isDragging = false
local dragStart = nil
local dragOrigin = nil

button.TouchBegan:Connect(function(input)
    isDragging = false
    dragStart = input.Position
    dragOrigin = button.Position
end)

button.TouchMoved:Connect(function(input)
    if not dragStart then return end
    local delta = input.Position - dragStart
    if delta.Magnitude > 10 then
        isDragging = true
        local newX = dragOrigin.X.Scale + delta.X / screenGui.AbsoluteSize.X
        local newY = dragOrigin.Y.Scale + delta.Y / screenGui.AbsoluteSize.Y
        button.Position = UDim2.new(math.clamp(newX, 0.05, 0.85), 0, math.clamp(newY, 0.05, 0.85), 0)
    end
end)

button.TouchEnded:Connect(function()
    dragStart = nil
    dragOrigin = nil
    -- 注意：如果拖动，则不会触发 Activated（因为 Activated 是在点击时触发，拖动不会触发）
end)

-- 点击事件（使用 Activated，触摸和鼠标均有效，且不会因拖动而触发）
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

button.Activated:Connect(toggleFly)

-- 飞行控制
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
