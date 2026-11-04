-- Kaitun Lymn Malam Sama Opah
-- No UI library: blurred screen + logo + title + timer + progress status

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local LOGO_ID = 122937454340636
local TITLE = "Kaitun Lymn Malam Sama Opah"
local LOADING_DELAY = 1.5

-- Clean up old instance if executed twice
pcall(function()
    local old = (gethui and gethui() or CoreGui):FindFirstChild("LymnKaitunGui")
    if old then old:Destroy() end
    local oldBlur = Lighting:FindFirstChild("LymnKaitunBlur")
    if oldBlur then oldBlur:Destroy() end
end)

------------------------------------------------------------
-- UI OVERLAY
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LymnKaitunGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
gui.Parent = (gethui and gethui()) or CoreGui

local blur = Instance.new("BlurEffect")
blur.Name = "LymnKaitunBlur"
blur.Size = 0
blur.Parent = Lighting
TweenService:Create(blur, TweenInfo.new(0.8), {Size = 28}):Play()

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Active = true -- blocks clicks to the game
dim.Parent = gui
TweenService:Create(dim, TweenInfo.new(0.8), {BackgroundTransparency = 0.45}):Play()

local center = Instance.new("Frame")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromOffset(460, 390)
center.BackgroundTransparency = 1
center.Parent = gui

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 14)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = center

-- Timer (top)
local timerLabel = Instance.new("TextLabel")
timerLabel.LayoutOrder = 0
timerLabel.Size = UDim2.new(1, 0, 0, 30)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Text = "00:00"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.TextSize = 24
timerLabel.Parent = center

local logo = Instance.new("ImageLabel")
logo.LayoutOrder = 1
logo.Size = UDim2.fromOffset(110, 110)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://" .. LOGO_ID
logo.ScaleType = Enum.ScaleType.Crop
logo.ClipsDescendants = true
logo.Parent = center
Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 26)
local logoStroke = Instance.new("UIStroke", logo)
logoStroke.Color = Color3.fromRGB(255, 255, 255)
logoStroke.Thickness = 2
logoStroke.Transparency = 0.4

local title = Instance.new("TextLabel")
title.LayoutOrder = 2
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = TITLE
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 28
title.Parent = center

local status = Instance.new("TextLabel")
status.LayoutOrder = 3
status.Size = UDim2.new(1, 0, 0, 26)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = "Loading..."
status.TextColor3 = Color3.fromRGB(210, 210, 210)
status.TextSize = 18
status.Parent = center

local barBg = Instance.new("Frame")
barBg.LayoutOrder = 4
barBg.Size = UDim2.new(0.8, 0, 0, 8)
barBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
barBg.BorderSizePixel = 0
barBg.Parent = center
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local percent = Instance.new("TextLabel")
percent.LayoutOrder = 5
percent.Size = UDim2.new(1, 0, 0, 20)
percent.BackgroundTransparency = 1
percent.Font = Enum.Font.GothamMedium
percent.Text = "0%"
percent.TextColor3 = Color3.fromRGB(170, 170, 170)
percent.TextSize = 14
percent.Parent = center

local function setStatus(text, pct)
    status.Text = text
    if pct then
        pct = math.clamp(pct, 0, 100)
        percent.Text = string.format("%d%%", pct)
        TweenService:Create(barFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
            Size = UDim2.fromScale(pct / 100, 1)
        }):Play()
    end
end

-- Floating logo animation
task.spawn(function()
    local t = 0
    while gui.Parent do
        t += RunService.Heartbeat:Wait()
        logo.Position = UDim2.fromOffset(0, math.sin(t * 2) * 4)
    end
end)

------------------------------------------------------------
-- TIMER
------------------------------------------------------------
local runStart = nil      -- set after loading finishes
local frozenTime = nil    -- set when the run is completed

local function formatTime(sec)
    sec = math.floor(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

task.spawn(function()
    while gui.Parent do
        if runStart then
            timerLabel.Text = formatTime(frozenTime or (os.clock() - runStart))
        end
        task.wait(0.25)
    end
end)

------------------------------------------------------------
-- ANTI AFK
------------------------------------------------------------
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

------------------------------------------------------------
-- LOADING DELAY (1.5s)
------------------------------------------------------------
setStatus("Loading...", 0)
task.wait(LOADING_DELAY)
runStart = os.clock()

------------------------------------------------------------
-- KAITUN LOGIC
------------------------------------------------------------
local currentCutsceneType = "Bus"
local TOTAL_KEYS = 5

-- Auto skip cutscene
task.spawn(function()
    while gui.Parent do
        task.wait(0.1)
        pcall(function()
            ReplicatedStorage:WaitForChild("Cutscenes"):WaitForChild("Remote"):FireServer("SkipVote", currentCutsceneType)
        end)
    end
end)

local function getPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Attachment") then return obj.WorldPosition end
    return obj:GetPivot().Position
end

local function getKeyColor(keyObj)
    local colorName = ""
    local prop = keyObj:FindFirstChild("KeyColor")
    if prop then
        colorName = tostring(prop.Value)
    elseif keyObj:GetAttribute("KeyColor") then
        colorName = tostring(keyObj:GetAttribute("KeyColor"))
    end
    return string.lower(colorName)
end

local function getPasscode()
    local note = workspace:FindFirstChild("PuzzleItems") and workspace.PuzzleItems:FindFirstChild("PasscodeNote")
    if not note then
        note = workspace:FindFirstChild("PasscodeNote", true)
    end
    if note then
        local paper = note:FindFirstChild("Paper")
        local writing = paper and paper:FindFirstChild("Writing")
        local codeObj = writing and writing:FindFirstChild("Code")
        if codeObj and (codeObj:IsA("TextLabel") or codeObj:IsA("TextBox") or codeObj:IsA("SurfaceGui")) then
            return string.gsub(tostring(codeObj.Text), "%s+", "")
        end
    end
    return nil
end

local function tp(rootPart, character, pos)
    rootPart.Velocity = Vector3.zero
    character:PivotTo(CFrame.new(pos))
end

local doorKnockDone = false
local passcodeSubmitted = false
local finished = false
local startClock = os.clock()

local function resetRound()
    doorKnockDone = false
    passcodeSubmitted = false
    finished = false
    frozenTime = nil
    runStart = os.clock()
    startClock = os.clock()
    currentCutsceneType = "Bus"
    setStatus("New round detected...", 0)
end

task.spawn(function()
    while gui.Parent do
        task.wait(0.2)

        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        local puzzleItems = workspace:FindFirstChild("PuzzleItems")

        if finished then
            -- Run is done: stay at 100%, only watch for a new round
            if puzzleItems and puzzleItems:FindFirstChild("Key") then
                resetRound()
            else
                task.wait(1)
            end
            continue
        end

        if not rootPart then
            setStatus("Waiting for character...", nil)
        else
            -- 1. Door Knock (remote: Reveal)
            local doorKnockObj
            pcall(function()
                doorKnockObj = workspace.Cutscenes.Markers.DoorKnock
            end)

            -- Wait for the DoorKnock marker (max 25s), then move on to keys
            if not doorKnockDone and not doorKnockObj and (os.clock() - startClock) < 25 then
                setStatus("Waiting for the door to be ready...", 3)
                task.wait(0.5)
                continue
            end

            if doorKnockObj and not doorKnockDone then
                currentCutsceneType = "Reveal"
                setStatus("Knocking on the door...", 5)
                local targetPos = Vector3.new(301.94, 9.59, -210.44)
                pcall(function() targetPos = getPos(doorKnockObj) end)

                for attempt = 1, 12 do
                    tp(rootPart, character, targetPos + Vector3.new(0, 2, 0))
                    task.wait(0.3)

                    local prompt
                    pcall(function()
                        prompt = doorKnockObj:FindFirstChild("DoorKnock", true)
                        if not (prompt and prompt:IsA("ProximityPrompt")) then
                            prompt = doorKnockObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        end
                        if not prompt and doorKnockObj.Parent then
                            prompt = doorKnockObj.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
                        end
                    end)

                    if prompt and prompt:IsA("ProximityPrompt") then
                        pcall(function()
                            prompt.HoldDuration = 0
                            prompt.RequiresLineOfSight = false
                            prompt.MaxActivationDistance = 50
                        end)
                        pcall(function() fireproximityprompt(prompt) end)
                        pcall(function()
                            prompt:InputHoldBegin()
                            task.wait(0.1)
                            prompt:InputHoldEnd()
                        end)
                        setStatus("Knocking on the door... (attempt " .. attempt .. ")", 6)
                        task.wait(0.8)
                        local stillThere = false
                        pcall(function()
                            stillThere = workspace.Cutscenes.Markers.DoorKnock ~= nil
                        end)
                        if not stillThere then break end
                        if attempt >= 4 then break end
                    else
                        setStatus("Looking for the door prompt... (" .. attempt .. ")", 5)
                        task.wait(0.5)
                    end
                end

                doorKnockDone = true
                task.wait(0.5)
            end

            -- 2. Count remaining keys
            local keysList = {}
            if puzzleItems then
                for _, item in ipairs(puzzleItems:GetChildren()) do
                    if item.Name == "Key" then
                        table.insert(keysList, item)
                    end
                end
            end

            local keysLeft = #keysList
            local collected = math.clamp(TOTAL_KEYS - keysLeft, 0, TOTAL_KEYS)

            if keysLeft > 0 then
                -- 3. Collect key + unlock padlock (remote stays Reveal)
                if currentCutsceneType == "Bus" and doorKnockDone then
                    currentCutsceneType = "Reveal"
                end

                setStatus(string.format("Collecting key %d/%d", collected + 1, TOTAL_KEYS), 10 + (collected / TOTAL_KEYS) * 65)

                local targetKey = keysList[1]
                local targetPos = getPos(targetKey)
                local colorStr = getKeyColor(targetKey)

                tp(rootPart, character, targetPos + Vector3.new(0, 2, 0))
                task.wait(0.2)

                local puzzleChests = workspace:FindFirstChild("PuzzleChests")
                if puzzleChests then
                    for _, chest in ipairs(puzzleChests:GetChildren()) do
                        local chestPos = getPos(chest)
                        if chestPos and (targetPos - chestPos).Magnitude <= 8 then
                            for _, desc in ipairs(chest:GetDescendants()) do
                                if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                    fireproximityprompt(desc)
                                end
                            end
                        end
                    end
                end
                task.wait(0.3)

                local keyRoot = targetKey:FindFirstChild("Root")
                local attachment = keyRoot and keyRoot:FindFirstChild("ItemPromptAttachment")
                local puzzlePrompt = attachment and attachment:FindFirstChild("PuzzlePrompt")
                if puzzlePrompt and puzzlePrompt:IsA("ProximityPrompt") then
                    fireproximityprompt(puzzlePrompt)
                end
                task.wait(0.4)

                setStatus(string.format("Unlocking padlock %d/%d", collected + 1, TOTAL_KEYS), 10 + ((collected + 0.6) / TOTAL_KEYS) * 65)

                local lockIndex = "1"
                if colorStr:find("red") then lockIndex = "1"
                elseif colorStr:find("blue") then lockIndex = "2"
                elseif colorStr:find("green") then lockIndex = "3"
                elseif colorStr:find("yellow") or colorStr:find("gold") then lockIndex = "4"
                elseif colorStr:find("purple") or colorStr:find("tulip") then lockIndex = "5" end

                local frontDoor = workspace:FindFirstChild("FrontDoor")
                local puzzleLocks = frontDoor and frontDoor:FindFirstChild("PuzzleLocks")
                local lockNode = puzzleLocks and (puzzleLocks:FindFirstChild("Lock_" .. lockIndex) or puzzleLocks:FindFirstChild("Lock_1"))

                if lockNode then
                    local padlockBody = lockNode:FindFirstChild("Padlock") and lockNode.Padlock:FindFirstChild("Body")
                    if padlockBody then
                        tp(rootPart, character, getPos(padlockBody) + Vector3.new(0, 0, 3))
                        task.wait(0.2)
                    end

                    for _, desc in ipairs(lockNode:GetDescendants()) do
                        if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                            fireproximityprompt(desc)
                            break
                        end
                    end
                end
                task.wait(0.4)
            else
                -- 4. Submit passcode ONCE (remote: OutroOpening)
                currentCutsceneType = "OutroOpening"

                if not passcodeSubmitted then
                    setStatus("Submitting passcode...", 80)
                    task.wait(0.3)

                    local code = getPasscode()
                    if code and code ~= "" then
                        pcall(function()
                            ReplicatedStorage:WaitForChild("PuzzleShared"):WaitForChild("Remotes"):WaitForChild("SubmitPasscode"):InvokeServer(code)
                        end)
                        passcodeSubmitted = true
                    end
                    task.wait(0.3)
                end

                -- 5. Escape (remote: OutroDrive)
                local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
                if targetObj then
                    setStatus("Escaping with Atok Belalang...", 92)
                    tp(rootPart, character, getPos(targetObj) + Vector3.new(0, 3, 0))
                    task.wait(0.2)

                    currentCutsceneType = "OutroDrive"

                    for _, obj in ipairs(targetObj:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            fireproximityprompt(obj)
                        end
                    end

                    -- Teleported + OutroDrive active: instantly 100%, no more passcode
                    finished = true
                    frozenTime = os.clock() - runStart
                    setStatus("Completed! Waiting for the next round...", 100)
                else
                    setStatus("Waiting for outro...", 85)
                end
                task.wait(1)
            end
        end
    end
end)
