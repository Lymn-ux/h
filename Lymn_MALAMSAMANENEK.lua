-- Lymn X MALAM SAMA OPAH
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/AetherXOfficial/x/refs/heads/main/UiLibary"))()

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
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local espKeyEnabled = false
local espOpahEnabled = false
local escapeEnabled = false
local autoFarmEnabled = false
local activeESPObjects = {}
local activeOpahESPObjects = {}

local function createESP(obj, textName, color, storageTable)
    if not obj then return end
    
    local targetPart = nil
    if obj:IsA("BasePart") then
        targetPart = obj
    elseif obj:IsA("Model") then
        targetPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end

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
                    if keyColorProp:IsA("StringValue") then
                        colorName = keyColorProp.Value
                    elseif type(keyColorProp.Value) == "string" then
                        colorName = keyColorProp.Value
                    end
                elseif item:GetAttribute("KeyColor") then
                    colorName = tostring(item:GetAttribute("KeyColor"))
                end

                local displayName = "Key: " .. colorName

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

                createESP(item, displayName, itemColor, activeESPObjects)
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
        if keyColorProp:IsA("StringValue") then
            colorName = keyColorProp.Value
        elseif type(keyColorProp.Value) == "string" then
            colorName = keyColorProp.Value
        end
    elseif keyObj:GetAttribute("KeyColor") then
        colorName = tostring(keyObj:GetAttribute("KeyColor"))
    end
    return string.lower(colorName)
end

-- Fungsi ngambil kode dan membersihkan spasi otomatis
local function getPasscode()
    local passcodeNote = nil
    local puzzleItems = workspace:FindFirstChild("PuzzleItems")
    if puzzleItems then
        passcodeNote = puzzleItems:FindFirstChild("PasscodeNote")
    end
    if not passcodeNote then
        passcodeNote = workspace:FindFirstChild("PasscodeNote", true)
    end

    if passcodeNote then
        local paper = passcodeNote:FindFirstChild("Paper")
        local writing = paper and paper:FindFirstChild("Writing")
        local codeObj = writing and writing:FindFirstChild("Code")
        if codeObj and (codeObj:IsA("TextLabel") or codeObj:IsA("TextBox") or codeObj:IsA("SurfaceGui")) then
            local rawText = tostring(codeObj.Text)
            -- Menghilangkan semua spasi atau karakter non-angka/string kosong
            local cleanCode = string.gsub(rawText, "%s+", "")
            return cleanCode
        end
    end
    return nil
end

local farmedKeys = {}
local isBusy = false
local passcodeSubmitted = false

RunService.Heartbeat:Connect(function()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = character.HumanoidRootPart

    -- Auto Farm Loop
    if autoFarmEnabled and not isBusy then
        isBusy = true
        
        local targetKey = nil
        local targetPos = nil
        
        local puzzleItems = workspace:FindFirstChild("PuzzleItems")
        if puzzleItems then
            for _, item in ipairs(puzzleItems:GetChildren()) do
                if item.Name == "Key" and not farmedKeys[item] then
                    local pos = item:IsA("BasePart") and item.Position or (item:IsA("Model") and item:GetPivot().Position)
                    if pos then
                        targetKey = item
                        targetPos = pos
                        break
                    end
                end
            end
        end

        if targetKey and targetPos then
            farmedKeys[targetKey] = true 
            local colorStr = getKeyColor(targetKey)
            
            -- 1. TP ke posisi key/chest
            rootPart.Velocity = Vector3.new(0, 0, 0)
            character:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
            task.wait(0.2)
            
            -- 2. Buka SEMUA laci/drawer di TripleChest terdekat
            local puzzleChests = workspace:FindFirstChild("PuzzleChests")
            if puzzleChests then
                for _, chest in ipairs(puzzleChests:GetChildren()) do
                    if chest.Name:find("TripleChest") or chest.Name:find("DoubleChest") or chest.Name:find("Chest") then
                        local chestPos = chest:IsA("BasePart") and chest.Position or (chest:IsA("Model") and chest:GetPivot().Position)
                        if chestPos and (targetPos - chestPos).Magnitude <= 8 then
                            for _, desc in ipairs(chest:GetDescendants()) do
                                if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                                    fireproximityprompt(desc)
                                end
                            end
                        end
                    end
                end
            end

            -- Backup prompt universal
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local part = obj.Parent
                    if part then
                        local partPos = part:IsA("BasePart") and part.Position or (part:IsA("Model") and part:GetPivot().Position)
                        if partPos and (rootPart.Position - partPos).Magnitude <= 5 then
                            fireproximityprompt(obj)
                        end
                    end
                end
            end

            task.wait(0.4)

            -- 3. Ambil key-nya lewat PuzzlePrompt attachment
            local rootPartKey = targetKey:FindFirstChild("Root")
            local attachment = rootPartKey and rootPartKey:FindFirstChild("ItemPromptAttachment")
            local puzzlePrompt = attachment and attachment:FindFirstChild("PuzzlePrompt")
            if puzzlePrompt and puzzlePrompt:IsA("ProximityPrompt") then
                fireproximityprompt(puzzlePrompt)
            end
            
            task.wait(0.5)
            
            -- 4. Pindah ke gembok pintu sesuai warna key
            local lockIndex = "1"
            if colorStr:find("red") then
                lockIndex = "1"
            elseif colorStr:find("blue") then
                lockIndex = "2"
            elseif colorStr:find("green") then
                lockIndex = "3"
            elseif colorStr:find("yellow") or colorStr:find("gold") then
                lockIndex = "4"
            elseif colorStr:find("purple") or colorStr:find("tulip") then
                lockIndex = "5"
            end

            local frontDoor = workspace:FindFirstChild("FrontDoor")
            local puzzleLocks = frontDoor and frontDoor:FindFirstChild("PuzzleLocks")
            local targetLockNode = puzzleLocks and (puzzleLocks:FindFirstChild("Lock_" .. lockIndex) or puzzleLocks:FindFirstChild("Lock_1"))
            
            if targetLockNode then
                local padlockBody = targetLockNode:FindFirstChild("Padlock") and targetLockNode.Padlock:FindFirstChild("Body")
                if padlockBody then
                    local lockPos = padlockBody:IsA("BasePart") and padlockBody.Position or padlockBody:GetPivot().Position
                    rootPart.Velocity = Vector3.new(0, 0, 0)
                    character:PivotTo(CFrame.new(lockPos + Vector3.new(0, 0, 3)))
                    task.wait(0.2)
                end

                local lockPrompt = targetLockNode:FindFirstChild("Padlock") and targetLockNode.Padlock:FindFirstChild("Body") and targetLockNode.Padlock.Body:FindFirstChild("LockPromptAttachment") and targetLockNode.Padlock.Body.LockPromptAttachment:FindFirstChild("PuzzlePrompt")
                if lockPrompt and lockPrompt:IsA("ProximityPrompt") then
                    fireproximityprompt(lockPrompt)
                else
                    for _, desc in ipairs(targetLockNode:GetDescendants()) do
                        if desc.Name == "PuzzlePrompt" and desc:IsA("ProximityPrompt") then
                            fireproximityprompt(desc)
                            break
                        end
                    end
                end
            end

            task.wait(0.5)
        else
            -- Kalau semua key udah habis, submit passcode (tanpa spasi) & escape otomatis!
            if not passcodeSubmitted then
                passcodeSubmitted = true
                local code = getPasscode()
                if code and code ~= "" then
                    pcall(function()
                        local args = {code}
                        ReplicatedStorage:WaitForChild("PuzzleShared"):WaitForChild("Remotes"):WaitForChild("SubmitPasscode"):InvokeServer(unpack(args))
                    end)
                    Library:SendNotification("Auto Farm", "All keys collected! Passcode submitted: " .. code, 4, 122937454340636, 2, "grey")
                end
                escapeEnabled = true 
            end
            task.wait(0.5)
        end
        
        isBusy = false
    end

    -- Escape Loop
    if not escapeEnabled then return end
    local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
    if targetObj then
        local pos = targetObj:IsA("BasePart") and targetObj.Position or (targetObj:IsA("Model") and targetObj:GetPivot().Position)
        if pos then
            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
            
            if (rootPart.Position - pos).Magnitude <= 8 then
                for _, obj in ipairs(targetObj:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        fireproximityprompt(obj)
                    end
                end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj.Name == "Actor_AtokBelalang" then
                        for _, p in ipairs(obj:GetDescendants()) do
                            if p:IsA("ProximityPrompt") then
                                fireproximityprompt(p)
                            end
                        end
                    end
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
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    local targetKey = nil
    local puzzleItems = workspace:FindFirstChild("PuzzleItems")
    if puzzleItems then
        for _, item in ipairs(puzzleItems:GetChildren()) do
            if item.Name == "Key" then
                targetKey = item
                break
            end
        end
    end

    if targetKey then
        local pos = targetKey:IsA("BasePart") and targetKey.Position or (targetKey:IsA("Model") and targetKey:GetPivot().Position)
        if pos then
            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
            Library:SendNotification("Teleport", "Successfully teleported to Key!", 2, 122937454340636, 2, "grey")
        end
    else
        Library:SendNotification("Error", "Key not found in PuzzleItems!", 2, 122937454340636, 2, "grey")
    end
end)

TeleportSection:CreateButton("TP to PasscodeNote", function()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    local targetNote = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "PasscodeNote" then
            targetNote = obj
            break
        end
    end

    if targetNote then
        local pos = targetNote:IsA("BasePart") and targetNote.Position or (targetNote:IsA("Model") and targetNote:GetPivot().Position)
        if pos then
            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
            Library:SendNotification("Teleport", "Successfully teleported to PasscodeNote!", 2, 122937454340636, 2, "grey")
        end
    else
        Library:SendNotification("Error", "PasscodeNote not found!", 3, 122937454340636, 2, "grey")
    end
end)

TeleportSection:CreateButton("TP to Safe Zone", function()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    character:PivotTo(CFrame.new(320.51, 11.14, -227.66))
    Library:SendNotification("Teleport", "Teleported to Safe Zone!", 2, 122937454340636, 2, "grey")
end)

-- Main Section
MainSection:CreateToggle("Auto Farm", false, function(Value)
    autoFarmEnabled = Value
    if not Value then
        table.clear(farmedKeys)
        isBusy = false
        passcodeSubmitted = false
    end
    Library:SendNotification("Auto Farm", "Auto Farm status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

MainSection:CreateToggle("Escape", false, function(Value)
    escapeEnabled = Value
    if escapeEnabled then
        Library:SendNotification("Escape", "Escape Activated!", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Escape", "Escape Deactivated!", 2, 122937454340636, 2, "grey")
    end
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
    setclipboard("https://www.tiktok.com/@michellyjowzero_")
    Library:SendNotification(
        "Copied!",
        "TikTok link copied to clipboard!",
        3,
        17757765730,
        2
    )
end)

CreditsSection:CreateButton("Copy Discord", function()
    setclipboard("https://discord.gg/6B36mdd6cJ")
    Library:SendNotification(
        "Copied!",
        "Discord invite copied to clipboard!",
        3,
        16584754883,
        2
    )
end)
