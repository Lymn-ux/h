-- Lymn X MALAM SAMA OPAH (Orion Library - Compact & Clean)
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local Window = OrionLib:MakeWindow({
    Name = "Lymn X MALAM SAMA OPAH",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "LymnMalamSamaOpah",
    IntroEnabled = false -- Skip intro biar langsung buka
})

OrionLib:MakeNotification({
    Title = "Lymn",
    Content = "Script loaded successfully!",
    Image = "rbxassetid://122937454340636",
    Time = 2
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

-- Skip Cutscene (0.05 detik)
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

-- Auto Farm Loop (Teleport & Jeda Aksi 0.10 detik)
task.spawn(function()
    while true do
        task.wait(0.10)
        if autoFarmEnabled then
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart then
                local knockPrompt = nil
                pcall(function()
                    knockPrompt = workspace.Cutscenes.Markers.DoorKnock.KnockPrompt.KnockPrompt
                end)

                if knockPrompt and knockPrompt:IsA("ProximityPrompt") then
                    local targetPos = Vector3.new(301.94, 9.59, -210.44)
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
                    task.wait(0.10)
                    fireproximityprompt(knockPrompt)
                    task.wait(0.10)
                    
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
                    task.wait(0.10)

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
                    task.wait(0.10)

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
                            task.wait(0.10)
                        end

                        for _, desc in ipairs(targetLockNode:GetDescendants()) do
                            if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                fireproximityprompt(desc)
                                break
                            end
                        end
                    end
                    task.wait(0.10)

                else
                    currentCutsceneType = "OutroOpening"
                    task.wait(0.10)

                    local code = getPasscode()
                    if code and code ~= "" then
                        pcall(function()
                            local args = {code}
                            ReplicatedStorage:WaitForChild("PuzzleShared"):WaitForChild("Remotes"):WaitForChild("SubmitPasscode"):InvokeServer(unpack(args))
                        end)
                    end

                    task.wait(0.10)

                    local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
                    if targetObj then
                        local pos = targetObj:IsA("BasePart") and targetObj.Position or targetObj:GetPivot().Position
                        if pos then
                            rootPart.Velocity = Vector3.zero
                            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
                            task.wait(0.10)

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

-- Tab Pembuatan Menu Orion
local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://6035067836",
    PremiumOnly = false
})

local ExtraTab = Window:MakeTab({
    Name = "Extra",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

local InfoTab = Window:MakeTab({
    Name = "Information",
    Icon = "rbxassetid://6031075938",
    PremiumOnly = false
})

-- Main Elements
MainTab:AddToggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(Value)
        autoFarmEnabled = Value
        currentCutsceneType = "Bus"
    end
})

-- Extra Elements
ExtraTab:AddToggle({
    Name = "ESP Key & Note Code",
    Default = false,
    Callback = function(Value)
        espKeyEnabled = Value
        task.defer(updateESP)
    end
})

ExtraTab:AddToggle({
    Name = "ESP Opah",
    Default = false,
    Callback = function(Value)
        espOpahEnabled = Value
        task.defer(updateOpahESP)
    end
})

ExtraTab:AddButton({
    Name = "TP to Key",
    Callback = function()
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        local puzzleItems = workspace:FindFirstChild("PuzzleItems")
        local targetKey = puzzleItems and puzzleItems:FindFirstChild("Key")

        if targetKey then
            local pos = targetKey:IsA("BasePart") and targetKey.Position or targetKey:GetPivot().Position
            rootPart.Velocity = Vector3.zero
            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
        end
    end
})

ExtraTab:AddButton({
    Name = "TP to Safe Zone",
    Callback = function()
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.Velocity = Vector3.zero
            character:PivotTo(CFrame.new(320.51, 11.14, -227.66))
        end
    end
})

-- Info Elements
InfoTab:AddParagraph("Lymn Official", "Join our server for updates, announcements, support, and community.")
InfoTab:AddButton({
    Name = "Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/6B36mdd6cJ")
        OrionLib:MakeNotification({
            Title = "Copied!",
            Content = "Discord link copied!",
            Image = "rbxassetid://122937454340636",
            Time = 1.5
        })
    end
})

InfoTab:AddButton({
    Name = "Copy TikTok Link",
    Callback = function()
        setclipboard("https://www.tiktok.com/@michel.ljw")
        OrionLib:MakeNotification({
            Title = "Copied!",
            Content = "TikTok link copied!",
            Image = "rbxassetid://122937454340636",
            Time = 1.5
        })
    end
})

-- Paksa scale/ukuran window Orion supaya lebih compact di HP
pcall(function()
    local mainFrame = game:GetService("CoreGui"):FindFirstChild("Orion")
    if mainFrame then
        for _, v in ipairs(mainFrame:GetDescendants()) do
            if v.Name == "Container" and v:IsA("Frame") then
                v.Size = UDim2.new(0, 420, 0, 280)
            end
        end
    end
end)

OrionLib:Init()
