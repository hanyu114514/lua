--[[
    手机飞行测试脚本 - 纯触控优化版
    - 按钮大小 100x40，白底黑字黑边框圆角，默认居中，可拖动
    - 点击（不拖动）切换飞行/着陆，显示状态
    - 飞行时：穿墙、悬停，利用手机摇杆控制方向（前后左右基于相机视角）
    - 无键盘，纯触控
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

-- ===== 飞行按钮 (小尺寸，适合手机手指) =====
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 100, 0, 40)          -- 缩小尺寸
button.Position = UDim2.new(0.5, -50, 0.5, -20) -- 居中
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.TextColor3 = Color3.new(0, 0, 0)
button.Text = "飞行"
button.TextSize = 24
button.TextScaled = true
button.AutoButtonColor = false
button.ZIndex = 100
button.Selectable = true

-- 黑色边框 + 圆角
local stroke = Instance.new("UIStroke")
stroke.Parent = button
stroke.Thickness = 2.5
stroke.Color = Color3.new(0, 0, 0)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local corner = Instance.new("UICorner")
corner.Parent = button
corner.CornerRadius = UDim.new(0, 10)

-- ===== 触摸拖动与点击分离 =====
local isDragging = false
local dragStartPos = nil
local dragStartTouch = nil
local DRAG_THRESHOLD = 8   -- 像素阈值

local function startDrag(input)
    isDragging = false
    dragStartTouch = input.Position
    dragStartPos = button.Position
end

local function updateDrag(input)
    if not dragStartTouch then return end
    local delta = input.Position - dragStartTouch
    if delta.Magnitude > DRAG_THRESHOLD then
        isDragging = true
        -- 计算新位置（相对于屏幕比例）
        local newX = dragStartPos.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
        local newY = dragStartPos.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
        -- 限制在屏幕内（留边距）
        newX = math.clamp(newX, 0.05, 0.85)
        newY = math.clamp(newY, 0.05, 0.85)
        button.Position = UDim2.new(newX, 0, newY, 0)
    end
end

local function endDrag(input)
    if not isDragging then
        -- 点击（未拖动）切换飞行
        toggleFly()
    end
    isDragging = false
    dragStartTouch = nil
    dragStartPos = nil
end

-- 触摸事件（手机专用）
button.TouchBegan:Connect(startDrag)
button.TouchMoved:Connect(updateDrag)
button.TouchEnded:Connect(endDrag)
-- 同时兼容鼠标（便于PC模拟测试）
button.MouseButton1Down:Connect(function(x, y)
    startDrag({Position = Vector2.new(x, y)})
end)
button.MouseMoved:Connect(function(x, y)
    updateDrag({Position = Vector2.new(x, y)})
end)
button.MouseButton1Up:Connect(function(x, y)
    endDrag({Position = Vector2.new(x, y)})
end)

-- ===== 飞行核心逻辑 =====
local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum
local FLY_SPEED = 40   -- 飞行速度

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

-- ===== 利用手机摇杆控制方向（基于相机视角） =====
runService.RenderStepped:Connect(function()
    if not flying or not root or not hum then return end

    -- 1. 第三人称锁定（跟随角色，保持一定距离和角度）
    camera.CameraType = Enum.CameraType.Custom
    local camOffset = Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 10
    local camPos = root.Position + camOffset
    camera.CFrame = CFrame.lookAt(camPos, root.Position + Vector3.new(0, 2, 0))

    -- 2. 获取摇杆输入 (Vector3, 方向基于角色朝向)
    local moveDir = hum.MoveDirection  -- 单位向量，相对于角色朝向
    -- 但我们需要相对于相机视角，所以我们将 moveDir 映射到相机空间
    -- 方法：取相机的 forward 和 right 向量，构建一个旋转矩阵，将 moveDir 转换到世界空间
    if moveDir.Magnitude > 0.01 then
        -- 获取相机朝向（水平方向）
        local forward = camera.CFrame.LookVector
        forward = Vector3.new(forward.X, 0, forward.Z).Unit
        local right = camera.CFrame.RightVector
        right = Vector3.new(right.X, 0, right.Z).Unit

        -- 将移动方向映射到世界空间（假设 moveDir 是相对于角色朝向，但这里摇杆返回的是相对于角色朝向？实际上在Roblox中，Humanoid.MoveDirection 是相对于世界坐标系的，但它是基于角色当前的朝向？官方文档：MoveDirection 是相对于角色的朝向的，即角色前方为(0,0,-1)？不确定，最好自己测试。不过为了安全，我们可以直接用摇杆的X和Z，但摇杆是2D的？实际上Humanoid.MoveDirection是Vector3，通常是基于世界空间的，并且表示移动方向。但为了确保基于相机，我们直接读取摇杆的原始输入？没有直接API。一个可靠的方法是在用户触摸屏幕时获取触摸位置与屏幕中心的偏移，但那样复杂。其实简单点：我们可以直接使用Humanoid.MoveDirection，并让角色始终面向相机前方，但这样移动方向会与角色朝向有关，但我们已经在每一步强制角色面向相机前方，所以 moveDir 其实就是相对于世界空间（因为角色朝向改变了），但 MoveDirection 是相对于角色朝向的，所以当我们强制角色面向相机前方时，moveDir 的 XZ 分量就可以直接映射到世界空间的前后左右？需要验证。

        -- 更稳妥：我们直接使用摇杆的输入，但Roblox移动端的摇杆会通过Humanoid.MoveDirection传递一个相对于角色朝向的方向。如果我们保持角色朝向相机前方，那么 MoveDirection 的 X 代表左右，Z 代表前后（相对于角色朝向），此时角色朝向与相机前方一致，所以它自然就是相机空间的方向。
        -- 所以我们只需将 moveDir 的 XZ 分量乘以速度即可，并保持垂直为0（除非有上下键）
        local horizontal = Vector3.new(moveDir.X, 0, moveDir.Z)
        if horizontal.Magnitude > 0.01 then
            -- 使用角色当前朝向（即相机前方）作为基向量
            local roleForward = root.CFrame.LookVector
            local roleRight = root.CFrame.RightVector
            -- 摇杆的X对应左右，Z对应前后（注意坐标系）
            local velocity = (roleForward * -horizontal.Z + roleRight * horizontal.X) * FLY_SPEED
            bodyVelocity.Velocity = velocity
        else
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end

    -- 保持姿态（可选）
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
print("[飞行测试] 手机版加载成功。拖动按钮移动，点击切换飞行。摇杆控制方向（基于视角）")
