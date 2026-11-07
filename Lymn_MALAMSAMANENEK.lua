-- Lymn X MALAM SAMA OPAH (Orion Library - No Loading Intro)
local allowedExecutorID = 101051454784523

-- Validasi Executor Whitelist
local executorValid = false
pcall(function()
    executorValid = true
end)

if tostring(allowedExecutorID) ~= "101051454784523" then
    game.Players.LocalPlayer:Kick("Lymn Security: Executor ID tidak diizinkan!")
    return
end

local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
local Window = OrionLib:MakeWindow({
    Name = "Lymn | Malam Sama Opah", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "LymnOpahConfig",
    IntroEnabled = false -- Loading dimatiin biar langsung ke-load instan
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local autoFarmEnabled = false
local espOpahEnabled = false
local espPlayerEnabled = false
local espKeyEnabled = false
local currentCutsceneType = "Bus" 

-- Storage untuk ESP Highlights
local espObjects = {
    Opah = {},
    Players = {},
    Keys = {}
}

local safezonePos = Vector3.new(301.94, 9.59, -210.44)

local function getKeyColor(keyObj)
    local colorName = ""
    local keyColorProp = keyObj:FindFirstChild("KeyColor")
    if keyColorProp then
        colorName = tostring(keyColorProp.Value)
    elseif keyObj:GetAttribute("KeyColor") then
        colorName = tostring(keyObj:GetAttribute("KeyColor"))
    end
    return string.lower(colorName)
end

local function getPasscode()
    local passcodeNote = workspace:FindFirstChild("PuzzleItems") and workspace.PuzzleItems:FindFirstChild("PasscodeNote")
    if not passcodeNote then
        passcodeNote = workspace:FindFirstChild("PasscodeNote", true)
    end

    if passcodeNote then
        local paper = passcodeNote:FindFirstChild("Paper")
        local writing = paper and paper:FindFirstChild("Writing")
        local codeObj = writing and writing:FindFirstChild("Code")
        if codeObj and (codeObj:IsA("TextLabel") or codeObj:IsA("TextBox") or codeObj:IsA("SurfaceGui")) then
            return string.gsub(tostring(codeObj.Text), "%s+", "")
        end
    end
    return nil
end

-- Tab Utama
local TabMain = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabMain:AddToggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(Value)
        autoFarmEnabled = Value
    end
})

TabMain:AddButton({
    Name = "TP Safezone",
    Callback = function()
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char:PivotTo(CFrame.new(safezonePos))
        end
    end
})

TabMain:AddButton({
    Name = "TP Nearest Key",
    Callback = function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local puzzleItems = workspace:FindFirstChild("PuzzleItems")
        if root and puzzleItems then
            for _, item in ipairs(puzzleItems:GetChildren()) do
                if item.Name == "Key" then
                    local pos = item:IsA("BasePart") and item.Position or item:GetPivot().Position
                    char:PivotTo(CFrame.new(pos + Vector3.new(0, 2, 0)))
                    break
                end
            end
        end
    end
})

-- Tab ESP & Visuals
local TabESP = Window:MakeTab({
    Name = "Visuals",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabESP:AddToggle({
    Name = "Opah ESP",
    Default = false,
    Callback = function(Value)
        espOpahEnabled = Value
        if not Value then
            for _, obj in pairs(espObjects.Opah) do
                if obj then obj:Destroy() end
            end
            espObjects.Opah = {}
        end
    end
})

TabESP:AddToggle({
    Name = "Player ESP",
    Default = false,
    Callback = function(Value)
        espPlayerEnabled = Value
        if not Value then
            for _, obj in pairs(espObjects.Players) do
                if obj then obj:Destroy() end
            end
            espObjects.Players = {}
        end
    end
})

TabESP:AddToggle({
    Name = "Key ESP",
    Default = false,
    Callback = function(Value)
        espKeyEnabled = Value
        if not Value then
            for _, obj in pairs(espObjects.Keys) do
                if obj then obj:Destroy() end
            end
            espObjects.Keys = {}
        end
    end
})

-- Skip Cutscene Loop (0.05s)
task.spawn(function()
    while true do
        task.wait(0.05)
        if autoFarmEnabled then
            pcall(function()
                local args = {"SkipVote", currentCutsceneType}
                ReplicatedStorage:WaitForChild("Cutscenes"):WaitForChild("Remote"):FireServer(unpack(args))
            end)
        end
    end
end)

-- Auto Farm Core Loop (TP 0.25s, Prompt 0s Instant)
task.spawn(function()
    while true do
        task.wait(0.25)
        if autoFarmEnabled then
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart then
                local knockPrompt = nil
                pcall(function()
                    knockPrompt = workspace.Cutscenes.Markers.DoorKnock.KnockPrompt.KnockPrompt
                end)

                if knockPrompt and knockPrompt:IsA("ProximityPrompt") then
                    local targetPos = safezonePos
                    pcall(function()
                        local knockPart = knockPrompt.Parent
                        if knockPart and knockPart:IsA("BasePart") then
                            targetPos = knockPart.Position
                        elseif knockPart and knockPart:IsA("Model") then
                            targetPos = knockPart:GetPivot().Position
                        end
                    end)

                    rootPart.Velocity = Vector3.zero
                    character:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
                    task.wait(0.25)
                    fireproximityprompt(knockPrompt)
                    
                    currentCutsceneType = "Reveal"
                    continue 
                end

                local puzzleItems = workspace:FindFirstChild("PuzzleItems")
                local keysList = {}
                if puzzleItems then
                    for _, item in ipairs(puzzleItems:GetChildren()) do
                        if item.Name == "Key" then
                            table.insert(keysList, item)
                        end
                    end
                end

                local currentKeysLeft = #keysList

                if currentKeysLeft > 0 then
                    local targetKey = keysList[1]
                    local targetPos = targetKey:IsA("BasePart") and targetKey.Position or targetKey:GetPivot().Position
                    local colorStr = getKeyColor(targetKey)

                    rootPart.Velocity = Vector3.zero
                    character:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
                    task.wait(0.25)

                    local puzzleChests = workspace:FindFirstChild("PuzzleChests")
                    if puzzleChests then
                        for _, chest in ipairs(puzzleChests:GetChildren()) do
                            local chestPos = chest:IsA("BasePart") and chest.Position or chest:GetPivot().Position
                            if chestPos and (targetPos - chestPos).Magnitude <= 8 then
                                for _, desc in ipairs(chest:GetDescendants()) do
                                    if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                        fireproximityprompt(desc)
                                    end
                                end
                            end
                        end
                    end

                    local rootPartKey = targetKey:FindFirstChild("Root")
                    local attachment = rootPartKey and rootPartKey:FindFirstChild("ItemPromptAttachment")
                    local puzzlePrompt = attachment and attachment:FindFirstChild("PuzzlePrompt")
                    if puzzlePrompt and puzzlePrompt:IsA("ProximityPrompt") then
                        fireproximityprompt(puzzlePrompt)
                    end

                    local lockIndex = "1"
                    if colorStr:find("red") then lockIndex = "1"
                    elseif colorStr:find("blue") then lockIndex = "2"
                    elseif colorStr:find("green") then lockIndex = "3"
                    elseif colorStr:find("yellow") or colorStr:find("gold") then lockIndex = "4"
                    elseif colorStr:find("purple") or colorStr:find("tulip") then lockIndex = "5" end

                    local frontDoor = workspace:FindFirstChild("FrontDoor")
                    local puzzleLocks = frontDoor and frontDoor:FindFirstChild("PuzzleLocks")
                    local targetLockNode = puzzleLocks and (puzzleLocks:FindFirstChild("Lock_" .. lockIndex) or puzzleLocks:FindFirstChild("Lock_1"))

                    if targetLockNode then
                        local padlockBody = targetLockNode:FindFirstChild("Padlock") and targetLockNode.Padlock:FindFirstChild("Body")
                        if padlockBody then
                            local lockPos = padlockBody:IsA("BasePart") and padlockBody.Position or padlockBody:GetPivot().Position
                            rootPart.Velocity = Vector3.zero
                            character:PivotTo(CFrame.new(lockPos + Vector3.new(0, 0, 3)))
                            task.wait(0.25)
                        end

                        for _, desc in ipairs(targetLockNode:GetDescendants()) do
                            if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                fireproximityprompt(desc)
                                break
                            end
                        end
                    end

                else
                    currentCutsceneType = "OutroOpening"
                    task.wait(0.25)

                    local code = getPasscode()
                    if code and code ~= "" then
                        pcall(function()
                            local args = {code}
                            ReplicatedStorage:WaitForChild("PuzzleShared"):WaitForChild("Remotes"):WaitForChild("SubmitPasscode"):InvokeServer(unpack(args))
                        end)
                    end

                    local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
                    if targetObj then
                        local pos = targetObj:IsA("BasePart") and targetObj.Position or targetObj:GetPivot().Position
                        if pos then
                            rootPart.Velocity = Vector3.zero
                            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
                            task.wait(0.25)

                            currentCutsceneType = "OutroDrive"

                            for _, obj in ipairs(targetObj:GetDescendants()) do
                                if obj:IsA("ProximityPrompt") then
                                    fireproximityprompt(obj)
                                end
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end
        end
    end
end)

-- ESP Rendering Loop
RunService.RenderStepped:Connect(function()
    if espKeyEnabled then
        local puzzleItems = workspace:FindFirstChild("PuzzleItems")
        if puzzleItems then
            for _, item in ipairs(puzzleItems:GetChildren()) do
                if item.Name == "Key" then
                    local hl = item:FindFirstChild("LymnKeyESP")
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "LymnKeyESP"
                        hl.FillColor = Color3.fromRGB(255, 215, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = item
                        table.insert(espObjects.Keys, hl)
                    end
                end
            end
        end
    end

    if espPlayerEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hl = p.Character:FindFirstChild("LymnPlayerESP")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "LymnPlayerESP"
                    hl.FillColor = Color3.fromRGB(0, 255, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.Parent = p.Character
                    table.insert(espObjects.Players, hl)
                end
            end
        end
    end

    if espOpahEnabled then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name:lower():find("opah") or obj.Name:lower():find("atok") or obj.Name:lower():find("monster") then
                local hl = obj:FindFirstChild("LymnOpahESP")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "LymnOpahESP"
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.Parent = obj
                    table.insert(espObjects.Opah, hl)
                end
            end
        end
    end
end)

OrionLib:Init()
