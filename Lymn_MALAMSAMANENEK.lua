-- Lymn X MALAM SAMA OPAH
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/UiLibary/x/refs/heads/main/source.lua"))()

local Window = Library:NewWindow(
    "Lymn X MALAM SAMA OPAH",
    122937454340636,
    2,
    "grey"
)

Library:SendNotification("Lymn", "Script loaded successfully!", 2, 122937454340636, 2, "grey")

Window:SetFooter(
    "https://discord.gg/6B36mdd6cJ",
    16584754883,
    2
)

local VisualSection = Window:NewSection("Visual")
local TeleportSection = Window:NewSection("Teleport")
local MainSection = Window:NewSection("Main")
local CreditsSection = Window:NewSection("Credits")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local espKeyEnabled = false
local espOpahEnabled = false
local autoFarmEnabled = false
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

                createESP(item, "Key: " + colorName, itemColor, activeESPObjects)
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

-- Loop Auto Farm Mandiri dengan Progress Notification
task.spawn(function()
    while true do
        task.wait(0.2)
        if autoFarmEnabled then
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart then
                -- 1. Door Knock Handler
                local doorKnockObj = nil
                pcall(function()
                    doorKnockObj = workspace.Cutscenes.Markers.DoorKnock
                end)

                if doorKnockObj and not workspace:FindFirstChild("DoorKnockDone_Flag") then
                    local targetPos = Vector3.new(301.94, 9.59, -210.44)
                    pcall(function()
                        if doorKnockObj:IsA("BasePart") then
                            targetPos = doorKnockObj.Position
                        elseif doorKnockObj:IsA("Model") then
                            targetPos = doorKnockObj:GetPivot().Position
                        elseif doorKnockObj:IsA("Attachment") then
                            targetPos = doorKnockObj.WorldPosition
                        end
                    end)

                    rootPart.Velocity = Vector3.zero
                    character:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
                    task.wait(0.3)

                    pcall(function()
                        local prompt = workspace.Cutscenes.Markers.DoorKnock:FindFirstChild("DoorKnock") or workspace.Cutscenes.Markers.DoorKnock:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and prompt:IsA("ProximityPrompt") then
                            fireproximityprompt(prompt)
                        end
                    end)

                    local flag = Instance.new("Folder")
                    flag.Name = "DoorKnockDone_Flag"
                    flag.Parent = workspace
                    task.wait(0.5)

                    -- Remote Event setelah DoorKnock selesai
                    pcall(function()
                        local args = {"SkipVote", "Reveal"}
                        ReplicatedStorage:WaitForChild("Cutscenes"):WaitForChild("Remote"):FireServer(unpack(args))
                    end)

                    Library:SendNotification("Progress", "Door Knocked: 10%", 2, 122937454340636, 2, "grey")
                end

                -- Hitung total key awal untuk kalkulasi progress persen (10% + [10% per key])
                local initialTotalKeys = 5
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
                local keysCollectedCount = initialTotalKeys - currentKeysLeft
                local currentPercent = math.clamp(10 + (keysCollectedCount * 10), 10, 60)

                -- 3. Eksekusi Ambil Key + Buka Lock Pintu
                if currentKeysLeft > 0 then
                    local targetKey = keysList[1]
                    local targetPos = targetKey:IsA("BasePart") and targetKey.Position or targetKey:GetPivot().Position
                    local colorStr = getKeyColor(targetKey)

                    -- TP ke Key
                    rootPart.Velocity = Vector3.zero
                    character:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
                    task.wait(0.2)

                    -- Buka SEMUA Drawer Chest terdekat
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
                    task.wait(0.3)

                    -- Fire Prompt Ambil Key
                    local rootPartKey = targetKey:FindFirstChild("Root")
                    local attachment = rootPartKey and rootPartKey:FindFirstChild("ItemPromptAttachment")
                    local puzzlePrompt = attachment and attachment:FindFirstChild("PuzzlePrompt")
                    if puzzlePrompt and puzzlePrompt:IsA("ProximityPrompt") then
                        fireproximityprompt(puzzlePrompt)
                    end
                    task.wait(0.4)

                    -- Pindah Ke Lock Pintu Sesuai Warna
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
                            task.wait(0.2)
                        end

                        for _, desc in ipairs(targetLockNode:GetDescendants()) do
                            if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                fireproximityprompt(desc)
                                break
                            end
                        end
                    end
                    task.wait(0.4)

                    Library:SendNotification("Progress", "Key Collected & Locked (" .. tostring(keysCollectedCount + 1) .. "/5): " .. tostring(currentPercent + 10) .."%", 2, 122937454340636, 2, "grey")

                else
                    -- 4. Jika Key Sudah Habis (0) -> Remote OutroOpening -> Submit Code (85%) -> Escape (100%)
                    pcall(function()
                        local args = {"SkipVote", "OutroOpening"}
                        ReplicatedStorage:WaitForChild("Cutscenes"):WaitForChild("Remote"):FireServer(unpack(args))
                    end)
                    task.wait(0.3)

                    local code = getPasscode()
                    if code and code ~= "" then
                        pcall(function()
                            local args = {code}
                            ReplicatedStorage:WaitForChild("PuzzleShared"):WaitForChild("Remotes"):WaitForChild("SubmitPasscode"):InvokeServer(unpack(args))
                        end)
                        Library:SendNotification("Progress", "Passcode Submitted: 85%", 2, 122937454340636, 2, "grey")
                    end

                    task.wait(0.3)

                    -- Teleport ke Actor_AtokBelalang buat Escape
                    local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
                    if targetObj then
                        local pos = targetObj:IsA("BasePart") and targetObj.Position or targetObj:GetPivot().Position
                        if pos then
                            rootPart.Velocity = Vector3.zero
                            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
                            task.wait(0.2)

                            pcall(function()
                                local args = {"SkipVote", "OutroDrive"}
                                ReplicatedStorage:WaitForChild("Cutscenes"):WaitForChild("Remote"):FireServer(unpack(args))
                            end)

                            for _, obj in ipairs(targetObj:GetDescendants()) do
                                if obj:IsA("ProximityPrompt") then
                                    fireproximityprompt(obj)
                                end
                            end

                            Library:SendNotification("Progress", "Escaped Successfully: 100%", 3, 122937454340636, 2, "grey")
                        end
                    end
                    task.wait(1)
                end
            end
        end
    end
end)

-- Visual Section
VisualSection:CreateToggle("Esp Key And Note Code", false, function(Value)
    espKeyEnabled = Value
    task.defer(updateESP)
    Library:SendNotification("ESP", "ESP Key & Note status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

VisualSection:CreateToggle("Esp Opah", false, function(Value)
    espOpahEnabled = Value
    task.defer(updateOpahESP)
    Library:SendNotification("ESP", "ESP Opah status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

-- Teleport Section
TeleportSection:CreateButton("TP to Key", function()
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local puzzleItems = workspace:FindFirstChild("PuzzleItems")
    local targetKey = puzzleItems and puzzleItems:FindFirstChild("Key")

    if targetKey then
        local pos = targetKey:IsA("BasePart") and targetKey.Position or targetKey:GetPivot().Position
        rootPart.Velocity = Vector3.zero
        character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
        Library:SendNotification("Teleport", "Successfully teleported to Key!", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Error", "Key not found in PuzzleItems!", 2, 122937454340636, 2, "grey")
    end
end)

TeleportSection:CreateButton("TP to Safe Zone", function()
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Velocity = Vector3.zero
        character:PivotTo(CFrame.new(320.51, 11.14, -227.66))
        Library:SendNotification("Teleport", "Teleported to Safe Zone!", 2, 122937454340636, 2, "grey")
    end
end)

-- Main Section
MainSection:CreateToggle("Auto Farm", false, function(Value)
    autoFarmEnabled = Value
    pcall(function()
        if workspace:FindFirstChild("DoorKnockDone_Flag") then
            workspace.DoorKnockDone_Flag:Destroy()
        end
    end)
    Library:SendNotification("Auto Farm", "Auto Farm status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

MainSection:CreateButton("Code Reveal", function()
    local code = getPasscode()
    if code and code ~= "" then
        Library:SendNotification("Code Reveal", "Code : " .. code, 5, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Error", "PasscodeNote not found!", 3, 122937454340636, 2, "grey")
    end
end)

-- Credits Section
CreditsSection:CreateButton("Copy TikTok", function()
    setclipboard("https://www.tiktok.com/@michel.ljw")
    Library:SendNotification("Copied!", "TikTok link copied to clipboard!", 3, 17757765730, 2)
end)

CreditsSection:CreateButton("Copy Discord", function()
    setclipboard("https://discord.gg/6B36mdd6cJ")
    Library:SendNotification("Copied!", "Discord invite copied to clipboard!", 3, 16584754883, 2)
end)
