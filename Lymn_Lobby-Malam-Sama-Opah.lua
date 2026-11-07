-- LocalScript / Roblox Luau
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Hapus instance lama kalau diexecute ulang
local existingGui = playerGui:FindFirstChild("LobbyWarningGui")
if existingGui then
    existingGui:Destroy()
end

-- ScreenGui Setup (pakai DisplayOrder tinggi biar di atas UI game tanpa ngerusak)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyWarningGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999
screenGui.Parent = playerGui

-- Dark Background
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Main Warning Text
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(1, -40, 0, 80)
warningLabel.Position = UDim2.new(0.5, 0, 0.45, 0)
warningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
warningLabel.BackgroundTransparency = 1
warningLabel.Text = "PLS EXECUTE IN GAME, DON'T IN THE LOBBY"
warningLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
warningLabel.TextScaled = true
warningLabel.Font = Enum.Font.GothamBold
warningLabel.Parent = frame

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = 28
textConstraint.MinTextSize = 14
textConstraint.Parent = warningLabel

-- Countdown Label
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -40, 0, 50)
timerLabel.Position = UDim2.new(0.5, 0, 0.55, 0)
timerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.Gotham
timerLabel.Parent = frame

local timerConstraint = Instance.new("UITextSizeConstraint")
timerConstraint.MaxTextSize = 22
timerConstraint.MinTextSize = 12
timerConstraint.Parent = timerLabel

-- Countdown Logic
task.spawn(function()
    for i = 3, 1, -1 do
        timerLabel.Text = "Closing in " .. i .. "..."
        task.wait(1)
    end
    
    -- Fade Out Animation
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fadeFrame = TweenService:Create(frame, tweenInfo, {BackgroundTransparency = 1})
    local fadeText1 = TweenService:Create(warningLabel, tweenInfo, {TextTransparency = 1})
    local fadeText2 = TweenService:Create(timerLabel, tweenInfo, {TextTransparency = 1})
    
    fadeFrame:Play()
    fadeText1:Play()
    fadeText2:Play()
    
    fadeFrame.Completed:Wait()
    screenGui:Destroy()
end)
