--[[ Anime-Dice | Lymn (ProxyLib UI) ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local env = (getgenv and getgenv()) or _G
if type(env.lymn_AnimeDice_Unload) == "function" then
	pcall(env.lymn_AnimeDice_Unload)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer


do
	local count = #Players:GetPlayers()
	if count <= 2 then
		pcall(function()
			LocalPlayer:Kick(("Only %d player(s) in this server.\nPlease Join on a Public server to prevent being banned from using this."):format(count))
		end)
		task.wait(1)
		error("Lymn: low player count.", 0)
	end
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Lib = ProxyLib.new()

local Window = Lib:CreateWindow({
	Title = "Lymn",
	Subtitle = "Anime Dice",
	Size = Vector2.new(540, 340),
	MinSize = Vector2.new(460, 300),
	MaxSize = Vector2.new(950, 650),
	TypeUI = "Modern",
	Language = "English",
	Theme = "Grey",
	Search = true,
	AutoSave = true,
	AutoLoad = true,
	DefaultFps = false,
	DefaultPing = false,
	DefaultProfile = true,
	TitleConfig = {
		Gradient = true,
		Colors = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(150, 150, 150) },
		Words = {
			{ Text = "Ly", Colors = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(150, 150, 150) } },
			{ Text = "mn", Colors = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(150, 150, 150) } },
		},
	},
	ConfigPanel = {
		Enabled = true,
		Acrylic = false,
		Theme = false,
		Fps = false,
		Ping = false,
		Profile = false,
		HideNotify = false,
		Language = false,
		BackgroundImage = false,
	},
	FloatButton = {
		Shape = "Squircle",
		Color = "Translucent",
		Size = 50,
		Icon = "rbxassetid://105369821130198"
	},
	Acrylic = { Enabled = false, Opacity = 0 },
})

local ICONS = {
	info = "rbxassetid://6031075938",
	auto = "rbxassetid://10709782230",
	hub = "rbxassetid://10734975692",
	level = "rbxassetid://10747363465",
	potion = "rbxassetid://10734883986",
	sell = "rbxassetid://10709811110",
	misc = "rbxassetid://10734950309",
}

-- Adapter: keeps the feature code below untouched (Tab -> Card -> Toggle/Button/Slider/...)
local function call(obj, names, ...)
	if type(obj) ~= "table" then return false end
	for _, n in ipairs(names) do
		local f = obj[n]
		if type(f) == "function" then
			if pcall(f, obj, ...) then return true end
		end
	end
	return false
end

local function run(cb, ...)
	if type(cb) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(cb, table.unpack(args, 1, args.n))
		if not ok then warn("[Lymn] callback error: " .. tostring(err)) end
	end)
end

local function normList(v)
	local out = {}
	if type(v) == "string" then
		out[1] = v
	elseif type(v) == "table" then
		if #v > 0 then
			for _, x in ipairs(v) do
				if type(x) == "table" then x = x.Value or x.Text or x.Name or x.Title end
				if x ~= nil then out[#out + 1] = tostring(x) end
			end
		else
			for k, x in pairs(v) do
				if x == true then out[#out + 1] = tostring(k) end
			end
		end
	end
	return out
end

local function optionList(opts)
	local t = {}
	for _, o in ipairs(opts or {}) do
		t[#t + 1] = { Value = tostring(o), Text = tostring(o) }
	end
	return t
end

local UI = { Window = Window }

function UI:Notify(title, content, dur)
	pcall(function()
		Window:Notify({ Title = tostring(title), Description = tostring(content), Duration = dur or 3 })
	end)
end

function UI:LoadConfig() end -- AutoLoad + SaveId handle persistence

function UI:Destroy()
	if call(Window, { "Destroy", "Unload" }) then return end
	call(Lib, { "Destroy", "Unload" })
end

function UI:Tab(name, icon, subtitle)
	local t = Window:CreateTab({ Title = name, Subtitle = subtitle or "", Icon = icon })
	local tab = { Raw = t }

	function tab:Card(title)
		local card, started = {}, false
		local function head()
			if started then return end
			started = true
			pcall(function() t:CreateSection({ Text = title }) end)
		end

		function card:Toggle(o)
			head()
			local obj = { Value = o.Default and true or false }
			local ok, raw = pcall(function()
				return t:CreateToggle({
					Title = o.Name, Default = obj.Value, SaveId = o.Flag,
					Callback = function(v)
						obj.Value = v and true or false
						run(o.Callback, obj.Value)
					end,
				})
			end)
			if not ok then warn("[Lymn] toggle '" .. tostring(o.Name) .. "': " .. tostring(raw)) raw = nil end
			function obj:Set(v)
				obj.Value = v and true or false
				call(raw, { "Set", "SetValue", "SetState", "SetToggle" }, obj.Value)
			end
			return obj
		end

		function card:Button(o)
			head()
			local ok, raw = pcall(function()
				return t:CreateButton({
					Title = o.Name, Text = o.Name,
					Callback = function() run(o.Callback) end,
				})
			end)
			if not ok then warn("[Lymn] button '" .. tostring(o.Name) .. "': " .. tostring(raw)) end
			return raw
		end

		function card:Label(text)
			head()
			local ok, raw = pcall(function()
				return t:CreateParagraph({ Title = "Info", Description = text })
			end)
			if not ok then warn("[Lymn] label: " .. tostring(raw)) end
			return raw
		end

		function card:Paragraph(o)
			head()
			local obj = {}
			local ok, raw = pcall(function()
				return t:CreateParagraph({ Title = o.Title or "", Description = o.Content or "" })
			end)
			if not ok then warn("[Lymn] paragraph: " .. tostring(raw)) raw = nil end
			function obj:Set(v)
				if type(v) ~= "table" or not raw then return end
				local title, desc = v.Title, v.Content or v.Description
				if call(raw, { "Set", "Update", "SetData" }, { Title = title, Description = desc, Content = desc }) then return end
				if title then call(raw, { "SetTitle" }, title) end
				if desc then call(raw, { "SetDescription", "SetContent", "SetText" }, desc) end
			end
			return obj
		end

		function card:Slider(o)
			head()
			local obj = { Value = o.Default or o.Min or 0 }
			local ok, raw = pcall(function()
				return t:CreateSlider({
					Title = o.Name, Min = o.Min or 0, Max = o.Max or 100, Default = o.Default or o.Min or 0,
					Step = o.Step or 1, Suffix = o.Suffix, SaveId = o.Flag,
					Callback = function(v)
						obj.Value = v
						run(o.Callback, v)
					end,
				})
			end)
			if not ok then warn("[Lymn] slider '" .. tostring(o.Name) .. "': " .. tostring(raw)) raw = nil end
			function obj:Set(v)
				obj.Value = v
				call(raw, { "Set", "SetValue" }, v)
			end
			return obj
		end

		function card:Input(o)
			head()
			local obj = { Value = tostring(o.Default or "") }
			local ok, raw = pcall(function()
				return t:CreateTextBox({
					Title = o.Name, Placeholder = o.Placeholder or "", Default = tostring(o.Default or ""),
					SaveId = o.Flag,
					Callback = function(text)
						obj.Value = tostring(text or "")
						run(o.Callback, obj.Value)
					end,
				})
			end)
			if not ok then warn("[Lymn] textbox '" .. tostring(o.Name) .. "': " .. tostring(raw)) raw = nil end
			function obj:Set(v)
				obj.Value = tostring(v or "")
				call(raw, { "Set", "SetValue", "SetText" }, obj.Value)
			end
			return obj
		end

		function card:Dropdown(o)
			head()
			local multi = o.Multi and true or false
			local default = multi and normList(o.Default) or normList(o.Default)[1]
			local obj = { Value = default }
			local ok, raw = pcall(function()
				local opts = optionList(o.Options)
				return t:CreateDropdown({
					Title = o.Name, Options = opts, Values = opts, Default = default,
					Multi = multi, MultiSelect = multi, Multiple = multi, SaveId = o.Flag,
					Callback = function(v)
						local list = normList(v)
						obj.Value = multi and list or list[1]
						run(o.Callback, obj.Value)
					end,
				})
			end)
			if not ok then warn("[Lymn] dropdown '" .. tostring(o.Name) .. "': " .. tostring(raw)) raw = nil end
			function obj:Set(v)
				local list = normList(v)
				obj.Value = multi and list or list[1]
				call(raw, { "Set", "SetValue", "Select" }, obj.Value)
			end
			function obj:Refresh(newOptions)
				local opts = optionList(newOptions)
				call(raw, { "Refresh", "SetOptions", "SetValues", "UpdateOptions" }, opts)
			end
			return obj
		end

		return card
	end

	return tab
end

local InfoTab = UI:Tab("Information", ICONS.info, "Update/Dev Info")
InfoTab.Raw:CreateDiscordInvite({
	Title = "Lymn Official",
	Description = "Join our server for updates, announcements, support, and community.",
	Icon = "rbxassetid://105369821130198",
	Banner = "rbxassetid://123002136721231",
	Link = "https://discord.gg/6B36mdd6cJ",
	Button = "Join Server",
})

local AutoTab = UI:Tab("Auto", ICONS.auto, "Roll, plot, dice, quests")
local HubTab = UI:Tab("AutoHub", ICONS.hub, "Towers, grade, trait")
local LevelTab = UI:Tab("LevelUp", ICONS.level, "Auto level up")
local PotionTab = UI:Tab("Potions", ICONS.potion, "Auto use potions")
local SellTab = UI:Tab("Auto Sell", ICONS.sell, "Sell by rarity")
local MiscTab = UI:Tab("Misc", ICONS.misc, "Tools")


local Network = ReplicatedStorage:WaitForChild("Network")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Features = Framework:WaitForChild("Features")

local Remotes = {
	RollDice = Network.RollService.RF.RollDice,
	SellInventory = Network.SellService.RF.SellInventory,
	CollectBalance = Network.PlotService.RE.CollectBalance,
	EquipBest = Network.PlotService.RE.EquipBest,
	LevelUpSlot = Network.PlotService.RE.LevelUpSlot,
	BuyDice = Network.DiceShopService.RE.BuyDice,
	EquipDice = Network.DiceShopService.RE.EquipDice,
	Rebirth = Network.RebirthService.RE.Rebirth,
	BuyUpgrade = Network.RE.BuyUpgrade,
	ClaimQuest = Network.QuestService.RE.Claim,
	PlayTower = Network.Towers.RF.PlayTower,
	CompleteFloor = Network.Towers.RF.CompleteTowerFloor,
	CancelTower = Network.Towers.RF.CancelTower,
	EquipTowerTeam = Network.Towers.RE.EquipBestTowerTeam,
	GradeRoll = Network.GradeService.RE.Roll,
	TraitRoll = Network.TraitService.RE.Roll,
	UseBoost = Network.BoostService.RE.Use,
}

local RARITIES = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical",
	"Divine", "Exotic", "Celestial", "Exclusive", "Secret1", "Secret2"
}
local MUTATIONS = { "Silver", "Gold", "Emerald", "Diamond", "Ruby", "Rainbow" }
local BRANCHES = { "Luck", "Fortune", "Roll Speed", "Unit Storage", "Money", "Sell", "Damage", "Health", "Walkspeed" }
local ROMAN = {
	I = true, II = true, III = true, IV = true, V = true, VI = true,
	VII = true, VIII = true, IX = true, X = true, XI = true, XII = true
}

local unloaded = false
local Loops, Toggles = {}, {}
local afkConn

local function alive() return not unloaded and LocalPlayer.Parent ~= nil end
local function notify(title, content)
	task.spawn(function()
		pcall(function() UI:Notify(title, content, 3) end)
	end)
end
local function setSafe(obj, value)
	if not obj then return end
	task.spawn(function()
		pcall(function() obj:Set(value) end)
	end)
end
local function toSet(list)
	local s = {}
	if type(list) == "table" then
		for _, v in ipairs(list) do s[tostring(v)] = true end
	elseif type(list) == "string" then
		s[list] = true
	end
	return s
end
local function first(v)
	if type(v) == "table" then return v[1] end
	return v
end
local function fmtMoney(n)
	n = tonumber(n) or 0
	local steps = { { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "k" } }
	for _, s in ipairs(steps) do
		if n >= s[1] then return ("%.2f%s"):format(n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end
local CHANCE_SUFFIX = { "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }
local function fmtChance(n)
	n = tonumber(n) or 0
	local i = 0
	while n >= 1000 and i < #CHANCE_SUFFIX do
		n /= 1000
		i += 1
	end
	local str
	if n >= 100 or i == 0 then
		str = tostring(math.floor(n + 0.5))
	else
		str = (("%.1f"):format(n):gsub("%.0$", ""))
	end
	return str .. (CHANCE_SUFFIX[i] or "")
end
local moduleCache = {}
local function getModule(path, root)
	local inst = root or Features
	for part in path:gmatch("[^%.]+") do
		inst = inst and inst:FindFirstChild(part)
	end
	if not inst then return nil end
	if moduleCache[inst] then return moduleCache[inst] end
	local ok, res = pcall(require, inst)
	if ok and res then
		moduleCache[inst] = res
		return res
	end
	return nil
end
local function getData(name)
	local D = getModule("Data.DataController")
	if not D then return nil end
	local ok, res = pcall(function() return D[name]() end)
	if ok then return res end
	return nil
end
local function entryConfig(name)
	local Reg = getModule("Inventory.EntryRegistry")
	if not Reg then return nil end
	local ok, cfg = pcall(Reg.getEntryConfig, name)
	return ok and cfg or nil
end

local function newLoop(name, fn, delay, hidden)
	local gen, on = 0, false
	local loop = { Name = name, Hidden = hidden }
	function loop.IsOn() return on end
	function loop.Set(state)
		on = state and true or false
		gen += 1
		if not on then return end
		local id = gen
		local function active() return on and id == gen and alive() end
		task.spawn(function()
			while active() do
				local ok, res = pcall(fn, active)
				if not ok then warn("[Lymn] " .. name .. ": " .. tostring(res)) end
				local d = (ok and type(res) == "number") and res
					or (type(delay) == "function" and delay() or delay or 1)
				task.wait(math.max(tonumber(d) or 1, 0.1))
			end
		end)
	end
	Loops[#Loops + 1] = loop
	return loop
end

local function addToggle(card, name, flag, loop, onChange)
	local t = card:Toggle({
		Name = name,
		Flag = flag,
		Callback = function(v)
			local was = loop.IsOn()
			loop.Set(v)
			if onChange then onChange(v, was) end
		end
	})
	Toggles[#Toggles + 1] = t
	return t
end

local statusPara

local function stopAll()
	for _, t in ipairs(Toggles) do pcall(function() t:Set(false) end) end
	for _, l in ipairs(Loops) do l.Set(false) end
end

local function unload()
	unloaded = true
	for _, l in ipairs(Loops) do l.Set(false) end
	if afkConn then afkConn:Disconnect() afkConn = nil end
	pcall(function() UI:Destroy() end)
	env.lymn_AnimeDice_Unload = nil
end
env.lymn_AnimeDice_Unload = unload
UI.OnClose = unload

local rollCard = AutoTab:Card("Roll")
local rollCount, rollStart, lastRoll = 0, os.clock(), "—"
local rollPara = rollCard:Paragraph({ Title = "Fast Roll", Content = "Idle." })

local function rollCooldown()
	local BC = getModule("Buffs.BuffController")
	if not BC then return 2.5 end
	local ok, r = pcall(BC.GetBuff, "Roll Duration")
	if ok and type(r) == "number" then return math.max(r, 0) end
	return 2.5
end
local function inventoryUsage()
	local BC = getModule("Buffs.BuffController")
	local inv = getData("Inventory")
	if not BC or type(inv) ~= "table" then return nil end
	local n = 0
	for _, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Unit" then n += 1 end
	end
	local _, storage = pcall(BC.GetBuff, "Unit Storage")
	local _, extra = pcall(BC.GetBuff, "Rolls")
	return n, (tonumber(storage) or 100) + (tonumber(extra) or 1) - 1
end
local function refreshRoll(note)
	local n, cap = inventoryUsage()
	local elapsed = os.clock() - rollStart
	local perMin = elapsed > 1 and rollCount / elapsed * 60 or 0
	local lines = {
		("Server cooldown: %.2fs"):format(rollCooldown()),
		("Rolls: %d (%.1f/min)"):format(rollCount, perMin),
		"Last: " .. lastRoll,
		n and ("Inventory: %d/%d units"):format(n, cap) or "Inventory: ?",
	}
	if n and cap and n >= cap then
		lines[#lines + 1] = "Inventory full — enable Auto Sell."
	end
	if note then lines[#lines + 1] = note end
	setSafe(rollPara, { Title = "Fast Roll", Content = table.concat(lines, "\n") })
end

local rollLoop = newLoop("Fast Roll", function()
	local ok, res = pcall(function() return Remotes.RollDice:InvokeServer() end)
	if ok and type(res) == "table" and #res > 0 then
		rollCount += #res
		local parts = {}
		for _, r in ipairs(res) do
			parts[#parts + 1] = r.mutation and (r.mutation .. " " .. tostring(r.result)) or tostring(r.result)
		end
		lastRoll = table.concat(parts, ", ")
		if #lastRoll > 60 then lastRoll = lastRoll:sub(1, 57) .. "..." end
		return math.max(rollCooldown() - 0.25, 0.1)
	end
	return 0.2
end, 0.2)

local rollStatusLoop = newLoop("Roll status", function()
	refreshRoll()
	return 2
end, 2, true)

addToggle(rollCard, "Fast Roll", "AnimeDiceFastRoll", rollLoop, function(v)
	if v then
		rollCount, rollStart = 0, os.clock()
		rollStatusLoop.Set(true)
	else
		rollStatusLoop.Set(false)
		refreshRoll("Stopped.")
	end
end)
rollCard:Button({
	Name = "Reset roll counter",
	Callback = function()
		rollCount, rollStart, lastRoll = 0, os.clock(), "—"
		refreshRoll()
	end
})

local plotCard = AutoTab:Card("Plot")
local collectInterval, equipInterval = 15, 10

local function collectableSlots()
	local PlotConfig = getModule("Plot.PlotConfig")
	local slots = getData("Slots")
	if not PlotConfig or type(slots) ~= "table" then return {}, 0 end
	local rebirth = tonumber(getData("Rebirth")) or 0
	local okMax, max = pcall(PlotConfig.GetMaxSlots)
	max = okMax and tonumber(max) or 13
	local list, total = {}, 0
	for i = 1, max do
		local okReq, req = pcall(PlotConfig.GetSlotRebirthRequirement, i)
		req = okReq and tonumber(req) or math.huge
		if req <= rebirth then
			local slot = slots[tostring(i)]
			local bal = slot and tonumber(slot.balance) or 0
			if bal > 0 then
				list[#list + 1] = i
				total += bal
			end
		end
	end
	return list, total
end
local function collectNow()
	local list, total = collectableSlots()
	for _, i in ipairs(list) do
		pcall(function() Remotes.CollectBalance:FireServer(i) end)
		task.wait(0.05)
	end
	return #list, total
end
local collectLoop = newLoop("Auto Collect", function()
	collectNow()
	return collectInterval
end, 15)
local equipLoop = newLoop("Auto Equip Best", function()
	pcall(function() Remotes.EquipBest:FireServer() end)
	return equipInterval
end, 10)

addToggle(plotCard, "Auto Collect", "AnimeDiceAutoCollect", collectLoop)
plotCard:Slider({
	Name = "Collect interval", Min = 1, Max = 60, Default = 15, Step = 1, Suffix = "s",
	Flag = "AnimeDiceCollectInterval",
	Callback = function(v) collectInterval = math.max(tonumber(v) or 15, 1) end
})
addToggle(plotCard, "Auto Equip Best", "AnimeDiceAutoEquipBest", equipLoop)
plotCard:Slider({
	Name = "Equip interval", Min = 2, Max = 120, Default = 10, Step = 1, Suffix = "s",
	Flag = "AnimeDiceEquipInterval",
	Callback = function(v) equipInterval = math.max(tonumber(v) or 10, 2) end
})
plotCard:Button({
	Name = "Collect now",
	Callback = function()
		task.spawn(function()
			local n, total = collectNow()
			notify("Collect", n > 0 and ("%d slots · +$%s"):format(n, fmtMoney(total)) or "Nothing to collect.")
		end)
	end
})

local diceCard = AutoTab:Card("Dice")

local function diceList()
	local Dice = getModule("Rolling.Dice")
	if not Dice then return {} end
	local ok, all = pcall(Dice.GetAll)
	if not ok or type(all) ~= "table" then return {} end
	local list = {}
	for name, d in pairs(all) do
		if type(d) == "table" and d.price then
			list[#list + 1] = { name = name, price = d.price, luck = d.luck or 0 }
		end
	end
	table.sort(list, function(a, b) return a.price > b.price end)
	return list
end
local function diceState()
	local owned = getData("OwnedDice")
	local money = tonumber(getData("Money")) or 0
	local equipped = getData("Dice")
	return type(owned) == "table" and owned or {}, money, equipped
end
local function equipBestDice()
	local owned, _, equipped = diceState()
	local bestName, bestLuck
	for _, d in ipairs(diceList()) do
		if owned[d.name] and (not bestLuck or d.luck > bestLuck) then
			bestName, bestLuck = d.name, d.luck
		end
	end
	if bestName and equipped ~= bestName then
		pcall(function() Remotes.EquipDice:FireServer(bestName) end)
		return bestName
	end
	return nil
end
local function buyDice()
	local owned, money = diceState()
	local bought = 0
	for _, d in ipairs(diceList()) do
		if not owned[d.name] and money >= d.price then
			pcall(function() Remotes.BuyDice:FireServer(d.name) end)
			money -= d.price
			bought += 1
			task.wait(0.6)
		end
	end
	if bought > 0 then
		task.wait(0.6)
		equipBestDice()
	end
	return bought
end

local diceLoop = newLoop("Auto Buy Dice", function()
	buyDice()
	return 5
end, 5)
addToggle(diceCard, "Auto Buy Dice", "AnimeDiceAutoBuyDice", diceLoop)
diceCard:Button({
	Name = "Equip best owned dice",
	Callback = function()
		task.spawn(function()
			local name = equipBestDice()
			notify("Dice", name and ("Equipped: " .. name) or "Already the best.")
		end)
	end
})

local upgradeCard = AutoTab:Card("Upgrades")
local branchSet = toSet(BRANCHES)
local function branchOf(name)
	local base, numeral = tostring(name):match("^(.*)%s+(%S+)$")
	if base and ROMAN[numeral] then return base end
	return nil
end
local function buyUpgrades(active)
	local Upg = getModule("Upgrades.Upgrades")
	local Tree = getModule("Upgrades.TreeStructure")
	local ownedRaw = getData("Upgrades")
	if not Upg or not Tree or type(ownedRaw) ~= "table" or type(Upg) ~= "table" then return 0 end
	local money = tonumber(getData("Money")) or 0
	local owned = {}
	for k, v in pairs(ownedRaw) do
		if v then owned[k] = true end
	end
	local list = {}
	for name, up in pairs(Upg) do
		local branch = branchOf(name)
		if branch and branchSet[branch] and not owned[name] and type(up) == "table" and up.price then
			list[#list + 1] = { name = name, price = up.price }
		end
	end
	table.sort(list, function(a, b) return a.price < b.price end)
	local bought, changed = 0, true
	while changed and active() do
		changed = false
		for _, up in ipairs(list) do
			if not owned[up.name] and money >= up.price then
				local okP, parent = pcall(Tree.GetParent, up.name)
				if not okP or not parent or parent == "Start" or owned[parent] then
					pcall(function() Remotes.BuyUpgrade:FireServer(up.name) end)
					owned[up.name] = true
					money -= up.price
					bought += 1
					changed = true
					task.wait(0.1)
				end
			end
		end
	end
	return bought
end

local upgradeLoop = newLoop("Auto Upgrades", function(active)
	buyUpgrades(active)
	return 5
end, 5)
addToggle(upgradeCard, "Auto Upgrades", "AnimeDiceAutoUpgrades", upgradeLoop)
upgradeCard:Dropdown({
	Name = "Branches to upgrade", Options = BRANCHES, Default = table.clone(BRANCHES), Multi = true,
	Flag = "AnimeDiceUpgradeBranches",
	Callback = function(v) branchSet = toSet(v) end
})
upgradeCard:Button({
	Name = "Buy available upgrades",
	Callback = function()
		task.spawn(function()
			local n = buyUpgrades(function() return true end)
			notify("Upgrades", n > 0 and ("%d upgrade(s) bought"):format(n) or "Nothing affordable.")
		end)
	end
})

local questCard = AutoTab:Card("Quests")
local function claimQuests()
	local D = getModule("Data.DataController")
	local Cfg = getModule("Quests.QuestConfig")
	if not D or not Cfg then return 0 end
	local periods = Cfg.Periods or {}
	local claimed = 0
	for _, period in ipairs({ "Daily", "Weekly" }) do
		local ok, state = pcall(function() return D.Quests[period]() end)
		if ok and type(state) == "table" then
			local progress, done = state.progress or {}, state.claimed or {}
			local pcfg = periods[period]
			for _, q in ipairs(pcfg and pcfg.quests or {}) do
				if (progress[q.id] or 0) >= q.target and not done[q.id] then
					pcall(function() Remotes.ClaimQuest:FireServer(period, q.id, state.expiresAt) end)
					claimed += 1
					task.wait(0.25)
				end
			end
		end
	end
	return claimed
end
local questLoop = newLoop("Auto Claim Quests", function()
	claimQuests()
	return 10
end, 10)
addToggle(questCard, "Auto Claim Quests", "AnimeDiceAutoClaimQuests", questLoop)
questCard:Button({
	Name = "Claim now",
	Callback = function()
		task.spawn(function()
			local n = claimQuests()
			notify("Quests", n > 0 and ("%d quest(s) claimed"):format(n) or "Nothing to claim.")
		end)
	end
})

local rebirthCard = AutoTab:Card("Rebirth")
local function rebirthInfo()
	local R = getModule("Rebirth.Rebirths")
	if not R then return nil end
	local current = tonumber(getData("Rebirth")) or 0
	local money = tonumber(getData("Money")) or 0
	local ok, nxt = pcall(R.GetNext, current)
	return current, money, (ok and nxt) or nil
end
local function tryRebirth()
	local current, money, nxt = rebirthInfo()
	if not current or not nxt or money < nxt.cost then return false end
	pcall(function() Remotes.Rebirth:FireServer() end)
	task.wait(1)
	local after = rebirthInfo()
	if after and current < after then
		notify("Rebirth", ("Rebirth %d · luck x%s"):format(after, tostring(nxt.luckMultiplier)))
		return true
	end
	return false
end
local rebirthLoop = newLoop("Auto Rebirth", function()
	tryRebirth()
	return 3
end, 3)
addToggle(rebirthCard, "Auto Rebirth", "AnimeDiceAutoRebirth", rebirthLoop)
rebirthCard:Button({
	Name = "Rebirth now",
	Callback = function()
		task.spawn(function()
			local current, money, nxt = rebirthInfo()
			if not current then
				notify("Rebirth", "Game data not loaded yet.")
			elseif not nxt then
				notify("Rebirth", ("Max level reached (%d)."):format(current))
			elseif not tryRebirth() then
				if money >= nxt.cost then
					notify("Rebirth", "Rebirth did not go through.")
				else
					notify("Rebirth", ("Missing $%s."):format(fmtMoney(nxt.cost - money)))
				end
			end
		end)
	end
})

local levelCard = LevelTab:Card("Auto Level Up")
local levelSettings = LevelTab:Card("Settings")
local levelMinRarity, levelTarget = "Common", 10
local function levelPass(active)
	local Reg = getModule("Inventory.EntryRegistry")
	local Rar = getModule("Other.Rarities", Framework)
	local UU = getModule("Inventory.Kinds.Unit.UnitUtil")
	local slots, inv = getData("Slots"), getData("Inventory")
	if not Reg or not Rar or not UU or type(slots) ~= "table" or type(inv) ~= "table" then return 0 end
	local okMin, minOrder = pcall(function() return Rar.Get(levelMinRarity).sortOrder end)
	minOrder = okMin and minOrder or 0
	local count = 0
	for key, slot in pairs(slots) do
		local num = tonumber(key)
		if num and slot.unitId then
			local unit = inv[slot.unitId]
			local cfg = unit and entryConfig(unit.name)
			if cfg and cfg.kind == "Unit" then
				local okR, order = pcall(function() return Rar.Get(cfg.getRarity(unit.attributes or {})).sortOrder end)
				if okR and order >= minOrder then
					local lastLevel, stuck = nil, 0
					while active() do
						local cur = getData("Inventory")
						local u = type(cur) == "table" and cur[slot.unitId]
						if not u then break end
						local level = tonumber((u.attributes or {}).level) or 1
						if level >= levelTarget then break end
						if level == lastLevel then stuck += 1 else stuck = 0 end
						lastLevel = level
						if stuck >= 8 then break end
						local money = tonumber(getData("Money")) or 0
						local okP, price = pcall(UU.GetLevelPrice, u.name, u.attributes)
						if not okP or type(price) ~= "number" or price > money then break end
						pcall(function() Remotes.LevelUpSlot:FireServer(num) end)
						count += 1
						task.wait(0.15)
					end
				end
			end
		end
	end
	return count
end
local levelLoop = newLoop("Auto Level Up", function(active)
	levelPass(active)
	return 6
end, 6)
addToggle(levelCard, "Auto Level Up", "AnimeDiceAutoLevelUp", levelLoop)
levelCard:Button({
	Name = "Run a pass",
	Callback = function()
		task.spawn(function()
			local n = levelPass(function() return true end)
			notify("Level Up", n > 0 and ("%d level(s)"):format(n) or "Nothing to level.")
		end)
	end
})
levelSettings:Dropdown({
	Name = "Minimum rarity (plotted units)", Options = RARITIES, Default = "Common",
	Flag = "AnimeDiceLevelUpRarity",
	Callback = function(v) levelMinRarity = first(v) or "Common" end
})
levelSettings:Input({
	Name = "Target level", Placeholder = "10", Default = "10",
	Flag = "AnimeDiceLevelUpTarget",
	Callback = function(v)
		local n = tonumber(v)
		if n and n >= 1 then
			levelTarget = math.floor(n)
		else
			notify("Level Up", "Invalid target level.")
		end
	end
})

local towerCard = HubTab:Card("Towers")
local towerDifficulty, towerReEquip = "Dragon Tower", true
local function towerNames()
	local T = getModule("Towers.Towers")
	local list = {}
	if T then
		local ok, all = pcall(T.GetAll)
		if ok and type(all) == "table" then
			for name, t in pairs(all) do
				list[#list + 1] = { name = name, order = type(t) == "table" and t.order or 0 }
			end
			table.sort(list, function(a, b) return a.order < b.order end)
		end
	end
	local names = {}
	for _, t in ipairs(list) do names[#names + 1] = t.name end
	if #names == 0 then names = { "Dragon Tower" } end
	return names
end
local function pollFloor()
	local ok, res = pcall(function() return Remotes.CompleteFloor:InvokeServer() end)
	if not ok or type(res) ~= "table" then return nil end
	for _, ev in ipairs(res) do
		if ev.action == "ended" then return "ended" end
	end
	return "running"
end
local function runTower(active)
	while active() do
		local s = pollFloor()
		if s ~= "running" then break end
		task.wait(0.5)
	end
	if not active() then return end
	local ok, started = pcall(function() return Remotes.PlayTower:InvokeServer(towerDifficulty) end)
	if not ok or not started then return end
	local lastGood = os.clock()
	while active() do
		local s = pollFloor()
		if s == "ended" then return end
		if s == "running" then
			lastGood = os.clock()
		elseif os.clock() - lastGood > 180 then
			return
		end
		task.wait(0.5)
	end
end
local towerLoop = newLoop("Auto Tower", function(active)
	if towerReEquip then
		pcall(function() Remotes.EquipTowerTeam:FireServer() end)
		task.wait(1.1)
	end
	runTower(active)
	return 3.1
end, 3.1)
addToggle(towerCard, "Auto Tower", "AnimeDiceAutoTower", towerLoop, function(v, was)
	if not v and was then
		task.spawn(function()
			pcall(function() Remotes.CancelTower:InvokeServer() end)
		end)
	end
end)
towerCard:Dropdown({
	Name = "Difficulty", Options = towerNames(), Default = "Dragon Tower",
	Flag = "AnimeDiceTowerDifficulty",
	Callback = function(v) towerDifficulty = first(v) or "Dragon Tower" end
})
towerCard:Toggle({
	Name = "Re-equip before each run", Default = true, Flag = "AnimeDiceTowerReEquip",
	Callback = function(v) towerReEquip = v end
})
towerCard:Button({
	Name = "Equip best team",
	Callback = function()
		task.spawn(function()
			pcall(function() Remotes.EquipTowerTeam:FireServer() end)
			task.wait(1.1)
			notify("Towers", "Team updated.")
		end)
	end
})

local function buildRoller(cfg)
	local selected, target, overwrite = {}, cfg.defaultTarget, false
	local card = HubTab:Card(cfg.name)
	local function tiersSorted()
		local tiers = getModule(cfg.tiersPath)
		local list = {}
		if type(tiers) == "table" then
			for name, t in pairs(tiers) do
				list[#list + 1] = { name = name, order = t.order or 0, protected = t.protected }
			end
			table.sort(list, function(a, b) return a.order < b.order end)
		end
		return list
	end
	local function unitEntries()
		local inv = getData("Inventory")
		if type(inv) ~= "table" then return {} end
		local out = {}
		for key, item in pairs(inv) do
			local ucfg = entryConfig(item.name)
			if ucfg and ucfg.kind == "Unit" then
				local attrs = item.attributes or {}
				local okC, chance = pcall(ucfg.chance, attrs)
				chance = okC and tonumber(chance) or 0
				local label = ("1 in %s · %s%s"):format(
					fmtChance(chance), item.name,
					attrs.mutation and (" (" .. tostring(attrs.mutation) .. ")") or ""
				)
				out[#out + 1] = { key = key, label = label, chance = chance }
			end
		end
		table.sort(out, function(a, b)
			if a.chance ~= b.chance then return a.chance > b.chance end
			return a.label < b.label
		end)
		return out
	end
	local function labels()
		local out, seen = {}, {}
		for _, u in ipairs(unitEntries()) do
			if not seen[u.label] then
				seen[u.label] = true
				out[#out + 1] = u.label
			end
		end
		return out
	end
	local function rollPass(active)
		local tiers = getModule(cfg.tiersPath)
		local inv = getData("Inventory")
		if type(tiers) ~= "table" or type(inv) ~= "table" then return 0 end
		local cur = inv[cfg.currency]
		local budget = cur and tonumber(cur.amount) or 0
		if budget <= 0 then return 0 end
		local targetOrder = (tiers[target] or {}).order or 0
		local count = 0
		for _, u in ipairs(unitEntries()) do
			if budget <= 0 or not active() then return count end
			if selected[u.label] then
				while budget > 0 and active() do
					local now = getData("Inventory")
					local item = type(now) == "table" and now[u.key]
					if not item then break end
					local tierName = item.attributes and item.attributes[cfg.attribute]
					local tier = tierName and tiers[tierName]
					if ((tier and tier.order) or 0) >= targetOrder then break end
					if tier and tier.protected and not overwrite then break end
					pcall(function() cfg.remote:FireServer(u.key, overwrite) end)
					budget -= 1
					count += 1
					task.wait(0.3)
				end
			end
		end
		return count
	end
	local loop = newLoop("Auto " .. cfg.name, function(active)
		rollPass(active)
		return 6
	end, 6)
	addToggle(card, "Auto " .. cfg.name, cfg.flags.enabled, loop)

	local unitDropdown = card:Dropdown({
		Name = "Units to " .. cfg.name:lower() .. " (rarest first)",
		Options = labels(), Default = {}, Multi = true, Flag = cfg.flags.units,
		Callback = function(v) selected = toSet(v) end
	})
	card:Button({
		Name = "Refresh unit list",
		Callback = function()
			local list = labels()
			task.spawn(function() pcall(function() unitDropdown:Refresh(list) end) end)
		end
	})

	local tierNames, protectedName = {}, "?"
	for _, t in ipairs(tiersSorted()) do
		tierNames[#tierNames + 1] = t.name
		if t.protected and protectedName == "?" then protectedName = t.name end
	end
	card:Dropdown({
		Name = "Minimum " .. cfg.name:lower(), Options = tierNames, Default = cfg.defaultTarget,
		Flag = cfg.flags.target,
		Callback = function(v) target = first(v) or cfg.defaultTarget end
	})
	card:Toggle({
		Name = ("Overwrite protected (%s+)"):format(protectedName), Flag = cfg.flags.overwrite,
		Callback = function(v) overwrite = v end
	})
	card:Button({
		Name = "Run a pass",
		Callback = function()
			task.spawn(function()
				local n = rollPass(function() return alive() end)
				notify(cfg.name, n > 0 and ("%d roll(s)"):format(n) or "Nothing to roll.")
			end)
		end
	})
end

buildRoller({
	name = "Grade", attribute = "grade", currency = "Gems",
	remote = Remotes.GradeRoll, tiersPath = "Grades.Grades", defaultTarget = "S",
	flags = {
		enabled = "AnimeDiceAutoGrade", units = "AnimeDiceGradeUnits",
		target = "AnimeDiceGradeTarget", overwrite = "AnimeDiceGradeOverwrite"
	}
})
buildRoller({
	name = "Trait", attribute = "trait", currency = "Trait Reroll",
	remote = Remotes.TraitRoll, tiersPath = "Traits.Traits", defaultTarget = "Damage I",
	flags = {
		enabled = "AnimeDiceAutoTrait", units = "AnimeDiceTraitUnits",
		target = "AnimeDiceTraitTarget", overwrite = "AnimeDiceTraitOverwrite"
	}
})

local potionCard = PotionTab:Card("Auto Use")
local potionTypes = PotionTab:Card("Potion Types")
local POTION_BASES = { "Normal", "Dragon", "Cursed", "Pirate", "Leaf" }
local CATEGORY_SUFFIX = { Luck = "Luck", Money = "Income", Damage = "Damage" }
local potionPicks = { Luck = {}, Money = {}, Damage = {} }
local wantedCategories = {}
local potionStackMinutes = 0
local function rebuildWanted()
	local set = {}
	for kind, picks in pairs(potionPicks) do
		local suffix = CATEGORY_SUFFIX[kind]
		for prefix in pairs(picks) do
			set[prefix == "Normal" and suffix or (prefix .. " " .. suffix)] = true
		end
	end
	wantedCategories = set
end
local potionOptions = table.clone(POTION_BASES)
pcall(function()
	local Reg = getModule("Inventory.EntryRegistry")
	local seen, extra = toSet(POTION_BASES), {}
	for id in pairs(Reg.entriesOfKind("Boost")) do
		local cfg = Reg.getEntryConfig(id)
		local prefix = cfg and cfg.category and cfg.category:match("^(.+) %a+$")
		if prefix and not seen[prefix] then
			seen[prefix] = true
			extra[#extra + 1] = prefix
		end
	end
	table.sort(extra)
	for _, p in ipairs(extra) do potionOptions[#potionOptions + 1] = p end
end)
local function usePotions(force)
	local inv = getData("Inventory")
	if type(inv) ~= "table" then return 0 end
	local activeEntries = getData("ActiveEntries")
	if type(activeEntries) ~= "table" then activeEntries = {} end
	local now = workspace:GetServerTimeNow()
	local remaining = {}
	for _, e in pairs(activeEntries) do
		local cfg = entryConfig(e.name)
		if cfg and cfg.kind == "Boost" then
			local left = tonumber(e.remaining) or 0
			if type(e.startedAt) == "number" then left -= now - e.startedAt end
			if left > 0 then remaining[cfg.category] = (remaining[cfg.category] or 0) + left end
		end
	end
	local byCat = {}
	for key, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Boost" and (item.amount or 0) > 0 and wantedCategories[cfg.category] then
			local list = byCat[cfg.category] or {}
			list[#list + 1] = {
				key = key, tier = cfg.tier or 0,
				duration = tonumber(cfg.duration) or 0, amount = item.amount
			}
			byCat[cfg.category] = list
		end
	end
	local goal = math.max(potionStackMinutes * 60, 1)
	local used = 0
	for cat, list in pairs(byCat) do
		table.sort(list, function(a, b) return a.tier > b.tier end)
		local left = remaining[cat] or 0
		for _, p in ipairs(list) do
			while p.amount > 0 and (force or left < goal) do
				pcall(function() Remotes.UseBoost:FireServer(p.key) end)
				p.amount -= 1
				left += (p.duration > 0) and p.duration or goal
				used += 1
				task.wait(0.15)
			end
		end
	end
	return used
end
local potionLoop = newLoop("Auto Use Potions", function()
	usePotions(false)
	return 5
end, 5)
addToggle(potionCard, "Auto Use Potions", "AnimeDiceAutoPotions", potionLoop)
potionCard:Slider({
	Name = "Keep stacked per type", Min = 0, Max = 180, Default = 0, Step = 5, Suffix = "min",
	Flag = "AnimeDicePotionStackMinutes",
	Callback = function(v) potionStackMinutes = tonumber(v) or 0 end
})
potionCard:Button({
	Name = "Use potions now",
	Callback = function()
		task.spawn(function()
			local n = usePotions(false)
			notify("Potions", n > 0 and ("%d potion(s) used"):format(n) or "Nothing to use.")
		end)
	end
})
potionCard:Button({
	Name = "Use ALL selected (stack everything)",
	Callback = function()
		task.spawn(function()
			local n = usePotions(true)
			notify("Potions", n > 0 and ("%d potion(s) used"):format(n) or "Nothing to use.")
		end)
	end
})
for _, kind in ipairs({ "Luck", "Money", "Damage" }) do
	potionTypes:Dropdown({
		Name = kind .. " potions", Options = table.clone(potionOptions), Default = {}, Multi = true,
		Flag = "AnimeDicePotion" .. kind,
		Callback = function(v)
			potionPicks[kind] = toSet(v)
			rebuildWanted()
		end
	})
end

local sellCard = SellTab:Card("Auto Sell")
local sellAllCard = SellTab:Card("Sell whole rarity")
local sellMutCard = SellTab:Card("Sell by mutation")
local sellRarityAll, sellRarityMut, sellMutations = {}, {}, {}
local sellInterval = 5

local function sellableKeys()
	local inv, slots = getData("Inventory"), getData("Slots")
	if type(inv) ~= "table" or type(slots) ~= "table" then return {} end
	local equipped = {}
	for _, s in pairs(slots) do
		if s.unitId then equipped[s.unitId] = true end
	end
	local keys = {}
	for key, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Unit" and (item.amount or 0) > 0 and not equipped[key] then
			local attrs = item.attributes or {}
			if not attrs.locked then
				local okR, rarity = pcall(function() return cfg.getRarity(attrs) end)
				if not okR or not rarity then rarity = cfg.rarity end
				local r = tostring(rarity)
				local mutation = attrs.mutation and tostring(attrs.mutation) or "No mutation"
				if sellRarityAll[r] or (sellRarityMut[r] and sellMutations[mutation]) then
					keys[#keys + 1] = key
				end
			end
		end
	end
	return keys
end
local function sellNow()
	local keys = sellableKeys()
	if #keys == 0 then return 0, 0 end
	local ok, money, count = pcall(function() return Remotes.SellInventory:InvokeServer(keys) end)
	if not ok then return 0, 0 end
	return tonumber(money) or 0, tonumber(count) or 0
end
local sellLoop = newLoop("Auto Sell", function()
	sellNow()
	return sellInterval
end, 5)
addToggle(sellCard, "Auto Sell", "AnimeDiceAutoSell", sellLoop)
sellCard:Slider({
	Name = "Interval", Min = 1, Max = 30, Default = 5, Step = 1, Suffix = "s",
	Flag = "AnimeDiceSellInterval",
	Callback = function(v) sellInterval = math.max(tonumber(v) or 5, 1) end
})
sellCard:Button({
	Name = "Sell now",
	Callback = function()
		task.spawn(function()
			local money, count = sellNow()
			notify("Sell", count > 0 and ("%d units · +$%s"):format(count, fmtMoney(money)) or "Nothing to sell.")
		end)
	end
})
sellAllCard:Dropdown({
	Name = "Rarities to sell (any mutation)", Options = RARITIES, Default = {}, Multi = true,
	Flag = "AnimeDiceSellRaritiesAll",
	Callback = function(v) sellRarityAll = toSet(v) end
})
sellMutCard:Dropdown({
	Name = "Rarities", Options = RARITIES, Default = {}, Multi = true,
	Flag = "AnimeDiceSellMutatedRarities",
	Callback = function(v) sellRarityMut = toSet(v) end
})
do
	local muts = { "No mutation" }
	for _, m in ipairs(MUTATIONS) do muts[#muts + 1] = m end
	sellMutCard:Dropdown({
		Name = "Mutations to sell", Options = muts, Default = {}, Multi = true,
		Flag = "AnimeDiceSellMutations",
		Callback = function(v) sellMutations = toSet(v) end
	})
end

local utilCard = MiscTab:Card("Utility")
local scriptCard = MiscTab:Card("Script")

local function antiAfkTick()
	pcall(function()
		local vp = workspace.CurrentCamera.ViewportSize
		VirtualInputManager:SendMouseMoveEvent(vp.X / 2 + 2, vp.Y / 2, game)
		task.wait(0.05)
		VirtualInputManager:SendMouseMoveEvent(vp.X / 2, vp.Y / 2, game)
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F13, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F13, false, game)
	end)
end
local afkLoop = newLoop("Anti-AFK", function()
	antiAfkTick()
	return 60
end, 60)
addToggle(utilCard, "Anti-AFK", "AnimeDiceAntiAfk", afkLoop, function(v)
	if v then
		if not afkConn then afkConn = LocalPlayer.Idled:Connect(antiAfkTick) end
	elseif afkConn then
		afkConn:Disconnect()
		afkConn = nil
	end
end)
utilCard:Label("Sends a virtual mouse move + key press every 60s (works with Roblox in background).")
utilCard:Button({
	Name = "Rejoin server",
	Callback = function()
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	end
})

statusPara = scriptCard:Paragraph({ Title = "Running now", Content = "Nothing running." })
scriptCard:Button({
	Name = "Stop all automation",
	Callback = function()
		stopAll()
		notify("Lymn", "All automation stopped.")
	end
})
scriptCard:Button({ Name = "Unload script", Callback = unload })
scriptCard:Label("Toggle the menu with the floating button.")

UI:LoadConfig()

task.spawn(function()
	while alive() do
		local names = {}
		for _, l in ipairs(Loops) do
			if l.IsOn() and not l.Hidden then names[#names + 1] = l.Name end
		end
		setSafe(statusPara, {
			Title = "Running now",
			Content = #names > 0 and table.concat(names, "\n") or "Nothing running."
		})
		task.wait(3)
	end
end)

task.spawn(function()
	task.wait(1)
	refreshRoll()
end)

Window:Notify({ Title = "Success!", Description = "Lymn loaded successfully.", Duration = 4 })
