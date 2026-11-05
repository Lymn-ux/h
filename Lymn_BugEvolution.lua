if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.GameId ~= 10769957062 then
    game:GetService("Players").LocalPlayer:Kick("Lymn: this script is for Bug Evolution only")
    return
end

do
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" and type(env.BugEvolutionUnload) == "function" then
        pcall(env.BugEvolutionUnload)
    end
end


-- ═══════════════════════════════════════
-- SERVICES & GAME OBJECTS
-- ═══════════════════════════════════════

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
end)

-- Shared Modules & Remotes
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ConfigMod = Shared and Shared:FindFirstChild("Config") and require(Shared.Config)
local SpiderDefs = Shared and Shared:FindFirstChild("SpiderDefs") and require(Shared.SpiderDefs)
local BugDefs = Shared and Shared:FindFirstChild("BugDefs") and require(Shared.BugDefs)
local BreakableDefs = Shared and Shared:FindFirstChild("BreakableDefs") and require(Shared.BreakableDefs)
local TraitDefs = Shared and Shared:FindFirstChild("TraitDefs") and require(Shared.TraitDefs)

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local AttackRemote = Remotes:WaitForChild("Attack", 10)
local SetSprintRemote = Remotes:WaitForChild("SetSprint", 10)
local PickTraitRemote = Remotes:WaitForChild("PickTrait", 10)
local TraitOfferRemote = Remotes:WaitForChild("TraitOffer", 10)
local UseAbilityRemote = Remotes:WaitForChild("UseAbility", 10)
local TreeActionRemote = Remotes:WaitForChild("TreeAction", 10)
local EvolveRemote = Remotes:WaitForChild("Evolve", 10)
local RewardsRemote = Remotes:WaitForChild("Rewards", 10)
local NestActionRemote = Remotes:WaitForChild("NestAction", 10)
local VoidActionRemote = Remotes:WaitForChild("VoidAction", 10)


-- ═══════════════════════════════════════
-- CONFIG & STATE
-- ═══════════════════════════════════════

local LymnCore = {}
getgenv().LymnBugEvolution = LymnCore

LymnCore.Config = {
    Discord = "https://discord.gg/6B36mdd6cJ",
    UpdateLog = {
        { "2026-11-03", "BUG EVOLUTION Full Auto Edition!\nMaster Kaitun, Auto Hunt & Kill Aura, Auto Orbs & Rainbow Orbs, Auto Evolve & Traits, Auto Tree Unlocks, Auto Rewards & Zone Teleports" },
    },
}

LymnCore.State = {
    Alive = true,
    Status = "Idle",

    -- 1. MASTER KAITUN
    Kaitun = false,

    -- 2. COMBAT & FARM
    AutoAttack = false,
    FarmMode = "Teleport Orbit", -- "Teleport Orbit", "Tween Walk", "Reach Only"
    TargetBugs = false,
    TargetBreakables = false,
    TargetPlayers = false,
    TargetBoss = false,
    AvoidHigherLevel = false, -- Do not fight targets with higher level than us
    PrioritizeOneShot = false, -- Prioritize targets whose HP <= our damage for instant 1-hit kills
    SelectedBug = "All", -- "All" or bug name
    KillDistance = 2.5,
    AutoAbilities = false,
    AutoSprint = false,

    -- 3. ORBS FARM
    AutoOrbs = false,
    OrbVacuum = false, -- Vacuum / fast sweep through orbs
    AutoRainbowOrbs = false, -- DISABLED: Paid Robux Orb (Safely ignored to prevent purchase prompts)
    AutoVoidOrbs = false,
    OrbCollectRadius = 50,

    -- 4. EVOLUTION & PROGRESSION
    AutoEvolve = false,
    AutoPickTraits = false,
    PreferredTrait = "Offensive", -- Prioritize Offensive / Attack Speed to lower server cooldown
    AutoUnlockTree = false,
    SelectedSpider = "GardenSpider",

    -- 5. REWARDS & VOID
    AutoClaimRewards = false,
    AutoSpinVoid = false,
    AutoJoinVoid = false,

    -- 6. MISC & MOVEMENT
    WalkSpeedOn = false,
    WalkSpeed = 30,
    InfJump = false,
    Noclip = false,
    AutoFly = false, -- Auto 3D flight for flying insects (Housefly, Dragonfly, Hornet, etc.)
    AntiAfk = false,

    -- 7. ESP
    EspBugs = false,
    EspBreakables = false,
    EspRainbow = false, -- Disabled by default (Paid Robux Orb)
    EspPlayers = false,
    EspObjects = {},
}

local State = LymnCore.State
local HubConfig = LymnCore.Config

-- ═══════════════════════════════════════
-- UNLOAD HOOK
-- ═══════════════════════════════════════

getgenv().BugEvolutionUnload = function()
    State.Alive = false
    pcall(function()
        local w = getgenv().LymnBugEvolutionWindow
        if w and type(w.Destroy) == "function" then w:Destroy() end
    end)
    -- Clear ESP
    for _, item in pairs(State.EspObjects) do
        if item.Highlight then pcall(item.Highlight.Destroy, item.Highlight) end
        if item.Billboard then pcall(item.Billboard.Destroy, item.Billboard) end
    end
    table.clear(State.EspObjects)
    warn("[Lymn] Bug Evolution script unloaded cleanly.")
end

-- ═══════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════

local function SafeRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function SafeHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function SafeTeleport(targetCFrame)
    local hrp = SafeRoot()
    if not hrp then return false end
    hrp.CFrame = typeof(targetCFrame) == "CFrame" and targetCFrame or CFrame.new(targetCFrame)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Zone definitions
local ZONES = {
    ["Sunny Meadow"] = Vector3.new(0, 10, 120),
    ["Whispering Woods"] = Vector3.new(-470, 10, -70),
    ["Muddy Lake"] = Vector3.new(460, 5, 100),
    ["Mushroom Grove"] = Vector3.new(-370, 10, 440),
    ["Dusty Desert"] = Vector3.new(340, 10, 490),
    ["Stony Ridge"] = Vector3.new(-60, 15, -470),
    ["Web Caves"] = Vector3.new(420, -10, -400),
    ["Void Gate"] = Vector3.new(722.5, 10, 97.8),
    ["Void Arena"] = Vector3.new(0, 705, 2600),
}

-- Target Validation
local function IsValidTarget(inst)
    if not inst or not inst.Parent then return false end
    
    -- Check if it's a Breakable
    if inst:GetAttribute("BreakId") then
        if not State.TargetBreakables and not State.Kaitun then return false end
        local hp = inst:GetAttribute("HP") or 0
        local part = inst.PrimaryPart or inst:FindFirstChild("Hitbox") or inst:FindFirstChildWhichIsA("BasePart")
        return hp > 0 and part ~= nil
    end

    -- Check if it's a Player
    if inst:GetAttribute("IsPlayer") then
        if inst == LocalPlayer.Character then return false end
        if not State.TargetPlayers then return false end
        if inst:GetAttribute("Shielded") then return false end

        -- Avoid fighting players with higher level than us
        if State.AvoidHigherLevel then
            local otherPlr = Players:GetPlayerFromCharacter(inst)
            local otherLvl = (otherPlr and otherPlr:GetAttribute("Level")) or inst:GetAttribute("Level") or 0
            local myLvl = LocalPlayer:GetAttribute("Level") or 1
            if otherLvl > myLvl then
                return false
            end
        end

        local root = inst:FindFirstChild("HumanoidRootPart")
        local hum = inst:FindFirstChildOfClass("Humanoid")
        return root and hum and hum.Health > 0
    end

    -- Check if it's a Bug
    local hum = inst:FindFirstChildOfClass("Humanoid")
    local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
    if not (root and hum and hum.Health > 0) then return false end
    if inst:GetAttribute("Corpse") then return false end

    -- Avoid fighting monsters with dangerous health / level if AvoidHigherLevel is enabled
    if State.AvoidHigherLevel and not inst.Name:find("Boss") then
        local myDmg = LocalPlayer:GetAttribute("Damage") or 20
        local myHp = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").MaxHealth) or 100
        if hum.Health > (myHp * 3) or hum.Health > (myDmg * 15) then
            return false
        end
    end

    -- Check Boss vs regular bug
    local bugId = inst:GetAttribute("BugId") or inst.Name
    if bugId == "VoidMosquito" or bugId == "GiantEnemy" or inst.Name:find("Boss") then
        if not State.TargetBoss and not State.Kaitun then return false end
    else
        if not State.TargetBugs and not State.Kaitun then return false end
        if State.SelectedBug ~= "All" and inst.Name ~= State.SelectedBug and bugId ~= State.SelectedBug then
            return false
        end
    end

    return true
end

-- Find Best Target
local function FindBestTarget()
    local hrp = SafeRoot()
    if not hrp then return nil end

    local myPos = hrp.Position
    local bestTarget = nil
    local bestScore = 99999
    local myDmg = LocalPlayer:GetAttribute("Damage") or 20

    -- 1. Check Void Boss if active
    local voidBoss = workspace:FindFirstChild("VoidBoss")
    if voidBoss and IsValidTarget(voidBoss) then
        return voidBoss
    end

    -- 2. Search Breakables
    if State.TargetBreakables or State.Kaitun then
        local breakables = workspace:FindFirstChild("Breakables")
        if breakables then
            for _, b in ipairs(breakables:GetChildren()) do
                if IsValidTarget(b) then
                    local part = b.PrimaryPart or b:FindFirstChild("Hitbox") or b:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local dist = (part.Position - myPos).Magnitude
                        local hp = b:GetAttribute("HP") or 100
                        local isOneShot = State.PrioritizeOneShot and (hp <= myDmg)
                        local score = dist - (isOneShot and 1500 or 0)
                        if score < bestScore then
                            bestScore = score
                            bestTarget = b
                        end
                    end
                end
            end
        end
    end

    -- 3. Search Bugs
    if State.TargetBugs or State.Kaitun then
        local bugs = workspace:FindFirstChild("Bugs")
        if bugs then
            for _, b in ipairs(bugs:GetChildren()) do
                if IsValidTarget(b) then
                    local root = b:FindFirstChild("HumanoidRootPart") or b.PrimaryPart
                    local hum = b:FindFirstChildOfClass("Humanoid")
                    if root and hum then
                        local dist = (root.Position - myPos).Magnitude
                        local isOneShot = State.PrioritizeOneShot and (hum.Health <= myDmg)
                        local score = dist - (isOneShot and 1500 or 0)
                        if score < bestScore then
                            bestScore = score
                            bestTarget = b
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- ═══════════════════════════════════════
-- CORE AUTOMATION LOOPS
-- ═══════════════════════════════════════

-- 1. Auto Attack / Kill Aura Loop
task.spawn(function()
    while State.Alive do
        if State.AutoAttack or State.Kaitun then
            local hrp = SafeRoot()
            local hum = SafeHumanoid()
            if hrp and hum and hum.Health > 0 then
                local target = FindBestTarget()
                if target and IsValidTarget(target) then
                    local targetPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or target:FindFirstChild("Hitbox") or target:FindFirstChildWhichIsA("BasePart")
                    if targetPart then
                        local targetPos = targetPart.Position
                        local dist = (targetPos - hrp.Position).Magnitude

                        -- Approach mode
                        if State.FarmMode == "Teleport Orbit" then
                            -- Orbit slightly above or behind target
                            local offset = (hrp.Position - targetPos)
                            if offset.Magnitude < 0.1 then offset = Vector3.new(0, 0, 1) end
                            local approachPos = targetPos + (offset.Unit * State.KillDistance) + Vector3.new(0, 1.2, 0)
                            hrp.CFrame = CFrame.lookAt(approachPos, targetPos)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        elseif State.FarmMode == "Tween Walk" then
                            if dist > (LocalPlayer:GetAttribute("Reach") or 6) then
                                local approachPos = targetPos + Vector3.new(0, 1, 0)
                                pcall(function()
                                    TweenService:Create(hrp, TweenInfo.new(dist / 40, Enum.EasingStyle.Linear), {
                                        CFrame = CFrame.lookAt(approachPos, targetPos)
                                    }):Play()
                                end)
                            else
                                hrp.CFrame = CFrame.lookAt(hrp.Position, targetPos)
                            end
                        else
                            -- Reach only: just face target if in range
                            if dist <= (LocalPlayer:GetAttribute("Reach") or 8) then
                                hrp.CFrame = CFrame.lookAt(hrp.Position, targetPos)
                            end
                        end

                        -- Attack
                        pcall(function()
                            AttackRemote:FireServer(target)
                        end)

                        -- Auto Abilities
                        if State.AutoAbilities then
                            local now = os.clock()
                            local cd1 = LocalPlayer:GetAttribute("Ability1Ready") or 0
                            local cd2 = LocalPlayer:GetAttribute("Ability2Ready") or 0
                            if now >= cd1 then
                                pcall(function() UseAbilityRemote:FireServer(1) end)
                            end
                            if now >= cd2 then
                                pcall(function() UseAbilityRemote:FireServer(2) end)
                            end
                        end
                    end
                end
            end
        end

        local atkSpeed = (LocalPlayer:GetAttribute("AttackSpeed") or 1) * (LocalPlayer:GetAttribute("AttackSpeedMult") or 1)
        local cd = math.clamp(1 / math.max(atkSpeed, 0.5), 0.05, 0.6)
        task.wait(cd)
    end
end)

-- 2. Auto Collect Orbs (Free XP Orbs & Void Credits - Strictly Ignores Paid Robux Orbs)
task.spawn(function()
    while State.Alive do
        if State.AutoOrbs or State.OrbVacuum or State.Kaitun then
            local hrp = SafeRoot()
            if hrp then
                -- A. Void Orbs (Free Event Credits, Not Paid)
                if State.AutoVoidOrbs then
                    local voidOrbs = workspace:FindFirstChild("VoidOrbs")
                    if voidOrbs and #voidOrbs:GetChildren() > 0 then
                        for _, vo in ipairs(voidOrbs:GetChildren()) do
                            local part = vo:IsA("BasePart") and vo or (vo.PrimaryPart or vo:FindFirstChildWhichIsA("BasePart"))
                            if part and (part.Position - hrp.Position).Magnitude < 150 then
                                if firetouchinterest then
                                    firetouchinterest(hrp, part, 0)
                                    firetouchinterest(hrp, part, 1)
                                end
                            end
                        end
                    end
                end

                -- B. Standard Orbs & Orb Vacuum (Strictly skips RainbowOrbs / Paid Orbs)
                local orbs = workspace:FindFirstChild("Orbs")
                if orbs and (State.AutoOrbs or State.OrbVacuum or State.Kaitun) then
                    local myPos = hrp.Position
                    local collected = 0
                    for _, orb in ipairs(orbs:GetChildren()) do
                        -- Safeguard: Strictly never touch paid Rainbow Orbs to avoid purchase prompt
                        if orb.Name == "RainbowOrb" or (orb.Parent and orb.Parent.Name == "RainbowOrbs") then
                            continue
                        end

                        if orb:IsA("BasePart") and orb.Parent then
                            local d = (orb.Position - myPos).Magnitude
                            if d <= State.OrbCollectRadius then
                                if State.OrbVacuum then
                                    hrp.CFrame = orb.CFrame
                                    task.wait(0.02)
                                else
                                    if firetouchinterest then
                                        firetouchinterest(hrp, orb, 0)
                                        firetouchinterest(hrp, orb, 1)
                                    end
                                end
                                collected = collected + 1
                                if collected >= 20 then break end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.15)
    end
end)

-- 3. Auto Evolve & Trait Picker
task.spawn(function()
    while State.Alive do
        if State.AutoEvolve or State.Kaitun then
            pcall(function()
                if not LocalPlayer:GetAttribute("Transforming") then
                    EvolveRemote:InvokeServer()
                end
            end)
        end
        task.wait(2)
    end
end)

-- Trait Offer listener
if TraitOfferRemote then
    TraitOfferRemote.OnClientEvent:Connect(function(offerList)
        if (State.AutoPickTraits or State.Kaitun) and type(offerList) == "table" and #offerList > 0 then
            task.wait(0.1)
            local chosenIndex = 1
            if State.PreferredTrait ~= "First Available" and TraitDefs then
                for idx, traitKey in ipairs(offerList) do
                    local tInfo = TraitDefs.Get and TraitDefs.Get(traitKey)
                    if tInfo and tInfo.Category == State.PreferredTrait then
                        chosenIndex = idx
                        break
                    end
                end
            end
            pcall(function()
                PickTraitRemote:FireServer(chosenIndex)
            end)
        end
    end)
end

-- 4. Auto Tree Unlock Loop
task.spawn(function()
    while State.Alive do
        if (State.AutoUnlockTree or State.Kaitun) and SpiderDefs and SpiderDefs.List then
            pcall(function()
                local coins = LocalPlayer:GetAttribute("Coins") or 0
                local currentLevel = LocalPlayer:GetAttribute("Level") or 1
                for _, sp in ipairs(SpiderDefs.List) do
                    local reqLevel = sp.ReqLevel or 0
                    local cost = sp.Cost or sp.Price or 0
                    if cost > 0 and currentLevel >= reqLevel and coins >= cost then
                        local ok, unl, msg = TreeActionRemote:InvokeServer("Unlock", sp.Id)
                        if ok and unl then
                            task.wait(0.5)
                        end
                    end
                end
            end)
        end
        task.wait(5)
    end
end)

-- 5. Auto Rewards & Claims Loop
task.spawn(function()
    while State.Alive do
        if State.AutoClaimRewards or State.Kaitun then
            pcall(function()
                RewardsRemote:InvokeServer("ClaimDaily")
                RewardsRemote:InvokeServer("ClaimPlaytime")
                RewardsRemote:InvokeServer("ClaimGroup")
            end)
        end

        if State.AutoSpinVoid and VoidActionRemote then
            pcall(function()
                VoidActionRemote:InvokeServer("Spin")
            end)
        end

        if State.AutoSprint and SetSprintRemote then
            pcall(function()
                SetSprintRemote:FireServer(true)
            end)
        end

        task.wait(10)
    end
end)

-- 6. Movement / WalkSpeed & Noclip Loops
local NoclipTouched, WasNoclip = {}, false
local WasSpeedOn, OriginalSpeed = false, nil
RunService.Stepped:Connect(function()
    if not State.Alive then return end

    local char = LocalPlayer.Character
    if not char then return end

    if State.Noclip then
        WasNoclip = true
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                NoclipTouched[part] = true
                part.CanCollide = false
            end
        end
    elseif WasNoclip then
        WasNoclip = false
        for part in pairs(NoclipTouched) do
            if part and part.Parent then part.CanCollide = true end
        end
        table.clear(NoclipTouched)
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if State.WalkSpeedOn then
        if hum then
            if not WasSpeedOn then
                WasSpeedOn = true
                OriginalSpeed = hum.WalkSpeed
            end
            if hum.WalkSpeed ~= State.WalkSpeed then
                hum.WalkSpeed = State.WalkSpeed
            end
        end
    elseif WasSpeedOn then
        WasSpeedOn = false
        if hum and OriginalSpeed then hum.WalkSpeed = OriginalSpeed end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.Alive and State.InfJump then
        local hum = SafeHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Anti AFK
LocalPlayer.Idled:Connect(function()
    if State.Alive and State.AntiAfk then
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- Auto Flight for Flying Bugs (Housefly, Dragonfly, Hornet, Mosquito, Moths)
local WasAutoFly = false
task.spawn(function()
    while State.Alive do
        if State.AutoFly then
            WasAutoFly = true
            local char = LocalPlayer.Character
            if char and (char:GetAttribute("CanFly") == true or LocalPlayer:GetAttribute("CanFly") == true) then
                if not char:GetAttribute("Flying") then
                    pcall(function()
                        local setFlying = Remotes:FindFirstChild("SetFlying")
                        if setFlying then setFlying:FireServer(true) end
                    end)
                end
            end
        elseif WasAutoFly then
            WasAutoFly = false
            pcall(function()
                local setFlying = Remotes:FindFirstChild("SetFlying")
                if setFlying then setFlying:FireServer(false) end
            end)
        end
        task.wait(2)
    end
end)



-- 7. ESP System
local function UpdateEsp()
    if not State.Alive then return end

    -- Clean invalid
    local kindOn = { RB = State.EspRainbow, BUG = State.EspBugs, BRK = State.EspBreakables }
    for key, data in pairs(State.EspObjects) do
        local kind = key:match("^(%a+)_")
        if not data.Instance or not data.Instance.Parent or not kindOn[kind] then
            if data.Highlight then pcall(data.Highlight.Destroy, data.Highlight) end
            if data.Billboard then pcall(data.Billboard.Destroy, data.Billboard) end
            State.EspObjects[key] = nil
        end
    end

    -- Rainbow Orbs ESP
    if State.EspRainbow then
        local rainbow = workspace:FindFirstChild("RainbowOrbs")
        if rainbow then
            for _, rb in ipairs(rainbow:GetChildren()) do
                local key = "RB_" .. rb:GetDebugId()
                if not State.EspObjects[key] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "Lymn_RainbowESP"
                    hl.FillColor = Color3.fromRGB(255, 215, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.4
                    hl.Adornee = rb
                    hl.Parent = rb

                    local bb = Instance.new("BillboardGui")
                    bb.Name = "Lymn_RainbowBB"
                    bb.Size = UDim2.fromOffset(100, 30)
                    bb.AlwaysOnTop = true
                    bb.StudsOffset = Vector3.new(0, 2, 0)
                    local lbl = Instance.new("TextLabel", bb)
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
                    lbl.TextStrokeTransparency = 0.2
                    lbl.TextSize = 13
                    lbl.Font = Enum.Font.GothamBold
                    lbl.Text = "★ RAINBOW ORB (+30 LV)"
                    bb.Parent = rb

                    State.EspObjects[key] = { Instance = rb, Highlight = hl, Billboard = bb }
                end
            end
        end
    end

    -- Bugs ESP
    if State.EspBugs then
        local bugs = workspace:FindFirstChild("Bugs")
        if bugs then
            for _, b in ipairs(bugs:GetChildren()) do
                local root = b:FindFirstChild("HumanoidRootPart") or b.PrimaryPart
                local hum = b:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 and not b:GetAttribute("Corpse") then
                    local key = "BUG_" .. b:GetDebugId()
                    if not State.EspObjects[key] then
                        local hl = Instance.new("Highlight")
                        hl.Name = "Lymn_BugESP"
                        hl.FillColor = Color3.fromRGB(255, 120, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 200, 100)
                        hl.FillTransparency = 0.6
                        hl.Adornee = b
                        hl.Parent = b

                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.fromOffset(90, 25)
                        bb.AlwaysOnTop = true
                        bb.StudsOffset = Vector3.new(0, 2, 0)
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.TextColor3 = Color3.fromRGB(255, 170, 70)
                        lbl.TextStrokeTransparency = 0.3
                        lbl.TextSize = 11
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.Text = b.Name .. " [" .. math.floor(hum.Health) .. "]"
                        bb.Parent = root

                        State.EspObjects[key] = { Instance = b, Highlight = hl, Billboard = bb, Label = lbl }
                    else
                        local entry = State.EspObjects[key]
                        if entry.Label and hum then
                            entry.Label.Text = b.Name .. " [" .. math.floor(hum.Health) .. "]"
                        end
                    end
                end
            end
        end
    end

    -- Breakables ESP
    if State.EspBreakables then
        local breakables = workspace:FindFirstChild("Breakables")
        if breakables then
            for _, brk in ipairs(breakables:GetChildren()) do
                local hp = brk:GetAttribute("HP") or 0
                local part = brk.PrimaryPart or brk:FindFirstChild("Hitbox") or brk:FindFirstChildWhichIsA("BasePart")
                if hp > 0 and part then
                    local key = "BRK_" .. brk:GetDebugId()
                    if not State.EspObjects[key] then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.fromRGB(100, 220, 255)
                        hl.OutlineColor = Color3.fromRGB(200, 240, 255)
                        hl.FillTransparency = 0.6
                        hl.Adornee = brk
                        hl.Parent = brk

                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.fromOffset(80, 20)
                        bb.AlwaysOnTop = true
                        bb.StudsOffset = Vector3.new(0, 1.5, 0)
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.TextColor3 = Color3.fromRGB(120, 220, 255)
                        lbl.TextStrokeTransparency = 0.3
                        lbl.TextSize = 10
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.Text = brk.Name .. " [" .. math.floor(hp) .. "]"
                        bb.Parent = part

                        State.EspObjects[key] = { Instance = brk, Highlight = hl, Billboard = bb, Label = lbl }
                    else
                        local entry = State.EspObjects[key]
                        if entry.Label then
                            entry.Label.Text = brk.Name .. " [" .. math.floor(hp) .. "]"
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while State.Alive do
        pcall(UpdateEsp)
        task.wait(1.5)
    end
end)


-- ═══════════════════════════════════════
-- USER INTERFACE (LYMN / PROXYLIB)
-- ═══════════════════════════════════════

task.spawn(function()
    local okLib, ProxyLib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
    end)
    if not okLib or type(ProxyLib) ~= "table" then
        warn("[Lymn] Failed to load ProxyLib!")
        return
    end

    local Lib = ProxyLib.new()

    local Window = Lib:CreateWindow({
        Title = "Lymn",
        Subtitle = "Bug Evolution",
        Size = Vector2.new(540, 340),
        MinSize = Vector2.new(460, 300),
        MaxSize = Vector2.new(950, 650),
        TypeUI = "Modern",
        Language = "English",
        Theme = "White",
        Search = true,
        AutoSave = true,
        AutoLoad = true,
        DefaultFps = false,
        DefaultPing = false,
        DefaultProfile = true,

        ConfigPanel = {
            Enabled = true,
            Acrylic = false,
            Theme = false,
            Fps = false,
            Ping = false,
            Profile = false,
            HideNotify = false,
            Language = false,
            BackgroundImage = false,
        },
        FloatButton = {
            Shape = "Squircle",
            Color = "Translucent",
            Size = 50,
            Icon = "rbxassetid://122937454340636"
        },
        Acrylic = { Enabled = false, Opacity = 0 },
    })

    getgenv().LymnBugEvolutionWindow = Window

    local function Notify(title, desc, duration)
        pcall(function()
            Window:Notify({ Title = title, Description = desc, Duration = duration or 3 })
        end)
    end

    -- Element helpers: every ProxyLib element call goes through here.
    local function Toggle(tab, title, desc, key, extra)
        tab:CreateToggle({
            Title = title,
            Description = desc,
            Default = State[key],
            Callback = function(v)
                State[key] = v
                if extra then extra(v) end
            end
        })
    end

    local function Slider(tab, title, key, min, max, rounding)
        tab:CreateSlider({
            Title = title,
            Min = min,
            Max = max,
            Default = State[key],
            Rounding = rounding or 0,
            Increment = rounding and rounding > 0 and (1 / 10 ^ rounding) or 1,
            Callback = function(v) State[key] = v end
        })
    end

    local function Dropdown(tab, title, values, key)
        tab:CreateDropdown({
            Title = title,
            Values = values,
            Options = values,
            Default = State[key],
            Callback = function(v) State[key] = v end
        })
    end

    local function Button(tab, title, cb)
        tab:CreateButton({ Title = title, Callback = cb })
    end

    local function Label(tab, title, content)
        return tab:CreateParagraph({ Title = title, Content = content or "" })
    end

    local function SetLabel(obj, text)
        if not obj then return end
        for _, method in ipairs({ "SetContent", "SetText", "SetDescription", "Set" }) do
            if type(obj[method]) == "function" then
                if pcall(obj[method], obj, text) then return end
            end
        end
    end

    -- ── TABS ─────────────────────────────────────────────────
    local Info = Window:CreateTab({ Title = "Information", Subtitle = "Update/Dev Info", Icon = "rbxassetid://6031075938" })
    local Kaitun = Window:CreateTab({ Title = "Kaitun", Subtitle = "Auto progression", Icon = "rbxassetid://6035067836" })
    local Combat = Window:CreateTab({ Title = "Combat", Subtitle = "Attack, aura & abilities", Icon = "rbxassetid://6035047409" })
    local Orbs = Window:CreateTab({ Title = "Orbs", Subtitle = "Auto collect orbs", Icon = "rbxassetid://6031280882" })
    local Evo = Window:CreateTab({ Title = "Evolution", Subtitle = "Evolve, traits & tree", Icon = "rbxassetid://6034509993" })
    local Events = Window:CreateTab({ Title = "Events", Subtitle = "Rewards & Void", Icon = "rbxassetid://6031094678" })
    local Teleports = Window:CreateTab({ Title = "Teleports", Subtitle = "Map zones & server", Icon = "rbxassetid://6031225819" })
    local Misc = Window:CreateTab({ Title = "Misc", Subtitle = "Character & ESP", Icon = "rbxassetid://6034287594" })

    Info:CreateDiscordInvite({
        Title = "Lymn Official",
        Description = "Join our server for updates, announcements, support, and community.",
        Icon = "rbxassetid://122937454340636",
        Banner = "rbxassetid://123002136721231",
        Link = "https://discord.gg/6B36mdd6cJ",
        Button = "Join Server",
    })

    -- ── KAITUN ───────────────────────────────────────────────
    Kaitun:CreateSection({ Text = "Master Kaitun" })
    Toggle(Kaitun, "Master Kaitun (All-in-One)",
        "Automatically hunts bugs, breaks cocoons, picks traits, evolves and unlocks spiders",
        "Kaitun", function(v)
            if v then
                State.AutoAttack = true
                State.AutoOrbs = true
                State.AutoRainbowOrbs = false -- Strictly disabled (Paid Robux Orb)
                State.AutoEvolve = true
                State.AutoPickTraits = true
                State.AutoClaimRewards = true
                State.AutoSprint = true
                State.TargetBugs = true
                State.TargetBreakables = true
                State.TargetBoss = true
                State.AvoidHigherLevel = true
                State.PrioritizeOneShot = true
                State.AutoAbilities = true
                State.AutoVoidOrbs = true
                State.OrbVacuum = true
            end
        end)

    Kaitun:CreateSection({ Text = "Player Status" })
    local SpiderLabel = Label(Kaitun, "Bug", "Loading...")
    local LevelLabel = Label(Kaitun, "Level", "0")
    local CoinsLabel = Label(Kaitun, "Coins", "0")
    local DmgLabel = Label(Kaitun, "Damage", "0")
    local StageLabel = Label(Kaitun, "Stage", "Baby")

    task.spawn(function()
        while State.Alive do
            pcall(function()
                local name = LocalPlayer:GetAttribute("StageName") or LocalPlayer:GetAttribute("SpiderId") or "Unknown"
                local lvl = LocalPlayer:GetAttribute("Level") or 0
                local xp = LocalPlayer:GetAttribute("XP") or 0
                local xpNeed = LocalPlayer:GetAttribute("XPNeed") or 1
                local coins = LocalPlayer:GetAttribute("Coins") or 0
                local dmg = LocalPlayer:GetAttribute("Damage") or 0
                local stage = LocalPlayer:GetAttribute("StageId") or "Baby"

                SetLabel(SpiderLabel, tostring(name))
                SetLabel(LevelLabel, string.format("%d  (XP: %d / %d)", lvl, xp, xpNeed))
                SetLabel(CoinsLabel, tostring(coins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
                SetLabel(DmgLabel, string.format("%.1f", dmg))
                SetLabel(StageLabel, tostring(stage))
            end)
            task.wait(1)
        end
    end)

    -- ── COMBAT ───────────────────────────────────────────────
    Combat:CreateSection({ Text = "Auto Attack" })
    Toggle(Combat, "Auto Attack / Kill Aura", "Continuously attacks the best nearby target", "AutoAttack")
    Dropdown(Combat, "Approach Mode", { "Teleport Orbit", "Tween Walk", "Reach Only" }, "FarmMode")
    Slider(Combat, "Orbit Distance (Studs)", "KillDistance", 1, 8, 1)
    Toggle(Combat, "Auto Use Abilities", "Uses combat ability 1 & 2 whenever off cooldown", "AutoAbilities")
    Toggle(Combat, "Prioritize 1-Hit Kill Targets", "Prioritizes low HP cocoons and bugs that die in one bite", "PrioritizeOneShot")

    Combat:CreateSection({ Text = "Target Filters" })
    Toggle(Combat, "Avoid Higher Level Enemies", "Ignores players and monsters with higher level or dangerous HP", "AvoidHigherLevel")
    Toggle(Combat, "Target Bugs", nil, "TargetBugs")
    Toggle(Combat, "Target Cocoons & Objects", nil, "TargetBreakables")
    Toggle(Combat, "Target Boss / Void Mosquito", nil, "TargetBoss")
    Toggle(Combat, "Target Other Players (PvP)", nil, "TargetPlayers")

    -- ── ORBS ─────────────────────────────────────────────────
    Orbs:CreateSection({ Text = "Orbs Collection" })
    Toggle(Orbs, "Orb Vacuum / Speed Sweep", "Rapidly glides through orbs without waiting for attack cooldown", "OrbVacuum")
    Toggle(Orbs, "Auto Collect Nearby Orbs", "Picks up XP orbs on the ground", "AutoOrbs")
    Toggle(Orbs, "Auto Collect Void Orbs", nil, "AutoVoidOrbs")
    Label(Orbs, "Paid Robux Orbs", "Blocked & ignored")
    Slider(Orbs, "Orb Sweep Radius", "OrbCollectRadius", 20, 200, 0)

    -- ── EVOLUTION ────────────────────────────────────────────
    Evo:CreateSection({ Text = "Evolution & Traits" })
    Toggle(Evo, "Auto Evolve Stage", "Grows to Juvenile and Adult as soon as required level is reached", "AutoEvolve")
    Toggle(Evo, "Auto Pick Traits on Level Up", nil, "AutoPickTraits")
    Dropdown(Evo, "Preferred Trait Category", { "First Available", "Offensive", "Defensive", "Movement" }, "PreferredTrait")

    Evo:CreateSection({ Text = "Spider Tree" })
    Toggle(Evo, "Auto Unlock Spiders in Tree", "Purchases new spiders as soon as you have enough coins & levels", "AutoUnlockTree")

    local spiderNames = { "GardenSpider", "Housefly", "Grasshopper", "Monarch", "JumpingSpider", "Locust", "BlackWidow", "Mosquito", "WolfSpider", "Swallowtail", "FunnelWeb", "Horsefly", "Katydid", "Tarantula", "Lubber", "LunaMoth", "Goliath", "RobberFly", "BroodMother", "AtlasMoth", "Dragonfly", "GiantHuntsman", "DeathsHeadMoth", "GiantHornet" }
    Dropdown(Evo, "Select Spider to Equip", spiderNames, "SelectedSpider")
    Button(Evo, "Equip Selected Spider", function()
        local ok, res, msg = TreeActionRemote:InvokeServer("Play", State.SelectedSpider)
        if ok and res then
            Notify("Lymn", "Switched to " .. State.SelectedSpider, 3)
        else
            Notify("Lymn", tostring(msg or "Cannot switch now"), 3)
        end
    end)

    -- ── EVENTS ───────────────────────────────────────────────
    Events:CreateSection({ Text = "Rewards Automation" })
    Toggle(Events, "Auto Claim Daily & Playtime Rewards", nil, "AutoClaimRewards")
    Button(Events, "Claim Daily Reward Now", function()
        local ok = RewardsRemote:InvokeServer("ClaimDaily")
        Notify("Lymn", ok and "Daily claimed!" or "Already claimed or failed", 3)
    end)
    Button(Events, "Claim Playtime Reward Now", function()
        local ok = RewardsRemote:InvokeServer("ClaimPlaytime")
        Notify("Lymn", ok and "Playtime reward claimed!" or "Not ready yet", 3)
    end)

    Events:CreateSection({ Text = "Void Event & Spinner" })
    local VoidPhaseLabel = Label(Events, "Void Phase", "Before")
    task.spawn(function()
        while State.Alive do
            pcall(function()
                local phase = workspace:GetAttribute("VoidEventPhase") or "Unknown"
                local live = workspace:GetAttribute("VoidLive") and "ACTIVE" or "WAITING"
                SetLabel(VoidPhaseLabel, string.format("%s  [%s]", phase, live))
            end)
            task.wait(2)
        end
    end)
    Toggle(Events, "Auto Spin Void Spinner (500 Credits)", nil, "AutoSpinVoid")
    Button(Events, "Spin Void Spinner Once", function()
        local ok, res = VoidActionRemote:InvokeServer("Spin")
        Notify("Lymn", ok and ("Spin result: " .. tostring(res)) or "Failed to spin", 3)
    end)

    -- ── TELEPORTS ────────────────────────────────────────────
    Teleports:CreateSection({ Text = "Map Zones" })
    for zoneName, coords in pairs(ZONES) do
        Button(Teleports, "Teleport: " .. zoneName, function()
            SafeTeleport(CFrame.new(coords))
            Notify("Lymn", "Teleported to " .. zoneName, 2)
        end)
    end

    Teleports:CreateSection({ Text = "Server Actions" })
    Button(Teleports, "Rejoin Server", function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    Button(Teleports, "Server Hop (Find New Server)", function()
        pcall(function()
            local sfUrl = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(game.PlaceId))
            local data = HttpService:JSONDecode(game:HttpGet(sfUrl))
            if data and data.data then
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        break
                    end
                end
            end
        end)
    end)

    -- ── MISC ─────────────────────────────────────────────────
    Misc:CreateSection({ Text = "Character Mods" })
    Toggle(Misc, "Custom WalkSpeed", nil, "WalkSpeedOn")
    Slider(Misc, "Speed Value", "WalkSpeed", 16, 120, 0)
    Toggle(Misc, "Infinite Jump", nil, "InfJump")
    Toggle(Misc, "Noclip (Walk through walls)", nil, "Noclip")
    Toggle(Misc, "Auto 3D Flight (For Flying Insects)", "Maintains flight state for flies, bees, moths, and dragonflies", "AutoFly")
    Toggle(Misc, "Anti-AFK (20 min disconnect bypass)", nil, "AntiAfk")

    Misc:CreateSection({ Text = "ESP Visuals" })
    Toggle(Misc, "Rainbow Orbs ESP (Robux / Paid)", nil, "EspRainbow", function() pcall(UpdateEsp) end)
    Toggle(Misc, "Bugs ESP", nil, "EspBugs", function() pcall(UpdateEsp) end)
    Toggle(Misc, "Breakables ESP (Cocoons)", nil, "EspBreakables", function() pcall(UpdateEsp) end)

    Notify("Success!", "Lymn loaded successfully.", 4)
end)
