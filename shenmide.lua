-- 飞行按钮脚本（放在按钮内的LocalScript）
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

local flying = false
local bodyVelocity = nil
local bodyGyro = nil

local button = script.Parent

-- 飞行切换函数
local function toggleFly()
    flying = not flying
    if flying then
        -- 开启飞行
        hum.PlatformStand = true
        hum.WalkSpeed = 0
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
        button.Text = "降落"
    else
        -- 关闭飞行
        hum.PlatformStand = false
        hum.WalkSpeed = 16 -- 默认速度
        if bodyVelocity then bodyVelocity:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        button.Text = "飞行"
    end
end

-- 点击按钮切换
button.MouseButton1Click:Connect(toggleFly)

-- 移动端触控也兼容
button.TouchTap:Connect(toggleFly)

-- 角色重生后重新绑定
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    -- 如果飞行状态还开着，关闭它
    if flying then
        flying = false
        if bodyVelocity then bodyVelocity:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        button.Text = "飞行"
    end
end)
