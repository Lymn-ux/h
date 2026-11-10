-- Lymn X MALAM SAMA OPAH (Auto Farm, TP, & ESP)
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
    Name = "Song Hub | Malam Sama Opah", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "LymnOpahConfig",
    IntroEnabled = false
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local autoFarmEnabled = false
local espKeyEnabled = false
local espOpahEnabled = false
local currentCutsceneType = "Bus" 
local activeESPObjects = {}
local activeOpahESPObjects = {}

-- Safezone Position Sesuai Request
local safezonePos = Vector3.new(309.77, 11.14, -223.19)

local function createESP(obj, textName, color, storageTable)
    if not obj then return end
    local targetPart = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
    if targetPart and not targetPart:FindFirstChild("LymnESP_Folder") then
        local container = Instance.new("Folder")
        container.Name = "LymnESP_Folder"
        container.Parent = targetPart

        local hl = Instance.new("Highlight")
        hl.Name = "LymnHighlight"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 0
        hl.Adornee = obj
        hl.Parent = container

        local bb = Instance.new("BillboardGui")
        bb.Name = "LymnTitle"
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = targetPart
        bb.Parent = container

        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = bb
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.Text = textName
        textLabel.TextColor3 = color
        textLabel.TextSize = 14
        textLabel.TextStrokeTransparency = 0

        table.insert(storageTable, container)
    end
end

local function updateESP()
    for _, item in ipairs(activeESPObjects) do
        if item then item:Destroy() end
    end
    table.clear(activeESPObjects)

    if not espKeyEnabled then return end

    local puzzleItems = workspace:FindFirstChild("PuzzleItems")
    if puzzleItems then
        for _, item in ipairs(puzzleItems:GetChildren()) do
            if item.Name == "Key" then
                local colorName = "Unknown"
                local itemColor = Color3.fromRGB(255, 255, 255)

                local keyColorProp = item:FindFirstChild("KeyColor")
                if keyColorProp then
                    colorName = tostring(keyColorProp.Value)
                elseif item:GetAttribute("KeyColor") then
                    colorName = tostring(item:GetAttribute("KeyColor"))
                end

                local lowerColor = string.lower(colorName)
                if lowerColor:find("purple") or lowerColor:find("tulip") then
                    itemColor = Color3.fromRGB(170, 0, 255)
                elseif lowerColor:find("blue") then
                    itemColor = Color3.fromRGB(50, 150, 255)
                elseif lowerColor:find("red") then
                    itemColor = Color3.fromRGB(255, 50, 50)
                elseif lowerColor:find("yellow") or lowerColor:find("gold") then
                    itemColor = Color3.fromRGB(255, 215, 0)
                elseif lowerColor:find("green") then
                    itemColor = Color3.fromRGB(50, 255, 50)
                end

                createESP(item, "Key: " .. colorName, itemColor, activeESPObjects)
            end
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "PasscodeNote" then
            createESP(obj, "PasscodeNote", Color3.fromRGB(0, 255, 255), activeESPObjects)
        end
    end
end

local function updateOpahESP()
    for _, item in ipairs(activeOpahESPObjects) do
        if item then item:Destroy() end
    end
    table.clear(activeOpahESPObjects)

    if not espOpahEnabled then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Opah" and (obj:IsA("Model") or obj:IsA("BasePart")) then
            createESP(obj, "Opah", Color3.fromRGB(255, 0, 0), activeOpahESPObjects)
        end
    end
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
    Icon = "rbxassetid://18102581819",
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

-- Tab Visual / ESP
local TabVisual = Window:MakeTab({
    Name = "Visuals",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

TabVisual:AddToggle({
    Name = "ESP Key & Note Code",
    Default = false,
    Callback = function(Value)
        espKeyEnabled = Value
        task.defer(updateESP)
    end
})

TabVisual:AddToggle({
    Name = "ESP Opah",
    Default = false,
    Callback = function(Value)
        espOpahEnabled = Value
        task.defer(updateOpahESP)
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
                    
                    local colorName = "Unknown"
                    local keyColorProp = targetKey:FindFirstChild("KeyColor")
                    if keyColorProp then
                        colorName = tostring(keyColorProp.Value)
                    elseif targetKey:GetAttribute("KeyColor") then
                        colorName = tostring(targetKey:GetAttribute("KeyColor"))
                    end

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

                    local lowerColor = string.lower(colorName)
                    local lockIndex = "1"
                    if lowerColor:find("red") then lockIndex = "1"
                    elseif lowerColor:find("blue") then lockIndex = "2"
                    elseif lowerColor:find("green") then lockIndex = "3"
                    elseif lowerColor:find("yellow") or lowerColor:find("gold") then lockIndex = "4"
                    elseif lowerColor:find("purple") or lowerColor:find("tulip") then lockIndex = "5" end

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

OrionLib:Init()
