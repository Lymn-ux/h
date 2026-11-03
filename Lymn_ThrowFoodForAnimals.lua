local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/AetherXOfficial/x/refs/heads/main/UiLibary"))()

local Window = Library:NewWindow(
    "Lymn X Throw Food For Animals",
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

-- ==================== LOGIC VARIABELS ====================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local perfectThrowEnabled = false
local equipBestEnabled = false
local tapBonusEnabled = false
local autoUpgradeEnabled = false
local autoBuyFoodEnabled = false

local isBusyBuying = false

local TARGET_FOOD_COLOR = "0 1 0.862745 0.352941 0 1 0.941176 0.627451 0.0784314 0 "
local TARGET_UPGRADE_COLOR = "0 0.596078 0.964706 0.282353 0 1 0.384314 0.8 0.133333 0 "

local startTapBonus

local function stopTraining()
    pcall(function()
        local stopEvent = ReplicatedStorage:WaitForChild("Remotes", 2):WaitForChild("Training_Stop", 2)
        if stopEvent then
            stopEvent:InvokeServer()
        end
    end)
end

-- 1. Perfect Throw Logic
local function startPerfectThrow()
    task.spawn(function()
        while perfectThrowEnabled do
            if not isBusyBuying then
                pcall(function()
                    local character = LocalPlayer.Character
                    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                    
                    if humanoidRootPart then
                        humanoidRootPart.CFrame = CFrame.new(-0.37, 5.20, -35.80)
                    end
                    
                    local eventStart = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Throw_Start")
                    if eventStart then eventStart:InvokeServer() end

                    local eventResolve = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Throw_Resolve")
                    if eventResolve then eventResolve:InvokeServer(1) end

                    local eventComplete = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Throw_Complete")
                    if eventComplete then eventComplete:InvokeServer() end
                end)
            end
            task.wait()
        end
    end)
end

-- 2. Equip Best Logic
local function startEquipBest()
    task.spawn(function()
        while equipBestEnabled do
            pcall(function()
                local event = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Plot_EquipBest")
                if event then event:InvokeServer() end
            end)
            task.wait(1)
        end
    end)
end

-- 3. Auto Tap Bonus Logic (x2 Train)
startTapBonus = function()
    task.spawn(function()
        pcall(function()
            if not isBusyBuying then
                local character = LocalPlayer.Character
                local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                local trainingArea = workspace:FindFirstChild("LocalPlotProps") and workspace.LocalPlotProps:FindFirstChild("TrainingArea")
                
                if humanoidRootPart and trainingArea then
                    if trainingArea:IsA("BasePart") then
                        humanoidRootPart.CFrame = trainingArea.CFrame + Vector3.new(0, 3, 0)
                    elseif trainingArea:IsA("Model") and trainingArea.PrimaryPart then
                        humanoidRootPart.CFrame = trainingArea.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end
        end)

        while tapBonusEnabled and not isBusyBuying do
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local trainingSeq = playerGui and playerGui:FindFirstChild("TrainingSequence")
                local tapBonusLayer = trainingSeq and trainingSeq:FindFirstChild("TrainingSequence") and trainingSeq.TrainingSequence:FindFirstChild("TapBonusLayer") or (trainingSeq and trainingSeq:FindFirstChild("TapBonusLayer"))
                local tapBonusBtn = tapBonusLayer and tapBonusLayer:FindFirstChild("TapBonus")

                if tapBonusBtn then
                    if tapBonusBtn:IsA("GuiButton") then
                        for _, connection in ipairs(getconnections(tapBonusBtn.Activated)) do connection:Fire() end
                        for _, connection in ipairs(getconnections(tapBonusBtn.MouseButton1Click)) do connection:Fire() end
                    elseif tapBonusBtn:IsA("GuiObject") then
                        if typeof(firesignal) == "function" then
                            firesignal(tapBonusBtn.MouseButton1Click)
                            firesignal(tapBonusBtn.Activated)
                        end
                    end
                end
            end)
            task.wait(0.1)
        end

        stopTraining()
    end)
end

-- 4. Auto Upgrade Train
local function startAutoUpgrade()
    task.spawn(function()
        while autoUpgradeEnabled do
            pcall(function()
                local trainingArea = workspace:FindFirstChild("LocalPlotProps") and workspace.LocalPlotProps:FindFirstChild("TrainingArea")
                local trainingSpot = trainingArea and trainingArea:FindFirstChild("TrainingSpot")
                local upgradeBtn = trainingSpot and trainingSpot:FindFirstChild("UpgradeButton")
                local priceNode = upgradeBtn and upgradeBtn:FindFirstChild("PriceAnchor") and upgradeBtn.PriceAnchor:FindFirstChild("PriceBillboard") and upgradeBtn.PriceAnchor.PriceBillboard:FindFirstChild("Holder") and upgradeBtn.PriceAnchor.PriceBillboard.Holder:FindFirstChild("PriceHolder") and upgradeBtn.PriceAnchor.PriceBillboard.Holder.PriceHolder:FindFirstChild("Price")
                local uiGradient = priceNode and priceNode:FindFirstChild("UIGradient")

                if not uiGradient and upgradeBtn then
                    uiGradient = upgradeBtn:FindFirstDescendant("UIGradient")
                end

                if uiGradient and upgradeBtn then
                    local currentColor = tostring(uiGradient.Color)
                    if currentColor == TARGET_UPGRADE_COLOR then
                        if tapBonusEnabled then
                            stopTraining()
                        end

                        isBusyBuying = true

                        for i = 1, 6 do
                            local character = LocalPlayer.Character
                            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                            if humanoidRootPart and upgradeBtn then
                                if upgradeBtn:IsA("BasePart") then
                                    humanoidRootPart.CFrame = upgradeBtn.CFrame + Vector3.new(0, 3, 0)
                                elseif upgradeBtn:IsA("Model") and upgradeBtn.PrimaryPart then
                                    humanoidRootPart.CFrame = upgradeBtn.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                                end
                            end

                            local upgradeEvent = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Stand_Upgrade")
                            if upgradeEvent then
                                upgradeEvent:InvokeServer()
                            end
                            task.wait(0.5)
                        end

                        isBusyBuying = false

                        if tapBonusEnabled then
                            startTapBonus()
                        end
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

-- 5. Auto Buy Best Food
local function startAutoBuyFood()
    task.spawn(function()
        while autoBuyFoodEnabled do
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local foodShop = playerGui and playerGui:FindFirstChild("FoodShop")
                local cardsScroll = foodShop and foodShop:FindFirstChild("Main") and foodShop.Main:FindFirstChild("Panel") and foodShop.Main.Panel:FindFirstChild("Body") and foodShop.Main.Panel.Body:FindFirstChild("CardsScroll")

                if cardsScroll then
                    local foodNumbers = {}
                    for _, child in ipairs(cardsScroll:GetChildren()) do
                        local numStr = child.Name:match("^Food(%d+)$")
                        if numStr then
                            table.insert(foodNumbers, tonumber(numStr))
                        end
                    end

                    table.sort(foodNumbers, function(a, b) return a > b end)

                    for _, foodIndex in ipairs(foodNumbers) do
                        local foodFrame = cardsScroll:FindFirstChild("Food" .. tostring(foodIndex))
                        if foodFrame then
                            local actionBtn = foodFrame:FindFirstChild("ActionButton")
                            local uiGradient = actionBtn and actionBtn:FindFirstChild("UIGradient")
                            
                            if uiGradient and tostring(uiGradient.Color) == TARGET_FOOD_COLOR then
                                if tapBonusEnabled then
                                    stopTraining()
                                end

                                isBusyBuying = true

                                for i = 1, 6 do
                                    local character = LocalPlayer.Character
                                    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                                    local localPlot = workspace:WaitForChild("LocalPlotProps", 2)
                                    local shopArea = localPlot and localPlot:WaitForChild("FoodShop", 2)
                                    local activationCircle = shopArea and shopArea:WaitForChild("ActivationCircle", 2)

                                    if humanoidRootPart and activationCircle then
                                        if activationCircle:IsA("BasePart") then
                                            humanoidRootPart.CFrame = activationCircle.CFrame + Vector3.new(0, 3, 0)
                                        elseif activationCircle:IsA("Model") and activationCircle.PrimaryPart then
                                            humanoidRootPart.CFrame = activationCircle.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                                        end
                                    end

                                    local buyEvent = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Shop_Buy")
                                    if buyEvent then
                                        buyEvent:InvokeServer(foodIndex)
                                    end
                                    task.wait(0.5)
                                end

                                isBusyBuying = false

                                if tapBonusEnabled then
                                    startTapBonus()
                                end
                                
                                break
                            end
                        end
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

-- 6. Sell All Logic
local function sellAllTrigger()
    task.spawn(function()
        pcall(function()
            local event = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Plot_SellAll")
            if event then event:InvokeServer() end
        end)
    end)
end

-- ==================== UI TABS & SECTIONS ====================
local MainTab = Window:NewSection("Main")
local FarmTab = Window:NewSection("Training & Shop")
local CreditsTab = Window:NewSection("Credits")

-- --- TAB MAIN ---
MainTab:CreateToggle("Perfect Throw", false, function(on)
    if on and tapBonusEnabled then
        tapBonusEnabled = false
        Library:SendNotification("Lymn X", "x2 Train Turned Off", 2, 122937454340636, 2, "grey")
    end

    perfectThrowEnabled = on
    if on then
        startPerfectThrow()
        Library:SendNotification("Lymn X", "Perfect Throw Enabled", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Lymn X", "Perfect Throw Disabled", 2, 122937454340636, 2, "grey")
    end
end)

MainTab:CreateToggle("Equip Best", false, function(on)
    equipBestEnabled = on
    if on then
        startEquipBest()
        Library:SendNotification("Lymn X", "Equip Best Enabled", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Lymn X", "Equip Best Disabled", 2, 122937454340636, 2, "grey")
    end
end)

MainTab:CreateButton("Sell All", function()
    sellAllTrigger()
    Library:SendNotification("Lymn X", "Sell All Executed!", 2, 122937454340636, 2, "grey")
end)

-- --- TAB TRAINING & SHOP ---
FarmTab:CreateToggle("x2 Train", false, function(on)
    if on and perfectThrowEnabled then
        perfectThrowEnabled = false
        Library:SendNotification("Lymn X", "Perfect Throw Turned Off", 2, 122937454340636, 2, "grey")
    end

    tapBonusEnabled = on
    if on then
        startTapBonus()
        Library:SendNotification("Lymn X", "x2 Train Enabled", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Lymn X", "x2 Train Disabled", 2, 122937454340636, 2, "grey")
    end
end)

FarmTab:CreateToggle("Auto Upgrade Train", false, function(on)
    autoUpgradeEnabled = on
    if on then
        startAutoUpgrade()
        Library:SendNotification("Lymn X", "Auto Upgrade Train Enabled", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Lymn X", "Auto Upgrade Train Disabled", 2, 122937454340636, 2, "grey")
    end
end)

FarmTab:CreateToggle("Auto Buy Best Food", false, function(on)
    autoBuyFoodEnabled = on
    if on then
        startAutoBuyFood()
        Library:SendNotification("Lymn X", "Auto Buy Best Food Enabled", 2, 122937454340636, 2, "grey")
    else
        Library:SendNotification("Lymn X", "Auto Buy Best Food Disabled", 2, 122937454340636, 2, "grey")
    end
end)

-- --- TAB CREDITS ---
CreditsTab:CreateButton("Copy TikTok", function()
    setclipboard("https://www.tiktok.com/@michellyjowzero_")
    Library:SendNotification(
        "Copied!",
        "TikTok link copied to clipboard!",
        3,
        17757765730,
        2
    )
end)

CreditsTab:CreateButton("Copy Discord", function()
    setclipboard("https://discord.gg/6B36mdd6cJ")
    Library:SendNotification(
        "Copied!",
        "Discord invite copied to clipboard!",
        3,
        16584754883,
        2
    )
end)
