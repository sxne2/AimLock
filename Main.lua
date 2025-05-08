-- Lock-On Script for Roblox (Press Q to Toggle Mode)
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configurable Settings (user can change these)
local Config = {
    smoothSpeed = 0.15,         -- Camera smoothing speed
    showHitbox = true,         -- Toggle visibility of hitbox
    enableKnockCheck = true,   -- Automatically unlock if target is knocked out
    enableKnifeCheck = true,   -- Prevent lock-on while holding [Knife]
    alwaysKnifeCheck = true    -- If true, auto-unlock if [Knife] is equipped during lock-on
}

-- Non-configurable state values (runtime only) DONT CHANGE THESE
local State = {
    lockOnMode = false,
    lockOnPlayer = nil,
    scriptActive = true,
    queuedLockOn = false,
    pendingRelockPlayer = nil -- Stores target if lock-on was interrupted by knife
}

-- Get closest player to mouse
local function getClosestPlayerToMouse()
    local mousePos = localPlayer:GetMouse().Hit.Position
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in pairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - mousePos).Magnitude
            if distance < shortestDistance then
                closestPlayer = player
                shortestDistance = distance
            end
        end
    end

    return closestPlayer
end

-- Show or hide the target's hitbox
local function setHitboxVisibility(player, visible)
    if not Config.showHitbox then return end
    if player and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local attachment = hrp:FindFirstChild("RootAttachment")
            if attachment then
                local hitbox = attachment:FindFirstChild("Hitbox")
                if hitbox and hitbox:IsA("BasePart") then
                    hitbox.Transparency = visible and 0.5 or 1
                end
            end
        end
    end
end

-- Check if [Knife] is currently equipped
local function isKnifeEquipped()
    local char = localPlayer.Character
    if not char then return false end
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == "[Knife]" then
            return true
        end
    end
    return false
end

-- Update camera lock-on smoothly
local function updateCamera()
    if not State.scriptActive then return end
    if State.lockOnPlayer and State.lockOnPlayer.Character and State.lockOnPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = State.lockOnPlayer.Character.HumanoidRootPart.Position
        local targetRotation = CFrame.lookAt(camera.CFrame.Position, targetPosition)
        camera.CFrame = camera.CFrame:Lerp(targetRotation, Config.smoothSpeed)
    end
end

-- Permanently deactivate the script
local function deactivateScript()
    if State.lockOnPlayer then
        setHitboxVisibility(State.lockOnPlayer, false)
    end
    State.lockOnMode = false
    State.scriptActive = false
end

-- Handle Q toggle and End key
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not State.scriptActive then return end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Q then
            if not State.lockOnMode then
                if Config.enableKnifeCheck and isKnifeEquipped() then
                    State.queuedLockOn = true
                    return
                end
                State.lockOnPlayer = getClosestPlayerToMouse()
                State.lockOnMode = true
                setHitboxVisibility(State.lockOnPlayer, true)
            else
                setHitboxVisibility(State.lockOnPlayer, false)
                State.lockOnMode = false
                State.lockOnPlayer = nil
            end
        elseif input.KeyCode == Enum.KeyCode.End then
            deactivateScript()
        end
    end
end)

-- Knife check listener: Try lock-on when unequipped or relock
local function monitorKnifeEquip(char)
    char.ChildAdded:Connect(function(child)
        -- For normal knife check (queued lock)
        if State.queuedLockOn and child:IsA("Tool") and child.Name ~= "[Knife]" then
            State.lockOnPlayer = getClosestPlayerToMouse()
            State.lockOnMode = true
            setHitboxVisibility(State.lockOnPlayer, true)
            State.queuedLockOn = false
        end
    end)

    char.ChildRemoved:Connect(function(child)
        -- For alwaysKnifeCheck: re-lock to previous target if knife was unequipped
        if Config.alwaysKnifeCheck and child:IsA("Tool") and child.Name == "[Knife]" and State.pendingRelockPlayer then
            State.lockOnPlayer = State.pendingRelockPlayer
            State.lockOnMode = true
            setHitboxVisibility(State.lockOnPlayer, true)
            State.pendingRelockPlayer = nil
        end
    end)
end

-- Attach knife monitor if character exists
if localPlayer.Character then
    monitorKnifeEquip(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(monitorKnifeEquip)

-- Render loop
game:GetService("RunService").RenderStepped:Connect(function()
    if State.scriptActive and State.lockOnMode then
        -- Knockout check
        if Config.enableKnockCheck and State.lockOnPlayer and State.lockOnPlayer.Character then
            local bodyEffects = workspace:FindFirstChild("Players")
            if bodyEffects then
                local target = bodyEffects:FindFirstChild(State.lockOnPlayer.Name)
                if target and target:FindFirstChild("BodyEffects") then
                    local ko = target.BodyEffects:FindFirstChild("K.O")
                    if ko and ko:IsA("BoolValue") and ko.Value == true then
                        setHitboxVisibility(State.lockOnPlayer, false)
                        State.lockOnPlayer = nil
                        State.lockOnMode = false
                        return
                    end
                end
            end
        end

        -- Always knife check: Unlock if knife is pulled out mid-lock
        if Config.alwaysKnifeCheck and isKnifeEquipped() then
            State.pendingRelockPlayer = State.lockOnPlayer
            setHitboxVisibility(State.lockOnPlayer, false)
            State.lockOnPlayer = nil
            State.lockOnMode = false
            return
        end

        updateCamera()
    end
end)
