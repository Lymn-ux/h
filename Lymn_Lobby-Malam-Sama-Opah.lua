local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local Window = OrionLib:MakeWindow({
    Name = "Lymn | Malam Sama Opah",
    HidePremium = true,
    SaveConfig = true,
    ConfigFolder = "LymnConfig",
    IntroEnabled = false -- Mematikan animasi loading awal agar langsung terbuka instan
})

-- Tabs dengan Icon Berbeda & Unik
local InfoTab = Window:MakeTab({
    Name = "Information",
    Icon = "rbxassetid://6031075938",
    PremiumOnly = false
})

local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://18102581819", -- Icon Tab Main yang baru
    PremiumOnly = false
})

local ExtraTab = Window:MakeTab({
    Name = "Extra",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

-- Information Tab
InfoTab:AddSection({ Name = "Update & Dev Info" })
InfoTab:AddButton({
    Name = "Copy Discord Invite",
    Callback = function()
        setclipboard("https://discord.gg/6B36mdd6cJ")
        OrionLib:MakeNotification({
            Name = "Success",
            Content = "Discord link copied to clipboard!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- Global Variables
getgenv().SelectedMode = "Easy"
getgenv().SelectItem = "SprayNyamuk"
getgenv().BuyAmount = 10
getgenv().AutoBuy = false
getgenv().TouchFling = false

local partyRemote = game:GetService("ReplicatedStorage"):WaitForChild("LobbyShared"):WaitForChild("PartyRemote")
local duitRequest = game:GetService("ReplicatedStorage"):WaitForChild("DuitShared"):WaitForChild("DuitRequest")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- Party Manager Section (Main Tab)
MainTab:AddSection({ Name = "Party Manager" })

MainTab:AddDropdown({
    Name = "Select Difficulty Mode",
    Default = "Easy",
    Options = {"Easy", "Normal", "Nightmare"},
    Callback = function(Value)
        getgenv().SelectedMode = Value
    end    
})

MainTab:AddButton({
    Name = "Create Party & Start",
    Callback = function()
        task.spawn(function()
            -- 1. Create Party
            partyRemote:FireServer("Create")
            task.wait(1)

            -- 2. Vote Mode
            partyRemote:FireServer("Vote", getgenv().SelectedMode)
            task.wait(1)

            -- 3. Start Game
            partyRemote:FireServer("Start")
        end)
    end
})

-- Auto Buy Section (Main Tab)
MainTab:AddSection({ Name = "Auto Buy Items" })

MainTab:AddDropdown({
    Name = "Select Item",
    Default = "SprayNyamuk",
    Options = {"SprayNyamuk", "Flashlight"},
    Callback = function(Value)
        getgenv().SelectItem = Value
    end    
})

MainTab:AddTextbox({
    Name = "Buy Amount",
    Default = "10",
    TextDisappear = false,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            getgenv().BuyAmount = num
        end
    end
})

MainTab:AddToggle({
    Name = "Auto Buy Item",
    Default = false,
    Callback = function(Value)
        getgenv().AutoBuy = Value

        if getgenv().AutoBuy then
            task.spawn(function()
                local amount = tonumber(getgenv().BuyAmount) or 10

                for i = 1, amount do
                    if not getgenv().AutoBuy then break end

                    -- Invoke Remote Function ke Server
                    duitRequest:InvokeServer("BuyItem", getgenv().SelectItem)

                    -- Jeda 0.70 detik
                    task.wait(0.70)
                end

                getgenv().AutoBuy = false
            end)
        end
    end    
})

-- Extra Tab: Touch Fling & Server Tools
ExtraTab:AddSection({ Name = "Trolling / Physics" })

-- Setup Detection ReplicatedStorage buat Touch Fling[cite: 1]
if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
    local detection = Instance.new("Decal")
    detection.Name = "juisdfj0i32i0eidsuf0iok"
    detection.Parent = ReplicatedStorage
end

ExtraTab:AddToggle({
    Name = "Touch Fling",
    Default = false,
    Callback = function(Value)
        getgenv().TouchFling = Value
        
        if getgenv().TouchFling then
            task.spawn(function()
                local lp = Players.LocalPlayer
                local c, hrp, vel, movel = nil, nil, nil, 0.1
            
                while getgenv().TouchFling do
                    RunService.Heartbeat:Wait()
                    c = lp.Character
                    hrp = c and c:FindFirstChild("HumanoidRootPart")
            
                    if hrp then
                        vel = hrp.Velocity
                        hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                        RunService.RenderStepped:Wait()
                        hrp.Velocity = vel
                        RunService.Stepped:Wait()
                        hrp.Velocity = vel + Vector3.new(0, movel, 0)
                        movel = -movel
                    end
                end
            end)
        end
    end
})

ExtraTab:AddSection({ Name = "Server Tools" })

ExtraTab:AddButton({
    Name = "Server Hop",
    Callback = function()
        local Http = game:GetService("HttpService")
        local TPS = game:GetService("TeleportService")
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        
        local function getServer()
            local Success, Event = pcall(function()
                return Http:JSONDecode(game:HttpGet(Api))
            end)
            if Success and Event and Event.data then
                for _, Server in ipairs(Event.data) do
                    if Server.playing < Server.maxPlayers and Server.id ~= game.JobId then
                        return Server.id
                    end
                end
            end
            return nil
        end
        
        local ServerId = getServer()
        if ServerId then
            TPS:TeleportToPlaceInstance(game.PlaceId, ServerId, Players.LocalPlayer)
        else
            OrionLib:MakeNotification({
                Name = "Server Hop",
                Content = "No empty server found!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

ExtraTab:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        if #Players:GetPlayers() <= 1 then
            Players.LocalPlayer:Kick("\nRejoining...")
            task.wait(1)
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
        end
    end
})

-- Init UI
OrionLib:Init()
