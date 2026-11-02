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

local MainSection = Window:NewSection("Main")
local CreditsSection = Window:NewSection("Credits")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local espKeyEnabled = false
local espOpahEnabled = false
local escapeEnabled = false
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

-- Loop Escape & Distance Check ProximityPrompt
RunService.Heartbeat:Connect(function()
    if not escapeEnabled then return end
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    local targetObj = workspace:FindFirstChild("CutsceneLocal") and workspace.CutsceneLocal:FindFirstChild("Actor_AtokBelalang")
    if targetObj then
        local pos = targetObj:IsA("BasePart") and targetObj.Position or (targetObj:IsA("Model") and targetObj:GetPivot().Position)
        if pos then
            character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
            
            -- Cek jarak 3 stud ke AtokBelalang sebelum trigger proximity prompt
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart and (rootPart.Position - pos).Magnitude <= 8 then
                local remainingKeys = 0
                local puzzleItems = workspace:FindFirstChild("PuzzleItems")
                if puzzleItems then
                    for _, item in ipairs(puzzleItems:GetChildren()) do
                        if item.Name == "Key" then
                            remainingKeys = remainingKeys + 1
                        end
                    end
                end

                if remainingKeys == 0 then
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
    end
end)

MainSection:CreateToggle("Esp Key And Note Code", false, function(Value)
    espKeyEnabled = Value
    task.defer(updateESP)
    Library:SendNotification("ESP", "ESP Key & Note status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

MainSection:CreateToggle("Esp Opah", false, function(Value)
    espOpahEnabled = Value
    task.defer(updateOpahESP)
    Library:SendNotification("ESP", "ESP Opah status: " .. tostring(Value), 2, 122937454340636, 2, "grey")
end)

MainSection:CreateToggle("Escape", false, function(Value)
    escapeEnabled = Value
    
    if escapeEnabled then
        local remainingKeys = 0
        local puzzleItems = workspace:FindFirstChild("PuzzleItems")
        if puzzleItems then
            for _, item in ipairs(puzzleItems:GetChildren()) do
                if item.Name == "Key" then
                    remainingKeys = remainingKeys + 1
                end
            end
        end

        if remainingKeys > 0 then
            Library:SendNotification("Escape", "COMPLETE " .. tostring(remainingKeys) .. " KEYS FIRST", 3, 122937454340636, 2, "grey")
        else
            Library:SendNotification("Escape", "Escape Activated!", 2, 122937454340636, 2, "grey")
        end
    else
        Library:SendNotification("Escape", "Escape Deactivated!", 2, 122937454340636, 2, "grey")
    end
end)

MainSection:CreateButton("Code Reveal", function()
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
            local codeText = codeObj.Text
            Library:SendNotification("Code Reveal", "Code : " .. tostring(codeText), 5, 122937454340636, 2, "grey")
        else
            Library:SendNotification("Error", "Code property not found inside Writing!", 3, 122937454340636, 2, "grey")
        end
    else
        Library:SendNotification("Error", "PasscodeNote not found!", 3, 122937454340636, 2, "grey")
    end
end)

MainSection:CreateButton("TP to Key", function()
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

MainSection:CreateButton("TP to PasscodeNote", function()
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

MainSection:CreateButton("TP to Safe Zone", function()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    character:PivotTo(CFrame.new(320.51, 11.14, -227.66))
    Library:SendNotification("Teleport", "Teleported to Safe Zone!", 2, 122937454340636, 2, "grey")
end)

CreditsSection:CreateButton("Copy TikTok", function()
    setclipboard("https://www.tiktok.com/@michel.ljw")
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
