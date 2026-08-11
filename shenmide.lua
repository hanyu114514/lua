--[[
    摇杆触发飞行脚本 – 无需点击按钮
    操作：向前推摇杆并保持 1.5 秒切换飞行/着陆
]]

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")

local flying = false
local bodyVelocity = nil
local bodyGyro = nil
local char, root, hum
local FLY_SPEED = 40
local toggleHoldTime = 1.5  -- 秒
local holdTimer = 0

local function getChar()
    char = player.Character
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    return char and root and hum
end

function enableFly()
    if not getChar() then return false end
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
    print("[飞行] 已开启")
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
    print("[飞行] 已关闭")
end

function toggleFly()
    if flying then
        disableFly()
    else
        enableFly()
    end
end

-- 监听摇杆输入（通过 Humanoid.MoveDirection 变化）
runService.RenderStepped:Connect(function()
    if not getChar() then return end

    -- 第三人称
    if flying then
        camera.CameraType = Enum.CameraType.Custom
        local camOffset = Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 10
        camera.CFrame = CFrame.lookAt(root.Position + camOffset, root.Position + Vector3.new(0, 2, 0))

        local lookDir = camera.CFrame.LookVector
        lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        if lookDir.Magnitude > 0.01 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir * 10)
        end
    end

    -- 获取摇杆方向
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0.5 then  -- 有摇杆输入
        -- 检测摇杆是否主要向前（Z 负值表示向前，因为 Roblox 的 Z 轴向前是 -Z）
        local forwardness = -moveDir.Z  -- 向前分量
        if forwardness > 0.5 then  -- 向前推的程度
            holdTimer = holdTimer + runService.RenderStepped:Wait()
            if holdTimer >= toggleHoldTime then
                toggleFly()
                holdTimer = 0  -- 重置计时，避免连续触发
            end
        else
            holdTimer = 0  -- 不是向前推，重置计时
        end
    else
        holdTimer = 0  -- 无摇杆输入，重置
    end

    -- 飞行状态更新速度
    if flying and bodyVelocity then
        -- 如果飞行中，摇杆控制方向（已有 moveDir）
        if moveDir.Magnitude > 0.01 then
            local forward = root.CFrame.LookVector
            local right = root.CFrame.RightVector
            local velocity = (forward * -moveDir.Z + right * moveDir.X) * FLY_SPEED
            bodyVelocity.Velocity = velocity
        else
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)

-- 角色重生重置
player.CharacterAdded:Connect(function(newChar)
    if flying then disableFly() end
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end)

getChar()
print("[飞行] 摇杆触发脚本已加载，向前推摇杆 1.5 秒切换飞行/着陆")
