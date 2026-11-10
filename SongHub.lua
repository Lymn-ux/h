local players = game:GetService("Players")
local runService = game:GetService("RunService")
local virtualInputManager = game:GetService("VirtualInputManager")
local guiService = game:GetService("GuiService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local marketplaceService = game:GetService("MarketplaceService")
local coreGui = game:GetService("CoreGui")
local tweenService = game:GetService("TweenService")
local teleportService = game:GetService("TeleportService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local localPlayer = players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local worldCache = {
    Visibility = {},
    Generators = {},
    Pallets = {},
    Hooks = {},
    Gates = {},
    Windows = {},
    SCPs = {},
}

local isLungeBoostEnabled = false
local isAutoGeneratorEnabled = false
local isAutoWiggleEnabled = false
local isKillerNoSlowdownEnabled = false
local isSurvivorNoSlowdownEnabled = false
local isFleeKillerEnabled = false
local fleeDistance = 40
local lastFleeTeleportTime = 0
local isAutoHealEnabled = false
local afkEscapeThread = nil
local previousRole = localPlayer.Team and localPlayer.Team.Name or "Unknown"
local lockAimTarget = nil

local SurvivorSettings = {
    Surv_AutoParry = false,
    Surv_ParrySafety = false,
    Surv_ParryAggressive = false,
    Surv_ParryCircle = true,
    Surv_ParryRadius = 15,
    Surv_ParryFace = 0.7,
    Ignored_Skills_List = {},
    Surv_VaultSpeed = 13,
    Surv_Perks = false,
    LockAim = false,
    Killer_3rdPerson = false,
    AUTO_AFKEscape = false,
    Surv_Aimbot_Enabled = false,
    Surv_Aimbot_ShowFOV = true,
    Surv_Aimbot_Radius = 150,
    Surv_Aimbot_MaxDist = 300,
    Surv_Aimbot_Smoothness = 0.5,
    Surv_Aimbot_Predict = 0.01,
    Killer_Aimbot_Enabled = false,
    Killer_Aimbot_MaxDist = 12,
    Killer_Aimbot_Smoothness = 0.5,
    Surv_AutoCrouch = false,
    Surv_InstanSkillCheck = false,
    ESP_Master = false,
    ESP_Player = false,
    ESP_Outline = true,
    ESP_Name = false,
    ESP_Distance = false,
    ESP_Killer = false,
    ESP_ItemIcon = false,
    ESP_Generator = false,
    ESP_Pallet = false,
    ESP_Hook = false,
    ESP_KillerWarn = false,
    ESP_Gate = false,
    ESP_Window = false,
    ESP_SCP = false,
}

local AimSettings = {
    Aim_Silent = false,
    Pistol_BlockKnocked = false,
    WallCheck = false,
    Flash_Silent = false,
    Flash_YOffset = 1.5,
    LockAim = false,
    Pistol_Target = "Survivor",
    Pistol_FOVMode = false,
    Pistol_ShowFOV = false,
    Pistol_FOV = 150,
    Aim_SilentVeil = false,
    Veil_ShowFOV = true,
    Veil_FOV = 150,
    SPEAR_Speed = 165,
    SPEAR_Gravity = workspace.Gravity * 0.5,
    SPEAR_MaxDist = 200,
    AIM_Auto = false,
    AIM_TargetPart = "Torso",
    Killer_InfAbyssal = false,
}

if not getgenv().VD_SmartLogic then
    getgenv().VD_SmartLogic = {
        WallCheck = function() return true end,
        IsOverCancel = function() return false end,
    }
end

local runtimeState = {
    ParryCooldown = false,
    ParryCooldownTime = 60,
    fakeLevel = 0,
    fakeGears = 0,
    fakeScrews = 0,
    AutoParryAdornment = nil,
    ThirdPersonConn = nil,
    SpooferConns = {},
    ItemESPs = {},
}

local animationNameById = {
    ["122812055447896"] = "Veil lunge",
    ["133963973694098"] = "Mayers Basic",
    ["117042998468241"] = "Mayers lunge",
    ["135002183282873"] = "cure lunge",
    ["121216847022485"] = "cure Basic",
    ["132817836308238"] = "Jeff Basic",
    ["129784271201071"] = "Jeff lunge",
    ["82666958311998"] = "Jeff Frenzy",
    ["78432063483146"] = "Abyssal Basic",
    ["118907603246885"] = "Abyssal lunge",
    ["139369275981139"] = "Jason Basic",
    ["110355011987939"] = "Jason lunge",
    ["111920872708571"] = "Masked Basic",
    ["105374834496520"] = "Masked lunge",
    ["138720291317243"] = "Masked Tony",
    ["106871536134254"] = "Masked Alex",
    ["130593238885843"] = "Masked Cobra",
    ["115244153053858"] = "Masked Cobra lunge",
    ["74968262036854"] = "Hidden Basic",
    ["113255068724446"] = "Hidden lunge",
    ["98163597193511"] = "Hidden S1",
    ["80411309607666"] = "Abyssal S1",
}

local trackedAnimators = {}

local armPartNames = {
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    LeftHand = true,
    RightHand = true,
    LeftLowerArm = true,
    RightLowerArm = true,
    LeftUpperArm = true,
    RightUpperArm = true,
}

local function canParry(character)
    if not SurvivorSettings.Surv_ParrySafety then
        return true
    end

    if not character then
        return false
    end

    local checkInterractable = character:FindFirstChild("CheckInterractable")

    if checkInterractable then
        if checkInterractable:GetAttribute("isVaulting") == true then
            return false
        end

        if checkInterractable:GetAttribute("isRepairing") == true then
            return false
        end

        if checkInterractable:GetAttribute("isUnhooking") == true then
            return false
        end

        if checkInterractable:GetAttribute("isHealing") == true then
            return false
        end

        if checkInterractable:GetAttribute("isSliding") == true then
            return false
        end
    end

    return true
end

local function isWeaponTool(instance)
    if instance:IsA("Tool") then
        return true
    end

    if instance.Parent and armPartNames[instance.Parent.Name] then
        return true
    end

    local lowerName = instance.Name:lower()

    if lowerName:match("weapon") or lowerName:match("gun") or lowerName:match("blade") then
        return true
    end

    return false
end

local function getLocalRole()
    if not localPlayer.Team then
        return "Unknown"
    end

    local teamName = localPlayer.Team.Name

    if teamName == "Killer" then
        return "Killer"
    elseif teamName == "Survivors" then
        return "Survivor"
    else
        return "Spectator"
    end
end

local function isKillerPlayer(player)
    return player and player.Team and player.Team.Name == "Killer"
end

local function isKnockedOrHooked(character)
    if not character then
        return false
    end

    return character:GetAttribute("Knocked") == true or character:GetAttribute("IsHooked") == true
end

local function refreshWorldCache()
    table.clear(worldCache.Generators)
    table.clear(worldCache.Windows)
    table.clear(worldCache.Pallets)
    table.clear(worldCache.Hooks)
    table.clear(worldCache.Gates)
    table.clear(worldCache.SCPs)

    for _, descendant in ipairs((workspace:FindFirstChild("Map") or workspace):GetDescendants()) do
        if descendant:IsA("Model") then
            local lowerName = string.lower(descendant.Name)

            if lowerName == "generator" then
                local basePart = descendant:FindFirstChildWhichIsA("BasePart")

                if basePart then
                    table.insert(worldCache.Generators, { model = descendant, part = basePart })
                end
            elseif lowerName == "hook" and descendant:FindFirstChild("HookPoint") then
                table.insert(worldCache.Hooks, descendant)
            elseif lowerName == "gate" and descendant:FindFirstChild("ExitLever") then
                table.insert(worldCache.Gates, descendant)
            elseif lowerName == "window" then
                table.insert(worldCache.Windows, descendant)
            end
        elseif descendant:IsA("BasePart") and descendant.Name == "PrimaryPartPallet" then
            if descendant.Parent and not table.find(worldCache.Pallets, descendant.Parent) then
                table.insert(worldCache.Pallets, descendant.Parent)
            end
        end
    end
end

local function aimCameraAt(targetPart, alpha)
    if not targetPart then
        return
    end

    alpha = alpha or 0.1
    local targetCFrame = CFrame.lookAt(currentCamera.CFrame.Position, targetPart.Position)
    currentCamera.CFrame = currentCamera.CFrame:Lerp(targetCFrame, alpha)
end

local function distanceFromLocalRoot(position)
    local localRoot = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return math.huge
    end

    return (position - localRoot.Position).Magnitude
end

local function requestHeal()
    local character = localPlayer.Character

    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoidRootPart and humanoid and humanoid.Health < humanoid.MaxHealth then
        pcall(function()
            local remotes = replicatedStorage:FindFirstChild("Remotes")

            if remotes and remotes:FindFirstChild("Healing") then
                remotes.Healing.HealEvent:FireServer(humanoidRootPart, true)
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(5)

        if isAutoHealEnabled then
            requestHeal()
        end
    end
end)

if coreGui:FindFirstChild("FOVCircleGui_Standalone") then
    coreGui:FindFirstChild("FOVCircleGui_Standalone"):Destroy()
end

local fovCircleGuiStandalone = Instance.new("ScreenGui")
fovCircleGuiStandalone.Name = "FOVCircleGui_Standalone"
fovCircleGuiStandalone.Parent = coreGui
fovCircleGuiStandalone.ResetOnSpawn = false
fovCircleGuiStandalone.IgnoreGuiInset = true

local fovCircleFrame = Instance.new("Frame")
fovCircleFrame.BackgroundTransparency = 1
fovCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircleFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircleFrame.Visible = false
fovCircleFrame.Parent = fovCircleGuiStandalone

local fovCircleCorner = Instance.new("UICorner")
fovCircleCorner.CornerRadius = UDim.new(1, 0)
fovCircleCorner.Parent = fovCircleFrame

local fovCircleStroke = Instance.new("UIStroke")
fovCircleStroke.Color = Color3.fromRGB(0, 255, 100)
fovCircleStroke.Thickness = 1.5
fovCircleStroke.Parent = fovCircleFrame

local function findAimbotTarget()
    local closestTarget = nil
    local role = getLocalRole()
    local bestScore = role == "Survivor" and SurvivorSettings.Surv_Aimbot_Radius or math.huge
    local viewportCenter = Vector2.new(
        currentCamera.ViewportSize.X / 2, currentCamera.ViewportSize.Y / 2
    )

    for _, player in pairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart") then
            local isCandidate = false

            if role == "Survivor" and SurvivorSettings.Surv_Aimbot_Enabled and isKillerPlayer(player) then
                isCandidate = true
            elseif role == "Killer" and SurvivorSettings.Killer_Aimbot_Enabled and not isKillerPlayer(player) then
                local humanoid = player.Character:FindFirstChild("Humanoid")

                if humanoid and humanoid.Health > 0 and not isKnockedOrHooked(player.Character) then
                    isCandidate = true
                end
            end

            if isCandidate then
                local targetRoot = player.Character.HumanoidRootPart
                local distance = distanceFromLocalRoot(targetRoot.Position)

                if role == "Survivor" and distance <= SurvivorSettings.Surv_Aimbot_MaxDist then
                    local screenPos, onScreen = currentCamera:WorldToViewportPoint(targetRoot.Position)

                    if onScreen then
                        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude

                        if screenDistance < bestScore then
                            bestScore = screenDistance
                            closestTarget = targetRoot
                        end
                    end
                elseif role == "Killer" and distance <= SurvivorSettings.Killer_Aimbot_MaxDist then
                    if distance < bestScore then
                        bestScore = distance
                        closestTarget = targetRoot
                    end
                end
            end
        end
    end

    return closestTarget
end

local function findMobileControlsFrame()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")

    if not playerGui then
        return nil
    end

    for _, child in pairs(playerGui:GetChildren()) do
        if string.sub(child.Name, -4) == "-mob" and child.Name ~= "Survivor-mob" then
            return child
        end
    end

    return nil
end

local touchAimbotInput = nil
local isKillerAimbotLockActive = false
local veilThrowCooldown = false
local hideSilentLaser = false

local function triggerAbyssalCorrupt()
    if getLocalRole() ~= "Killer" then
        return
    end

    local selectedKiller = localPlayer:FindFirstChild("SelectedKiller")

    local killerValue = selectedKiller and selectedKiller.Value
        or localPlayer:GetAttribute("SelectedKiller")

    if string.find(string.lower(tostring(killerValue)), "abyss") then
        pcall(function()
            replicatedStorage.Remotes.Killers.Abysswalker.corrupt:FireServer()
        end)
    end
end

local isInfiniteAbyssalActive = false

local function startInfiniteAbyssal()
    if isInfiniteAbyssalActive then
        return
    end

    isInfiniteAbyssalActive = true

    task.spawn(function()
        while isInfiniteAbyssalActive and SurvivorSettings.Killer_InfAbyssal and getLocalRole() == "Killer" do
            triggerAbyssalCorrupt()
            task.wait(0.5)
        end
    end)
end

local function stopInfiniteAbyssal()
    isInfiniteAbyssalActive = false
end

userInputService.InputBegan:Connect(function(input, gameProcessed)
    local isTouchInput = input.UserInputType == Enum.UserInputType.Touch
    local role = getLocalRole()

    if SurvivorSettings.Killer_InfAbyssal and input.KeyCode == Enum.KeyCode.Q then
        startInfiniteAbyssal()
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if gameProcessed then
            return
        end

        if role == "Killer" and SurvivorSettings.Killer_Aimbot_Enabled then
            lockAimTarget = findAimbotTarget()

            if lockAimTarget then
                isKillerAimbotLockActive = true
            end
        end
    end

    if isTouchInput then
        if SurvivorSettings.Killer_InfAbyssal then
            local mobFrame = findMobileControlsFrame()

            local moveButton = mobFrame and mobFrame:FindFirstChild("Controls")
                and mobFrame.Controls:FindFirstChild("move2")

            if moveButton and moveButton.Visible then
                local touchPos = input.Position
                local buttonPos = moveButton.AbsolutePosition
                local buttonSize = moveButton.AbsoluteSize

                if touchPos.X >= buttonPos.X
                    and touchPos.X <= buttonPos.X + buttonSize.X
                    and touchPos.Y >= buttonPos.Y
                    and touchPos.Y <= buttonPos.Y + buttonSize.Y then
                    startInfiniteAbyssal()
                    touchAimbotInput = input
                end
            end
        end

        if role == "Killer" and SurvivorSettings.Killer_Aimbot_Enabled then
            local mobFrame = findMobileControlsFrame()

            local attackButton = mobFrame and mobFrame:FindFirstChild("Controls")
                and mobFrame.Controls:FindFirstChild("attack")

            if attackButton and attackButton.Visible then
                local touchPos = input.Position
                local buttonPos = attackButton.AbsolutePosition
                local buttonSize = attackButton.AbsoluteSize

                if touchPos.X >= buttonPos.X
                    and touchPos.X <= buttonPos.X + buttonSize.X
                    and touchPos.Y >= buttonPos.Y
                    and touchPos.Y <= buttonPos.Y + buttonSize.Y then
                    lockAimTarget = findAimbotTarget()

                    if lockAimTarget then
                        isKillerAimbotLockActive = true
                        touchAimbotInput = input
                    end
                end
            end
        end
    end
end)

userInputService.InputEnded:Connect(function(input, gameProcessed)
    local isTouchInput = input.UserInputType == Enum.UserInputType.Touch

    if input.KeyCode == Enum.KeyCode.Q then
        stopInfiniteAbyssal()
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isKillerAimbotLockActive = false
        lockAimTarget = nil
    end

    if isTouchInput and input == touchAimbotInput then
        stopInfiniteAbyssal()
        touchAimbotInput = nil
    end
end)

runService.RenderStepped:Connect(function()
    local character = localPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    local role = getLocalRole()

    if character and humanoidRootPart then
        if role == "Survivor" and SurvivorSettings.Surv_Aimbot_Enabled then
            local target = findAimbotTarget()

            if target then
                local targetPosition = target.Position
                local distance = distanceFromLocalRoot(targetPosition)

                if distance < 100 then
                    local predictionOffset = (100 - distance) * SurvivorSettings.Surv_Aimbot_Predict
                    targetPosition = targetPosition + currentCamera.CFrame.RightVector * predictionOffset
                end

                local cameraCFrame = CFrame.new(currentCamera.CFrame.Position, targetPosition)
                currentCamera.CFrame = currentCamera.CFrame:Lerp(cameraCFrame, SurvivorSettings.Surv_Aimbot_Smoothness)

                local bodyCFrame = CFrame.new(humanoidRootPart.Position, Vector3.new(
                    targetPosition.X, humanoidRootPart.Position.Y, targetPosition.Z
                ))

                humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(
                    bodyCFrame, SurvivorSettings.Surv_Aimbot_Smoothness
                )
            end
        elseif role == "Killer" and SurvivorSettings.Killer_Aimbot_Enabled then
            local target = findAimbotTarget()

            if target and humanoidRootPart and currentCamera then
                lockAimTarget = target
                local targetPosition = target.Position

                if distanceFromLocalRoot(targetPosition) <= SurvivorSettings.Killer_Aimbot_MaxDist then
                    local cameraCFrame = CFrame.new(currentCamera.CFrame.Position, targetPosition)

                    currentCamera.CFrame = currentCamera.CFrame:Lerp(
                        cameraCFrame, SurvivorSettings.Killer_Aimbot_Smoothness
                    )

                    local bodyCFrame = CFrame.new(humanoidRootPart.Position, Vector3.new(
                        targetPosition.X, humanoidRootPart.Position.Y, targetPosition.Z
                    ))

                    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(
                        bodyCFrame, SurvivorSettings.Killer_Aimbot_Smoothness
                    )
                end
            else
                lockAimTarget = nil
            end
        end
    end

    local shouldShowFov = false

    local viewportCenter = Vector2.new(
        currentCamera.ViewportSize.X / 2, currentCamera.ViewportSize.Y / 2
    )

    if role == "Survivor" and SurvivorSettings.Surv_Aimbot_Enabled and SurvivorSettings.Surv_Aimbot_ShowFOV then
        shouldShowFov = true
        local radius = SurvivorSettings.Surv_Aimbot_Radius

        fovCircleFrame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
        fovCircleFrame.Position = UDim2.new(0, viewportCenter.X, 0, viewportCenter.Y)

        if findAimbotTarget() ~= nil then
            fovCircleStroke.Color = Color3.fromRGB(255, 0, 0)
        else
            fovCircleStroke.Color = Color3.fromRGB(0, 255, 100)
        end
    end

    fovCircleFrame.Visible = shouldShowFov
end)

local function getLocalRootPart()
    local character = players.LocalPlayer.Character

    if character then
        return character:FindFirstChild("HumanoidRootPart")
    end

    return nil
end

local function teleportToExit()
    local localRoot = getLocalRootPart()
    local map = workspace:FindFirstChild("Map")

    if not localRoot or not map then
        return false
    end

    local exitPosition = nil

    pcall(function()
        for _, descendant in ipairs(map:GetDescendants()) do
            local lowerName = string.lower(descendant.Name)

            if lowerName == "fininshline" or lowerName == "finishline" or string.find(lowerName, "finish") then
                if descendant:IsA("BasePart") then
                    exitPosition = descendant.Position
                    break
                elseif descendant:IsA("Model") then
                    local basePart = descendant:FindFirstChildWhichIsA("BasePart")

                    if basePart then
                        exitPosition = basePart.Position
                        break
                    end
                end
            end
        end

        if not exitPosition then
            if map:FindFirstChild("RooftopHitbox") or map:FindFirstChild("Rooftop") then
                exitPosition = Vector3.new(3098.16, 454.04, -4918.74)
            elseif map:FindFirstChild("HooksMeat") then
                exitPosition = Vector3.new(1546.12, 152.21, -796.72)
            elseif map:FindFirstChild("churchbell") then
                exitPosition = Vector3.new(760.98, -20.14, -78.48)
            else
                for _, descendant in ipairs(map:GetDescendants()) do
                    if descendant:IsA("MeshPart") and descendant.Material == Enum.Material.Limestone then
                        exitPosition = Vector3.new(-947.9, 152.12, -7579.52)
                        break
                    elseif descendant:IsA("MeshPart") and descendant.Material == Enum.Material.Leather then
                        exitPosition = Vector3.new(1546.12, 152.21, -796.72)
                        break
                    end
                end
            end
        end
    end)

    if exitPosition then
        localRoot.CFrame = CFrame.new(exitPosition + Vector3.new(0, 3, 0))
        return true
    end

    return false
end

local function hopToRandomServer()
    local success, response = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
    end)

    if success and response then
        local decoded = httpService:JSONDecode(response)
        local serverIds = {}

        if decoded and decoded.data then
            for _, server in ipairs(decoded.data) do
                if type(server) == "table" and server.id and server.id ~= game.JobId then
                    table.insert(serverIds, server.id)
                end
            end
        end

        if #serverIds > 0 then
            local chosenId = serverIds[math.random(#serverIds)]
            teleportService:TeleportToPlaceInstance(game.PlaceId, chosenId, localPlayer)
        elseif getgenv().Library then
            getgenv().Library:Notify("Failed: No servers available.", 3)
        end
    end
end

local function startAfkEscape(role)
    if not SurvivorSettings.AUTO_AFKEscape then
        return
    end

    if afkEscapeThread then
        task.cancel(afkEscapeThread)
    end

    if role == "Survivors" then
        afkEscapeThread = task.spawn(function()
            if Library then
                Library:Notify("AFK Mode ON!", 3)
            end

            task.wait(18)

            if SurvivorSettings.AUTO_AFKEscape and localPlayer.Team and localPlayer.Team.Name == "Survivors" then
                if teleportToExit() then
                    if Library then
                        Library:Notify("Teleported to exit! Waiting for server...", 3)
                    end
                elseif Library then
                    Library:Notify("Failed to find exit!", 3)
                end
            end

            task.wait(5)

            if SurvivorSettings.AUTO_AFKEscape and localPlayer.Team and localPlayer.Team.Name == "Survivors" then
                if Library then
                    Library:Notify("Match stuck, searching for a new server...", 3)
                end

                hopToRandomServer()
            end
        end)
    elseif role == "Spectator" then
        afkEscapeThread = task.spawn(function()
            if previousRole == "Survivors" then
                if Library then
                    Library:Notify("Match finished, sending data & searching for a new server...", 3)
                end

                task.wait(5)
                hopToRandomServer()
            else
                local hasActiveMatch = false

                for _, player in ipairs(players:GetPlayers()) do
                    if player.Team and (player.Team.Name == "Survivors" or player.Team.Name == "Killer") then
                        hasActiveMatch = true
                        break
                    end
                end

                if hasActiveMatch then
                    if Library then
                        Library:Notify("Match in progress, searching for a new server...", 3)
                    end

                    task.wait(2)
                    hopToRandomServer()
                else
                    if Library then
                        Library:Notify("Waiting for match to start, max 2 minutes..", 3)
                    end

                    task.wait(120)

                    if Library then
                        Library:Notify("Wait time expired, searching for a new server...", 3)
                    end

                    task.wait(2)
                    hopToRandomServer()
                end
            end
        end)
    elseif role == "Killer" then
        afkEscapeThread = task.spawn(function()
            if Library then
                Library:Notify("You are Killer! Searching for a new server...", 3)
            end

            task.wait(3)
            hopToRandomServer()
        end)
    end

    previousRole = role
end

local function setupAutoGenerator()
    pcall(function()
        local kingscourge = replicatedStorage:WaitForChild("Remotes"):WaitForChild("KillerPerks"):WaitForChild("kingscourge")

        kingscourge.KingScourgeStart.OnClientEvent:Connect(function(target, _, hitCount)
            if isAutoGeneratorEnabled then
                for _ = 1, hitCount or 1 do
                    kingscourge.KingScourgeHit:FireServer(target, "success")
                    task.wait(0.05)
                end
            end
        end)
    end)

    task.spawn(function()
        local skillCheckPromptGui = localPlayer:FindFirstChild("PlayerGui"):WaitForChild(
            "SkillCheckPromptGui", 10
        )

        local checkPrompt = skillCheckPromptGui and skillCheckPromptGui:WaitForChild("Check", 8)

        if not checkPrompt then
            return
        end

        checkPrompt:GetPropertyChangedSignal("Visible"):Connect(function()
            if checkPrompt.Visible and isAutoGeneratorEnabled then
                local line = checkPrompt:FindFirstChild("Line")
                local goal = checkPrompt:FindFirstChild("Goal")

                if line and goal then
                    task.wait(0.01)
                    line.Rotation = goal.Rotation + 109
                end
            end
        end)
    end)
end

local function setupParryCooldownTracker()
    task.spawn(function()
        local remotes = replicatedStorage:WaitForChild("Remotes", 5)

        local parryDagger = remotes and remotes:WaitForChild("Items", 5):WaitForChild(
            "Parrying Dagger", 5
        )

        local parryResult = parryDagger and parryDagger:WaitForChild("parryResult", 5)

        if parryResult then
            parryResult.OnClientEvent:Connect(function(success, duration)
                local cooldown = tonumber(duration) or (success == true and 90 or 60)
                runtimeState.ParryCooldown = true

                if runtimeState.ParryCooldownThread then
                    task.cancel(runtimeState.ParryCooldownThread)
                end

                runtimeState.ParryCooldownThread = task.delay(cooldown, function()
                    runtimeState.ParryCooldown = false
                end)
            end)
        end
    end)
end

setupParryCooldownTracker()

local function trackKillerAnimations(character)
    if not character or trackedAnimators[character] then
        return
    end

    trackedAnimators[character] = true
    local humanoid = character:FindFirstChild("Humanoid")

    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)

        if not humanoid then
            return
        end
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")

    if not animator then
        animator = humanoid:WaitForChild("Animator", 5)

        if not animator then
            return
        end
    end

    humanoid.ChildAdded:Connect(function(child)
        if child:IsA("Animator") then
            trackedAnimators[character] = nil
            trackKillerAnimations(character)
        end
    end)

    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            trackedAnimators[character] = nil
        end
    end)

    animator.AnimationPlayed:Connect(function(animationTrack)
        local animationId = (animationTrack.Animation and animationTrack.Animation.AnimationId or ""):match("%d+")
        local animationName = animationNameById[animationId]

        if not animationName then
            return
        end

        if animationId == "80411309607666" and SurvivorSettings.Surv_AutoCrouch then
            local localCharacter = localPlayer.Character

            if isKnockedOrHooked(localCharacter) then
                return
            end

            return
        end

        if not SurvivorSettings.Surv_AutoParry then
            return
        end

        if runtimeState.ParryCooldown then
            return
        end

        if SurvivorSettings.Ignored_Skills_List and SurvivorSettings.Ignored_Skills_List[animationName] then
            return
        end

        local localCharacter = localPlayer.Character

        if isKnockedOrHooked(localCharacter) or not canParry(localCharacter) then
            return
        end

        local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        local killerRoot = character:FindFirstChild("HumanoidRootPart")

        if not localRoot or not killerRoot then
            return
        end

        local distance = (localRoot.Position - killerRoot.Position).Magnitude

        if SurvivorSettings.Surv_ParryAggressive then
            if distance > SurvivorSettings.Surv_ParryRadius + 5 then
                return
            end

            if distance <= 12 then
            else
                local startTime = os.clock()

                local heartbeatConn
                heartbeatConn = runService.Heartbeat:Connect(function()
                    if os.clock() - startTime >= 1.5 or runtimeState.ParryCooldown
                        or not localRoot or not killerRoot or isKnockedOrHooked(localCharacter) then
                        if heartbeatConn then
                            heartbeatConn:Disconnect()
                        end

                        return
                    end

                    if (localRoot.Position - killerRoot.Position).Magnitude <= 12 then
                        if heartbeatConn then
                            heartbeatConn:Disconnect()
                        end
                    end
                end)
            end
        else
            if distance > SurvivorSettings.Surv_ParryRadius then
                return
            end

            local flatOffset = Vector3.new(localRoot.Position.X, 0, localRoot.Position.Z)
                - Vector3.new(killerRoot.Position.X, 0, killerRoot.Position.Z)

            if flatOffset.Magnitude > 0 then
                local unitOffset = flatOffset.Unit

                local killerLookFlat = Vector3.new(
                    killerRoot.CFrame.LookVector.X, 0, killerRoot.CFrame.LookVector.Z
                ).Unit

                if killerLookFlat:Dot(unitOffset) < SurvivorSettings.Surv_ParryFace then
                    return
                end
            end
        end
    end)
end

local function tryTrackKiller(player)
    if player ~= localPlayer and isKillerPlayer(player) and player.Character then
        trackKillerAnimations(player.Character)
    end
end

local function setupPlayerTracking(player)
    if player == localPlayer then
        return
    end

    player.CharacterAdded:Connect(function() tryTrackKiller(player) end)
    player:GetPropertyChangedSignal("Team"):Connect(function() tryTrackKiller(player) end)

    if player.Character then
        tryTrackKiller(player)
    end
end

local isPistolAimActive = false
local isVeilAimActive = false
local touchPistolInput = nil

local vdPistolLaser = Instance.new("Part")
vdPistolLaser.Name = "VD_PistolLaser"
vdPistolLaser.Material = Enum.Material.Neon
vdPistolLaser.Color = Color3.fromRGB(255, 0, 0)
vdPistolLaser.CanCollide = false
vdPistolLaser.Anchored = true
vdPistolLaser.CastShadow = false
vdPistolLaser.Size = Vector3.new(0.05, 0.05, 1)

local vdVeilTargetHighlight = Instance.new("Highlight")
vdVeilTargetHighlight.Name = "VD_VeilTarget"
vdVeilTargetHighlight.FillColor = Color3.fromRGB(255, 0, 0)
vdVeilTargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
vdVeilTargetHighlight.FillTransparency = 0.5
vdVeilTargetHighlight.OutlineTransparency = 0

local veilFovCircle = Drawing.new("Circle")
veilFovCircle.Color = Color3.fromRGB(0, 255, 100)
veilFovCircle.Thickness = 1.5
veilFovCircle.Filled = false

local pistolFovCircle = Drawing.new("Circle")
pistolFovCircle.Color = Color3.fromRGB(255, 255, 255)
pistolFovCircle.Thickness = 1.5
pistolFovCircle.Filled = false

local function getAimTargetPart(character)
    if AimSettings.AIM_TargetPart == "Head" then
        return character:FindFirstChild("Head")
    elseif AimSettings.AIM_TargetPart == "Root" or AimSettings.AIM_TargetPart == "HumanoidRootPart" then
        return character:FindFirstChild("HumanoidRootPart")
    else
        return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("HumanoidRootPart")
    end
end

local function findVeilSpearTarget()
    local localCharacter = localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return nil
    end

    local bestScore = AimSettings.Veil_FOV
    local bestPart = nil
    local camera = workspace.CurrentCamera

    local viewportCenter = Vector2.new(
        camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
    )

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Team and player.Team.Name == "Survivors"
            and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local targetPart = getAimTargetPart(character)

            if humanoid and humanoid.Health > 0 and targetPart then
                if (targetPart.Position - localRoot.Position).Magnitude <= AimSettings.SPEAR_MaxDist then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)

                    if onScreen then
                        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude

                        if screenDistance <= bestScore then
                            bestScore = screenDistance
                            bestPart = targetPart
                        end
                    end
                end
            end
        end
    end

    return bestPart
end

local function findPistolTarget()
    local bestScore = AimSettings.Pistol_ShowFOV and AimSettings.Pistol_FOVMode and AimSettings.Pistol_FOV or math.huge
    local bestPart = nil
    local localCharacter = localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return nil
    end

    if AimSettings.Pistol_BlockKnocked and isKnockedOrHooked(localCharacter) then
        return nil
    end

    local camera = workspace.CurrentCamera

    local viewportCenter = Vector2.new(
        camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
    )

    if AimSettings.Pistol_Target == "SCP" then
        for _, scpModel in ipairs(worldCache.SCPs) do
            if scpModel and scpModel.Parent then
                local humanoid = scpModel:FindFirstChildOfClass("Humanoid")

                local targetPart = scpModel:FindFirstChild("HumanoidRootPart")
                    or scpModel:FindFirstChild("Torso") or scpModel:FindFirstChild("Head")
                    or scpModel.PrimaryPart

                if humanoid and targetPart and humanoid.Health > 0
                    and math.floor(humanoid.WalkSpeed) == 9 then
                    local screenPos, onScreen = currentCamera:WorldToViewportPoint(targetPart.Position)

                    if onScreen or not AimSettings.Pistol_FOVMode then
                        local score = AimSettings.Pistol_FOVMode
                                and (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                            or (targetPart.Position - localRoot.Position).Magnitude

                        if score < bestScore then
                            bestScore = score
                            bestPart = targetPart
                        end
                    end
                end
            end
        end
    else
        for _, player in ipairs(players:GetPlayers()) do
            if player ~= localPlayer and player.Character then
                local isCandidate = false

                if AimSettings.Pistol_Target == "Killer" and isKillerPlayer(player) then
                    isCandidate = true
                elseif AimSettings.Pistol_Target == "Survivor" and not isKillerPlayer(player) then
                    isCandidate = true
                end

                if isCandidate then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

                    if humanoid and humanoid.Health > 0 and not isKnockedOrHooked(player.Character) then
                        local targetPart = getAimTargetPart(player.Character)

                        if targetPart then
                            local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                            local mouseLocation = userInputService:GetMouseLocation()

                            if onScreen or not AimSettings.Pistol_FOVMode then
                                local score = AimSettings.Pistol_FOVMode
                                        and (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
                                    or (targetPart.Position - localRoot.Position).Magnitude

                                if score < bestScore then
                                    local passedWallCheck = true

                                    if AimSettings.WallCheck then
                                        local smartLogic = getgenv().VD_SmartLogic

                                        if smartLogic and smartLogic.WallCheck then
                                            passedWallCheck = smartLogic.WallCheck(targetPart)
                                        end
                                    end

                                    if passedWallCheck then
                                        bestScore = score
                                        bestPart = targetPart
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPart
end

local function firePistolSilentAim()
    local target = findPistolTarget()
    local localCharacter = localPlayer.Character

    if AimSettings.Pistol_BlockKnocked and isKnockedOrHooked(localCharacter) then
        return
    end

    if target and localCharacter then
        if not localCharacter:FindFirstChildOfClass("Humanoid") then
            return
        end

        local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")

        if localRoot then
            local twistOfFate = localCharacter:FindFirstChild("Twist of Fate")

            if twistOfFate then
                local gunInstance = twistOfFate
                local rightArm = twistOfFate:FindFirstChild("Right Arm")

                if rightArm then
                    if rightArm:FindFirstChild("EmperorGun") then
                        gunInstance = rightArm:FindFirstChild("EmperorGun")
                    elseif rightArm:FindFirstChild("gun") then
                        gunInstance = rightArm:FindFirstChild("gun")
                    else
                        gunInstance = rightArm
                    end
                end

                local targetPosition = target.Position
                local localPosition = localRoot.Position
                local targetVelocity = target.AssemblyLinearVelocity

                targetVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)

                local distance = (targetPosition - localPosition).Magnitude

                if distance < 4 then
                    targetPosition = targetPosition + target.CFrame.RightVector * 2
                end

                local fireDirection = (targetPosition + targetVelocity * (distance / 400)
                        + Vector3.new(0, -2, 0)
                    - localPosition).Unit

                local remotes = replicatedStorage:FindFirstChild("Remotes")

                if remotes and remotes:FindFirstChild("Items")
                    and remotes.Items:FindFirstChild("Twist of Fate")
                    and remotes.Items["Twist of Fate"]:FindFirstChild("Fire") then
                    remotes.Items["Twist of Fate"].Fire:FireServer(gunInstance, fireDirection)
                end
            end
        end
    end
end

local isSpearInterceptorHooked = false

local function hookSpearInterceptor()
    if isSpearInterceptorHooked then
        return
    end

    if not getrawmetatable or not setreadonly then
        warn("[SpearInterceptor]: Executor does not support getrawmetatable or setreadonly.")
        return
    end

    local metatable = getrawmetatable(game)
    setreadonly(metatable, false)
    local originalNamecall = metatable.__namecall

    metatable.__namecall = newcclosure(function(self, ...)
        if getnamecallmethod() == "FireServer" and not checkcaller() then
            if typeof(self) == "Instance" and self.ClassName == "RemoteEvent"
                and self.Name == "Spearthrow" and AimSettings.Aim_SilentVeil then
                return nil
            end
        end

        return originalNamecall(self, ...)
    end)

    setreadonly(metatable, true)
    isSpearInterceptorHooked = true
end

hookSpearInterceptor()

local function collectGates()
    local gates = {}
    local map = workspace:FindFirstChild("Map")

    if not map then
        warn("Map not found")
        return gates
    end

    for _, descendant in pairs(map:GetDescendants()) do
        if descendant.Name == "Gate" then
            table.insert(gates, descendant)
        end
    end

    return gates
end

local function setGateBypass(isEnabled)
    getgenv().GateBypassActive = isEnabled

    for _, gate in pairs(collectGates()) do
        local leftGate = gate:FindFirstChild("LeftGate")
        local rightGate = gate:FindFirstChild("RightGate")

        local leftGateEnd = gate:FindFirstChild("LeftGate-end")
            or gate:FindFirstChild("LeftGate-end2")

        local rightGateEnd = gate:FindFirstChild("RightGate-end")
            or gate:FindFirstChild("RightGate-end2")

        local box = gate:FindFirstChild("Box")

        if isEnabled then
            if leftGate then
                leftGate.Transparency = 1
                leftGate.CanCollide = false
            end

            if rightGate then
                rightGate.Transparency = 1
                rightGate.CanCollide = false
            end

            if leftGateEnd then
                leftGateEnd.Transparency = 0
            end

            if rightGateEnd then
                rightGateEnd.Transparency = 0
            end

            if box then
                box.CanCollide = false
            end
        else
            if leftGate then
                leftGate.Transparency = 0
                leftGate.CanCollide = true
            end

            if rightGate then
                rightGate.Transparency = 0
                rightGate.CanCollide = true
            end

            if leftGateEnd then
                leftGateEnd.Transparency = 1
            end

            if rightGateEnd then
                rightGateEnd.Transparency = 1
            end

            if box then
                box.CanCollide = true
            end
        end
    end
end

local function findNearestKiller()
    local localRoot = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return nil, math.huge
    end

    local nearestKiller = nil
    local nearestDistance = math.huge

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Team and player.Team.Name == "Killer"
            and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - localRoot.Position).Magnitude

            if distance < nearestDistance then
                nearestDistance = distance
                nearestKiller = player
            end
        end
    end

    return nearestKiller, nearestDistance
end

local function fleeFromKiller()
    if not isFleeKillerEnabled then
        return
    end

    local localRoot = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local nearestKiller, distance = findNearestKiller()

    if not nearestKiller or distance > fleeDistance then
        return
    end

    if tick() - lastFleeTeleportTime < 3 then
        return
    end

    local killerRoot = nearestKiller.Character and nearestKiller.Character:FindFirstChild("HumanoidRootPart")

    if not killerRoot then
        return
    end

    local escapeDirection = (localRoot.Position - killerRoot.Position).Unit
    local escapePosition = localRoot.Position + escapeDirection * 80
    localRoot.CFrame = CFrame.new(escapePosition)
    lastFleeTeleportTime = tick()
end

local function enableInfiniteLunge()
    isLungeBoostEnabled = true
    local character = localPlayer.Character

    if character then
        character:SetAttribute("lungeboost", 999)
    end

    Library:Notify({ Title = "Infinite Lunge", Description = "ACTIVE 999x", Time = 3 })
end

local function disableInfiniteLunge()
    isLungeBoostEnabled = false
    local character = localPlayer.Character

    if character then
        character:SetAttribute("lungeboost", 1)
    end

    Library:Notify({ Title = "Infinite Lunge", Description = "❌ Disabled", Time = 3 })
end

task.spawn(function()
    while true do
        task.wait(0.4)

        if isLungeBoostEnabled then
            local character = localPlayer.Character

            if character and character:GetAttribute("lungeboost") ~= 999 then
                character:SetAttribute("lungeboost", 999)
            end
        end
    end
end)

localPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.8)

    if isLungeBoostEnabled and character then
        character:SetAttribute("lungeboost", 999)
    end
end)

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YantoRoblox/ObsidianHUB/main/Library.lua"))()
local themeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/YantoRoblox/ObsidianHUB/main/addons/ThemeManager.lua"))()
local saveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/YantoRoblox/ObsidianHUB/main/addons/SaveManager.lua"))()
local options = library.Options

library.ForceCheckbox = false
library.ShowToggleFrameInKeybinds = true

local songHubWindow = library:CreateWindow({
    Title = "Song Hub",
    Footer = "THIS SCRIPT IS FREE DO NOT SELL | Song Hub",
    Icon = "78025331847712",
    IconSize = UDim2.fromOffset(50, 50),
    NotifySide = "Right",
    EnableSidebarResize = true,
    EnableCompacting = true,
    SidebarCompacted = true,
    Size = UDim2.fromOffset(450, 1000),
    CornerRadius = 10,
    AutoShow = true,
})

local homeTab = songHubWindow:AddTab("Home", "house")

local tabs = {
    Player = songHubWindow:AddTab("Player", "user"),
    Survivor = songHubWindow:AddTab("Survivor", "users"),
    Killer = songHubWindow:AddTab("Killer", "swords"),
    Esp = songHubWindow:AddTab("ESP", "eye"),
    Teleport = songHubWindow:AddTab("Teleport", "map-pin"),
    ["UI Settings"] = songHubWindow:AddTab("Misc", "zap"),
    AFK = songHubWindow:AddTab("Auto Farm", "settings"),
}

local infoGroupbox = homeTab:AddLeftGroupbox("Important Information", "info")
infoGroupbox:AddLabel({ Text = "👋 Hello Song Hub Member!", DoesWrap = true })

infoGroupbox:AddLabel({
    Text = "Thank you for using this FREE script. Join our Discord to get the latest updates!",
    DoesWrap = true,
})

infoGroupbox:AddDivider()
infoGroupbox:AddLabel({ Text = "🔗 Important Links:", DoesWrap = true })

infoGroupbox:AddButton({
    Text = "📱 Join Discord",
    Func = function()
        setclipboard("https://discord.gg/s2rnnmWa38")
        library:Notify({ Title = "Link Discord", Description = "Link copied!", Time = 3 })
    end,
})

infoGroupbox:AddButton({
    Text = "🎵 Follow TikTok",
    Func = function()
        setclipboard("https://www.tiktok.com/@michellyjowzero_")
        library:Notify({ Title = "Link TikTok", Description = "Link copied!", Time = 3 })
    end,
})

infoGroupbox:AddDivider()

infoGroupbox:AddLabel({
    Text = "💡 Support us by following TikTok and sharing with your friends!",
    DoesWrap = true,
})

infoGroupbox:AddDivider()

local guideGroupbox = homeTab:AddRightGroupbox("UI & Keybind Guide", "book")
guideGroupbox:AddLabel({ Text = "📖 How To Change UI Toggle Keybind", DoesWrap = true })

guideGroupbox:AddLabel({
    Text = [[
1. Click the keybind text below
2. Press the key you want
3. The keybind changes instantly]],
    DoesWrap = true,
})

guideGroupbox:AddDivider()

guideGroupbox:AddLabel("UI keybind:"):AddKeyPicker("ToggleKeybindPicker", {
    Text = "Keybind",
    Default = "RightControl",
    Mode = "Toggle",
    SyncToggleState = false,
    ChangedCallback = function(toggleKeybind) library.ToggleKeybind = toggleKeybind end,
})

guideGroupbox:AddDivider()

guideGroupbox:AddLabel({
    Text = "⚡ Tips: You can use F1, F2, Left Ctrl, or anything else!",
    DoesWrap = true,
})

getgenv().WalkSpeedValue = 16
getgenv().VaultSpeedValue = 1
getgenv().SpeedEnabled = false

task.spawn(function()
    runService.Heartbeat:Connect(function(delta)
        local character = game.Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if getgenv().SpeedEnabled and character and humanoid and humanoid.Health > 0 then
            if humanoid.MoveDirection.Magnitude > 0 then
                character:TranslateBy(humanoid.MoveDirection
                    * (getgenv().WalkSpeedValue - humanoid.WalkSpeed) * delta)
            end

            if character:GetAttribute("vaultspeed") ~= nil then
                character:SetAttribute("vaultspeed", getgenv().VaultSpeedValue)
            end
        end
    end)
end)

local playerSettingsGroupbox = tabs.Player:AddLeftGroupbox("Player Settings", "shield")

playerSettingsGroupbox:AddToggle("SpeedPlayerToggle", {
    Text = "Enable Speed & Vault",
    Default = false,
    Callback = function(value)
        getgenv().SpeedEnabled = value

        if not value then
            pcall(function()
                local character = game.Players.LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if humanoid then
                    humanoid.WalkSpeed = 16
                end

                if character then
                    character:SetAttribute("vaultspeed", 1)
                end
            end)
        end
    end,
})

playerSettingsGroupbox:AddSlider("SpeedPlayerSlider", {
    Text = "Speed Player",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(value) getgenv().WalkSpeedValue = value end,
})

playerSettingsGroupbox:AddSlider("VaultSpeedSlider", {
    Text = "Vault Speed Pallet/Window",
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(value) getgenv().VaultSpeedValue = value end,
})

local genBoostGroupbox = tabs.Player:AddLeftGroupbox("Gen Boost OP", "zap")

genBoostGroupbox:AddToggle("GenBoostToggle", {
    Text = "Gen Boost Multi-Repair",
    Default = false,
    Callback = function(value) end,
})

genBoostGroupbox:AddLabel("Status: Ready")

local survivorGroupbox = tabs.Survivor:AddLeftGroupbox("Survivor", "users")

survivorGroupbox:AddToggle("AutoSkillCheck", {
    Text = "Auto Generator Perfect",
    Default = false,
    Callback = function(value) isAutoGeneratorEnabled = value end,
}):AddKeyPicker("AutoGeneratorKey", {
    Default = "None",
    Text = "Auto Generator Key",
    Mode = "Toggle",
    Callback = function(value) isAutoGeneratorEnabled = value end,
})

survivorGroupbox:AddToggle("Surv_AutoCrouch", {
    Text = "Dodge Skill S1",
    Tooltip = "Automatically crouches when Abyssal uses S1",
    Default = false,
    Callback = function(value) SurvivorSettings.Surv_AutoCrouch = value end,
})

survivorGroupbox:AddSlider("SkillFrequency", {
    Text = "Skill Check Rate",
    Tooltip = "Adjust how often skill checks appear",
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(value) end,
})

survivorGroupbox:AddSlider("SkillSpeed", {
    Text = "Skill Check Velocity",
    Tooltip = "Adjust skill check rotation speed, 1-30, 10 is Normal",
    Default = 10,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(value) end,
})

survivorGroupbox:AddToggle("BypassGate", {
    Text = "Instant Pass Gate",
    Tooltip = "Pass through gates without collision",
    Default = false,
    Callback = function(value)
        setGateBypass(value)

        if value then
            library:Notify({
                Title = "Instant Pass Gate",
                Description = "Gate bypass enabled!",
                Time = 3,
            })
        else
            library:Notify({
                Title = "Instant Pass Gate",
                Description = "Gate bypass disabled!",
                Time = 3,
            })
        end
    end,
})

survivorGroupbox:AddToggle("AutoHeal", {
    Text = "Auto Self Heal",
    Tooltip = "Automatically heals yourself",
    Default = false,
    Callback = function(value)
        isAutoHealEnabled = value

        if value then
            library:Notify({ Title = "Auto Self Heal", Description = "ENABLED!", Time = 2 })
        else
            library:Notify({ Title = "Auto Self Heal", Description = "DISABLED", Time = 2 })
        end
    end,
}):AddKeyPicker("AutoHealKey", {
    Default = "None",
    Text = "Auto Heal Key",
    Mode = "Toggle",
    Callback = function(value) isAutoHealEnabled = value end,
})

survivorGroupbox:AddToggle("NoSlowdownSurvivor", {
    Text = "No Slowdown Movement",
    Tooltip = "Prevents slowdown when hit by effects, Survivor Only",
    Default = false,
    Callback = function(value)
        isSurvivorNoSlowdownEnabled = value

        if value then
            library:Notify({
                Title = "No Slowdown",
                Description = "✅ Enabled for Survivor!",
                Time = 3,
            })
        else
            library:Notify({ Title = "No Slowdown", Description = "❌ Disabled", Time = 2 })
        end
    end,
}):AddKeyPicker("NoSlowdownSurvivorKey", {
    Default = "None",
    Text = "No Slowdown Key",
    Mode = "Toggle",
    Callback = function(value) isSurvivorNoSlowdownEnabled = value end,
})

survivorGroupbox:AddToggle("AutoWiggle", {
    Text = "Fast Escape Carry",
    Tooltip = "Escape the killer carry faster",
    Default = false,
    Callback = function(value) isAutoWiggleEnabled = value end,
})

survivorGroupbox:AddToggle("FleeKiller", {
    Text = "Safe Evade Auto",
    Tooltip = "Teleports when the killer is too close",
    Default = false,
    Callback = function(value) isFleeKillerEnabled = value end,
})

survivorGroupbox:AddSlider("FleeDistance", {
    Text = "Evade Distance",
    Tooltip = "Teleport trigger distance",
    Default = 40,
    Min = 15,
    Max = 80,
    Rounding = 0,
    Callback = function(value) fleeDistance = value end,
})

survivorGroupbox:AddDivider()

survivorGroupbox:AddToggle("AutoParry", {
    Text = "Smart Auto Parry",
    Default = false,
    Callback = function(value) SurvivorSettings.Surv_AutoParry = value end,
}):AddKeyPicker("AutoParryKey", {
    Default = "None",
    Text = "Auto Parry Key",
    Mode = "Toggle",
    Callback = function(value) SurvivorSettings.Surv_AutoParry = value end,
})

survivorGroupbox:AddCheckbox("Surv_ParrySafety", {
    Text = "Safety Parry",
    Default = false,
    Callback = function(value) SurvivorSettings.Surv_ParrySafety = value end,
})

survivorGroupbox:AddToggle("ParryAggressive", {
    Text = "Aggressive Mode",
    Tooltip = "Parries immediately regardless of face direction",
    Default = false,
    Callback = function(value) SurvivorSettings.Surv_ParryAggressive = value end,
})

survivorGroupbox:AddToggle("ParryCircle", {
    Text = "ESP Range Circle",
    Tooltip = "Shows the parry radius on your character",
    Default = true,
    Callback = function(value) SurvivorSettings.Surv_ParryCircle = value end,
})

survivorGroupbox:AddSlider("ParryRadius", {
    Text = "Parry Radius",
    Tooltip = "Maximum distance the parry reacts",
    Default = 15,
    Min = 5,
    Max = 25,
    Rounding = 0,
    Callback = function(value) SurvivorSettings.Surv_ParryRadius = value end,
})

survivorGroupbox:AddSlider("ParryFace", {
    Text = "Face Sensitivity",
    Tooltip = "Facing direction sensitivity, 1-10",
    Default = 7,
    Min = -10,
    Max = 10,
    Rounding = 0,
    Callback = function(value) SurvivorSettings.Surv_ParryFace = value / 10 end,
})

survivorGroupbox:AddDropdown("IgnoreSkills", {
    Values = { "Hidden S1", "Abyssal S1" },
    Default = {},
    Multi = true,
    Text = "Ignore specific skills",
    Tooltip = "Ignore specific skills",
    Callback = function(value)
        local ignored = {}

        for key, entry in pairs(value) do
            if type(key) == "string" and entry then
                ignored[key] = true
            elseif type(entry) == "string" then
                ignored[entry] = true
            end
        end

        SurvivorSettings.Ignored_Skills_List = ignored
    end,
})

survivorGroupbox:AddDivider()

local silentAimGroupbox = tabs.Survivor:AddRightGroupbox("Silent Aim Pistol", "crosshair")

silentAimGroupbox:AddToggle("SilentAim", {
    Text = "Silent Aim Pistol",
    Default = false,
    Callback = function(value) AimSettings.Aim_Silent = value end,
}):AddKeyPicker("SilentAimKey", {
    Default = "None",
    Text = "Silent Aim Key",
    Mode = "Toggle",
    Callback = function(value) AimSettings.Aim_Silent = value end,
})

silentAimGroupbox:AddCheckbox("Pistol_BlockKnocked", {
    Text = "OF Block aim Knocked",
    Default = false,
    Callback = function(value) AimSettings.Pistol_BlockKnocked = value end,
})

silentAimGroupbox:AddToggle("WallCheckToggle", {
    Text = "Wallcheck Anti Lock Wall",
    Default = false,
    Callback = function(value)
        AimSettings.WallCheck = value
    end,
})

silentAimGroupbox:AddToggle("FlashAim", {
    Text = "Silent Aim Flash",
    Default = false,
    Callback = function(value) AimSettings.Flash_Silent = value end,
}):AddKeyPicker("SilentFlashKey", {
    Default = "None",
    Text = "Silent Aim Key",
    Mode = "Toggle",
    Callback = function(value) AimSettings.Flash_Silent = value end,
})

silentAimGroupbox:AddSlider("FlashAimOffset", {
    Text = "Flash Head Offset Y",
    Tooltip = "Adjust aim position, 0 is Body, 1.5 is Head, 8 is Above Head",
    Default = 8,
    Min = 1,
    Max = 15,
    Rounding = 1,
    Callback = function(value) AimSettings.Flash_YOffset = value end,
})

silentAimGroupbox:AddToggle("LockAim", {
    Text = "Lock Aim Pistol",
    Tooltip = "Lock aim for Pistol items",
    Default = false,
    Callback = function(value) AimSettings.LockAim = value end,
})

silentAimGroupbox:AddToggle("HideSilentLaser", {
    Text = "Hide Silent Laser",
    Tooltip = "Hide the red silent aim laser",
    Default = false,
    Callback = function(value)
        hideSilentLaser = value

        if value and vdPistolLaser then
            vdPistolLaser.Transparency = 1
        elseif vdPistolLaser then
            vdPistolLaser.Transparency = 0
        end
    end,
})

silentAimGroupbox:AddButton({
    Text = "Killer K",
    Func = function()
        AimSettings.Pistol_Target = "Killer"
        library:Notify("Target: Killer", 1)
    end,
})

silentAimGroupbox:AddButton({
    Text = "Survivor J",
    Func = function()
        AimSettings.Pistol_Target = "Survivor"
        library:Notify("Target: Survivor", 1)
    end,
})

silentAimGroupbox:AddButton({
    Text = "SCP L",
    Func = function()
        AimSettings.Pistol_Target = "SCP"
        library:Notify("Target: SCP", 1)
    end,
})

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.K then
        AimSettings.Pistol_Target = "Killer"
        library:Notify("Target: Killer", 1)
    elseif input.KeyCode == Enum.KeyCode.J then
        AimSettings.Pistol_Target = "Survivor"
        library:Notify("Target: Survivor", 1)
    elseif input.KeyCode == Enum.KeyCode.L then
        AimSettings.Pistol_Target = "SCP"
        library:Notify("Target: SCP", 1)
    end
end)

silentAimGroupbox:AddToggle("PistolFOVMode", {
    Text = "Pistol FOV Mode",
    Default = false,
    Callback = function(value) AimSettings.Pistol_FOVMode = value end,
})

silentAimGroupbox:AddToggle("PistolShowFOV", {
    Text = "Show Pistol FOV",
    Default = false,
    Callback = function(value) AimSettings.Pistol_ShowFOV = value end,
})

silentAimGroupbox:AddSlider("PistolFOV", {
    Text = "Pistol FOV Radius",
    Default = 150,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) AimSettings.Pistol_FOV = value end,
})

silentAimGroupbox:AddDropdown("AimTargetPart", {
    Values = { "Head", "Torso", "Root", "HumanoidRootPart" },
    Default = "Torso",
    Text = "Target Part",
    Callback = function(value) AimSettings.AIM_TargetPart = value end,
})

local survivorAimbotGroupbox = tabs.Survivor:AddRightGroupbox("Aimbot Survivor", "target")

survivorAimbotGroupbox:AddToggle("Surv_Aimbot_Enabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(value) SurvivorSettings.Surv_Aimbot_Enabled = value end,
})

survivorAimbotGroupbox:AddCheckbox("Surv_Aimbot_ShowFOV", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(value) SurvivorSettings.Surv_Aimbot_ShowFOV = value end,
})

survivorAimbotGroupbox:AddSlider("Surv_Aimbot_Radius", {
    Text = "FOV Circle Radius",
    Min = 50,
    Max = 500,
    Default = 150,
    Rounding = 0,
    Callback = function(value) SurvivorSettings.Surv_Aimbot_Radius = value end,
})

survivorAimbotGroupbox:AddSlider("Surv_Aimbot_MaxDist", {
    Text = "Max Distance",
    Min = 50,
    Max = 1000,
    Default = 300,
    Rounding = 0,
    Callback = function(value) SurvivorSettings.Surv_Aimbot_MaxDist = value end,
})

survivorAimbotGroupbox:AddSlider("Surv_Aimbot_Smoothness", {
    Text = "Aimbot Smoothness",
    Min = 1,
    Max = 10,
    Default = 5,
    Rounding = 1,
    Callback = function(value) SurvivorSettings.Surv_Aimbot_Smoothness = value / 10 end,
})

survivorAimbotGroupbox:AddInput("Surv_Aimbot_Predict", {
    Text = "Predict Aim Offset",
    Default = "0.01",
    Numeric = true,
    Placeholder = "e.g. 0.05",
    Callback = function(value)
        local numericValue = tonumber(value)

        if numericValue then
            SurvivorSettings.Surv_Aimbot_Predict = numericValue
        end
    end,
})

local cameraSettingsGroupbox = tabs.Survivor:AddRightGroupbox("Camera Settings", "camera")

cameraSettingsGroupbox:AddToggle("InfinityZoom", {
    Text = "Infinity Zoom Out",
    Tooltip = "Unlimited zoom out",
    Default = false,
    Callback = function(value)
        if value then
            localPlayer.CameraMaxZoomDistance = math.huge
            localPlayer.CameraMinZoomDistance = 0
        else
            localPlayer.CameraMaxZoomDistance = 12
            localPlayer.CameraMinZoomDistance = 0.5
        end
    end,
})

local isCameraFovEnabled = false
local cameraFovValue = 90

local function tweenCameraFov(fieldOfView)
    if not currentCamera then
        return
    end

    tweenService:Create(
        currentCamera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { FieldOfView = fieldOfView }
    ):Play()
end

cameraSettingsGroupbox:AddToggle("CameraFOV", {
    Text = "Camera FOV",
    Tooltip = "Adjust camera view distance",
    Default = false,
    Callback = function(value)
        isCameraFovEnabled = value

        if value then
            tweenCameraFov(value)
        else
            tweenCameraFov(70)
        end
    end,
})

cameraSettingsGroupbox:AddSlider("FOVValue", {
    Text = "FOV Value",
    Default = 90,
    Min = 60,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        cameraFovValue = value

        if isCameraFovEnabled and currentCamera then
            currentCamera.FieldOfView = value
        end
    end,
})

local killerGroupbox = tabs.Killer:AddLeftGroupbox("Killer", "swords")

killerGroupbox:AddToggle("Killer_Aimbot_Enabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(value) SurvivorSettings.Killer_Aimbot_Enabled = value end,
})

killerGroupbox:AddSlider("Killer_Aimbot_MaxDist", {
    Text = "Melee Lock Distance",
    Min = 5,
    Max = 30,
    Default = 12,
    Rounding = 0,
    Callback = function(value) SurvivorSettings.Killer_Aimbot_MaxDist = value end,
})

killerGroupbox:AddSlider("Killer_Aimbot_Smoothness", {
    Text = "Aimbot Smoothness",
    Min = 1,
    Max = 10,
    Default = 5,
    Rounding = 1,
    Callback = function(value) SurvivorSettings.Killer_Aimbot_Smoothness = value / 10 end,
})

killerGroupbox:AddToggle("AutoAttack", {
    Text = "Auto Attack",
    Tooltip = "Automatically hits nearby survivors",
    Default = false,
    Callback = function(value) getgenv().KillerAutoAttackEnabled = value end,
})

killerGroupbox:AddToggle("NoSlowdown", {
    Text = "No Slowdown killer",
    Tooltip = "Removes slowdown while attacking, Killer Only",
    Default = false,
    Callback = function(value)
        isKillerNoSlowdownEnabled = value

        if value then
            library:Notify({
                Title = "No Slowdown",
                Description = "✅ ENABLED - WalkSpeed locked",
                Time = 3,
            })
        else
            library:Notify({ Title = "No Slowdown", Description = "❌ DISABLED", Time = 2 })
        end
    end,
}):AddKeyPicker("NoSlowdownKey", {
    Default = "None",
    Text = "No Slowdown Keybind",
    Mode = "Toggle",
    Callback = function(value) isKillerNoSlowdownEnabled = value end,
})

killerGroupbox:AddToggle("InfiniteLunge", {
    Text = "Infinite Lunge",
    Tooltip = "Unlimited lunge, Killer Only",
    Default = false,
    Callback = function(value)
        if value then
            enableInfiniteLunge()
        else
            disableInfiniteLunge()
        end
    end,
}):AddKeyPicker("InfiniteLungeKey", {
    Default = "F9",
    Text = "Infinite Lunge Key",
    Mode = "Toggle",
    Callback = function(value)
        if value then
            enableInfiniteLunge()
        else
            disableInfiniteLunge()
        end
    end,
})

killerGroupbox:AddToggle("Killer_InfAbyssal", {
    Text = "Infinite corrupt Abyssal",
    Default = false,
    Callback = function(value) SurvivorSettings.Killer_InfAbyssal = value end,
})

local veilSpearGroupbox = tabs.Killer:AddRightGroupbox("Silent Aim Veil Spear", "arrow-right")

veilSpearGroupbox:AddToggle("SilentAimVeil", {
    Text = "Silent Aim Veil Spear",
    Default = false,
    Callback = function(value) AimSettings.Aim_SilentVeil = value end,
}):AddKeyPicker("SilentAimVeilKey", {
    Default = "None",
    Text = "Veil Aim Key",
    Mode = "Toggle",
    Callback = function(value) AimSettings.Aim_SilentVeil = value end,
})

veilSpearGroupbox:AddSlider("Veil_SpearSpeed", {
    Text = "Spear Speed",
    Min = 50,
    Max = 200,
    Default = 165,
    Rounding = 0,
    Callback = function(value) AimSettings.SPEAR_Speed = value end,
})

veilSpearGroupbox:AddSlider("Veil_SpearGravity", {
    Text = "Spear Gravity",
    Min = 0,
    Max = 200,
    Default = 103,
    Rounding = 0,
    Callback = function(value) AimSettings.SPEAR_Gravity = value end,
})

local isVeilTrackerEnabled = false

local veilTrackerLine = Drawing.new("Line")
veilTrackerLine.Visible = false
veilTrackerLine.Thickness = 2
veilTrackerLine.Color = Color3.fromRGB(255, 0, 0)

local veilTrackerCircle = Drawing.new("Circle")
veilTrackerCircle.Visible = false
veilTrackerCircle.Thickness = 2
veilTrackerCircle.Filled = false
veilTrackerCircle.Radius = 40
veilTrackerCircle.Color = Color3.fromRGB(255, 0, 0)

veilSpearGroupbox:AddToggle("VeilTracker", {
    Text = "ESP Tracker Target",
    Default = false,
    Callback = function(value)
        isVeilTrackerEnabled = value

        if not value then
            veilTrackerLine.Visible = false
            veilTrackerCircle.Visible = false
        end
    end,
})

veilSpearGroupbox:AddToggle("SilentAimPredict", {
    Text = "Auto Predict",
    Tooltip = "Auto predict spear for Veil",
    Default = false,
    Callback = function(value) AimSettings.AIM_Auto = value end,
})

veilSpearGroupbox:AddToggle("VeilShowFOV", {
    Text = "Show Veil FOV",
    Default = true,
    Callback = function(value) AimSettings.Veil_ShowFOV = value end,
})

veilSpearGroupbox:AddSlider("VeilFOV", {
    Text = "Veil FOV Radius",
    Default = 150,
    Min = 50,
    Max = 400,
    Rounding = 0,
    Callback = function(value) AimSettings.Veil_FOV = value end,
})

tabs.Killer:AddRightGroupbox("Camera Setting", "camera"):AddToggle("KillerThirdPerson", {
    Text = "Third Person Killer",
    Tooltip = "Moves the camera behind the character",
    Default = false,
    Callback = function(value)
        local isKiller = localPlayer.Team and localPlayer.Team.Name == "Killer"

        if value and not isKiller then
            library:Notify({
                Title = "Access Denied",
                Description = "This feature is Killer only!",
                Time = 3,
            })

            return
        end

        SurvivorSettings.Killer_3rdPerson = value

        if not value then
            if runtimeState.ThirdPersonConn then
                runtimeState.ThirdPersonConn:Disconnect()
                runtimeState.ThirdPersonConn = nil
            end

            if isKiller then
                localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
                localPlayer.CameraMinZoomDistance = 0.5
                localPlayer.CameraMaxZoomDistance = 0.5
            else
                localPlayer.CameraMode = Enum.CameraMode.Classic
                localPlayer.CameraMinZoomDistance = 0.5
                localPlayer.CameraMaxZoomDistance = 128
            end

            for _, cameraChild in pairs(currentCamera:GetChildren()) do
                if cameraChild ~= localPlayer.Character then
                    for _, descendant in pairs(cameraChild:GetDescendants()) do
                        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                            descendant.LocalTransparencyModifier = 0
                            descendant.Transparency = 0
                        end
                    end
                end
            end

            if localPlayer.Character then
                for _, child in pairs(localPlayer.Character:GetChildren()) do
                    if child.Name == "Hat" and child:GetAttribute("loc") == "Head" then
                        for _, descendant in pairs(child:GetDescendants()) do
                            if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                                descendant.LocalTransparencyModifier = 1
                            end
                        end
                    end

                    if child:IsA("BasePart") and armPartNames[child.Name] then
                        child.LocalTransparencyModifier = 1
                    end

                    if isWeaponTool(child) then
                        for _, descendant in pairs(child:IsA("BasePart") and { child }
                            or child:GetDescendants()) do
                            if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                                descendant.LocalTransparencyModifier = 1
                                descendant.Transparency = 1
                            end
                        end
                    end
                end
            end
        else
            localPlayer.CameraMode = Enum.CameraMode.Classic
            localPlayer.CameraMinZoomDistance = 7
            localPlayer.CameraMaxZoomDistance = 128

            runtimeState.ThirdPersonConn = runService.RenderStepped:Connect(function()
                if not SurvivorSettings.Killer_3rdPerson then
                    return
                end

                if localPlayer.Team and localPlayer.Team.Name ~= "Killer" then
                    return
                end

                localPlayer.CameraMode = Enum.CameraMode.Classic
                localPlayer.CameraMinZoomDistance = 7
                localPlayer.CameraMaxZoomDistance = 128

                for _, cameraChild in pairs(currentCamera:GetChildren()) do
                    if cameraChild ~= localPlayer.Character then
                        for _, descendant in pairs(cameraChild:GetDescendants()) do
                            if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                                descendant.LocalTransparencyModifier = 1
                                descendant.Transparency = 1
                            end
                        end
                    end
                end

                if localPlayer.Character then
                    for _, child in pairs(localPlayer.Character:GetChildren()) do
                        if child.Name == "Hat" then
                            for _, descendant in pairs(child:GetDescendants()) do
                                if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                                    descendant.LocalTransparencyModifier = 0
                                    descendant.Transparency = 0
                                end
                            end
                        end

                        if child:IsA("BasePart") and armPartNames[child.Name] then
                            child.LocalTransparencyModifier = 0
                            child.Transparency = 0
                        end

                        if isWeaponTool(child) then
                            for _, descendant in pairs(child:IsA("BasePart") and { child }
                                or child:GetDescendants()) do
                                if descendant:IsA("BasePart") or descendant:IsA("Decal") then
                                    descendant.LocalTransparencyModifier = 0
                                    descendant.Transparency = 0
                                end
                            end
                        end
                    end
                end
            end)
        end
    end,
})

local isSpectatorCounterActive = false
local isNextKillerActive = false
local isNextMapNotifActive = false
local spectatorCounterGui = nil
local spectatorCountLabel = nil
local nextKillerNotifGui = nil
local nextMapNotifGui = nil
local lastNotifiedKillerName = nil
local lastNotifiedKillerSelection = nil
local isNextMapListenerSetup = false
local spectatorCounterThread = nil
local nextKillerThread = nil

local function createSpectatorCounterGui()
    if spectatorCounterGui then
        spectatorCounterGui:Destroy()
    end

    spectatorCounterGui = Instance.new("ScreenGui")
    spectatorCounterGui.Name = "SpectatorCounter"
    spectatorCounterGui.ResetOnSpawn = false
    spectatorCounterGui.Parent = localPlayer:WaitForChild("PlayerGui")

    local mainBox = Instance.new("Frame")
    mainBox.Name = "MainBox"
    mainBox.AnchorPoint = Vector2.new(0.5, 0)
    mainBox.Position = UDim2.new(0.5, 0, 0.005, 0)
    mainBox.Size = UDim2.new(0, 80, 0, 28)
    mainBox.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    mainBox.BackgroundTransparency = 0.2
    mainBox.Parent = spectatorCounterGui

    Instance.new("UICorner", mainBox).CornerRadius = UDim.new(0, 10)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 8, 0, 4)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://13321848320"
    icon.ImageColor3 = Color3.fromRGB(180, 200, 255)
    icon.Parent = mainBox

    spectatorCountLabel = Instance.new("TextLabel")
    spectatorCountLabel.Size = UDim2.new(0, 30, 1, 0)
    spectatorCountLabel.Position = UDim2.new(0, 32, 0, 0)
    spectatorCountLabel.BackgroundTransparency = 1
    spectatorCountLabel.Font = Enum.Font.GothamBold
    spectatorCountLabel.Text = "0"
    spectatorCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectatorCountLabel.TextSize = 16
    spectatorCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    spectatorCountLabel.Parent = mainBox
end

local function showNextKillerNotification(killerName, killerSelection)
    if nextKillerNotifGui then
        nextKillerNotifGui:Destroy()
    end

    nextKillerNotifGui = Instance.new("ScreenGui")
    nextKillerNotifGui.Name = "NextKillerNotif"
    nextKillerNotifGui.ResetOnSpawn = false
    nextKillerNotifGui.Parent = localPlayer:WaitForChild("PlayerGui")

    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.2, 0)
    container.Size = UDim2.new(0, 240, 0, 36)
    container.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
    container.BackgroundTransparency = 0.1
    container.Parent = nextKillerNotifGui

    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", container)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Transparency = 0.3

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 24, 1, 0)
    icon.Position = UDim2.new(0, 6, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.Text = "⭕"
    icon.TextSize = 18
    icon.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -38, 1, 0)
    label.Position = UDim2.new(0, 34, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = string.format("Next: %s - %s", killerName, killerSelection)
    label.TextColor3 = Color3.fromRGB(255, 100, 100)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    task.spawn(function()
        task.wait(4.5)

        if nextKillerNotifGui then
            nextKillerNotifGui:Destroy()
        end
    end)
end

local function showNextMapNotification(mapName)
    if not mapName or mapName == "" then
        return
    end

    if nextMapNotifGui then
        nextMapNotifGui:Destroy()
    end

    nextMapNotifGui = Instance.new("ScreenGui")
    nextMapNotifGui.Name = "VD_MapNotify"
    nextMapNotifGui.ResetOnSpawn = false
    nextMapNotifGui.Parent = localPlayer:WaitForChild("PlayerGui")

    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.35, 0)
    container.Size = UDim2.new(0, 270, 0, 44)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    container.BackgroundTransparency = 0.1
    container.Parent = nextMapNotifGui

    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", container)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Transparency = 0.4

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 28, 1, 0)
    icon.Position = UDim2.new(0, 6, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.Text = "🗺️"
    icon.TextSize = 24
    icon.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Position = UDim2.new(0, 38, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = "Next Map: " .. mapName
    label.TextColor3 = Color3.fromRGB(255, 255, 200)
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    task.spawn(function()
        task.wait(5)

        if nextMapNotifGui then
            nextMapNotifGui:Destroy()
        end
    end)
end

local function updateSpectatorCount()
    if not isSpectatorCounterActive or not spectatorCountLabel then
        return
    end

    local count = 0

    for _, player in ipairs(players:GetPlayers()) do
        if player.Team and player.Team.Name == "Spectator" then
            count = count + 1
        end
    end

    spectatorCountLabel.Text = tostring(count)
end

local function updateNextKiller()
    if not isNextKillerActive then
        return
    end

    local sortedPlayers = players:GetPlayers()

    table.sort(sortedPlayers, function(a, b)
        local aAllowKiller = a:GetAttribute("AllowKiller") or false

        if aAllowKiller ~= (b:GetAttribute("AllowKiller") or false) then
            return aAllowKiller
        end

        return (a:GetAttribute("KillerChance") or 0) > (b:GetAttribute("KillerChance") or 0)
    end)

    local topPlayer = sortedPlayers[1]

    if topPlayer then
        local selectedKiller = topPlayer:FindFirstChild("SelectedKiller")

        local killerValue = selectedKiller and selectedKiller.Value
            or topPlayer:GetAttribute("SelectedKiller") or "Unknown"

        local displayName = topPlayer == localPlayer and "YOU" or topPlayer.Name

        if lastNotifiedKillerName ~= displayName or lastNotifiedKillerSelection ~= killerValue then
            lastNotifiedKillerName = displayName
            lastNotifiedKillerSelection = killerValue
            showNextKillerNotification(displayName, killerValue)
        end
    else
        lastNotifiedKillerName = nil
        lastNotifiedKillerSelection = nil
    end
end

local function startSpectatorCounter()
    if isSpectatorCounterActive then
        return
    end

    isSpectatorCounterActive = true
    createSpectatorCounterGui()
    updateSpectatorCount()

    if spectatorCounterThread then
        task.cancel(spectatorCounterThread)
    end

    spectatorCounterThread = task.spawn(function()
        while isSpectatorCounterActive do
            updateSpectatorCount()
            task.wait(1.2)
        end
    end)
end

local function stopSpectatorCounter()
    isSpectatorCounterActive = false

    if spectatorCounterThread then
        task.cancel(spectatorCounterThread)
        spectatorCounterThread = nil
    end

    if spectatorCounterGui then
        spectatorCounterGui:Destroy()
        spectatorCounterGui = nil
        spectatorCountLabel = nil
    end
end

local function startNextKiller()
    if isNextKillerActive then
        return
    end

    isNextKillerActive = true
    lastNotifiedKillerName = nil
    lastNotifiedKillerSelection = nil
    updateNextKiller()

    if nextKillerThread then
        task.cancel(nextKillerThread)
    end

    nextKillerThread = task.spawn(function()
        while isNextKillerActive do
            updateNextKiller()
            task.wait(10)
        end
    end)
end

local function stopNextKiller()
    isNextKillerActive = false

    if nextKillerThread then
        task.cancel(nextKillerThread)
        nextKillerThread = nil
    end

    if nextKillerNotifGui then
        nextKillerNotifGui:Destroy()
    end
end

local function setupNextMapListener()
    if isNextMapListenerSetup then
        return
    end

    isNextMapListenerSetup = true
    local remotes = replicatedStorage:WaitForChild("Remotes", 10)
    local mapInfo = remotes and remotes:FindFirstChild("Mapinfo", true)

    if mapInfo then
        mapInfo.OnClientEvent:Connect(function(mapName)
            if mapName and isNextMapNotifActive then
                showNextMapNotification(tostring(mapName))
            end
        end)
    end
end

local infoGroupbox2 = tabs.Esp:AddRightGroupbox("Info", "info")

infoGroupbox2:AddToggle("SpectatorToggle", {
    Text = "Spectator Counter",
    Default = false,
    Callback = function(value)
        if value then
            startSpectatorCounter()
        else
            stopSpectatorCounter()
        end
    end,
})

infoGroupbox2:AddToggle("NextKillerToggle", {
    Text = "Next Killer",
    Default = false,
    Callback = function(value)
        if value then
            startNextKiller()
        else
            stopNextKiller()
        end
    end,
})

infoGroupbox2:AddToggle("NextMapToggle", {
    Text = "Next Map Notification",
    Default = false,
    Callback = function(value)
        isNextMapNotifActive = value

        if value then
            setupNextMapListener()
        end
    end,
})

local teleportPlayersGroupbox = tabs.Teleport:AddLeftGroupbox("Teleport Players", "users")
local selectedPlayerName = nil
local availablePlayerNames = {}
local playerDropdown = nil

local function refreshPlayerList()
    availablePlayerNames = {}

    for _, player in pairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            table.insert(availablePlayerNames, player.Name)
        end
    end

    table.sort(availablePlayerNames)
end

refreshPlayerList()

playerDropdown = teleportPlayersGroupbox:AddDropdown("PlayerDropdown", {
    Values = availablePlayerNames,
    Default = "",
    Text = "Select Player",
    Tooltip = "TP to the selected player",
    Callback = function(value) selectedPlayerName = value end,
})

teleportPlayersGroupbox:AddButton({
    Text = "Refresh Player",
    Func = function()
        refreshPlayerList()

        if playerDropdown then
            playerDropdown:SetValues(availablePlayerNames)
        end

        library:Notify({
            Title = "Teleport",
            Description = "Player list refreshed! " .. #availablePlayerNames .. " players",
            Time = 3,
        })
    end,
})

teleportPlayersGroupbox:AddButton({
    Text = "Teleport to selected player",
    Func = function()
        if not selectedPlayerName or selectedPlayerName == "" then
            library:Notify({ Title = "Error", Description = "Select a player first!", Time = 3 })
            return
        end

        local targetPlayer = players:FindFirstChild(selectedPlayerName)

        if targetPlayer and targetPlayer.Character
            and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local localCharacter = localPlayer.Character

            if localCharacter and localCharacter:FindFirstChild("HumanoidRootPart") then
                localCharacter.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
                    + Vector3.new(0, 3, 0)
            end
        end
    end,
})

local teleportMapsGroupbox = tabs.Teleport:AddRightGroupbox("Teleport Maps", "map")
local generatorIndex, hookIndex, gateIndex, palletIndex, windowIndex = 1, 1, 1, 1, 1

local function teleportLocalTo(part)
    local character = localPlayer.Character

    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 5, 0)
    end
end

teleportMapsGroupbox:AddButton({
    Text = "TP Generator Loop",
    Func = function()
        if #worldCache.Generators == 0 then
            refreshWorldCache()
        end

        if generatorIndex > #worldCache.Generators then
            generatorIndex = 1
        end

        if worldCache.Generators[generatorIndex] and worldCache.Generators[generatorIndex].part then
            teleportLocalTo(worldCache.Generators[generatorIndex].part)
        end

        generatorIndex = generatorIndex + 1
    end,
})

teleportMapsGroupbox:AddButton({
    Text = "TP Hook Loop",
    Func = function()
        if #worldCache.Hooks == 0 then
            refreshWorldCache()
        end

        if hookIndex > #worldCache.Hooks then
            hookIndex = 1
        end

        local hook = worldCache.Hooks[hookIndex]

        local hookPoint = hook
            and (hook:FindFirstChild("HookPoint") or hook:FindFirstChildWhichIsA("BasePart"))

        if hookPoint then
            teleportLocalTo(hookPoint)
        end

        hookIndex = hookIndex + 1
    end,
})

teleportMapsGroupbox:AddButton({
    Text = "TP Gate Loop",
    Func = function()
        if #worldCache.Gates == 0 then
            refreshWorldCache()
        end

        if gateIndex > #worldCache.Gates then
            gateIndex = 1
        end

        local gate = worldCache.Gates[gateIndex]
        local basePart = gate and gate:FindFirstChildWhichIsA("BasePart")

        if basePart then
            teleportLocalTo(basePart)
        end

        gateIndex = gateIndex + 1
    end,
})

teleportMapsGroupbox:AddButton({
    Text = "TP Pallet Loop",
    Func = function()
        if #worldCache.Pallets == 0 then
            refreshWorldCache()
        end

        if palletIndex > #worldCache.Pallets then
            palletIndex = 1
        end

        local pallet = worldCache.Pallets[palletIndex]

        local primaryPart = pallet
            and (pallet:FindFirstChild("PrimaryPartPallet") or pallet:FindFirstChildWhichIsA("BasePart"))

        if primaryPart then
            teleportLocalTo(primaryPart)
        end

        palletIndex = palletIndex + 1
    end,
})

teleportMapsGroupbox:AddButton({
    Text = "TP Window Loop",
    Func = function()
        if #worldCache.Windows == 0 then
            refreshWorldCache()
        end

        if windowIndex > #worldCache.Windows then
            windowIndex = 1
        end

        local window = worldCache.Windows[windowIndex]

        local bottom = window
            and (window:FindFirstChild("Bottom") or window:FindFirstChildWhichIsA("BasePart"))

        if bottom then
            teleportLocalTo(bottom)
        end

        windowIndex = windowIndex + 1
    end,
})

teleportMapsGroupbox:AddButton({
    Text = "Refresh Map",
    Func = function()
        refreshWorldCache()
        generatorIndex, hookIndex, gateIndex, palletIndex, windowIndex = 1, 1, 1, 1, 1
        library:Notify({ Title = "Map", Description = "Map Cache Refreshed", Time = 3 })
    end,
})

local afkGroupbox = tabs.AFK:AddLeftGroupbox("AFK Auto Farm", "bot")

afkGroupbox:AddToggle("AutoAFKEscape", {
    Text = "Afk Auto Farm Survivor",
    Default = false,
    Callback = function(value)
        SurvivorSettings.AUTO_AFKEscape = value

        if value then
            startAfkEscape(localPlayer.Team and localPlayer.Team.Name or "Unknown")
        elseif afkEscapeThread then
            task.cancel(afkEscapeThread)
        end
    end,
})

afkGroupbox:AddButton({ Text = "Server Hop", Func = function() hopToRandomServer() end })

local function setupTeleportFailHandler()
    teleportService.TeleportInitFailed:Connect(function(_, _, errorMessage)
        if SurvivorSettings.AUTO_AFKEscape then
            if getgenv().Library then
                getgenv().Library:Notify("Teleport Failed: " .. tostring(errorMessage)
                    .. ". Trying another server...", 3)
            end

            task.wait(2)
            hopToRandomServer()
        end
    end)

    pcall(function()
        local promptOverlay = coreGui:WaitForChild("RobloxPromptGui", 5):WaitForChild(
            "promptOverlay", 5
        )

        if promptOverlay then
            promptOverlay.ChildAdded:Connect(function(child)
                if SurvivorSettings.AUTO_AFKEscape and child.Name == "ErrorPrompt" then
                    if getgenv().Library then
                        getgenv().Library:Notify("Server Full/Disconnected! Trying server hop...", 3)
                    end

                    pcall(function() child.Visible = false end)
                    task.wait(2.5)
                    hopToRandomServer()
                end
            end)
        end
    end)
end

setupTeleportFailHandler()

localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    startAfkEscape(localPlayer.Team and localPlayer.Team.Name or "")

    if localPlayer.Team and localPlayer.Team.Name == "Survivors" then
        setupAutoGenerator()
    end
end)

setupAutoGenerator()

localPlayer.CharacterAdded:Connect(function()
    task.wait(1.2)
    setupAutoGenerator()

    if SurvivorSettings.Surv_InstanSkillCheck then
        task.spawn(function()
            local character = localPlayer.Character
            local skillCheckGen = character:WaitForChild("Skillcheck-gen", 3)
            local skillCheckPlayer = character:WaitForChild("Skillcheck-player", 3)

            if skillCheckGen then
                skillCheckGen.Disabled = true
            end

            if skillCheckPlayer then
                skillCheckPlayer.Disabled = true
            end
        end)
    end
end)

for _, player in pairs(players:GetPlayers()) do
    setupPlayerTracking(player)
end

players.PlayerAdded:Connect(setupPlayerTracking)

task.spawn(function()
    while true do
        task.wait(5)

        for _, player in pairs(players:GetPlayers()) do
            tryTrackKiller(player)
        end
    end
end)

local isFreeMouseActive = false
local freeMouseConn

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightAlt then
        isFreeMouseActive = not isFreeMouseActive

        if isFreeMouseActive then
            userInputService.MouseIconEnabled = true
            userInputService.MouseBehavior = Enum.MouseBehavior.Default

            if freeMouseConn then
                freeMouseConn:Disconnect()
            end

            freeMouseConn = runService.RenderStepped:Connect(function()
                if userInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                    userInputService.MouseBehavior = Enum.MouseBehavior.Default
                end

                if not userInputService.MouseIconEnabled then
                    userInputService.MouseIconEnabled = true
                end
            end)
        else
            if freeMouseConn then
                freeMouseConn:Disconnect()
            end

            freeMouseConn = nil

            userInputService.MouseIconEnabled = false
            userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    end
end)

local isFlashAimActive = false

local function findNearestKillerRootPart()
    local closestRootPart = nil
    local closestDistance = math.huge
    local localCharacter = localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return nil
    end

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and isKillerPlayer(player) and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local killerRoot = player.Character:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and killerRoot
                and not isKnockedOrHooked(player.Character) then
                local distance = (killerRoot.Position - localRoot.Position).Magnitude

                if distance < closestDistance then
                    closestDistance = distance
                    closestRootPart = killerRoot
                end
            end
        end
    end

    return closestRootPart
end

runService.RenderStepped:Connect(function()
    local character = localPlayer.Character

    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    fleeFromKiller()

    if isFlashAimActive and AimSettings.Flash_Silent then
        local targetRoot = findNearestKillerRootPart()

        if targetRoot then
            local localCharacter = localPlayer.Character
            local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            local aimPosition = targetRoot.Position + Vector3.new(0, AimSettings.Flash_YOffset, 0)

            local camera = workspace.CurrentCamera

            camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(
                camera.CFrame.Position, aimPosition
            ), 0.5)

            if localRoot then
                local bodyCFrame = CFrame.lookAt(
                    localRoot.Position,
                    Vector3.new(aimPosition.X, localRoot.Position.Y, aimPosition.Z)
                )

                localRoot.CFrame = localRoot.CFrame:Lerp(bodyCFrame, 0.5)
            end
        end
    end

    if isPistolAimActive then
        if lockAimTarget and AimSettings.LockAim and lockAimTarget.Parent and lockAimTarget.Parent:FindFirstChild("Humanoid")
            and lockAimTarget.Parent.Humanoid.Health > 0 then
            aimCameraAt(lockAimTarget)
        else
            lockAimTarget = findPistolTarget()
        end
    end

    if isCameraFovEnabled and currentCamera then
        currentCamera.FieldOfView = cameraFovValue
    end

    local isSpearModeActive = character and character:GetAttribute("spearmode") == true

    if AimSettings.Aim_SilentVeil and AimSettings.Veil_ShowFOV and isSpearModeActive then
        veilFovCircle.Visible = true
        veilFovCircle.Radius = AimSettings.Veil_FOV

        veilFovCircle.Position = Vector2.new(
            currentCamera.ViewportSize.X / 2, currentCamera.ViewportSize.Y / 2
        )
    else
        veilFovCircle.Visible = false
    end

    if AimSettings.Aim_Silent and AimSettings.Pistol_ShowFOV and AimSettings.Pistol_FOVMode then
        pistolFovCircle.Visible = true
        pistolFovCircle.Radius = AimSettings.Pistol_FOV

        pistolFovCircle.Position = Vector2.new(
            currentCamera.ViewportSize.X / 2, currentCamera.ViewportSize.Y / 2
        )
    else
        pistolFovCircle.Visible = false
    end

    if isPistolAimActive and AimSettings.Aim_Silent then
        local target = findPistolTarget()

        if target then
            local leftArm = character:FindFirstChild("Left Arm")
                or character:FindFirstChild("LeftHand")

            local originPosition = leftArm and leftArm.Position or character:GetPivot().Position
            local targetPosition = target.Position

            local targetVelocity = target.AssemblyLinearVelocity

            targetVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)

            local aimPosition = targetPosition
                + targetVelocity * ((targetPosition - originPosition).Magnitude / 400)
                + Vector3.new(0, -1.2, 0)

            vdPistolLaser.Parent = workspace
            vdPistolLaser.Transparency = hideSilentLaser and 1 or 0

            local laserLength = (aimPosition - originPosition).Magnitude

            if laserLength > 0 then
                vdPistolLaser.Size = Vector3.new(0.05, 0.05, laserLength)
                vdPistolLaser.CFrame = CFrame.new(originPosition, aimPosition) * CFrame.new(0, 0, -laserLength / 2)
            end
        elseif vdPistolLaser.Parent ~= nil then
            vdPistolLaser.Parent = nil
        end
    elseif vdPistolLaser.Parent ~= nil then
        vdPistolLaser.Parent = nil
    end

    if isVeilAimActive and AimSettings.Aim_SilentVeil and isSpearModeActive then
        local veilTarget = findVeilSpearTarget()

        if veilTarget and veilTarget.Parent then
            vdVeilTargetHighlight.Parent = veilTarget.Parent

            if isVeilTrackerEnabled and humanoidRootPart then
                local screenPos, onScreen = currentCamera:WorldToViewportPoint(veilTarget.Position)

                if onScreen then
                    veilTrackerLine.From = Vector2.new(
                        currentCamera.ViewportSize.X / 2, currentCamera.ViewportSize.Y / 2
                    )

                    veilTrackerLine.To = Vector2.new(screenPos.X, screenPos.Y)
                    veilTrackerLine.Visible = true

                    veilTrackerCircle.Position = Vector2.new(screenPos.X, screenPos.Y)
                    veilTrackerCircle.Visible = true
                else
                    veilTrackerLine.Visible = false
                    veilTrackerCircle.Visible = false
                end
            end
        else
            vdVeilTargetHighlight.Parent = nil
            veilTrackerLine.Visible = false
            veilTrackerCircle.Visible = false
        end
    else
        vdVeilTargetHighlight.Parent = nil
        veilTrackerLine.Visible = false
        veilTrackerCircle.Visible = false
    end

    if SurvivorSettings.Surv_ParryCircle and SurvivorSettings.Surv_AutoParry and humanoidRootPart then
        if not runtimeState.AutoParryAdornment or runtimeState.AutoParryAdornment.Parent ~= humanoidRootPart then
            if runtimeState.AutoParryAdornment then
                runtimeState.AutoParryAdornment:Destroy()
            end

            runtimeState.AutoParryAdornment = Instance.new("CylinderHandleAdornment")
            runtimeState.AutoParryAdornment.Name = "AutoParryCircleESP"
            runtimeState.AutoParryAdornment.Height = 0.05
            runtimeState.AutoParryAdornment.Transparency = 0.3
            runtimeState.AutoParryAdornment.Adornee = humanoidRootPart
            runtimeState.AutoParryAdornment.Parent = humanoidRootPart
            runtimeState.AutoParryAdornment.ZIndex = 0
            runtimeState.AutoParryAdornment.AlwaysOnTop = false
        end

        local parryRadius = SurvivorSettings.Surv_ParryRadius

        runtimeState.AutoParryAdornment.Radius = parryRadius
        runtimeState.AutoParryAdornment.InnerRadius = math.max(0.1, parryRadius - 0.15)
        runtimeState.AutoParryAdornment.CFrame = CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(90), 0, 0)

        if runtimeState.ParryCooldown then
            runtimeState.AutoParryAdornment.Color3 = Color3.fromRGB(255, 128, 0)
        elseif SurvivorSettings.Surv_ParryAggressive then
            runtimeState.AutoParryAdornment.Color3 = Color3.fromRGB(255, 0, 0)
        else
            runtimeState.AutoParryAdornment.Color3 = Color3.fromRGB(0, 255, 255)
        end
    elseif runtimeState.AutoParryAdornment then
        runtimeState.AutoParryAdornment:Destroy()
        runtimeState.AutoParryAdornment = nil
    end
end)

userInputService.InputBegan:Connect(function(input, gameProcessed)
    local isTouchInput = input.UserInputType == Enum.UserInputType.Touch

    if gameProcessed and not isTouchInput then
        return
    end

    local character = localPlayer.Character
    local isSpearModeActive = character and character:GetAttribute("spearmode") == true

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if AimSettings.Aim_Silent then
            isPistolAimActive = true
            lockAimTarget = findPistolTarget()
        end

        if AimSettings.Flash_Silent then
            isFlashAimActive = true
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        if AimSettings.Aim_Silent and isPistolAimActive then
            firePistolSilentAim()
        end

        if AimSettings.Aim_SilentVeil and isSpearModeActive then
            isVeilAimActive = true
        end
    elseif isTouchInput then
        if AimSettings.Aim_Silent or AimSettings.Flash_Silent then
            local playerGui = localPlayer:FindFirstChild("PlayerGui")

            if playerGui then
                local survivorMob = playerGui:FindFirstChild("Survivor-mob")

                if survivorMob then
                    local controls = survivorMob:FindFirstChild("Controls")

                    if controls then
                        local guiMob = controls:FindFirstChild("Gui-mob")

                        if guiMob and guiMob.Visible then
                            local touchPos = input.Position
                            local buttonPos = guiMob.AbsolutePosition
                            local buttonSize = guiMob.AbsoluteSize

                            if touchPos.X >= buttonPos.X
                                and touchPos.X <= buttonPos.X + buttonSize.X
                                and touchPos.Y >= buttonPos.Y
                                and touchPos.Y <= buttonPos.Y + buttonSize.Y then
                                if AimSettings.Aim_Silent then
                                    isPistolAimActive = true
                                    touchPistolInput = input
                                    lockAimTarget = findPistolTarget()
                                end

                                if AimSettings.Flash_Silent then
                                    isFlashAimActive = true
                                    touchPistolInput = input
                                end
                            end
                        end
                    end
                end
            end
        end

        if AimSettings.Aim_SilentVeil and isSpearModeActive then
            local playerGui = localPlayer:FindFirstChild("PlayerGui")

            if playerGui then
                local slasherMob = playerGui:FindFirstChild("Slasher-mob")

                if slasherMob then
                    local controls = slasherMob:FindFirstChild("Controls")

                    if controls then
                        local attackButton = controls:FindFirstChild("attack")

                        if attackButton and attackButton.Visible then
                            local touchPos = input.Position
                            local buttonPos = attackButton.AbsolutePosition
                            local buttonSize = attackButton.AbsoluteSize

                            if touchPos.X >= buttonPos.X
                                and touchPos.X <= buttonPos.X + buttonSize.X
                                and touchPos.Y >= buttonPos.Y
                                and touchPos.Y <= buttonPos.Y + buttonSize.Y then
                                isVeilAimActive = true
                                touchPistolInput = input
                            end
                        end
                    end
                end
            end
        end
    end
end)

userInputService.InputEnded:Connect(function(input, gameProcessed)
    local isTouchInput = input.UserInputType == Enum.UserInputType.Touch

    if isPistolAimActive and (input == touchPistolInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        isPistolAimActive = false

        if touchPistolInput == input then
            touchPistolInput = nil
        end

        local isOverCancelUi = false
        local smartLogic = getgenv().VD_SmartLogic

        if smartLogic and smartLogic.IsOverCancel then
            local success, result = pcall(smartLogic.IsOverCancel, smartLogic, input.Position)

            if success then
                isOverCancelUi = result
            end
        end

        if not isOverCancelUi then
            firePistolSilentAim()
        end

        lockAimTarget = nil
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isPistolAimActive = false
        lockAimTarget = nil
        isFlashAimActive = false
    end

    if isVeilAimActive and (input == touchPistolInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        isVeilAimActive = false

        if touchPistolInput == input then
            touchPistolInput = nil
        end

        if veilThrowCooldown then
            return
        end

        veilThrowCooldown = true
        task.delay(2, function() veilThrowCooldown = false end)
        local localCharacter = localPlayer.Character
        local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        local head = localCharacter and (localCharacter:FindFirstChild("Head") or localRoot)

        if head and localRoot then
            local headPosition = head.Position
            local spearSpeed = AimSettings.SPEAR_Speed
            local veilTarget = findVeilSpearTarget()
            local throwDirection

            if veilTarget then
                local targetRoot = veilTarget:IsA("Model") and veilTarget:FindFirstChild("HumanoidRootPart")
                    or veilTarget

                local targetPosition = targetRoot.Position

                local targetVelocity = targetRoot.AssemblyLinearVelocity
                    or Vector3.new(0, 0, 0)

                local distance = (targetPosition - headPosition).Magnitude
                local timeToTarget = distance / spearSpeed

                local gravityCompensation = 0.5 * (AimSettings.AIM_Auto and math.max(0, distance - 8) or AimSettings.SPEAR_Gravity)
                    * timeToTarget ^ 2 * math.clamp(distance / 100, 1, 2.5)

                throwDirection = (targetPosition + targetVelocity * timeToTarget + Vector3.new(0, gravityCompensation, 0)
                    - headPosition).Unit
            else
                throwDirection = currentCamera.CFrame.LookVector
            end

            pcall(function()
                replicatedStorage.Remotes.Killers.Veil.Spearthrow:FireServer(
                    throwDirection, spearSpeed, headPosition
                )
            end)
        end
    end

    if isTouchInput and input == touchPistolInput then
        isPistolAimActive = false
        isFlashAimActive = false
        touchPistolInput = nil
    end
end)

local lastWiggleTime = 0

runService.Heartbeat:Connect(function()
    local character = localPlayer.Character

    if not character then
        return
    end

    if SurvivorSettings.Surv_Perks and getLocalRole() ~= "Killer" then
        if character:GetAttribute("vaultspeed") ~= SurvivorSettings.Surv_VaultSpeed then
            character:SetAttribute("vaultspeed", SurvivorSettings.Surv_VaultSpeed)
        end
    end

    if isAutoWiggleEnabled and os.clock() - lastWiggleTime >= 0.1 then
        lastWiggleTime = os.clock()
        local isCarried = character:FindFirstChild("IsCarried")

        if isCarried and isCarried.Value then
            local selfUnHookEvent = replicatedStorage:FindFirstChild("Remotes")
                and replicatedStorage.Remotes:FindFirstChild("Carry")
                and replicatedStorage.Remotes.Carry:FindFirstChild("SelfUnHookEvent")

            if selfUnHookEvent then
                selfUnHookEvent:FireServer()
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.15)

        if isKillerNoSlowdownEnabled then
            local character = localPlayer.Character

            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid and getLocalRole() == "Killer" then
                    if humanoid.WalkSpeed < 16 then
                        humanoid.WalkSpeed = 16
                    end
                end
            end
        end

        if isSurvivorNoSlowdownEnabled then
            local character = localPlayer.Character

            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid and getLocalRole() == "Survivor" then
                    if humanoid.WalkSpeed < 16 then
                        humanoid.WalkSpeed = 16
                    end
                end
            end
        end
    end
end)

themeManager:SetLibrary(library)

saveManager:SetLibrary(library)
saveManager:SetIgnoreIndexes({ "ToggleKeybindPicker" })

themeManager:SetFolder("SongHub")

saveManager:SetFolder("SongHub/SurviveTheKiller")
saveManager:BuildConfigSection(tabs["UI Settings"])

themeManager:ApplyToTab(tabs["UI Settings"])
saveManager:LoadAutoloadConfig()