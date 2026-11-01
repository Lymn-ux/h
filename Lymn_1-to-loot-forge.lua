local Boot = getgenv()
if Boot.LymnBooting and os.clock() - Boot.LymnBooting < 25 then
	pcall(function()
		game:GetService("StarterGui")
			:SetCore("SendNotification", { Title = "Lymn", Text = "Already starting, give it a few seconds", Duration = 5 })
	end)
	return
end
Boot.LymnBooting = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
do
	local waited = 0
	local ok = false
	while not ok and waited < 25 do
		local remote = ReplicatedStorage:FindFirstChild("Remote")
		local world = workspace:FindFirstChild("WorldModel")
		ok = remote ~= nil
			and remote:FindFirstChild("Stage") ~= nil
			and remote:FindFirstChild("Forge") ~= nil
			and world ~= nil
			and world:FindFirstChild("StageMap") ~= nil
		if not ok then
			waited += task.wait(0.5) or 0.5
		end
	end
	if not ok then
		Boot.LymnBooting = nil
		warn("[Lymn] This is not +1 Loot To Forge, the hub was not started")
		return
	end
	-- The game marks its UI as ready once every controller and the player data are loaded.
	waited = 0
	while workspace:GetAttribute("UIInitDone") ~= true and waited < 60 do
		waited += task.wait(0.25) or 0.25
	end
	LocalPlayer:WaitForChild("Eco", 20)
	LocalPlayer:WaitForChild("PlayerGui", 20)
	task.wait(0.5)
end
local BootOk, BootError = xpcall(function()
local HubRepo = "https://raw.githubusercontent.com/vaensigma/Corvus/refs/heads/main/"
local Library = (function()
	local Players = game:GetService("Players")
	local StarterGui = game:GetService("StarterGui")
	local UserInputService = game:GetService("UserInputService")
	local TeleportService = game:GetService("TeleportService")
	local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

	local Library = {
		Options = {},
		Toggles = {},
		Unloaded = false,
		IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
	}
	local Signals, UnloadCallbacks, TabList = {}, {}, {}
	local Window

	local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
	local Lib = ProxyLib.new()

	local ICON_INFO = "rbxassetid://6031075938"
	local ICON_MAIN = "rbxassetid://6035067836"
	local ICON_EXTRA = "rbxassetid://6031280882"

	local function strip(text)
		text = tostring(text == nil and "" or text)
		text = (text:gsub("<br%s*/?>", "\n"))
		text = (text:gsub("<[^>]+>", ""))
		text = (text:gsub("&lt;", "<"))
		text = (text:gsub("&gt;", ">"))
		text = (text:gsub("&amp;", "&"))
		return text
	end

	local function method(obj, name)
		local ok, fn = pcall(function()
			return obj[name]
		end)
		if ok and type(fn) == "function" then
			return fn
		end
		return nil
	end

	local function callAny(obj, names, ...)
		if obj == nil then
			return false
		end
		for _, name in ipairs(names) do
			local fn = method(obj, name)
			if fn and pcall(fn, obj, ...) then
				return true
			end
		end
		return false
	end

	local function create(tab, names, props)
		for _, name in ipairs(names) do
			local fn = method(tab, name)
			if fn then
				local ok, element = pcall(fn, tab, props)
				if ok then
					return element
				end
			end
		end
		return nil
	end

	local function toSet(value)
		local set = {}
		if type(value) == "table" then
			for k, v in pairs(value) do
				if type(k) == "number" then
					set[tostring(v)] = true
				elseif v then
					set[tostring(k)] = true
				end
			end
		elseif value ~= nil then
			set[tostring(value)] = true
		end
		return set
	end

	local function toList(set, order)
		local list = {}
		for _, name in ipairs(order) do
			if set[name] then
				table.insert(list, name)
			end
		end
		return list
	end

	local function fireAll(obj, value)
		if obj.Callback then
			local ok, err = pcall(obj.Callback, value)
			if not ok then
				warn("[Lymn] callback " .. tostring(obj.Idx) .. ": " .. tostring(err))
			end
		end
		for _, fn in ipairs(obj.Changed) do
			pcall(fn, value)
		end
	end

	-- Shared option behaviour (Toggle, Slider, Dropdown, Input, Label)
	local Option = {}
	Option.__index = Option

	function Option:OnChanged(fn)
		table.insert(self.Changed, fn)
		return self
	end

	function Option:GetValue()
		return self.Value
	end

	function Option:SetVisible() end
	function Option:SetDisabled() end
	function Option:Show() end
	function Option:Hide() end

	function Option:_push(value)
		if self.Element then
			self._sync = true
			local shown = value
			if self.Type == "Dropdown" and self.Multi then
				shown = toList(value, self.Values)
			end
			callAny(self.Element, { "Set", "SetValue", "SetState", "SetSelected", "Select", "Update" }, shown)
			self._sync = false
		end
	end

	function Option:SetValue(value)
		if self.Type == "Toggle" then
			value = value == true
			if self.Value == value then
				return
			end
		elseif self.Type == "Slider" then
			value = self:_round(tonumber(value) or self.Default)
			if self.Value == value then
				return
			end
		elseif self.Type == "Dropdown" then
			if self.Multi then
				value = toSet(value)
			else
				if type(value) == "table" then
					value = value[1]
				end
				value = value ~= nil and tostring(value) or nil
				if self.Value == value then
					return
				end
			end
		elseif self.Type == "Input" then
			value = tostring(value == nil and "" or value)
			if self.Value == value then
				return
			end
		end
		self.Value = value
		self:_push(value)
		fireAll(self, value)
	end

	function Option:_round(v)
		local r = self.Rounding or 0
		local m = 10 ^ r
		v = math.floor(v * m + 0.5) / m
		return math.clamp(v, self.Min, self.Max)
	end

	function Option:SetText(text)
		text = strip(text)
		if self.Text == text then
			return
		end
		self.Text = text
		if self.Element then
			local fn
			for _, name in ipairs({ "SetDescription", "SetText", "SetContent", "SetBody", "Set", "SetValue", "Update" }) do
				fn = method(self.Element, name)
				if fn and pcall(fn, self.Element, text) then
					return
				end
			end
			pcall(function()
				self.Element.Description = text
			end)
		end
	end

	local function newOption(kind, idx, info)
		local obj = setmetatable({
			Type = kind,
			Idx = idx,
			Changed = {},
			Callback = info.Callback,
			Text = info.Text,
			Tooltip = info.Tooltip,
		}, Option)
		return obj
	end

	-- Groupbox: records controls and builds them in order when Library:Flush() runs
	local Groupbox = {}
	Groupbox.__index = Groupbox

	function Groupbox:_op(fn)
		table.insert(self.Ops, fn)
	end

	function Groupbox:AddToggle(idx, info)
		info = info or {}
		local obj = newOption("Toggle", idx, info)
		obj.Default = info.Default == true
		obj.Value = obj.Default
		Library.Toggles[idx] = obj
		self:_op(function(tab)
			obj.Element = create(tab, { "CreateToggle", "AddToggle", "Toggle" }, {
				Title = strip(info.Text or idx),
				Name = strip(info.Text or idx),
				Description = info.Tooltip and strip(info.Tooltip) or nil,
				Default = obj.Value,
				Callback = function(v)
					if obj._sync then
						return
					end
					v = v == true
					if obj.Value == v then
						return
					end
					obj.Value = v
					if type(Library.OnUserToggle) == "function" then
						pcall(Library.OnUserToggle, idx, v)
					end
					fireAll(obj, v)
				end,
			})
		end)
		return obj
	end

	function Groupbox:AddSlider(idx, info)
		info = info or {}
		local obj = newOption("Slider", idx, info)
		obj.Min = info.Min or 0
		obj.Max = info.Max or 100
		obj.Rounding = info.Rounding or 0
		obj.Default = info.Default or obj.Min
		obj.Value = obj.Default
		Library.Options[idx] = obj
		local suffix = info.Suffix and (strip(info.Suffix):gsub("^%s+", "")) or nil
		local title = strip(info.Text or idx) .. (suffix and suffix ~= "" and (" (" .. suffix .. ")") or "")
		self:_op(function(tab)
			obj.Element = create(tab, { "CreateSlider", "AddSlider", "Slider" }, {
				Title = title,
				Name = title,
				Description = info.Tooltip and strip(info.Tooltip) or nil,
				Min = obj.Min,
				Max = obj.Max,
				Default = obj.Value,
				Increment = 10 ^ -obj.Rounding,
				Step = 10 ^ -obj.Rounding,
				Suffix = info.Suffix,
				Callback = function(v)
					if obj._sync then
						return
					end
					v = obj:_round(tonumber(v) or obj.Default)
					if obj.Value == v then
						return
					end
					obj.Value = v
					fireAll(obj, v)
				end,
			})
		end)
		return obj
	end

	function Groupbox:AddDropdown(idx, info)
		info = info or {}
		local obj = newOption("Dropdown", idx, info)
		obj.Multi = info.Multi == true
		obj.Values = {}
		for _, v in ipairs(info.Values or {}) do
			table.insert(obj.Values, tostring(v))
		end
		obj.Default = info.Default
		if obj.Multi then
			obj.Value = toSet(info.Default)
		else
			local d = info.Default
			if type(d) == "number" then
				d = obj.Values[d]
			end
			obj.Value = d ~= nil and tostring(d) or nil
		end
		Library.Options[idx] = obj
		self:_op(function(tab)
			local start = obj.Value
			if obj.Multi then
				start = toList(obj.Value, obj.Values)
			end
			obj.Element = create(tab, { "CreateDropdown", "AddDropdown", "Dropdown" }, {
				Title = strip(info.Text or idx),
				Name = strip(info.Text or idx),
				Description = info.Tooltip and strip(info.Tooltip) or nil,
				Options = obj.Values,
				Values = obj.Values,
				List = obj.Values,
				Default = start,
				Multi = obj.Multi,
				Multiple = obj.Multi,
				MultiSelect = obj.Multi,
				Callback = function(v)
					if obj._sync then
						return
					end
					if obj.Multi then
						obj.Value = toSet(v)
						fireAll(obj, obj.Value)
					else
						if type(v) == "table" then
							v = v[1]
						end
						v = v ~= nil and tostring(v) or nil
						if obj.Value == v then
							return
						end
						obj.Value = v
						fireAll(obj, v)
					end
				end,
			})
		end)
		return obj
	end

	function Groupbox:AddInput(idx, info)
		info = info or {}
		local obj = newOption("Input", idx, info)
		obj.Default = info.Default or ""
		obj.Value = obj.Default
		Library.Options[idx] = obj
		self:_op(function(tab)
			obj.Element = create(tab, { "CreateInput", "CreateTextbox", "CreateTextBox", "AddInput", "Input" }, {
				Title = strip(info.Text or idx),
				Name = strip(info.Text or idx),
				Description = info.Tooltip and strip(info.Tooltip) or nil,
				Placeholder = info.Placeholder,
				Default = obj.Value,
				Callback = function(v)
					if obj._sync then
						return
					end
					v = tostring(v == nil and "" or v)
					if obj.Value == v then
						return
					end
					obj.Value = v
					fireAll(obj, v)
				end,
			})
		end)
		return obj
	end

	function Groupbox:AddButton(info, func)
		if type(info) == "string" then
			info = { Text = info, Func = func }
		end
		info = info or {}
		local obj = newOption("Button", nil, info)
		local fn = info.Func or info.Callback or function() end
		local label = strip(info.Text or "Button")
		self:_op(function(tab)
			obj.Element = create(tab, { "CreateButton", "AddButton", "Button" }, {
				Title = label,
				Name = label,
				Text = label,
				Description = info.Tooltip and strip(info.Tooltip) or label,
				Callback = function()
					local ok, err = pcall(fn)
					if not ok then
						warn("[Lymn] button " .. label .. ": " .. tostring(err))
					end
				end,
			})
		end)
		function obj:AddButton()
			return obj
		end
		return obj
	end

	function Groupbox:AddLabel(info, wrap)
		if type(info) == "string" then
			info = { Text = info, DoesWrap = wrap }
		end
		info = info or {}
		local obj = newOption("Label", nil, info)
		obj.Text = strip(info.Text or "")
		local box = self
		self:_op(function(tab)
			obj.Element = create(tab, { "CreateParagraph", "CreateLabel", "AddLabel", "Paragraph", "Label" }, {
				Title = box.Name,
				Name = box.Name,
				Text = obj.Text,
				Description = obj.Text,
			})
		end)
		return obj
	end

	function Groupbox:AddDivider() end

	-- Tabs
	local Tab = {}
	Tab.__index = Tab

	function Tab:_box(name)
		local box = setmetatable({ Name = strip(name or "Section"), Ops = {}, Tab = self }, Groupbox)
		table.insert(self.Boxes, box)
		return box
	end

	function Tab:AddLeftGroupbox(name)
		return self:_box(name)
	end

	function Tab:AddRightGroupbox(name)
		return self:_box(name)
	end

	function Tab:Show() end

	local function newTab(proxyTab)
		local tab = setmetatable({ Lib = proxyTab, Boxes = {} }, Tab)
		table.insert(TabList, tab)
		return tab
	end

	local WindowShim = {}

	function WindowShim:AddTab(a, b)
		local name, desc, icon = a, "", ICON_MAIN
		if type(a) == "table" then
			name, desc = a.Name or "Tab", a.Description or ""
		end
		local proxyTab = Window:CreateTab({ Title = tostring(name), Subtitle = tostring(desc), Icon = icon })
		return newTab(proxyTab)
	end

	function WindowShim:AddInfoTab()
		local proxyTab = Window:CreateTab({ Title = "Information", Subtitle = "Update/Dev Info", Icon = ICON_INFO })
		pcall(function()
			proxyTab:CreateDiscordInvite({
				Title = "Lymn Official",
				Description = "Join our server for updates, announcements, support, and community.",
				Icon = "rbxassetid://105369821130198",
				Banner = "rbxassetid://123002136721231",
				Link = "https://discord.gg/6B36mdd6cJ",
				Button = "Join Server",
			})
		end)
		return newTab(proxyTab)
	end

	function WindowShim:AddMiscTab(info)
		local proxyTab = Window:CreateTab({
			Title = "Misc",
			Subtitle = (type(info) == "table" and info.Description) or "Performance and AFK",
			Icon = ICON_EXTRA,
		})
		local tab = newTab(proxyTab)
		local box = tab:_box("Utility")
		box:AddToggle("LymnAntiAFK", {
			Text = "Anti AFK",
			Default = true,
			Tooltip = "Stops the game from kicking you for being idle",
		})
		box:AddButton({
			Text = "Rejoin Server",
			Tooltip = "Teleports you back into this server",
			Func = function()
				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end)
			end,
		})
		table.insert(
			Signals,
			LocalPlayer.Idled:Connect(function()
				local t = Library.Toggles.LymnAntiAFK
				if t and t.Value then
					pcall(function()
						local vu = game:GetService("VirtualUser")
						vu:CaptureController()
						vu:ClickButton2(Vector2.new())
					end)
				end
			end)
		)
		return tab
	end

	-- Library API used by the hub
	function Library:CreateWindow()
		Window = Lib:CreateWindow({
			Title = "Lymn",
			Subtitle = "+1 Loot To Forge",
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
				Icon = "rbxassetid://105369821130198",
			},
			Acrylic = { Enabled = false, Opacity = 0 },
		})
		return WindowShim
	end

	function Library:Flush()
		for _, tab in ipairs(TabList) do
			for _, box in ipairs(tab.Boxes) do
				if #box.Ops > 0 then
					create(tab.Lib, { "CreateSection", "AddSection", "Section" }, { Text = box.Name, Title = box.Name })
					for _, op in ipairs(box.Ops) do
						local ok, err = pcall(op, tab.Lib)
						if not ok then
							warn("[Lymn] UI: " .. tostring(err))
						end
					end
				end
			end
		end
	end

	function Library:Notify(info)
		info = type(info) == "table" and info or { Description = tostring(info) }
		local data = {
			Title = info.Title or "Lymn",
			Description = strip(info.Description or info.Text or ""),
			Duration = info.Time or info.Duration or 3,
		}
		if Window and pcall(Window.Notify, Window, data) then
			return
		end
		pcall(function()
			StarterGui:SetCore("SendNotification", { Title = data.Title, Text = data.Description, Duration = data.Duration })
		end)
	end

	function Library:ShowConfirmPrompt(info)
		if type(info) == "table" and type(info.OnConfirm) == "function" then
			pcall(info.OnConfirm)
		end
	end

	function Library:GiveSignal(signal)
		table.insert(Signals, signal)
		return signal
	end

	function Library:OnUnload(fn)
		table.insert(UnloadCallbacks, fn)
	end

	function Library:Unload()
		Library.Unloaded = true
		for _, fn in ipairs(UnloadCallbacks) do
			pcall(fn)
		end
		for _, signal in ipairs(Signals) do
			pcall(function()
				signal:Disconnect()
			end)
		end
	end

	return Library
end)()

local N = {}
local ThemeManager, SaveManager, Options, Toggles, Discord, GameName, LoaderScript, INSTANCE, alive, UIQueue, notify, HttpService
local RunService, LogFile, Log, brief, log, logProblem, flushLog, Perf, fire, invoke, waitFor, isolated
do
	ThemeManager = { Ignore = {} }
	SaveManager = { Ignore = {} }
	Options = Library.Options
	Toggles = Library.Toggles
	Discord = "https://discord.gg/6B36mdd6cJ"
	GameName = "+1 Loot To Forge"
	LoaderScript = ""
	local Env = getgenv()
	if Env.LootToForgeInstance then
		pcall(function()
			Env.LootToForgeInstance.stop = true
		end)
	end
	task.wait(0.2)
	INSTANCE = { stop = false }
	Env.LootToForgeInstance = INSTANCE
	function alive()
		return not INSTANCE.stop and Env.LootToForgeInstance == INSTANCE and not Library.Unloaded
	end
	UIQueue = { list = {} }
	function UIQueue.push(fn)
		if #UIQueue.list < 200 then
			table.insert(UIQueue.list, fn)
		end
	end
	function UIQueue.flush()
		local list = UIQueue.list
		if #list == 0 then
			return
		end
		UIQueue.list = {}
		for _, fn in ipairs(list) do
			pcall(fn)
		end
	end
	function notify(Title, Text, Time)
		UIQueue.push(function()
			Library:Notify({ Title = Title, Description = Text, Time = Time or 3 })
		end)
	end
	HttpService = game:GetService("HttpService")
	RunService = game:GetService("RunService")
	LogFile = "Lymn_LTF_" .. LocalPlayer.Name .. "_log.txt"
	Log = { lines = {}, start = os.clock(), dirty = false, flushedAt = 0, problems = {}, problemCount = 0, limit = 4000 }
	function brief(value, depth)
		depth = depth or 0
		local kind = typeof(value)
		if kind == "Instance" then
			local ok, name = pcall(function()
				return value.Name
			end)
			return if ok then tostring(name) else "?"
		elseif kind == "Vector3" then
			return string.format("(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
		elseif kind == "CFrame" then
			local p = value.Position
			return string.format("CF(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
		elseif kind == "number" then
			if value ~= value then
				return "nan"
			elseif value % 1 == 0 and math.abs(value) < 1e15 then
				return string.format("%d", value)
			elseif math.abs(value) >= 1e6 then
				return string.format("%.3g", value)
			end
			return string.format("%.2f", value)
		elseif kind == "string" then
			return if #value > 120 then string.sub(value, 1, 120) .. "..." else value
		elseif kind == "table" then
			if depth >= 2 then
				return "{...}"
			end
			local parts, n = {}, 0
			for k, v in pairs(value) do
				n += 1
				if n > 10 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, tostring(k) .. "=" .. brief(v, depth + 1))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return tostring(value)
	end
	function log(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = if type(parts[i]) == "string" then parts[i] else brief(parts[i])
		end
		local line =
			string.format("[%7.2f] %s", os.clock() - Log.start, (string.gsub(table.concat(parts, " ", 1, parts.n), "%s+$", "")))
		if #line > 600 then
			line = string.sub(line, 1, 600) .. "..."
		end
		local lines = Log.lines
		lines[#lines + 1] = line
		if #lines > Log.limit + 500 then
			table.move(lines, #lines - Log.limit + 1, #lines, 1)
			for i = #lines, Log.limit + 1, -1 do
				lines[i] = nil
			end
		end
		Log.dirty = true
	end
	Library.LoadLogger = function(line)
		pcall(log, line)
	end
	function logProblem(text)
		text = string.sub(tostring(text or ""), 1, 300)
		log("PROBLEM", text)
		Log.problemCount += 1
		if #Log.problems < 12 and not table.find(Log.problems, text) then
			table.insert(Log.problems, text)
		end
	end
	function flushLog(force)
		if Log.dirty and type(writefile) == "function" and (force or os.clock() - Log.flushedAt > 30) then
			Log.dirty = false
			Log.flushedAt = os.clock()
			local head = ""
			if Log.header then
				local ok, text = pcall(Log.header)
				if ok and type(text) == "string" then
					head = text .. "\n"
				end
			end
			task.spawn(pcall, writefile, LogFile, head .. table.concat(Log.lines, "\n"))
		end
	end
	local function argsText(args, first, last)
		local parts = {}
		for i = first, math.min(last, first + 5) do
			table.insert(parts, brief(args[i]))
		end
		if last > first + 5 then
			table.insert(parts, "...")
		end
		return table.concat(parts, ", ")
	end
	do
		local executor = "?"
		pcall(function()
			executor = table.concat({ identifyexecutor() }, " ")
		end)
		log("BOOT", GameName, "place", game.PlaceId, "job", string.sub(tostring(game.JobId), 1, 8), "executor", executor)
	end
	Perf = { frames = 0, time = 0, worst = 0, hitches = 0, freezes = 0, work = {}, hitchLogAt = 0, last = nil }
	Library:GiveSignal(RunService.Heartbeat:Connect(function(dt)
		Perf.frames += 1
		Perf.time += dt
		if dt > Perf.worst then
			Perf.worst = dt
		end
		if dt > 0.1 then
			Perf.hitches += 1
			if dt > 0.25 and os.clock() - Perf.hitchLogAt > 2 then
				Perf.hitchLogAt = os.clock()
				log("HITCH", math.floor(dt * 1000) .. "ms", "while:", if Log.context then Log.context() else "?")
			end
			if dt > 1 then
				Perf.freezes += 1
			end
		end
	end))
	-- Only the game's own player actions. Never Remote.Dev (admin tools), Attack.AttackPlayerRE (PvP),
	-- analytics, feedback or anything that prompts a Robux purchase.
	-- Paths are under ReplicatedStorage.Remote: "<Group>/<Name>".
	local Allowed = {
		["Backpack/TryEquipItemRE"] = true,
		["Backpack/TrySellItemRE"] = true,
		["Upgrade/UpgradeOnceRE"] = true,
		["Rebirth/TryRebirthRE"] = true,
		["Online/TryClaimRE"] = true,
		["Offline/TryClaimOfflineRewardRE"] = true,
		["Season/TryClaimAllRewardRE"] = true,
		["Season/TryClaimDailyTicRE"] = true,
		["Dungeon/TryClaimDailyDunTicRE"] = true,
		["Dungeon/ExitDungeonRE"] = true,
		["UpdateLog/TryClaimUPDRewardRE"] = true,
		["EnhantEvent/TryClaimQuestRE"] = true,
		["Player/TryJoinGroupRE"] = true,
		["Potion/TryUsePotionRE"] = true,
		["Class/LuckOnceRE"] = true,
		["WorldBoss/TryClaimBossRewardRE"] = true,
		["Season/LuckRE"] = true,
		["Season/ExchangeGoodsRE"] = true,
		-- Blatant probes (p05_probes, blatant.md): the game's own calls, sent sooner.
		["Dungeon/StartRoundRE"] = true,
		["Train/IntoAutoTrainRE"] = true,
	}
	local AllowedInvoke = {
		["Profile/GetTotalDataRF"] = true,
		["Forge/ForgeRF"] = true,
		["Index/TryClaimIndexExpRF"] = true,
		["Index/TryClaimLevelRewardRF"] = true,
		["Dungeon/TryIntoDungeonRF"] = true,
		["Code/TryUseCodeRF"] = true,
		["Backpack/EnhantEquipmentRF"] = true,
		["Stage/StageFinishedRF"] = true,
		["Stage/GetOreRF"] = true,
		["Dungeon/CompleteRoundRF"] = true,
	}
	-- Bindable events are the game's own buttons: ExitFightBE is the Return button (banks the ores),
	-- ATKOnceBE is one click of the attack button.
	local AllowedBindable = {
		["Stage/ExitFightBE"] = true,
		["Dungeon/DungeonGiveUpBE"] = true,
		["Attack/ATKOnceBE"] = true,
		["Attack/AttackEnemyBE"] = true,
		["Attack/EnemyHitBE"] = true,
	}
	local Quiet = {
		["Attack/ATKOnceBE"] = true,
		["Attack/AttackEnemyBE"] = true,
		["Attack/EnemyHitBE"] = true,
		["Profile/GetTotalDataRF"] = true,
		["Stage/GetOreRF"] = true,
		["Dungeon/StartRoundRE"] = true,
	}
	function N.remote(path)
		local node = ReplicatedStorage:FindFirstChild("Remote")
		for part in string.gmatch(path, "[^/]+") do
			node = node and node:FindFirstChild(part)
		end
		return node
	end
	function fire(name, ...)
		if not Allowed[name] then
			log("BLOCKED", name)
			return false
		end
		local remote = N.remote(name)
		if not (remote and remote:IsA("RemoteEvent")) then
			log("NO REMOTE", name)
			return false
		end
		local args = table.pack(...)
		local ok, err = pcall(function()
			remote:FireServer(table.unpack(args, 1, args.n))
		end)
		if not Quiet[name] or not ok then
			log("FIRE", name .. "(" .. argsText(args, 1, args.n) .. ")", if ok then "" else "failed: " .. tostring(err))
		end
		return ok
	end
	function N.bindable(name, ...)
		if not AllowedBindable[name] then
			log("BLOCKED", name)
			return false
		end
		local event = N.remote(name)
		if not (event and event:IsA("BindableEvent")) then
			log("NO BINDABLE", name)
			return false
		end
		local args = table.pack(...)
		local ok, err = pcall(function()
			event:Fire(table.unpack(args, 1, args.n))
		end)
		if not Quiet[name] or not ok then
			log("BINDABLE", name .. "(" .. argsText(args, 1, args.n) .. ")", if ok then "" else "failed: " .. tostring(err))
		end
		return ok
	end
	-- Returns ok and the first result.
	function invoke(name, timeout, ...)
		if not AllowedInvoke[name] then
			log("BLOCKED", name)
			return false, nil
		end
		local remote = N.remote(name)
		if not (remote and remote:IsA("RemoteFunction")) then
			log("NO REMOTE", name)
			return false, nil
		end
		local args = table.pack(...)
		local box = { done = false }
		task.spawn(function()
			local ok, result = pcall(function()
				return remote:InvokeServer(table.unpack(args, 1, args.n))
			end)
			box.ok, box.result, box.done = ok, result, true
		end)
		local started = os.clock()
		while not box.done and os.clock() - started < (timeout or 10) do
			task.wait(0.03)
		end
		if not Quiet[name] or not box.done or not box.ok then
			log("INVOKE", name .. "(" .. argsText(args, 1, args.n) .. ")", if box.done then brief(box.result) else "timed out")
		end
		if not box.done then
			return false, nil
		end
		return box.ok, box.result
	end
	function N.onRemote(name, fn)
		task.spawn(function()
			local remote = N.remote(name)
			local waited = 0
			while not remote and waited < 30 do
				waited += task.wait(1) or 1
				remote = N.remote(name)
			end
			if remote and remote:IsA("RemoteEvent") then
				Library:GiveSignal(remote.OnClientEvent:Connect(function(...)
					local args = table.pack(...)
					task.spawn(function()
						local ok, err = pcall(fn, table.unpack(args, 1, args.n))
						if not ok then
							log("ERROR", "event " .. name, tostring(err))
						end
					end)
				end))
			end
		end)
	end
	function waitFor(check, seconds)
		local waited = 0
		while waited < seconds do
			if check() then
				return true
			end
			waited += task.wait(0.05) or 0.05
		end
		return check() and true or false
	end
	function isolated(fn, ...)
		if type(fn) ~= "function" then
			return nil
		end
		local args = table.pack(...)
		local box = { done = false }
		task.spawn(function()
			box.result = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
			box.done = true
		end)
		if not box.done then
			local started = os.clock()
			while not box.done and os.clock() - started < 2 do
				task.wait()
			end
		end
		local result = box.result
		if box.done and result and result[1] then
			return table.unpack(result, 2, result.n)
		end
		if box.done and result and not result[1] then
			log("ISOLATED error", tostring(result[2]))
		end
		return nil
	end
	local function safeRequire(path)
		local result, done = nil, false
		task.spawn(function()
			local ok, value = pcall(function()
				local node = ReplicatedStorage
				for part in path:gmatch("[^%.]+") do
					node = node:WaitForChild(part, 8)
				end
				return require(node)
			end)
			result = ok and value or nil
			done = true
		end)
		local waited = 0
		while not done and waited < 12 do
			waited += task.wait(0.05) or 0.05
		end
		if result == nil then
			log("REQUIRE failed", path)
		end
		return result
	end
	function N.tableOr(value)
		return if type(value) == "table" then value else {}
	end
	-- Only the game's config modules and pure helpers. Player data comes from Profile.GetTotalDataRF plus the
	-- UpdateDataRE pushes, so the hub never depends on the game's own LocalData copies.
	N.G = {}
	N.G.Stage = N.tableOr(safeRequire("Config.Stage.Helper"))
	N.G.StageHP = N.tableOr(safeRequire("Config.Stage.HPConfig"))
	N.G.Recommend = N.tableOr(safeRequire("Config.Stage.RecommendConfig"))
	N.G.Level = N.tableOr(safeRequire("Config.Level.Helper"))
	N.G.Rebirth = N.tableOr(safeRequire("Config.Rebirth.Helper"))
	N.G.Upgrade = N.tableOr(safeRequire("Config.Upgrade.Config"))
	N.G.TrainArea = N.tableOr(safeRequire("Config.TrainArea.Config"))
	N.G.Weapon = N.tableOr(safeRequire("Config.Weapon.Helper"))
	N.G.Armor = N.tableOr(safeRequire("Config.Armor.Helper"))
	N.G.Ore = N.tableOr(safeRequire("Config.Ore.Helper"))
	N.G.Rarity = N.tableOr(safeRequire("Config.Rarity.Helper"))
	N.G.Class = N.tableOr(safeRequire("Config.Class.Helper"))
	N.G.Potion = N.tableOr(safeRequire("Config.Potion.Helper"))
	N.G.Online = N.tableOr(safeRequire("Config.Online.Helper"))
	N.G.UpdateLog = N.tableOr(safeRequire("Config.UpdateLog.Helper"))
	N.G.EnhantEvent = N.tableOr(safeRequire("Config.Enhant.EventHelper"))
	N.G.Dungeon = N.tableOr(safeRequire("Config.Dungeon.Helper"))
	N.G.Any = N.tableOr(safeRequire("Config.AnyHelper"))
	N.G.Balance = N.tableOr(safeRequire("Utils.BalanceUtils"))
	N.G.SuperLoot = N.tableOr(safeRequire("Config.SuperLoot.Helper"))
	N.G.Enhant = N.tableOr(safeRequire("Config.Enhant.Helper"))
	N.G.Season = N.tableOr(safeRequire("Config.Season.Helper"))
	-- Profit engine v2 inputs: the stage loot rolls, the forge roll and the training formula, all the game's own.
	N.G.StageLoots = N.tableOr(safeRequire("Config.Stage.Loots"))
	N.G.OreLoots = N.tableOr(safeRequire("Config.Stage.OreLoots"))
	N.G.Calc = N.tableOr(safeRequire("Utils.CalculateUtils"))
	N.G.ForgeUtils = N.tableOr(safeRequire("Utils.ForgeUtils"))
end
local formatNumber, allows, selected, on, optionNumber, optionText, Status, setStatus, picked
do
	local Suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
	function formatNumber(n)
		n = tonumber(n) or 0
		if n ~= n or n == math.huge then
			return "?"
		end
		local negative = n < 0
		n = math.abs(n)
		local text
		if n < 1000 then
			text = if n % 1 == 0 or n >= 100 then tostring(math.floor(n)) else (string.format("%.1f", n):gsub("%.0$", ""))
		else
			local i = 1
			while n >= 1000 and i < #Suffixes do
				n /= 1000
				i += 1
			end
			text = string.format("%.2f", n):gsub("%.?0+$", "") .. Suffixes[i]
		end
		return (if negative then "-" else "") .. text
	end
	function N.longTime(seconds)
		seconds = math.max(0, math.floor(tonumber(seconds) or 0))
		if seconds >= 3600 then
			return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
		elseif seconds >= 60 then
			return string.format("%dm", math.ceil(seconds / 60))
		end
		return string.format("%ds", seconds)
	end
	function allows(option, value)
		local v = option and option.Value
		if v == nil then
			return true
		end
		if type(v) == "table" then
			if next(v) == nil then
				return true
			end
			return v[value] == true
		end
		return v == value
	end
	function selected(option, value)
		local v = option and option.Value
		if type(v) == "table" then
			return v[value] == true
		end
		return v == value
	end
	function picked(option)
		local list = {}
		local v = option and option.Value
		if type(v) == "table" then
			for key, yes in pairs(v) do
				if yes then
					table.insert(list, key)
				end
			end
			table.sort(list)
		elseif type(v) == "string" and v ~= "" then
			table.insert(list, v)
		end
		return list
	end
	function on(name)
		local t = Toggles[name]
		return t ~= nil and t.Value == true
	end
	function optionNumber(name, default)
		local option = Options[name]
		return tonumber(option and option.Value) or default
	end
	function optionText(name, default)
		local option = Options[name]
		local value = option and option.Value
		return if type(value) == "string" and value ~= "" then value else default
	end
	-- Smart Planner (Main): one normal toggle that runs the profit engine for the whole loop. While it is on, the
	-- systems below run as the planner decides (it never flips their toggles; each toggle still works on its own).
	N.PlannerDrives = {
		AutoStages = true, KillAura = true, AutoSuperLoot = true, AutoTrain = true, AutoTower = true, AutoWorldBoss = true,
		AutoForge = true, AutoEquip = true, AutoSellGear = true, AutoUpgrade = true, AutoEnhance = true, AutoRebirth = true,
		AutoClassRoll = true, AutoSeason = true, AutoSeasonLuck = true, AutoSeasonShop = true, AutoPotions = true,
	}
	function N.planner()
		return on("SmartPlanner")
	end
	function N.want(name)
		return on(name) or (N.PlannerDrives[name] == true and on("SmartPlanner"))
	end
	-- PLAN lines are the planner's reasoning: written only while Smart Planner is on.
	function N.planLog(...)
		if on("SmartPlanner") then
			log(...)
		end
	end
	-- No master switch: every automation is its own toggle and uses the options exactly as set.
	function N.opActive()
		return false
	end
	function N.farmMode()
		return "Toggles"
	end
	function N.pickText(name, default)
		return optionText(name, default)
	end
	Status = "Idle"
	local StatusSeen, StatusSeenCount = {}, 0
	function setStatus(text)
		if Status ~= text then
			local now = os.clock()
			if now - (StatusSeen[text] or -1e9) > 4 then
				log("STATUS", text)
			end
			if not StatusSeen[text] then
				StatusSeenCount += 1
				if StatusSeenCount > 400 then
					table.clear(StatusSeen)
					StatusSeenCount = 0
				end
			end
			StatusSeen[text] = now
			Log.statusAt = now
		end
		Status = text
	end
	Log.context = function()
		return Status
	end
	-- Player data: the full profile from Profile.GetTotalDataRF, kept fresh by the game's UpdateDataRE pushes
	-- (one store at a time) and UpdateTotalDataRE. Read only, the hub never sends data back.
	N.Store = { data = {}, at = -1e9, pushes = 0 }
	function N.loadData()
		local ok, result = invoke("Profile/GetTotalDataRF", 15)
		if ok and type(result) == "table" then
			N.Store.data = result
			N.Store.at = os.clock()
			return true
		end
		return false
	end
	N.onRemote("Profile/UpdateDataRE", function(store, value)
		if type(store) == "string" then
			N.Store.data[store] = value
			N.Store.pushes += 1
		end
	end)
	N.onRemote("Profile/UpdateTotalDataRE", function(all)
		if type(all) == "table" then
			for key, value in pairs(all) do
				N.Store.data[key] = value
			end
			N.Store.pushes += 1
		end
	end)
	function N.store(name)
		local value = N.Store.data[name]
		return if type(value) == "table" then value else {}
	end
	function N.eco(name)
		local eco = LocalPlayer:FindFirstChild("Eco")
		local value = eco and eco:FindFirstChild(name)
		return tonumber(value and value.Value) or 0
	end
	function N.coin()
		return N.eco("coin")
	end
	function N.level()
		return N.eco("level")
	end
	function N.rebirth()
		return N.eco("rebirth")
	end
	local function call(fn, ...)
		if type(fn) ~= "function" then
			return nil
		end
		local ok, value = pcall(fn, ...)
		return if ok then value else nil
	end
	N.call = call
	-- Total power is what the stage boards compare with: all level exp so far plus the bonus power.
	function N.power()
		return (tonumber(call(N.G.Level.GetTotalPower, N.level())) or 0) + N.eco("power")
	end
	function N.serverTime()
		return tonumber(workspace:GetAttribute("ServerTime")) or os.time()
	end
	function N.char()
		return LocalPlayer.Character
	end
	function N.root()
		local char = LocalPlayer.Character
		return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	end
	function N.myPos()
		local root = N.root()
		return root and root.Position
	end
	function N.hp()
		local value = LocalPlayer:FindFirstChild("HPValue")
		if not value then
			return 1, 1
		end
		return tonumber(value.Value) or 0, tonumber(value:GetAttribute("MaxHP")) or 100
	end
	function N.fightMode()
		return LocalPlayer:GetAttribute("IntoFight")
	end
	function N.dead()
		return LocalPlayer:GetAttribute("Dead") == true
	end
	function N.tp(cf)
		local char = LocalPlayer.Character
		if not char then
			return false
		end
		local root = N.root()
		if root then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
			end)
		end
		local ok = pcall(function()
			char:PivotTo(cf)
		end)
		return ok
	end
	-- Rarity names are the game's own (Rarity.Helper and the ore drop colors).
	N.RarityOrder = { "Common", "UnCommon", "Rare", "Epic", "Legendary", "Mythic", "Eternal", "Secret", "Ancient", "Infinite", "Exclusive" }
	N.RarityColors = {
		Common = "#e6e6e6",
		UnCommon = "#4eff33",
		Rare = "#33fff1",
		Epic = "#a742ff",
		Legendary = "#ff9940",
		Mythic = "#ff3b3b",
		Eternal = "#d04cd0",
		Secret = "#00c264",
		Ancient = "#00fbc9",
		Infinite = "#df16ff",
		Exclusive = "#fdbbff",
	}
	function N.rarityText(rarity)
		if type(rarity) == "number" then
			local text = call(N.G.Rarity.GetTextRarity, rarity)
			if type(text) == "string" then
				return text
			end
			return N.RarityOrder[rarity] or "Common"
		end
		return if type(rarity) == "string" and rarity ~= "" then rarity else "Common"
	end
	function N.rarityRank(rarity)
		return table.find(N.RarityOrder, N.rarityText(rarity)) or 0
	end
	function N.rarityColor(rarity)
		return N.RarityColors[N.rarityText(rarity)] or "#dddddd"
	end
	function N.backpack()
		local bp = N.store("Backpack")
		if type(bp.have) ~= "table" then
			bp.have = {}
		end
		if type(bp.equiped) ~= "table" then
			bp.equiped = {}
		end
		return bp
	end
	function N.material(id)
		local total = 0
		for _, item in pairs(N.backpack().have) do
			if type(item) == "table" and item.ID == id and item.Type == "Material" then
				total += tonumber(item.Number) or 1
			end
		end
		return total
	end
	function N.itemName(kind, id)
		local configType = if kind == "Hat" then "Armor" else kind
		return tostring(call(N.G.Any.GetDisName, configType, id) or id)
	end
	-- How good a piece of gear is, with the game's own formula: a weapon adds Train power, armor and hats add
	-- their main stat. Both scale with the enhance level.
	function N.gearScore(item, bp)
		local kind = item.Type
		if kind == "Weapon" then
			local value = call(N.G.Balance.GetWeaponTrainValue, LocalPlayer, item, bp)
			return tonumber(value) or tonumber(call(N.G.Weapon.GetMainAffix, item.ID)) or 0
		elseif kind == "Armor" or kind == "Hat" then
			local value = call(N.G.Balance.GetArmorValue, LocalPlayer, item, bp)
			return tonumber(value) or tonumber(call(N.G.Armor.GetMainAffix, item.ID)) or 0
		end
		return 0
	end
	function N.gearRarity(item)
		if item.Type == "Weapon" then
			return N.rarityText(call(N.G.Weapon.GetRarity, item.ID))
		end
		return N.rarityText(call(N.G.Armor.GetRarity, item.ID))
	end
	-- Exclude (Main tab): resources the planner and the manual sell/forge/enhance/spend toggles never touch.
	N.ExcludeValues = { "Ores: Legendary", "Ores: Eternal", "Ores: Secret", "Gear: Epic and better", "Gear: Legendary and better", "Season Coins", "Potions" }
	N.ExcludeDefault = { "Ores: Eternal", "Ores: Secret", "Gear: Legendary and better" }
	N.GearTiers = { { "Gear: Epic and better", "Epic" }, { "Gear: Legendary and better", "Legendary" } }
	local ExcludeSeen = {}
	function N.excludeNote(item)
		local now = os.clock()
		if now - (ExcludeSeen[item] or -1e9) > 120 then
			ExcludeSeen[item] = now
			log("EXCLUDE", item)
		end
	end
	function N.oreExcluded(rarity, quiet)
		if selected(Options.FarmExclude, "Ores: " .. tostring(rarity)) then
			if not quiet then
				N.excludeNote("ore " .. tostring(rarity))
			end
			return true
		end
		return false
	end
	function N.gearExcluded(rarity, quiet)
		local rank = N.rarityRank(rarity)
		for _, tier in ipairs(N.GearTiers) do
			if selected(Options.FarmExclude, tier[1]) and rank >= N.rarityRank(tier[2]) then
				if not quiet then
					N.excludeNote("gear " .. tostring(rarity))
				end
				return true
			end
		end
		return false
	end
	-- "Season Coins" and "Potions": the whole spending/using loop stays off.
	function N.keepExcluded(name)
		if selected(Options.FarmExclude, name) then
			N.excludeNote(string.lower(name))
			return true
		end
		return false
	end
	function N.gear()
		local bp = N.backpack()
		local equipped = {}
		for slot, uuid in pairs(bp.equiped) do
			equipped[uuid] = slot
		end
		local list = {}
		for uuid, item in pairs(bp.have) do
			if type(item) == "table" and (item.Type == "Weapon" or item.Type == "Armor" or item.Type == "Hat") then
				table.insert(list, {
					uuid = uuid,
					item = item,
					kind = item.Type,
					id = item.ID,
					name = N.itemName(item.Type, item.ID),
					score = N.gearScore(item, bp),
					rarity = N.gearRarity(item),
					level = tonumber(item.Level) or 0,
					locked = item.Lock == true,
					equipped = equipped[uuid] ~= nil,
				})
			end
		end
		table.sort(list, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return tostring(a.uuid) < tostring(b.uuid)
		end)
		return list
	end
	function N.ores()
		local list = {}
		for uuid, item in pairs(N.backpack().have) do
			if type(item) == "table" and item.Type == "Ore" and (tonumber(item.Number) or 0) > 0 then
				table.insert(list, {
					uuid = uuid,
					id = item.ID,
					number = tonumber(item.Number) or 0,
					power = tonumber(call(N.G.Ore.GetPower, item.ID)) or 0,
					rarity = N.rarityText(call(N.G.Ore.GetRarity, item.ID)),
					price = tonumber(call(N.G.Ore.GetSellPrice, item.ID)) or 0,
					locked = item.Lock == true,
				})
			end
		end
		table.sort(list, function(a, b)
			if a.power ~= b.power then
				return a.power > b.power
			end
			return tostring(a.uuid) < tostring(b.uuid)
		end)
		return list
	end
	function N.oreTotal()
		local total = 0
		for _, ore in ipairs(N.ores()) do
			total += ore.number
		end
		return total
	end
	-- Ores picked up in the current run: the game shows them as "now/max" on the HUD.
	function N.pack()
		local now, max
		pcall(function()
			local title = LocalPlayer.PlayerGui.Hud.LeftInfos.OrePack.Title
			local a, b = string.match(tostring(title.Text), "(%d+)%s*/%s*(%d+)")
			now, max = tonumber(a), tonumber(b)
		end)
		if not max then
			local upgrade = N.store("Upgrade").OrePack or {}
			local levels = N.G.Upgrade.OrePack or {}
			local row = levels[tonumber(upgrade.Level) or 0]
			max = (tonumber(row and row.Number) or 4) + (tonumber(upgrade.Number) or 0)
		end
		-- Ores taken straight from the server (Blatant pickup, p05_probes) never touch the HUD counter.
		local F = N.Fight
		if F and (F.direct or 0) > 0 and not F.hudCounts then
			now = (now or 0) + F.direct
		end
		return now or 0, max
	end
end
local Session = {
	started = os.clock(),
	runs = 0,
	stages = 0,
	kills = 0,
	ores = 0,
	banks = 0,
	deaths = 0,
	lostRuns = 0,
	forged = 0,
	equips = 0,
	sold = 0,
	upgrades = 0,
	rebirths = 0,
	towerRuns = 0,
	bossFights = 0,
	claims = 0,
	potions = 0,
	classRolls = 0,
	codes = 0,
	superKills = 0,
	enhances = 0,
	seasonSpins = 0,
	shopBuys = 0,
	trainSeconds = 0,
	bestStage = 0,
	bestForge = nil,
	bestForgeRank = 0,
	levelStart = N.level(),
	rebirthStart = N.rebirth(),
	powerStart = N.power(),
}
N.Events = {}
N.Manual = { running = false }
N.R = {
	equip = "Backpack/TryEquipItemRE",
	sell = "Backpack/TrySellItemRE",
	upgrade = "Upgrade/UpgradeOnceRE",
	rebirth = "Rebirth/TryRebirthRE",
	online = "Online/TryClaimRE",
	offline = "Offline/TryClaimOfflineRewardRE",
	seasonAll = "Season/TryClaimAllRewardRE",
	seasonDaily = "Season/TryClaimDailyTicRE",
	towerDaily = "Dungeon/TryClaimDailyDunTicRE",
	towerExit = "Dungeon/ExitDungeonRE",
	updateLog = "UpdateLog/TryClaimUPDRewardRE",
	quest = "EnhantEvent/TryClaimQuestRE",
	group = "Player/TryJoinGroupRE",
	potion = "Potion/TryUsePotionRE",
	classRoll = "Class/LuckOnceRE",
	bossCard = "WorldBoss/TryClaimBossRewardRE",
	forge = "Forge/ForgeRF",
	indexExp = "Index/TryClaimIndexExpRF",
	indexLevel = "Index/TryClaimLevelRewardRF",
	tower = "Dungeon/TryIntoDungeonRF",
	code = "Code/TryUseCodeRF",
	exitFight = "Stage/ExitFightBE",
	attack = "Attack/ATKOnceBE",
	attackEnemy = "Attack/AttackEnemyBE",
	enemyHit = "Attack/EnemyHitBE",
	seasonLuck = "Season/LuckRE",
	seasonShop = "Season/ExchangeGoodsRE",
	enhance = "Backpack/EnhantEquipmentRF",
}
do
	-- Stages: the enemies live only on this client. Touching StageMap.AreaPart.Stage_N starts the stage, the
	-- server pre-rolls the ores, and the game itself attacks every 0.1 s while an enemy is within 20 studs.
	-- Picked ores sit in the run's pack until the Return button banks them; dying loses the whole pack.
	N.Fight = {
		run = false,
		stage = 0,
		seen = {},
		enteredAt = 0,
		idleSince = nil,
		hard = {},
		lastHp = nil,
		lastHit = 0,
		target = nil,
		trainUntil = 0,
		lastBank = "",
		lastRun = "",
	}
	local F = N.Fight
	function N.stageList()
		if N.StageCache then
			return N.StageCache
		end
		local list = {}
		for id, row in pairs(N.G.StageHP) do
			local n = tonumber(string.match(tostring(id), "^Stage_(%d+)$"))
			if n and type(row) == "table" then
				local rec = N.G.Recommend[id]
				table.insert(list, {
					n = n,
					id = id,
					recommend = tonumber(type(rec) == "table" and rec.Recommend) or 0,
					mobHP = tonumber(row.MobHP) or 0,
					bossHP = tonumber(row.BossHP),
				})
			end
		end
		table.sort(list, function(a, b)
			return a.n < b.n
		end)
		if #list > 0 then
			N.StageCache = list
		end
		return list
	end
	function N.stageInfo(n)
		for _, stage in ipairs(N.stageList()) do
			if stage.n == n then
				return stage
			end
		end
		return nil
	end
	-- The deepest stage worth farming: the game's recommended power against yours, minus any stage that beat
	-- the hub recently (too slow to kill or the HP guard pulled out).
	-- The stage a run goes to: the deepest one the power allows (below), or the one with the best coins per second
	-- below it when the profit planner has run data (p09_plan). A run keeps the target it started with.
	function N.stageTarget()
		local cap = N.stageTargetByPower()
		if N.pickText("StageMode", "Auto (by power)") ~= "Auto (by power)" then
			return cap
		end
		local planned = if F.run and F.runTarget then F.runTarget elseif N.Plan and N.plannerWanted and N.plannerWanted() then N.Plan.stage else nil
		if planned then
			return math.max(1, math.min(cap, planned))
		end
		return cap
	end
	function N.stageTargetByPower()
		local list = N.stageList()
		if #list == 0 then
			return 1
		end
		local best = 1
		if N.pickText("StageMode", "Auto (by power)") == "Pick a stage" then
			best = math.clamp(math.floor(optionNumber("StageFixed", 1)), 1, list[#list].n)
		else
			local power = N.power()
			local margin = math.clamp(optionNumber("StageMargin", 100), 10, 1000) / 100
			for _, stage in ipairs(list) do
				if stage.recommend * margin <= power then
					best = math.max(best, stage.n)
				end
			end
		end
		local now = os.clock()
		for n, untilAt in pairs(F.hard) do
			if untilAt > now and n <= best then
				best = math.max(n - 1, 1)
			end
		end
		return best
	end
	function N.stageMap()
		local world = workspace:FindFirstChild("WorldModel")
		return world and world:FindFirstChild("StageMap")
	end
	-- The map streams in and out (StreamingEnabled), so every stage area seen once is remembered and streamed
	-- back in around its spot when it is missing.
	N.StageSpots = {}
	local function findStagePart(n)
		local map = N.stageMap()
		local area = map and map:FindFirstChild("AreaPart")
		local part = area and area:FindFirstChild("Stage_" .. n)
		if part then
			N.StageSpots[n] = part.CFrame
		end
		return part
	end
	function N.rememberStages()
		for _, stage in ipairs(N.stageList()) do
			findStagePart(stage.n)
		end
	end
	function N.stagePart(n)
		local part = findStagePart(n)
		if part then
			return part
		end
		local spot = N.StageSpots[n]
		if spot then
			pcall(function()
				LocalPlayer:RequestStreamAroundAsync(spot.Position, 5)
			end)
			N.tp(spot + Vector3.new(0, 2, 0))
			waitFor(function()
				return findStagePart(n) ~= nil
			end, 3)
			return findStagePart(n)
		end
		return nil
	end
	function N.stagePoints(n)
		local map = N.stageMap()
		local points = map and map:FindFirstChild("EnemyPoint")
		local folder = points and points:FindFirstChild("Stage_" .. n)
		local list = {}
		if folder then
			for _, point in ipairs(folder:GetChildren()) do
				if point:IsA("BasePart") then
					table.insert(list, point.Position)
				end
			end
		end
		return list
	end
	local function enemyAlive(model)
		if not model:IsA("Model") or model:GetAttribute("Dead") then
			return false
		end
		local hp = model:FindFirstChild("HPValue")
		if hp and (tonumber(hp.Value) or 0) <= 0 then
			return false
		end
		local humanoid = model:FindFirstChild("Humanoid")
		if not hp and humanoid and (tonumber(humanoid.Health) or 0) <= 0 then
			return false
		end
		return model:FindFirstChild("HumanoidRootPart") ~= nil or model.PrimaryPart ~= nil
	end
	N.enemyAlive = enemyAlive
	local function pivotOf(model)
		local ok, cf = pcall(model.GetPivot, model)
		return if ok and cf then cf.Position else nil
	end
	-- Living enemies, nearest first. With a stage number only the ones around that stage's spawn points.
	function N.enemies(folderName, stageN)
		local folder = workspace:FindFirstChild(folderName or "EnemyFolder")
		local list = {}
		if not folder then
			return list
		end
		local points = if stageN then N.stagePoints(stageN) else nil
		local me = N.myPos()
		for _, model in ipairs(folder:GetChildren()) do
			-- The Super Loot runner has its own hunter (it runs away and has 6-15 hits of HP): it must never count
			-- as the stage's enemy or a stage would look "too strong" while it dodges.
			if enemyAlive(model) and model:GetAttribute("EnemyID") ~= "Super_1" then
				local pos = pivotOf(model)
				if pos then
					local near = true
					if points and #points > 0 then
						near = false
						for _, p in ipairs(points) do
							if (p - pos).Magnitude < 90 then
								near = true
								break
							end
						end
					end
					if near then
						table.insert(list, { model = model, pos = pos, dist = if me then (me - pos).Magnitude else 0 })
					end
				end
			end
		end
		table.sort(list, function(a, b)
			return a.dist < b.dist
		end)
		return list
	end
	function N.hpOf(model)
		local hp = model:FindFirstChild("HPValue")
		if hp then
			return tonumber(hp.Value) or 0
		end
		local humanoid = model:FindFirstChild("Humanoid")
		return tonumber(humanoid and humanoid.Health) or 0
	end
	-- Stands next to the enemy, facing it. The game's own attack does the rest.
	function N.standAt(pos, gap)
		local me = N.myPos() or pos
		local away = me - pos
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.5 then
			away = Vector3.new(0, 0, 1)
		end
		local spot = pos + away.Unit * (gap or 4)
		return N.tp(CFrame.lookAt(spot, Vector3.new(pos.X, spot.Y, pos.Z)))
	end
	function N.attackClick()
		N.bindable(N.R.attack)
	end
	-- Super Loot: every 12 / 30 / 45 min the server sends a runner (RefreshSuperLootRE: rarity, uuid, ore id,
	-- stage number, CFrame) that carries a Legendary / Eternal / Secret ore, the best ores of its stages (1-7,
	-- 8-14, 15-22). It lives only on this client with 6 / 10 / 15 HP, and every EnemyHitBE on it is one hit
	-- (the game's own handler turns each into 1/HP of its health). The kill sends KillSuperLootRE and drops the
	-- ore model into OreCache like any other drop. Profit: one kill is one ore worth far more than a whole stage
	-- run of common ores, for about 2 s of work. It is only hunted on stages the run can reach (<= target).
	N.Super = { info = {}, tries = {}, kills = 0, last = "", pickUntil = 0, noted = {} }
	N.onRemote("SuperLoot/RefreshSuperLootRE", function(rarity, uuid, oreId, stageNo)
		if type(uuid) == "string" then
			N.Super.info[uuid] = { rarity = tostring(rarity), ore = oreId, stage = tonumber(stageNo) }
			log("SUPER spawned", tostring(rarity), "stage", tostring(stageNo), "ore", tostring(oreId))
		end
	end)
	function N.superNearestStage(pos)
		local best, bestDist
		for n, cf in pairs(N.StageSpots) do
			local dist = (cf.Position - pos).Magnitude
			if not bestDist or dist < bestDist then
				best, bestDist = n, dist
			end
		end
		return best
	end
	function N.superList()
		local folder = workspace:FindFirstChild("EnemyFolder")
		local list = {}
		if not folder then
			return list
		end
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("EnemyID") == "Super_1" and enemyAlive(model) then
				local pos = pivotOf(model)
				if pos then
					local info = N.Super.info[model.Name] or {}
					table.insert(list, {
						model = model,
						uuid = model.Name,
						pos = pos,
						rarity = info.rarity or "?",
						stage = info.stage or N.superNearestStage(pos) or 1,
					})
				end
			end
		end
		-- Deepest stage first: it carries the best ore.
		table.sort(list, function(a, b)
			return a.stage > b.stage
		end)
		return list
	end
	-- The runner worth going for right now (nil when none, or when it is on a stage the run cannot reach yet).
	function N.superPick()
		if not N.want("AutoSuperLoot") then
			return nil
		end
		local target = N.stageTarget()
		for _, entry in ipairs(N.superList()) do
			if entry.stage <= target then
				if (N.Super.tries[entry.uuid] or 0) < 4 then
					return entry
				end
			elseif not N.Super.noted[entry.uuid] then
				N.Super.noted[entry.uuid] = true
				log("SUPER out of reach", entry.rarity, "stage", entry.stage, "target", target)
			end
		end
		return nil
	end
	-- One step of the hunt, called inside the stage run. True when it used the step.
	function N.superStep()
		local entry = N.superPick()
		if not entry then
			return false
		end
		local packNow, packMax = N.pack()
		if packNow >= packMax then
			N.bank("pack full, super loot is up")
			return true
		end
		if F.stage ~= entry.stage then
			setStatus(string.format("Super loot (%s) is on stage %d, going there", entry.rarity, entry.stage))
			log("SUPER going to stage", entry.stage, entry.rarity)
			N.enterStage(entry.stage)
			task.wait(0.4)
			return true
		end
		local hits = (tonumber(N.call(N.G.SuperLoot.GetHP, entry.rarity)) or 15) + 2
		N.Super.tries[entry.uuid] = (N.Super.tries[entry.uuid] or 0) + 1
		setStatus(string.format("Super loot (%s) on stage %d: hitting it", entry.rarity, entry.stage))
		local model = entry.model
		local sent = 0
		for _ = 1, hits do
			if not model.Parent or not enemyAlive(model) then
				break
			end
			local pos = pivotOf(model)
			if pos then
				N.standAt(pos, 3.5)
			end
			N.bindable(N.R.enemyHit, entry.uuid, 1, {})
			sent += 1
			task.wait(0.1)
		end
		if not model.Parent or not enemyAlive(model) then
			N.Super.kills += 1
			Session.superKills += 1
			N.Super.pickUntil = os.clock() + 10
			F.seen[F.stage] = true
			N.Super.last = string.format("Killed a %s runner on stage %d", entry.rarity, entry.stage)
			log("SUPER killed", entry.rarity, "stage", entry.stage, "hits", sent)
		else
			N.Super.last = string.format("The %s runner did not die after %d hits", entry.rarity, sent)
			log("SUPER hit failed", entry.rarity, "stage", entry.stage, "hits", sent, "try", N.Super.tries[entry.uuid])
		end
		return true
	end
	-- Kill Aura: hits every client enemy in range through the game's own damage path (AttackEnemyBE with your
	-- weapon's basic attack), so the damage is your real damage, just on all of them at once and without
	-- swinging. Insta-kill sends a hit as big as the enemy's HP (the enemies only exist on your client).
	-- World bosses are server enemies and are never touched by the aura.
	N.Aura = { at = 0, hits = 0 }
	-- Player powers. The player's HP only lives on this client (LocalPlayer.HPValue, attribute MaxHP), and the
	-- game's damage code skips anyone with the "Invincible" attribute, so both work without touching the server.
	--   God Mode: max HP becomes a trillion and is kept full; turning it off puts the real max HP back.
	--   Untouchable: sets Invincible, enemy hits never register at all.
	--   Walk Speed: sets the humanoid's speed while on.
	N.Powers = { maxHp = nil, invincible = false, speed = nil }
	local GodHP = 1e12
	function N.powerStep()
		local P = N.Powers
		local hp = LocalPlayer:FindFirstChild("HPValue")
		if hp then
			if on("GodMode") then
				local max = tonumber(hp:GetAttribute("MaxHP")) or 100
				if max < GodHP then
					P.maxHp = max
					hp:SetAttribute("MaxHP", GodHP)
				end
				if (tonumber(hp.Value) or 0) < GodHP * 0.9 then
					hp.Value = GodHP
				end
			elseif P.maxHp then 
				hp:SetAttribute("MaxHP", P.maxHp)
				hp.Value = P.maxHp
				P.maxHp = nil
			end
		end
		if on("Untouchable") then
			if LocalPlayer:GetAttribute("Invincible") ~= true then
				LocalPlayer:SetAttribute("Invincible", true)
				P.invincible = true
			end
		elseif P.invincible then
			LocalPlayer:SetAttribute("Invincible", nil)
			P.invincible = false
		end
		local char = LocalPlayer.Character
		local humanoid = char and char:FindFirstChild("Humanoid")
		if humanoid then
			if on("SpeedHack") then
				P.speed = P.speed or humanoid.WalkSpeed
				local want = math.clamp(optionNumber("WalkSpeed", 60), 16, 250)
				if humanoid.WalkSpeed ~= want then
					humanoid.WalkSpeed = want
				end
			elseif P.speed then
				humanoid.WalkSpeed = P.speed
				P.speed = nil
			end
		end
	end
	function N.auraStep()
		-- Instant tower floors must not kill the game's enemies (the game would complete that floor again).
		if N.Tower and N.Tower.fastRunning then
			return 0
		end
		if not N.want("KillAura") or N.dead() or os.clock() - N.Aura.at < math.clamp(optionNumber("AuraSpeed", 0.1), 0.1, 2) then
			return 0
		end
		N.Aura.at = os.clock()
		local range = math.clamp(optionNumber("AuraRange", 500), 5, 500)
		-- The tower arena is its own small map: every enemy there counts, wherever you stand.
		if N.fightMode() == "Dungeon" then
			range = math.huge
		end
		local me = N.myPos()
		if not me then
			return 0
		end
		local insta = N.auraInsta()
		local ids = {}
		for _, entry in ipairs(N.enemies("EnemyFolder")) do
			if entry.dist <= range then
				if insta then
					N.bindable(N.R.enemyHit, entry.model.Name, N.hpOf(entry.model) + 1, {})
				else
					table.insert(ids, entry.model.Name)
				end
			end
		end
		if #ids > 0 then
			local weapon = tostring(LocalPlayer:GetAttribute("WeaponType") or "Katana")
			N.bindable(N.R.attackEnemy, ids, { SkillID = string.sub(weapon, 1, 1) .. "_ATK_1", Phase = 1, Attacker = LocalPlayer })
		end
		N.Aura.hits += 1
		return #ids
	end
	-- Ore drops are local models in workspace.OreCache with a "Collect" prompt (0.5 s hold). The prompt's own
	-- callback asks the server for that ore, so the hub only has to stand next to it and trigger it.
	function N.orePrompts()
		local cache = workspace:FindFirstChild("OreCache")
		local list = {}
		if not cache then
			return list
		end
		local me = N.myPos()
		for _, d in ipairs(cache:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled ~= false and d.Parent and d.Parent:IsA("BasePart") then
				-- The drop model is named after the ore (Ore_12): only the picked rarities are collected.
				local model = d.Parent.Parent
				local id = model and model.Name
				local rarity = N.rarityText(N.call(N.G.Ore.GetRarity, id))
				if allows(Options.PickRarities, rarity) then
					local pos = d.Parent.Position
					table.insert(list, { prompt = d, pos = pos, dist = if me then (me - pos).Magnitude else 0, id = id, rarity = rarity })
				end
			end
		end
		table.sort(list, function(a, b)
			return a.dist < b.dist
		end)
		return list
	end
	function N.trigger(prompt)
		local fn = fireproximityprompt
		if type(fn) == "function" then
			local ok = pcall(fn, prompt)
			if ok then
				return true
			end
		end
		local ok = pcall(function()
			prompt:InputHoldBegin()
		end)
		task.wait((tonumber(prompt.HoldDuration) or 0.5) + 0.1)
		pcall(function()
			prompt:InputHoldEnd()
		end)
		return ok
	end
	function N.collectOne()
		local packNow, packMax = N.pack()
		if packNow >= packMax then
			return false
		end
		local entry = N.orePrompts()[1]
		if not entry then
			return false
		end
		N.tp(CFrame.new(entry.pos + Vector3.new(0, 2.5, 0)))
		task.wait(0.12)
		N.trigger(entry.prompt)
		Session.ores += 1
		return true
	end
	-- Banks the run: the game's Return button claims every picked ore and sends you to spawn.
	function N.bank(reason)
		if N.fightMode() ~= "Stage" then
			F.run = false
			return
		end
		local packNow = N.pack()
		setStatus("Banking ores (" .. reason .. ")")
		log("BANK", reason, "stage", F.stage, "pack", packNow, if (F.direct or 0) > 0 then "direct " .. F.direct else "")
		local lootSnap = N.lootBankStart and N.lootBankStart()
		N.bindable(N.R.exitFight, true)
		waitFor(function()
			return N.fightMode() ~= "Stage"
		end, 4)
		F.direct = 0
		F.lootedSpawn = false
		if lootSnap then
			pcall(N.lootBankEnd, lootSnap, if F.runStartedAt then os.clock() - F.runStartedAt else nil, F.runTarget or F.stage)
		end
		Session.banks += 1
		-- A full pack is a complete run: it calibrates the planner's run model (seconds per run at this depth).
		if reason == "pack full" and F.runStartedAt and N.planNoteRun then
			pcall(N.planNoteRun, F.runTarget or F.stage, os.clock() - F.runStartedAt, packNow)
		end
		F.lastBank = reason
		if F.runStartedAt and not on("SmartPlanner") then
			F.trainUntil = os.clock() + math.min(os.clock() - F.runStartedAt, 600)
		end
		F.run = false
		F.stage = 0
		F.runTarget = nil
		F.runStartedAt = nil
		table.clear(F.seen)
		-- No fixed training break: the planner compares the next run with training right away.
		if N.planRefresh then
			pcall(N.planRefresh, true)
		end
	end
	function N.enterStage(n)
		local part = N.stagePart(n)
		if not part then
			logProblem("No area part for Stage_" .. n)
			return false
		end
		F.stage = n
		F.enteredAt = os.clock()
		F.idleSince = nil
		F.clearedAt = nil
		F.lastHp = nil
		F.lastHit = os.clock()
		F.lootedSpawn = false
		setStatus("Entering stage " .. n)
		N.tp(part.CFrame + Vector3.new(0, 2, 0))
		local id = "Stage_" .. n
		local ok = waitFor(function()
			return LocalPlayer:GetAttribute("StageID") == id
		end, 1.5)
		if not ok then
			-- The touch did not register (it can miss after a teleport). Same as touching the area.
			log("STAGE touch missed, setting StageID", id)
			LocalPlayer:SetAttribute("StageID", id)
		end
		return true
	end
	function N.startRun()
		if N.fightMode() ~= nil or N.dead() then
			return false
		end
		F.run = false
		F.runTarget = nil
		local target = N.stageTarget()
		F.run = true
		F.runTarget = target
		F.runStartedAt = os.clock()
		F.seen = {}
		F.direct = 0
		F.directClears = 0
		-- Coins/s the run model expects before this run (the stage_loot probe compares the real run with it).
		F.coinsBefore = nil
		if N.farmValue then
			local _, cap = N.pack()
			F.coinsBefore = N.call(N.farmValue, target, cap)
		end
		Session.runs += 1
		F.lastRun = string.format("target stage %d, power %s", target, formatNumber(N.power()))
		log("RUN", Session.runs, F.lastRun)
		N.enterStage(1)
		waitFor(function()
			return N.fightMode() == "Stage"
		end, 3)
		return N.fightMode() == "Stage"
	end
	-- One step of the stage farm. Called over and over while IntoFight is "Stage".
	function N.fightStep()
		if N.dead() then
			setStatus("Died, the game respawns you")
			task.wait(0.5)
			return
		end
		F.run = true
		if F.stage < 1 then
			F.stage = 1
		end
		local hp, maxHp = N.hp()
		local guard = math.clamp(optionNumber("BankHP", 35), 0, 95) / 100
		if maxHp > 0 and hp / maxHp < guard then
			F.hard[F.stage] = os.clock() + 300
			N.bank(string.format("HP %d%%", math.floor(hp / maxHp * 100)))
			return
		end
		if N.want("AutoSuperLoot") and N.superStep() then
			return
		end
		local packNow, packMax = N.pack()
		local enemies = N.enemies("EnemyFolder", F.stage)
		if #enemies > 0 then
			if not F.seen[F.stage] then
				F.fightStart = os.clock()
			end
			F.seen[F.stage] = true
			F.idleSince = nil
			F.clearedAt = nil
			-- Blatant pickup: this spawn's ores were rolled when it appeared, take them before the fight.
			if not F.lootedSpawn and F.stage >= N.stageTarget() and N.directLootWanted and N.directLootWanted() then
				F.lootedSpawn = true
				if packNow < packMax then
					setStatus(string.format("Stage %d: taking the ores  \u{00B7}  pack %d/%d", F.stage, packNow, packMax))
					N.directLoot(F.stage)
					packNow, packMax = N.pack()
				end
			end
			local target = enemies[1]
			if F.target ~= target.model then
				F.target = target.model
				F.lastHp = N.hpOf(target.model)
				F.lastHit = os.clock()
			else
				local now = N.hpOf(target.model)
				if F.lastHp and now < F.lastHp then
					F.lastHit = os.clock()
				end
				F.lastHp = now
			end
			if os.clock() - F.lastHit > math.clamp(optionNumber("StuckSeconds", 20), 5, 120) then
				-- No damage for a long time: this stage is too strong right now.
				F.hard[F.stage] = os.clock() + 600
				logProblem("Stage " .. F.stage .. " too strong, no damage in " .. math.floor(os.clock() - F.lastHit) .. "s")
				F.lastHit = os.clock()
				if F.stage > 1 then
					N.bank("stage " .. F.stage .. " too strong")
				end
				return
			end
			setStatus(string.format("Stage %d: fighting %d enemies  \u{00B7}  pack %d/%d", F.stage, #enemies, packNow, packMax))
			N.standAt(target.pos, 3.5)
			N.auraStep()
			task.wait(0.15)
			return
		end
		if F.target then
			Session.kills += 1
			F.target = nil
		end
		-- note the clear time before the pack check, or a full pack would hide it from the planner forever
		if F.seen[F.stage] and F.fightStart and not F.clearedAt then
			F.clearedAt = os.clock()
			if N.planNoteClear then
				N.planNoteClear(F.clearedAt - F.fightStart)
			end
			F.fightStart = nil
		end
		if packNow >= packMax then
			N.bank("pack full")
			return
		end
		local target = N.stageTarget()
		-- The pack is small and deeper stages drop better ores, so ores are only picked on the deepest stage of
		-- the run (unless every stage is picked on purpose). Low stages are just cleared to unlock the next one.
		local pickHere = optionText("PickOres", "Deepest stage only") == "Every stage" or F.stage >= target
		if F.lootedSpawn then
			-- The ores of this spawn were already taken from the server: the drops on the ground are the same ones.
			pickHere = false
		end
		if os.clock() < N.Super.pickUntil then
			pickHere = true
		end
		local pickStart = os.clock()
		if pickHere and N.collectOne() then
			if N.planNotePick then
				N.planNotePick(os.clock() - pickStart)
			end
			setStatus(string.format("Stage %d: picking ores  \u{00B7}  pack %d/%d", F.stage, N.pack()))
			return
		end
		if F.seen[F.stage] then
			-- The ores drop once the server answers, give them a moment before moving on.
			if not F.clearedAt then
				F.clearedAt = os.clock()
				F.fightStart = nil
			end
			if pickHere and os.clock() - F.clearedAt < 2.5 then
				setStatus(string.format("Stage %d: cleared, waiting for the drops", F.stage))
				task.wait(0.2)
				return
			end
			F.clearedAt = nil
			F.lootedSpawn = false
			Session.stages += 1
			Session.bestStage = math.max(Session.bestStage, F.stage)
			F.seen[F.stage] = nil
			if F.stage < target then
				task.wait(0.3)
				N.enterStage(F.stage + 1)
				return
			end
		elseif F.stage > target then
			-- The target dropped (a hard stage): finish here.
			N.bank("target lowered")
			return
		end
		-- Waiting: either the server has not spawned this stage yet or it respawns (30 s after a clear).
		F.idleSince = F.idleSince or os.clock()
		local waited = os.clock() - F.idleSince
		local part = N.stagePart(F.stage)
		if part and (N.myPos() and (N.myPos() - part.Position).Magnitude > 25) then
			N.tp(part.CFrame + Vector3.new(0, 2, 0))
		end
		if waited > 45 then
			F.idleSince = nil
			if F.stage < target then
				N.enterStage(F.stage + 1)
			else
				LocalPlayer:SetAttribute("StageID", nil)
				task.wait(0.2)
				N.enterStage(F.stage)
			end
			return
		end
		setStatus(string.format("Stage %d: waiting for enemies  \u{00B7}  pack %d/%d", F.stage, packNow, packMax))
		task.wait(0.4)
	end
	-- Deaths are counted from the game's own event, the pack is lost then.
	pcall(function()
		local dead = N.remote("Stage/PlayerDeadBE")
		if dead and dead:IsA("BindableEvent") then
			Library:GiveSignal(dead.Event:Connect(function(kind)
				Session.deaths += 1
				if kind == "StageDead" then
					Session.lostRuns += 1
					F.direct = 0
					F.lootedSpawn = false
					F.hard[F.stage] = os.clock() + 600
					logProblem("Died on stage " .. tostring(F.stage) .. ", the pack was lost")
					if N.Events.lostRun then
						pcall(N.Events.lostRun, F.stage)
					end
					F.run = false
					F.stage = 0
				end
				if kind == "DungeonDead" and N.towerDied then
						pcall(N.towerDied)
					elseif kind == "WorldBossDead" and N.bossDied then
						pcall(N.bossDied)
					end
					log("DEAD", kind)
			end))
		end
	end)
end
do
	-- Forging: ForgeRF({ConfigType = "Weapon"|"Armor", UUIDList = {[oreUUID] = count}}) with at least 4 ores.
	-- The number of ores decides the item kind (Weapon 4..13: Katana to Great sword, Armor 4..23: light hat to
	-- heavy armor) and the average ore power decides the quality, so the hub always puts in the strongest ores.
	N.Forge = { last = "", log = {}, alternate = "Weapon", at = -1e9 }
	local Fo = N.Forge
	function N.forgeTable()
		local world = workspace:FindFirstChild("WorldModel")
		local forge = world and world:FindFirstChild("ForgeTable")
		return forge and (forge:FindFirstChild("Part") or forge:FindFirstChildWhichIsA("BasePart", true))
	end
	-- "Auto (best value)": the profit planner prices every kind and ore count with the game's own forge roll
	-- (N.forgeChoice). Without the game's forge module it falls back to alternating with the slider count.
	local function autoChoice()
		if N.pickText("ForgeType", "Auto (best value)") ~= "Auto (best value)" or not N.forgeChoice then
			return nil
		end
		return N.forgeChoice()
	end
	function N.forgeKind()
		local pick = N.pickText("ForgeType", "Auto (best value)")
		if pick == "Weapon" or pick == "Armor" then
			return pick
		end
		local choice = autoChoice()
		if choice then
			return choice.kind
		end
		return Fo.alternate
	end
	function N.forgeCount(kind)
		local choice = autoChoice()
		if choice and choice.kind == kind then
			return choice.count
		end
		local count = math.clamp(math.floor(optionNumber("ForgeOres", 8)), 4, 23)
		if kind == "Weapon" then
			count = math.min(count, 13)
		end
		return count
	end
	-- The ores for one forge: the strongest first, locked ores and kept rarities are never used.
	-- The forge window has 4 ore slots: the server refuses a forge with more than 4 different ore stacks
	-- (seen in the log as "Forge refused: nil" every time the plan used 5 or 6 stacks).
	N.ForgeSlots = 4
	function N.forgePlan(kind)
		return N.forgePlanFor(kind, N.forgeCount(kind))
	end
	function N.forgePlanFor(kind, count)
		local usable = {}
		for _, ore in ipairs(N.ores()) do
			if not ore.locked and not selected(Options.ForgeKeepRarities, ore.rarity) and not N.oreExcluded(ore.rarity) then
				table.insert(usable, ore)
			end
		end
		local function build(list)
			local plan, total, power, stacks = {}, 0, 0, 0
			for _, ore in ipairs(list) do
				if total >= count or stacks >= N.ForgeSlots then
					break
				end
				local take = math.min(ore.number, count - total)
				plan[ore.uuid] = take
				stacks += 1
				total += take
				power += take * ore.power
			end
			return plan, total, power / math.max(total, 1)
		end
		-- Strongest ores first. When 4 stacks are not enough ores, fill with the biggest stacks instead.
		local plan, total, avg = build(usable)
		if total < count then
			local big = table.clone(usable)
			table.sort(big, function(a, b)
				if a.number ~= b.number then
					return a.number > b.number
				end
				return a.power > b.power
			end)
			plan, total, avg = build(big)
		end
		if total < count then
			return nil, total
		end
		return plan, total, avg
	end
	local function noteForge(result, kind)
		local text = kind .. " forged"
		-- The game answers {itemData, uuid}; itemData has the forged ID and Type.
		local item = if type(result) == "table" then (if type(result[1]) == "table" then result[1] else result) else nil
		if item then
			local id = item.ID
			if type(id) == "string" then
				local configKind = if item.Type == "Weapon" or (item.Type == nil and kind == "Weapon") then "Weapon" else "Armor"
				local rarity = N.rarityText(N.call(N.G.Any.GetRarity, configKind, id))
				text = string.format('<font color="%s">%s</font> %s', N.rarityColor(rarity), rarity, N.itemName(configKind, id))
				if N.rarityRank(rarity) > Session.bestForgeRank then
					Session.bestForgeRank = N.rarityRank(rarity)
					Session.bestForge = rarity .. " " .. N.itemName(configKind, id)
				end
				if N.Events.forged then
					pcall(N.Events.forged, rarity, N.itemName(configKind, id))
				end
			end
		end
		table.insert(Fo.log, 1, text)
		while #Fo.log > 5 do
			table.remove(Fo.log)
		end
		Fo.last = text
	end
	-- Act ladder (SPEED_PLAN): rung 1 = fire the remote from where we stand; when refused, rung 3 = teleport onto the
	-- table's prompt side, wait 0.3 s + ping, retry. Two refusals in 60 s on a rung = remembered for 10 min.
	local Acts = {}
	local function pingSeconds()
		local ms = 0
		pcall(function()
			ms = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		return math.clamp((tonumber(ms) or 0) / 1000, 0, 1)
	end
	function N.Act(action, fire)
		local mem = Acts[action]
		if not mem then
			mem = { rung = "remote", rejects = {}, retryAt = 0 }
			Acts[action] = mem
		end
		if mem.retryAt > 0 and os.clock() >= mem.retryAt then
			mem.rung, mem.retryAt = "remote", 0
		end
		local ok, result
		local rung = mem.rung
		if rung == "teleport" then
			local part = N.forgeTable()
			if part then
				local land = CFrame.new(part.Position + Vector3.new(0, 3, 5), part.Position)
				N.tp(land)
				task.wait(0.3 + 1.5 * pingSeconds())
			end
		end
		ok, result = fire()
		if not (ok and result) and rung == "remote" then
			local part = N.forgeTable()
			if part then
				rung = "teleport"
				N.tp(CFrame.new(part.Position + Vector3.new(0, 3, 5), part.Position))
				task.wait(0.3 + 1.5 * pingSeconds())
				ok, result = fire()
			end
		end
		if ok and result then
			mem.rejects = {}
			if rung == "teleport" and mem.rung == "remote" then
				mem.rung, mem.retryAt = "teleport", os.clock() + 600
			end
			log("ACT", action, "via=" .. rung, "ok")
			return ok, result
		end
		local now = os.clock()
		table.insert(mem.rejects, now)
		for i = #mem.rejects, 1, -1 do
			if now - mem.rejects[i] > 60 then
				table.remove(mem.rejects, i)
			end
		end
		log("ACT", action, "via=" .. rung, "rejected reason=" .. brief(result))
		return ok, result
	end
	-- Forges while there are enough ores. Walks to the forge table first, like a player would.
	function N.forgeStep(maxForges)
		if N.fightMode() ~= nil then
			return 0
		end
		local done = 0
		for _ = 1, maxForges or 6 do
			local kind = N.forgeKind()
			local plan, total, avg = N.forgePlan(kind)
			if not plan then
				break
			end
			-- When the expected forged item is worth less than the same ores sold, the ores are sold.
			local choice = autoChoice()
			if choice and choice.perOre < choice.salePerOre and N.want("AutoSellGear") then
				N.planLog("PLAN forge", "selling", total, "ores: forged item", formatNumber(choice.perOre), "per ore < sale", formatNumber(choice.salePerOre))
				for uuid, n in pairs(plan) do
					fire(N.R.sell, uuid, n)
					Session.sold += n
				end
				N.Plan.forge.at = -1e9
				break
			end
			setStatus(string.format("Forging a %s from %d ores (avg power %s)", kind, total, formatNumber(avg)))
			local ok, result = N.Act("forge", function()
				return invoke(N.R.forge, 15, { ConfigType = kind, UUIDList = plan })
			end)
			if not ok or not result then
				logProblem("Forge refused: " .. brief(result))
				break
			end
			done += 1
			Session.forged += 1
			Fo.at = os.clock()
			noteForge(result, kind)
			if N.pickText("ForgeType", "Auto (best value)") ~= "Weapon" and N.pickText("ForgeType", "Auto (best value)") ~= "Armor" then
				Fo.alternate = if kind == "Weapon" then "Armor" else "Weapon"
			end
			if choice then
				N.planLog("PLAN forge", kind, "x" .. total, "value per ore", formatNumber(choice.perOre), "sale per ore", formatNumber(choice.salePerOre))
				N.Plan.forge.at = -1e9
			end
			-- Wait for the backpack update so the next plan does not reuse the same ores.
			local pushes = N.Store.pushes
			waitFor(function()
				return N.Store.pushes ~= pushes
			end, 3)
			task.wait(0.3)
		end
		return done
	end
	-- Gear: equips the best weapon, armor and hat by the game's own stat formula.
	function N.bestGear()
		local best = {}
		for _, g in ipairs(N.gear()) do
			if not best[g.kind] then
				best[g.kind] = g
			end
		end
		return best
	end
	function N.equipStep()
		local bp = N.backpack()
		local equipped = 0
		for kind, g in pairs(N.bestGear()) do
			local current = bp.equiped[kind]
			if current ~= g.uuid then
				local now = bp.have[current]
				local nowScore = if type(now) == "table" then N.gearScore(now, bp) else -1
				if g.score > nowScore + 1e-9 then
					fire(N.R.equip, g.uuid, kind)
					log("EQUIP", kind, g.name, "score", g.score, "was", nowScore)
					Session.equips += 1
					equipped += 1
				end
			end
		end
		return equipped
	end
	-- Selling gear: never equipped, locked, or at/above the kept rarity; keeps the best few of every kind.
	N.Sell = { why = {}, log = {}, tried = {}, refused = 0 }
	-- Every sale is remembered until the item is gone from the backpack. An item the server does not take is
	-- tried once more and then left alone (the log had one uuid sold 486 times, every 5 s, for nothing).
	local function sellable(uuid)
		local entry = N.Sell.tried[uuid]
		if not entry then
			return true
		end
		if entry.count >= 2 then
			return false
		end
		return os.clock() - entry.at > 8
	end
	local function markSold(uuid)
		local entry = N.Sell.tried[uuid]
		if not entry then
			entry = { count = 0, at = 0 }
			N.Sell.tried[uuid] = entry
		end
		local item = N.backpack().have[uuid]
		entry.number = tonumber(type(item) == "table" and item.Number) or 1
		entry.count += 1
		entry.at = os.clock()
	end
	local function forgetGone()
		local have = N.backpack().have
		local refused = 0
		for uuid, entry in pairs(N.Sell.tried) do
			local item = have[uuid]
			-- Gone, or the stack changed size: the sale (or a new drop) went through, start over.
			if item == nil or (tonumber(type(item) == "table" and item.Number) or 1) ~= entry.number then
				N.Sell.tried[uuid] = nil
			elseif entry.count >= 2 then
				refused += 1
			end
		end
		N.Sell.refused = refused
	end
	function N.sellPlan()
		local keepRank = N.rarityRank(optionText("SellKeepRarity", "Legendary"))
		local keepBest = math.clamp(math.floor(optionNumber("SellKeepBest", 2)), 0, 50)
		local counts, plan = {}, {}
		local why = { equipped = 0, locked = 0, rarity = 0, best = 0 }
		for _, g in ipairs(N.gear()) do
			counts[g.kind] = (counts[g.kind] or 0) + 1
			if g.equipped then
				why.equipped += 1
			elseif g.locked then
				why.locked += 1
			elseif N.rarityRank(g.rarity) >= keepRank or N.gearExcluded(g.rarity) then
				why.rarity += 1
			elseif counts[g.kind] <= keepBest + 1 then
				why.best += 1
			elseif sellable(g.uuid) then
				table.insert(plan, g)
			end
		end
		N.Sell.why = why
		return plan
	end
	function N.sellStep()
		forgetGone()
		local sold = 0
		if N.want("AutoSellGear") then
			for _, g in ipairs(N.sellPlan()) do
				if sold >= 10 then
					break
				end
				fire(N.R.sell, g.uuid, 1)
				markSold(g.uuid)
				sold += 1
				Session.sold += 1
				table.insert(N.Sell.log, 1, g.rarity .. " " .. g.name)
				while #N.Sell.log > 5 do
					table.remove(N.Sell.log)
				end
			end
		end
		local oreRank = N.rarityRank(optionText("SellOresBelow", "Off"))
		if oreRank > 0 then
			for _, ore in ipairs(N.ores()) do
				if sold >= 15 then
					break
				end
				if not ore.locked and N.rarityRank(ore.rarity) < oreRank and not N.oreExcluded(ore.rarity) and sellable(ore.uuid) then
					fire(N.R.sell, ore.uuid, ore.number)
					markSold(ore.uuid)
					sold += 1
					Session.sold += ore.number
				end
			end
		end
		return sold
	end
	-- Upgrades: Luck, Ore Pack and Train, 12 levels each, the cheapest affordable picked one first.
	N.UpgradeKinds = { "OrePack", "Train", "Luck" }
	N.UpgradeNames = { OrePack = "Ore Pack", Train = "Train", Luck = "Luck" }
	function N.upgradeNext(kind)
		local levels = N.G.Upgrade[kind]
		if type(levels) ~= "table" then
			return nil
		end
		local data = N.store("Upgrade")[kind]
		local level = tonumber(type(data) == "table" and data.Level) or 0
		local row = levels[level + 1]
		if type(row) ~= "table" then
			return nil
		end
		return { kind = kind, level = level, price = tonumber(row.Price) or math.huge, number = row.Number }
	end
	-- The upgrades the planner can price right now (N.upgradeGain in p09_plan: Ore Pack = more ores per run from the
	-- run model, Luck = better ore odds from the game's loot roll, Train = more rebirths), best gain per coin first.
	function N.upgradeOptions()
		local list = {}
		for _, option in ipairs(N.spendOptions()) do
			if option.kind == "upgrade" then
				option.up.gain = option.gain
				option.up.perCoin = option.perCoin
				table.insert(list, option.up)
			end
		end
		return list
	end
	-- Buys only what the profit planner picks (N.spendPick): the best gain per coin among upgrades and enhance
	-- tries, saving for it unless a cheaper option pays back before the saving is done.
	function N.upgradeStep()
		local pick = N.spendPick()
		local best = if pick and pick.kind == "upgrade" then pick.up else nil
		if best and best.price <= N.coin() then
			fire(N.R.upgrade, best.kind)
			log("UPGRADE", best.kind, "to", best.level + 1, "for", best.price)
			Session.upgrades += 1
			if N.Events.upgraded then
				pcall(N.Events.upgraded, N.UpgradeNames[best.kind], best.level + 1, best.price)
			end
			return true
		end
		return false
	end
	-- Gear enhance (Backpack/EnhantEquipmentRF(uuid, useProtect), opens at rebirth 6). Level L -> L+1 costs coins
	-- and EnhantStone_1/_2 (the stones fall from every stage for free, the pack never holds them, so they are idle
	-- capital) and succeeds with the chance in Config.Enhant.Config. Every level adds a boost to the item's main
	-- stat, which the gear score already includes. Which try is worth its coins is the planner's call (N.spendPick):
	-- success chance x the training the level adds (weapon Train power, hat Train boost), minus the level a failure
	-- takes from +6 on (no scroll), against every other use of the coins. Body armor only adds defence, so it is
	-- not enhanced. The slider is only a ceiling.
	N.Enhance = { last = "", tried = {}, pauseUntil = 0, refused = 0, tries = 0 }
	function N.enhanceMaxLevel()
		return math.clamp(math.floor(optionNumber("EnhanceMax", 20)), 1, 20)
	end
	function N.enhanceNext(item)
		local config = N.call(N.G.Enhant.GetConfig)
		if type(config) ~= "table" then
			return nil
		end
		local level = tonumber(item.Level) or 0
		local row = config[level + 1]
		if type(row) ~= "table" then
			return nil
		end
		local boostNow = tonumber(type(config[level]) == "table" and config[level].Boost) or 0
		return {
			level = level,
			coin = tonumber(row.NeedCoin) or math.huge,
			stone1 = tonumber(row.EnhantStone_1) or 0,
			stone2 = tonumber(row.EnhantStone_2) or 0,
			percent = tonumber(row.Percent) or 1,
			gain = (1 + (tonumber(row.Boost) or 0)) / (1 + boostNow),
		}
	end
	function N.enhanceStep()
		local E = N.Enhance
		if os.clock() < E.pauseUntil or N.rebirth() < 6 or N.fightMode() ~= nil then
			return false
		end
		local bp = N.backpack()
		local pick = N.spendPick()
		if pick and pick.kind == "enhance" and pick.step.coin <= N.coin() then
			local slot, uuid, step, protect = pick.slot, pick.uuid, pick.step, pick.protect
			local item = bp.have[uuid]
			local last = E.tried[uuid]
			if type(item) == "table" and (not last or os.clock() - last > 5) then
				do
					local coinBefore, stonesBefore = N.coin(), N.material("EnhantStone_1") + N.material("EnhantStone_2")
					E.tried[uuid] = os.clock()
					local ok, result = invoke(N.R.enhance, 10, uuid, protect)
					E.tries += 1
					Session.enhances += 1
					task.wait(0.6)
					local item2 = N.backpack().have[uuid]
					local levelAfter = tonumber(type(item2) == "table" and item2.Level) or step.level
					local spent = N.coin() < coinBefore or N.material("EnhantStone_1") + N.material("EnhantStone_2") < stonesBefore
					if levelAfter > step.level then
						E.refused = 0
						E.last = string.format("%s %s +%d -> +%d", slot, N.itemName(slot, item.ID), step.level, levelAfter)
					elseif spent then
						E.refused = 0
						E.last = string.format("%s %s +%d failed (%d%% chance), try again", slot, N.itemName(slot, item.ID), step.level, math.floor(step.percent * 100))
					else
						E.refused += 1
						E.last = "The game did not take the enhance (" .. brief(result) .. ")"
						if E.refused >= 3 then
							E.pauseUntil = os.clock() + 600
							E.refused = 0
							logProblem("Enhance refused 3 times, resting 10 min (" .. brief(result) .. ")")
						end
					end
					log("ENHANCE", slot, "level", step.level, "->", levelAfter, ok and "" or "no answer")
					return true
				end
			end
		end
		return false
	end
	function N.rebirthNeed()
		return tonumber(N.call(N.G.Rebirth.GetNeedLevel, N.rebirth() + 1))
	end
	function N.rebirthStep()
		local need = N.rebirthNeed()
		if need and N.level() >= need and N.fightMode() == nil then
			local before = N.rebirth()
			fire(N.R.rebirth)
			Session.rebirths += 1
			log("REBIRTH", before + 1, "level", N.level())
			if N.Events.rebirth then
				pcall(N.Events.rebirth, before + 1)
			end
			return true
		end
		return false
	end
	-- Training: standing in a TOUCHED.AutoTrainArea makes the game train by itself every 0.2 s. Areas 9-11 are
	-- paid, the rest open with rebirths. The best open one has the highest multiplier.
	function N.trainAreas()
		local list = {}
		for id, row in pairs(N.G.TrainArea) do
			if type(row) == "table" and tonumber(id) then
				table.insert(list, { id = tonumber(id), basic = tonumber(row.Basic) or 1, need = tonumber(row.NeedRebirth) or 0, pay = row.IsPay == true })
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		return list
	end
	function N.bestTrainArea()
		local best
		local rebirth = N.rebirth()
		local pick = optionText("TrainArea", "Best open")
		for _, area in ipairs(N.trainAreas()) do
			if not area.pay and area.need <= rebirth then
				if pick ~= "Best open" and tostring(area.id) == string.match(pick, "%d+") then
					return area
				end
				if not best or area.basic > best.basic then
					best = area
				end
			end
		end
		return best
	end
	function N.trainPart(id)
		local touched = workspace:FindFirstChild("TOUCHED")
		local folder = touched and touched:FindFirstChild("AutoTrainArea")
		local area = folder and folder:FindFirstChild(tostring(id))
		if area and not area:IsA("BasePart") then
			area = area:FindFirstChildWhichIsA("BasePart", true)
		end
		return area
	end
	N.Train = { since = nil, area = nil }
	function N.trainStep()
		if N.fightMode() ~= nil then
			return false
		end
		local area = N.bestTrainArea()
		if not area then
			setStatus("No training area open")
			task.wait(1)
			return false
		end
		local current = tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID"))
		-- Blatant: the server took the better free area (p05_probes train_area), stay where it put you.
		local held = N.trainZoneHold and N.trainZoneHold(current)
		if current ~= area.id and not held then
			local part = N.trainPart(area.id)
			if not part then
				logProblem("No AutoTrainArea." .. area.id)
				task.wait(2)
				return false
			end
			setStatus("Going to training area " .. area.id .. " (x" .. formatNumber(area.basic) .. ")")
			N.tp(part.CFrame + Vector3.new(0, 2.5, 0))
			waitFor(function()
				return tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID")) == area.id
			end, 3)
			N.Train.since = os.clock()
			N.Train.area = area.id
			return true
		end
		N.Train.area = area.id
		N.Train.since = N.Train.since or os.clock()
		if not held and N.probeOk and N.probeOk("train_area") and N.blatant("TrainSpeed") and os.clock() - (N.Train.zoneAt or -1e9) > 60 then
			local zone = N.trainZone()
			if zone then
				N.Train.zoneAt = os.clock()
				fire("Train/IntoAutoTrainRE", zone.id)
			end
		end
		local best = N.Plan and N.Plan.best
		setStatus(string.format(
			"Training in area %d (x%s)  \u{00B7}  level %d%s",
			area.id,
			formatNumber(area.basic),
			N.level(),
			if best and best.kind == "train" and best.eta then "  \u{00B7}  rebirth in " .. N.longTime(best.eta) else ""
		))
		task.wait(1)
		Session.trainSeconds += 1
		return true
	end
end
do
	-- Frostbound Tower (the game's dungeon): opens at rebirth 2, one Tower Ticket per run. TryIntoDungeonRF(floor)
	-- puts you in, the game spawns each floor's enemies here and pays every cleared floor by itself. Start floors
	-- are 1, 6, 11... up to one past your best floor. Unlike stages the game does not auto attack here, so the
	-- hub clicks the attack button for you.
	N.Tower = {
		at = -1e9,
		last = "",
		startedAt = 0,
		round = nil,
		emptySince = nil,
		deathStreak = 0,
		lastDeathRound = 0,
		pauseUntil = 0,
		stalls = 0,
	}
	function N.towerTickets()
		return N.material("Dungeon_Ticket")
	end
	-- How many floors the game has (its round table). A run started past the last floor never spawns anything
	-- and just hangs there (seen in the log: minutes on "floor 51" with 50 floors).
	function N.towerFloors()
		local config = N.call(N.G.Dungeon.GetConfig)
		if type(config) ~= "table" then
			return nil
		end
		local top = 0
		for key in pairs(config) do
			if type(key) == "number" and key > top then
				top = key
			end
		end
		return if top > 0 then top else nil
	end
	-- Start floors are 1, 6, 11... up to one past your best floor. With every floor cleared that would be past
	-- the last one, so a run from floor 1 is used instead: it pays all floors for the same single ticket.
	function N.towerFloor()
		local best = tonumber(N.store("Dungeon").maxRound) or 0
		local total = N.towerFloors()
		if optionText("TowerStart", "Highest unlocked") == "Floor 1" or (total and best >= total) then
			return 1
		end
		local floor = 1
		while floor + 5 <= best + 1 do
			floor += 5
		end
		return floor
	end
	-- Power needed before the tower is worth a ticket again after it beat us (0 = no block).
	N.Tower.needPower = 0
	function N.towerReady()
		return N.rebirth() >= 2
			and N.towerTickets() > 0
			and os.clock() - N.Tower.at > 20
			and os.clock() >= N.Tower.pauseUntil
			and N.power() >= (N.Tower.needPower or 0)
	end
	-- True when today's free Tower Ticket (TryClaimDailyDunTicRE, DungeonData.CheckTodayClaimed) is still unclaimed.
	function N.towerDailyOpen()
		local data = N.store("Dungeon")
		local today = workspace:GetAttribute("today")
		local daily = if type(data.DailyGet) == "table" then data.DailyGet else {}
		return N.rebirth() >= 2 and today ~= nil and not daily[today]
	end
	-- Why Auto Tower is not starting a run right now, in plain words (nil = ready). Shown in Status and logged as
	-- TOWER waiting reason=... so a tower that waits is never silent (tester 2026-10-07: "Auto Tower is not working").
	function N.towerWaitReason()
		local T = N.Tower
		if N.rebirth() < 2 then
			return "the tower opens at rebirth 2 (now " .. N.rebirth() .. ")"
		end
		if N.towerTickets() <= 0 then
			return if N.towerDailyOpen()
				then "no Tower Tickets, claiming today's free one"
				else "no Tower Tickets (next free one tomorrow; online gifts and rebirths give more)"
		end
		if os.clock() < T.pauseUntil then
			return "resting " .. N.longTime(T.pauseUntil - os.clock()) .. " after a stuck run"
		end
		if N.power() < (T.needPower or 0) then
			return "it beat us twice, waiting for power " .. formatNumber(T.needPower)
		end
		if os.clock() - T.at <= 20 then
			return "short pause between runs"
		end
		return nil
	end
	-- Smart Planner ranked a stage run or training above the tower (both priced in coins of value per second).
	function N.towerPlanReason(first)
		local options = N.Plan and N.Plan.options or {}
		local mine, other
		for _, o in ipairs(options) do
			if o.kind == "tower" and not mine then
				mine = o
			elseif o.kind == first and not other then
				other = o
			end
		end
		local function rate(o)
			return if o and o.gain and o.gain < math.huge then formatNumber(o.gain) .. "/s" else "?"
		end
		return string.format("Smart Planner: %s pays more (%s vs tower %s)", if first == "train" then "training" else "a stage run", rate(other), rate(mine))
	end
	function N.towerWaiting(reason)
		local T = N.Tower
		T.waitReason = reason
		-- Logged when the reason changes (numbers in brackets aside) and every 5 minutes.
		local key = string.match(tostring(reason), "^[^%(%d]*")
		if reason ~= "short pause between runs" and (key ~= T.loggedReason or os.clock() - (T.waitLogAt or -1e9) > 300) then
			T.loggedReason = key
			T.waitLogAt = os.clock()
			log("TOWER waiting", "reason=" .. tostring(reason))
		end
	end
	-- Run bookkeeping for the TOWER enter/floor/done log lines.
	function N.towerFinished()
		local T = N.Tower
		if not T.inRun then
			return
		end
		T.inRun = false
		local secs = os.clock() - (T.startedAt or os.clock())
		local coins = math.max(N.coin() - (T.coinAt or N.coin()), 0)
		local stones = (N.material("EnhantStone_1") + N.material("EnhantStone_2")) - (T.stonesAt or 0)
		log(
			"TOWER done",
			string.format("rewards=coins+%s stones+%d floors=%d best=%s tickets=%d in %.0fs", formatNumber(coins), math.max(stones, 0), T.floorsDone or 0, tostring(N.store("Dungeon").maxRound or 0), N.towerTickets(), secs)
		)
	end
	-- Enemy HP of one floor (the game's round table, mobs and boss).
	function N.towerFloorHP(round)
		local config = N.call(N.G.Dungeon.GetConfig)
		local row = type(config) == "table" and config[round]
		if type(row) ~= "table" then
			return nil
		end
		local hp = math.max(tonumber(row.MobHP) or 0, tonumber(row.BossHP) or 0)
		return if hp > 0 then hp else nil
	end
	-- Called by the game's death event. Two deaths in a row on the same floor or lower mean the tower is too
	-- strong: every death costs a ticket and a long respawn. No fixed rest: the tower waits until the power has
	-- grown by the floor's HP step (HP of the floor that killed us / HP of the floor before, from the game's round
	-- table), because damage grows with power and that floor was out of reach at today's power.
	function N.towerDied()
		local T = N.Tower
		local round = tonumber(T.round) or 0
		if T.lastDeathRound > 0 and round > T.lastDeathRound then
			T.deathStreak = 0
		end
		T.deathStreak += 1
		T.lastDeathRound = round
		if T.deathStreak >= 2 then
			local hp, before = N.towerFloorHP(round), N.towerFloorHP(round - 1)
			local step = if hp and before and before > 0 then math.max(hp / before, 1.01) else 2
			T.needPower = math.max(N.power(), 1) * step
			T.last = string.format("Died %d times around floor %d, waiting for power %s", T.deathStreak, round, formatNumber(T.needPower))
			logProblem(string.format("Tower too strong around floor %d, waiting for power %s (x%.2f)", round, formatNumber(T.needPower), step))
		else
			T.last = "Died on floor " .. round
		end
	end
	function N.towerStart()
		N.Tower.at = os.clock()
		local floor = N.towerFloor()
		setStatus("Starting the tower at floor " .. floor)
		local ok, result = invoke(N.R.tower, 15, floor)
		if not ok or not result then
			N.Tower.last = "The tower refused the start (" .. brief(result) .. ")"
			log("TOWER refused", brief(result))
			return false
		end
		Session.towerRuns += 1
		log("TOWER enter", "floor=" .. floor, "tickets=" .. N.towerTickets(), "best=" .. tostring(N.store("Dungeon").maxRound or 0))
		N.Tower.inRun = true
		N.Tower.waitReason = nil
		N.Tower.loggedReason = nil
		N.Tower.floorsDone = 0
		N.Tower.coinAt = N.coin()
		N.Tower.stonesAt = N.material("EnhantStone_1") + N.material("EnhantStone_2")
		N.Tower.startedAt = os.clock()
		N.Tower.fastTried = false
		N.Tower.roundAt = nil
		N.Tower.round = floor
		N.Tower.emptySince = nil
		N.Tower.last = "Run " .. Session.towerRuns .. " from floor " .. floor
		waitFor(function()
			return N.fightMode() == "Dungeon"
		end, 10)
		return true
	end
	function N.towerStep()
		local T = N.Tower
		local round = LocalPlayer:GetAttribute("CurrentRound")
		-- Blatant: instant floors (p05_probes), once per run, after the game has started its first floor (1 s).
		if not T.fastTried and N.towerFastWanted and N.towerFastWanted() and round ~= nil then
			if os.clock() - (T.startedAt or 0) < 1.5 then
				task.wait(0.2)
				return
			end
			T.fastTried = true
			if N.towerFast() then
				return
			end
		end
		if round ~= nil and round ~= T.round then
			-- Seconds per floor of the game's own flow: the baseline of the instant floors probe.
			if T.roundAt and tonumber(round) == (tonumber(T.round) or 0) + 1 then
				local secs = os.clock() - T.roundAt
				if secs > 0.5 and secs < 120 then
					T.perFloor = if T.perFloor then T.perFloor * 0.7 + secs * 0.3 else secs
				end
			end
			T.roundAt = os.clock()
			if T.round ~= nil and tonumber(round) and tonumber(round) > (tonumber(T.round) or 0) then
				T.floorsDone = (T.floorsDone or 0) + 1
			end
			T.round = round
			log("TOWER floor", tostring(round))
			if T.lastDeathRound > 0 and (tonumber(round) or 0) > T.lastDeathRound then
				T.deathStreak = 0
			end
		end
		local enemies = N.enemies("EnemyFolder")
		if #enemies > 0 then
			T.emptySince = nil
			setStatus(string.format("Tower floor %s: %d enemies", tostring(round or "?"), #enemies))
			N.standAt(enemies[1].pos, 3.5)
			N.attackClick()
			N.auraStep()
			task.wait(0.12)
			return
		end
		-- Between floors the game needs about 3 s. Much longer with nobody to fight means the run is stuck, so
		-- leave through the game's own exit instead of sitting there until the server gives up.
		T.emptySince = T.emptySince or os.clock()
		if os.clock() - T.emptySince > 30 then
			T.stalls += 1
			T.emptySince = nil
			-- Retry after as long as this run lasted (a server hang, not a power problem).
			T.pauseUntil = os.clock() + math.max(os.clock() - T.startedAt, 30)
			T.last = "Stuck on floor " .. tostring(round or "?") .. ", left the tower"
			logProblem("Tower stuck on floor " .. tostring(round or "?") .. " with no enemies, leaving")
			fire(N.R.towerExit)
			waitFor(function()
				return N.fightMode() ~= "Dungeon"
			end, 5)
			return
		end 
		setStatus("Tower floor " .. tostring(round or "?") .. ": next floor soon")
		task.wait(0.3)
	end
	-- World boss: a server boss in workspace.EnemyFolder_Server while workspace.CurrentWorldBoss is set. The
	-- TOUCHED.WorldBoss pad joins the fight, the reward cards open after it dies.
	N.Boss = { at = -1e9, last = "", joinedAt = 0, deaths = 0, skip = false }
	function N.bossActive()
		return workspace:GetAttribute("CurrentWorldBoss") ~= nil and workspace:GetAttribute("CurrentWorldBoss") ~= false
	end
	-- True while there is a boss worth joining. The game puts you back into the arena after every death, so a
	-- boss that kills you twice is skipped until it is gone (the log had six deaths in a row, 25 s each).
	function N.bossWanted()
		if not N.bossActive() then
			N.Boss.deaths = 0
			N.Boss.skip = false
			return false
		end
		return not N.Boss.skip
	end
	function N.bossDied()
		N.Boss.deaths += 1
		if N.Boss.deaths >= 2 then
			N.Boss.skip = true
			N.Boss.last = "Too strong, skipped for now (" .. N.Boss.deaths .. " deaths)"
			logProblem("World boss killed us " .. N.Boss.deaths .. " times, skipping it")
		end
	end
	local function pad(name)
		local touched = workspace:FindFirstChild("TOUCHED")
		local part = touched and touched:FindFirstChild(name)
		if part and not part:IsA("BasePart") then
			part = part:FindFirstChildWhichIsA("BasePart", true)
		end
		return part
	end
	function N.bossJoin()
		N.Boss.at = os.clock()
		local part = pad("WorldBoss")
		if not part then
			logProblem("No TOUCHED.WorldBoss pad")
			return false
		end
		setStatus("Joining the world boss")
		N.tp(part.CFrame + Vector3.new(0, 2, 0))
		local ok = waitFor(function()
			return N.fightMode() == "WorldBoss"
		end, 6)
		if ok then
			Session.bossFights += 1
			N.Boss.joinedAt = os.clock()
			N.Boss.last = "Fight " .. Session.bossFights .. " joined"
		end
		return ok
	end
	function N.bossLeave()
		local part = pad("WorldBoss_Back")
		if part then
			N.tp(part.CFrame + Vector3.new(0, 2, 0))
			waitFor(function()
				return N.fightMode() ~= "WorldBoss"
			end, 6)
		end
	end
	function N.bossStep()
		if N.Boss.skip then
			setStatus("World boss too strong, leaving")
			N.bossLeave()
			task.wait(1)
			return
		end
		local bosses = N.enemies("EnemyFolder_Server")
		if #bosses > 0 then
			setStatus("Fighting the world boss")
			N.standAt(bosses[1].pos, 7)
			N.attackClick()
			task.wait(0.12)
			return
		end
		if not N.bossActive() and os.clock() - N.Boss.joinedAt > 12 then
			setStatus("World boss over, leaving")
			task.wait(6)
			N.bossLeave()
			return
		end
		setStatus("Waiting for the world boss")
		task.wait(0.5)
	end
	N.onRemote("WorldBoss/BossDeadRE", function()
		if not N.want("AutoWorldBoss") then
			return
		end
		task.wait(4.5)
		local cards = if N.bossCards then N.bossCards() else (fire(N.R.bossCard, "1") and 1)
		N.Boss.last = if (tonumber(cards) or 0) > 1 then "Boss down, " .. cards .. " reward cards taken" else "Boss down, reward card picked"
	end)
	-- Rewards. Every one is checked against the player data first, so nothing is spammed.
	N.Reward = { log = {}, tried = {} }
	local function noteReward(text)
		Session.claims += 1
		table.insert(N.Reward.log, 1, text)
		while #N.Reward.log > 5 do
			table.remove(N.Reward.log)
		end
	end
	local function once(key, seconds)
		local now = os.clock()
		if now - (N.Reward.tried[key] or -1e9) < (seconds or 60) then
			return false
		end
		N.Reward.tried[key] = now
		return true
	end
	function N.onlineStep()
		local data = N.store("Online")
		local claimed = if type(data.Reward) == "table" then data.Reward else {}
		local played = N.serverTime() - (tonumber(data.StartTick) or N.serverTime())
		local config = N.call(N.G.Online.GetOnlineTimeConfig) or {}
		for id, need in pairs(config) do
			if not claimed[id] and played >= (tonumber(need) or math.huge) and once("online" .. id, 30) then
				fire(N.R.online, id)
				noteReward("Online gift " .. id)
			end
		end
	end
	function N.offlineStep()
		if LocalPlayer:GetAttribute("OfflineRewardValue") and once("offline", 120) then
			fire(N.R.offline)
			noteReward("Offline reward")
		end
	end
	function N.indexStep()
		local data = N.store("Index")
		local unlocked = if type(data.unlocked) == "table" then data.unlocked else {}
		local claimed = if type(data.claimed) == "table" then data.claimed else {}
		local count = 0
		for key in pairs(unlocked) do
			if count >= 8 then
				break
			end
			if not claimed[key] and once("index" .. tostring(key), 120) then
				local kind, id = string.match(tostring(key), "^([^%-]+)%-(.+)$")
				if kind and id then
					invoke(N.R.indexExp, 8, kind, id)
					count += 1
					noteReward("Index " .. id)
				end
			end
		end
		if once("indexLevel", 300) then
			invoke(N.R.indexLevel, 8)
		end
	end
	function N.seasonStep()
		local season = workspace:GetAttribute("Season")
		local data = N.store("Season")
		local mine = if season and type(data[season]) == "table" then data[season] else {}
		local today = workspace:GetAttribute("today")
		local daily = if type(mine.DailyGet) == "table" then mine.DailyGet else {}
		if season and today and not daily[today] and once("seasonDaily", 300) then
			fire(N.R.seasonDaily)
			noteReward("Season daily ticket")
		end
		if season and once("seasonAll", 300) then
			fire(N.R.seasonAll)
		end
	end
	-- Season Luck: the daily ticket (and the pass rewards) pay Season Tickets, a spin of 1 / 3 / 10 costs that many
	-- (the game opens a Robux prompt only when you have fewer, so the hub never spins without the tickets). Every
	-- prize is worth having (Enhance stones, Class rolls, Protection Scrolls, Season Coins, a weapon, coins), and an
	-- unspent ticket earns nothing, so they are spun as soon as they arrive. 10 at once saves calls.
	function N.seasonLuckStep()
		local season = workspace:GetAttribute("Season")
		local data = N.store("Season")
		local mine = if season and type(data[season]) == "table" then data[season] else {}
		local tickets = tonumber(mine.SeasonTicket) or 0
		if tickets >= 1 and once("seasonLuck", 7) then
			local n = if tickets >= 10 then 10 elseif tickets >= 3 then 3 else 1
			fire(N.R.seasonLuck, n)
			Session.seasonSpins += n
			noteReward("Season luck x" .. n)
		end
	end
	-- Season Shop: every good with stock is priced in coins by the planner (N.seasonGoodValue: tower ticket = the
	-- measured value of a tower run, Train potion = 300 s of faster training, Class roll = what one more roll adds
	-- by the game's class odds, stones / scroll = the enhance they unlock, Season gear = the training it adds or its
	-- sale price, Season Ticket = the expected spin, the coin deal = its coins). The best value per Season Coin is
	-- bought, saving for it when it is short (Season Coins have no other use).
	function N.seasonShopRanked()
		local season = workspace:GetAttribute("Season")
		local data = N.store("Season")
		local mine = if season and type(data[season]) == "table" then data[season] else {}
		local goods = if type(mine.Goods) == "table" then mine.Goods else {}
		local config = N.call(N.G.Season.GetGoodsConfig)
		local list = {}
		if type(config) ~= "table" then
			return list, tonumber(mine.SeasonCoin) or 0
		end
		for id, row in pairs(config) do
			if type(row) == "table" then
				local left = (tonumber(row.Store) or 0) - (tonumber(goods[id]) or 0)
				local price = tonumber(row.NeedSeasonCoin) or math.huge
				if left > 0 and price > 0 and price < math.huge then
					local ok, value = pcall(N.seasonGoodValue, row)
					value = if ok then tonumber(value) or 0 else 0
					if value > 0 then
						table.insert(list, { id = tostring(id), row = row, price = price, value = value, perCoin = value / price })
					end
				end
			end
		end
		table.sort(list, function(a, b)
			if a.perCoin ~= b.perCoin then
				return a.perCoin > b.perCoin
			end
			return a.id < b.id
		end)
		return list, tonumber(mine.SeasonCoin) or 0
	end
	function N.seasonShopStep()
		if N.keepExcluded("Season Coins") then
			return false
		end
		local list, coins = N.seasonShopRanked()
		local best = list[1]
		if not best then
			return false
		end
		local text = string.format("best=Season %s gain/SC=%.3g", tostring(best.row.ID), best.perCoin)
		if list[2] then
			text ..= string.format(" alt=%s:%.3g", tostring(list[2].row.ID), list[2].perCoin)
		end
		-- Logged when the best item changes, else once a minute (the gain number moves every call while training).
		N.Reward.shopText = text
		local key = tostring(best.row.ID)
		if N.Reward.shopKey ~= key or os.clock() - (N.Reward.shopLogAt or -1e9) > 60 then
			N.Reward.shopKey, N.Reward.shopLogAt = key, os.clock()
			N.planLog("PLAN", text)
		end
		if coins >= best.price and once("shop" .. best.id, 6) then
			fire(N.R.seasonShop, best.id)
			Session.shopBuys += 1
			noteReward("Season shop " .. tostring(best.row.ID) .. " x" .. tostring(best.row.Number))
			return true
		end
		return false
	end
	function N.towerDailyStep()
		local data = N.store("Dungeon")
		local today = workspace:GetAttribute("today")
		local daily = if type(data.DailyGet) == "table" then data.DailyGet else {}
		if N.rebirth() >= 2 and today and not daily[today] and once("towerDaily", 300) then
			fire(N.R.towerDaily)
			noteReward("Daily tower ticket")
		end
	end
	function N.questStep()
		local data = N.store("EnhantEvent")
		local record = if type(data.record) == "table" then data.record else {}
		local claimed = if type(data.claimed) == "table" then data.claimed else {}
		local quests = N.call(N.G.EnhantEvent.GetQuestConfig) or {}
		for id, quest in pairs(quests) do
			if type(quest) == "table" and not claimed[id] and (tonumber(record[quest.NeedType]) or 0) >= (tonumber(quest.NeedNumber) or math.huge) and once("quest" .. id, 60) then
				fire(N.R.quest, id)
				noteReward("Event quest " .. id)
			end
		end
	end
	function N.updateLogStep()
		local config = N.call(N.G.UpdateLog.GetConfig) or {}
		for k in pairs(config) do
			if once("upd" .. tostring(k), 1e9) then
				fire(N.R.updateLog, k)
			end
		end
	end
	function N.groupStep()
		if once("group", 1e9) then
			fire(N.R.group)
		end
	end
	function N.rewardStep()
		if on("AutoOnline") then
			N.onlineStep()
		end
		if on("AutoOffline") then
			N.offlineStep()
		end
		if on("AutoIndex") then
			N.indexStep()
		end
		if N.want("AutoSeason") then
			N.seasonStep()
		end
		if N.want("AutoSeasonLuck") then
			N.seasonLuckStep()
		end
		if N.want("AutoSeasonShop") then
			N.seasonShopStep()
		end
		-- Auto Tower needs tickets: it claims today's free one itself (a pre-step), not only via the Rewards toggle.
		if on("AutoTowerTicket") or N.want("AutoTower") then
			N.towerDailyStep()
		end
		if on("AutoQuests") then
			N.questStep()
		end
		if on("AutoUpdateRewards") then
			N.updateLogStep()
			N.groupStep()
		end
	end
	-- Potions: keeps one of each picked kind running while you have them.
	N.PotionNames = { CoinPotion = "Coin", TrainPotion = "Train", LuckPotion = "Luck", DamagePotion = "Damage", HPPotion = "HP" }
	function N.potionStep()
		if not N.want("AutoPotions") or N.keepExcluded("Potions") then
			return
		end
		local buffs = N.store("Buff")
		local now = N.serverTime()
		for uuid, item in pairs(N.backpack().have) do
			if type(item) == "table" and item.Type == "Potion" and (tonumber(item.Number) or 0) > 0 then
				local name = N.PotionNames[item.ID] or item.ID
				local buff = N.call(N.G.Potion.GetBuffID, item.ID)
				local running = buff and (tonumber(buffs[buff]) or 0) - now > 2
				if allows(Options.PotionKinds, name) and not running and once("potion" .. tostring(item.ID), 20) then
					fire(N.R.potion, item.ID, 1)
					Session.potions += 1
					log("POTION", item.ID, "uuid", uuid)
				end
			end
		end
	end
	-- Class rolls: rerolls the equipped class slot until it reaches the target rarity. Uses only the free
	-- rolls you already have (the game opens a Robux prompt when there are none, so the hub stops at 0).
	N.ClassRoll = { at = -1e9, last = "" }
	function N.classNow()
		local data = N.store("Class")
		local index = data.equiped
		local have = if type(data.have) == "table" then data.have else {}
		local class = have[index] or "Class_1"
		return index, class, N.rarityText(N.call(N.G.Class.GetRarity, class))
	end
	-- The Races menu (PlayerGui.ScreenMain.Class). Every roll makes the server fire Class/ShowLuckResultRE; the game's
	-- LuckAnim then opens the menu with UIController.OpenScreenMain but never sets the GUI's own "open" flag, so its X
	-- (ClassGUI.close) does nothing and the player is stuck (owner report 2026-10-05). The hub rolls only while no
	-- menu is open, one roll per 4 s (the result animation takes about 3 s), and closes the menu it caused through
	-- the same UIController.CloseScreenMain("Class") the X button uses.
	local function raceMenu()
		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		local screen = gui and gui:FindFirstChild("ScreenMain")
		return screen and screen:FindFirstChild("Class")
	end
	function N.closeRaceMenu()
		local menu = raceMenu()
		if not menu or not menu.Visible then
			return false
		end
		local ok = pcall(function()
			require(game:GetService("ReplicatedStorage"):WaitForChild("Utils", 5):WaitForChild("UIController", 5)).CloseScreenMain("Class")
		end)
		if not ok or menu.Visible then
			-- Fallback: what CloseScreenMain does (hide the frame, clear the open flag, give the HUD back).
			pcall(function()
				menu.Visible = false
				workspace:SetAttribute("SCREENMAINOPEN", nil)
				local gui = LocalPlayer.PlayerGui
				for _, name in ipairs({ "Hud", "Main", "UIVFX" }) do
					local g = gui:FindFirstChild(name)
					if g and g:IsA("ScreenGui") then
						g.Enabled = true
					end
				end
			end)
		end
		log("CLASS menu closed after the roll", if ok then "(UIController)" else "(fallback)")
		return true
	end
	function N.classStep()
		local C = N.ClassRoll
		-- Close the menu our own roll opened, once its result animation is over.
		if C.ownMenu and os.clock() - C.at > 3.5 then
			C.ownMenu = false
			pcall(N.closeRaceMenu)
		end
		if not N.want("AutoClassRoll") or os.clock() - C.at < 4 then
			return
		end
		-- Never roll while the player (or the game) has a menu open.
		local menu = raceMenu()
		if (menu and menu.Visible) or workspace:GetAttribute("SCREENMAINOPEN") then
			return
		end
		local data = N.store("Class")
		local rolls = tonumber(data.luckTimes) or 0
		local index, class, rarity = N.classNow()
		local locked = type(data.lock) == "table" and data.lock[index]
		if rolls <= 0 or index == nil or locked then
			return
		end
		local target = N.pickText("ClassTarget", "Auto (expected value)")
		local W = if target == "Auto (expected value)" then N.classThreshold(rolls) else nil
		if W then
			-- Optimal stopping: roll only while the class is worth less than what the rolls left are expected to reach.
			local record = data.recored
			local rec = type(record) == "table" and record[class]
			local now = N.classValue(class, tonumber(type(rec) == "table" and rec.Level) or 1) or 0
			if now >= W then
				return
			end
		elseif N.rarityRank(rarity) >= N.rarityRank(if target == "Auto (expected value)" then "Legendary" else target) then
			return
		end
		N.ClassRoll.at = os.clock()
		N.ClassRoll.ownMenu = true
		fire(N.R.classRoll, index)
		Session.classRolls += 1
		N.ClassRoll.last = string.format("Rolled slot %s (was %s %s, %d rolls left)", tostring(index), rarity, tostring(class), rolls - 1)
	end
	-- Codes: the list lives in the repo (HubRepo .. "Codes", game name -> codes). Each code is tried once per account,
	-- the outcome is remembered in Lymn/LTF_codes_<UserId>.txt ("R code" redeemed, "I code" invalid).
	N.Codes = { redeemed = {}, invalid = {}, nRed = 0, nBad = 0, lastRun = -1e9, loaded = false, running = false }
	local CodesFile = "Lymn/LTF_codes_" .. tostring(LocalPlayer.UserId) .. ".txt"
	local function codesLoad()
		local C = N.Codes
		if C.loaded then
			return
		end
		C.loaded = true
		local ok, text = pcall(function()
			return if isfile(CodesFile) then readfile(CodesFile) else ""
		end)
		if ok and type(text) == "string" then
			for kind, code in string.gmatch(text, "(%u) (%S+)") do
				local set = if kind == "R" then C.redeemed else C.invalid
				if not set[code] then
					set[code] = true
					if kind == "R" then
						C.nRed += 1
					else
						C.nBad += 1
					end
				end
			end
		end
	end
	local function codesSave()
		local C = N.Codes
		local out = {}
		for code in pairs(C.redeemed) do
			table.insert(out, "R " .. code)
		end
		for code in pairs(C.invalid) do
			table.insert(out, "I " .. code)
		end
		table.sort(out)
		pcall(function()
			if makefolder and isfolder and not isfolder("Lymn") then
				makefolder("Lymn")
			end
			writefile(CodesFile, table.concat(out, "\n"))
		end)
	end
	local function codeTry(code)
		local C = N.Codes
		local ok, result = invoke(N.R.code, 10, code)
		Session.codes += 1
		if not ok then
			log("CODE", code, "no answer, will retry")
			return nil
		end
		if result and result ~= false then
			if not C.redeemed[code] then
				C.redeemed[code] = true
				C.nRed += 1
			end
			log("CODE", code, "redeemed")
		else
			if not C.invalid[code] then
				C.invalid[code] = true
				C.nBad += 1
			end
			log("CODE", code, "invalid")
		end
		codesSave()
		return result and result ~= false
	end
	function N.codesList()
		if N.CodeSource then
			return N.CodeSource()
		end
		local ok, body = pcall(function()
			return game:HttpGet(HubRepo .. "Codes")
		end)
		if not ok or type(body) ~= "string" or body == "" then
			log("CODES list not available, skipped")
			return nil
		end
		local ok2, data = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not ok2 or type(data) ~= "table" then
			log("CODES list unreadable, skipped")
			return nil
		end
		local list = data["+1 Loot To Forge"] or data["Loot To Forge"]
		return if type(list) == "table" then list else nil
	end
	-- One pass over the known codes (2 s apart). Called at start and every 6 h.
	function N.codesRun()
		local C = N.Codes
		if C.running then
			return
		end
		C.running = true
		C.lastRun = os.clock()
		codesLoad()
		local list = N.codesList()
		local tried = 0
		for _, code in ipairs(list or {}) do
			if not alive() or not on("AutoCodes") then
				break
			end
			if type(code) == "string" and not C.redeemed[code] and not C.invalid[code] then
				if tried > 0 then
					task.wait(2)
				end
				tried += 1
				codeTry(code)
			end
		end
		C.running = false
		log("CODES pass", tried, "tried, redeemed", C.nRed, "invalid", C.nBad)
	end
	function N.codesText()
		codesLoad()
		return string.format("Codes redeemed %d / invalid %d", N.Codes.nRed, N.Codes.nBad)
	end
	function N.redeemCode(code)
		code = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if code == "" then
			notify("Codes", "Type a code first", 3)
			return
		end
		task.spawn(function()
			codesLoad()
			local result = codeTry(code)
			notify("Codes", if result then "Code redeemed: " .. code elseif result == nil then "No answer from the game for " .. code else "The game did not accept " .. code, 4)
		end)
	end
end
do
	-- Blatant probes (blatant.md, dump pv33715). Faster ways the dump shows the server may take: each one is tried
	-- once per game version (PlaceVersion), kept only when the server really pays (measured, never assumed) and
	-- logged as "PROBE <name> result=accepted|rejected gain=<x>". Rejected = the hub keeps the game's own way.
	-- No anticheat in the dump (notes.md): Blatant is the default of every speed dropdown and the only mode of the planner.
	local Pr = { file = "Lymn_LTF_probes.txt", results = {}, version = "?" }
	N.Probe = Pr
	pcall(function()
		Pr.version = tostring(game.PlaceVersion)
	end)
	N.ProbeNames = { "stage_loot", "train_rate", "train_area", "train_keep", "tower_fast", "boss_cards" }
	function N.probeEncode()
		local lines = { "version=" .. Pr.version }
		for _, name in ipairs(N.ProbeNames) do
			local r = Pr.results[name]
			if r then
				table.insert(lines, string.format("%s|%s|%.4f|%s", name, r.result, tonumber(r.gain) or 0, tostring(r.value or "")))
			end
		end
		return table.concat(lines, "\n")
	end
	function N.probeDecode(text)
		text = tostring(text or "")
		local results = {}
		local version = string.match(text, "^version=([^\n]*)")
		for name, result, gain, value in string.gmatch(text, "([%w_]+)|(%a+)|([^|\n]+)|([^\n]*)") do
			if result == "accepted" or result == "rejected" then
				results[name] = { result = result, gain = tonumber(gain) or 0, value = if value ~= "" then value else nil }
			end
		end
		return version, results
	end
	local function save()
		if type(writefile) == "function" then
			pcall(writefile, Pr.file, N.probeEncode())
		end
	end
	pcall(function()
		if type(isfile) == "function" and type(readfile) == "function" and isfile(Pr.file) then
			local version, results = N.probeDecode(readfile(Pr.file))
			if version == Pr.version then
				Pr.results = results
				local parts = {}
				for name, r in pairs(results) do
					table.insert(parts, name .. "=" .. r.result)
				end
				table.sort(parts)
				log("PROBE remembered for version", Pr.version, table.concat(parts, " "))
			else
				log("PROBE game version", Pr.version, "(saved " .. tostring(version) .. "), trying the fast ways again")
			end
		end
	end)
	function N.probe(name)
		return Pr.results[name]
	end
	function N.probeOk(name)
		local r = Pr.results[name]
		return r ~= nil and r.result == "accepted"
	end
	-- Not rejected: still to be measured, or accepted.
	function N.probeOpen(name)
		local r = Pr.results[name]
		return r == nil or r.result == "accepted"
	end
	function N.probeDone(name, accepted, gain, value, detail)
		gain = tonumber(gain) or 0
		if gain ~= gain or gain == math.huge or gain == -math.huge then
			gain = 0
		end
		gain = math.clamp(gain, 0, 999)
		Pr.results[name] = { result = if accepted then "accepted" else "rejected", gain = gain, value = value }
		log("PROBE", name, "result=" .. Pr.results[name].result, string.format("gain=%.2f", gain), detail or "")
		save()
	end
	N.SpeedValues = {
		LootSpeed = { "Blatant (instant pickup)", "Legit (walk to drops)" },
		TrainSpeed = { "Blatant (fastest the server takes)", "Legit (game speed)" },
		TowerSpeed = { "Blatant (instant floors)", "Legit (fight every floor)" },
		BossCards = { "Blatant (every card)", "Legit (one card)" },
	}
	-- Short plain-words line for the status labels.
	function N.probeText(name)
		local r = Pr.results[name]
		if not r then
			return "not tried yet"
		elseif r.result == "accepted" then
			return string.format("server takes it (x%.2f)", r.gain or 0)
		end
		return "server refused, game way used"
	end

	-- (1) Stage loot. The game asks the server for a stage's ores the moment its enemies spawn (StageUtils
	-- CreateStageEnemys -> StageFinishedRF("Stage_N"), dump 24799-24824) and every pickup is GetOreRF(uuid)
	-- (OreUtils.CreateOres 24518). Blatant takes the rolled ores at once, up to the free pack slots, best rarity
	-- first; the kill and the 30 s respawn stay the game's. Accepted only when the bank really adds them.
	N.Loot = { empty = 0, short = 0, last = "" }
	function N.directLootWanted()
		return N.blatant("LootSpeed") and N.probeOpen("stage_loot")
	end
	function N.directLoot(stageN)
		local F = N.Fight
		local L = N.Loot
		local ok, tab = invoke("Stage/StageFinishedRF", 8, "Stage_" .. tostring(stageN))
		if not ok or type(tab) ~= "table" or next(tab) == nil then
			L.empty += 1
			if N.probe("stage_loot") == nil and L.empty >= 3 then
				N.probeDone("stage_loot", false, 0, nil, "answer=" .. brief(tab))
			end
			return 0
		end
		local list = {}
		for uuid, id in pairs(tab) do
			if type(id) ~= "table" then
				local rarity = N.rarityText(N.call(N.G.Ore.GetRarity, id))
				if allows(Options.PickRarities, rarity) then
					table.insert(list, { uuid = uuid, id = id, rank = N.rarityRank(rarity) })
				end
			end
		end
		table.sort(list, function(a, b)
			if a.rank ~= b.rank then
				return a.rank > b.rank
			end
			return tostring(a.uuid) < tostring(b.uuid)
		end)
		local hudBefore = select(1, N.pack()) - (if F.hudCounts then 0 else (F.direct or 0))
		local picked = 0
		local started = os.clock()
		for _, entry in ipairs(list) do
			local now, max = N.pack()
			if now >= max then
				break
			end
			invoke("Stage/GetOreRF", 5, entry.uuid)
			F.direct = (F.direct or 0) + 1
			picked += 1
			Session.ores += 1
		end
		-- The planner's run model learns the real seconds per ore of this way of picking.
		if picked > 0 then
			F.directClears = (F.directClears or 0) + 1
		end
		if picked > 0 and N.planNotePick then
			N.planNotePick(math.max((os.clock() - started) / picked, 0.02))
		end
		if picked > 0 and F.hudCounts == nil then
			-- Does the HUD count server pickups by itself? Then the hub must not add them a second time.
			task.wait(0.3)
			local hudNow = select(1, N.pack()) - F.direct
			F.hudCounts = hudNow >= hudBefore + picked
			if F.hudCounts then
				log("LOOT the HUD counts direct pickups itself")
			end
		end
		L.last = string.format("Stage %d: took %d ores straight from the server", stageN, picked)
		log("LOOT direct stage", stageN, "picked", picked, "of", #list, "pack", select(1, N.pack()))
		return picked
	end
	-- Called by N.bank: snapshot before the Return button, verdict after the bank lands in the backpack.
	function N.lootBankStart()
		local F = N.Fight
		if (F.direct or 0) <= 0 then
			return nil
		end
		local packNow = N.pack()
		local snap = { ores = N.oreTotal(), direct = F.direct, regular = math.max(packNow - F.direct, 0), total = packNow, clears = F.directClears or 1 }
		F.directClears = 0
		return snap
	end
	function N.lootBankEnd(snap, seconds, target)
		if not snap or N.probeOk("stage_loot") then
			return
		end
		local L = N.Loot
		local need = snap.regular + math.max(1, math.floor(snap.direct * 0.7))
		local arrived = waitFor(function()
			return N.oreTotal() - snap.ores >= need
		end, 6)
		local gained = N.oreTotal() - snap.ores
		if arrived then
			local ev = N.stageOreEV and N.stageOreEV(target) or nil
			local mult = if N.coinMult then N.coinMult() else 1
			local after = if ev and seconds and seconds > 0 then snap.total / seconds * ev * mult else nil
			local before = N.Fight.coinsBefore
			if (not before or before <= 0) and after and seconds and seconds > 0 then
				-- No run model yet: the same run with the walk (about 0.62 s per ore) and the 2.5 s drop wait per clear.
				before = after * seconds / (seconds + snap.total * 0.62 + 2.5 * math.max(snap.clears, 1))
			end
			local gain = if after and before and before > 0 then after / before else 0
			N.probeDone(
				"stage_loot",
				true,
				gain,
				nil,
				string.format("ores=%d/%d coins/s before=%s after=%s", gained, snap.total, if before then formatNumber(before) else "?", if after then formatNumber(after) else "?")
			)
		elseif gained <= snap.regular then
			N.probeDone("stage_loot", false, 0, nil, string.format("ores=%d of %d, the %d direct ores never arrived", gained, snap.total, snap.direct))
		else
			L.short += 1
			log("PROBE stage_loot unclear", "ores", gained, "of", snap.total, "try", L.short)
			if L.short >= 3 then
				N.probeDone("stage_loot", false, 0, nil, "three banks came up short")
			end
		end
	end

	-- (2)+(3) Training. TrainCTRL.TrainOnce (dump 30880) is the game's own train click: its only limit is the
	-- client attribute LastTrainTick (0.15 s), the game's auto train clicks every 0.2 s. The ladder tries 0.15,
	-- 0.1, 0.075 and 0.05 s for 15 s each (exp per train-once value from Eco power) and keeps the fastest step
	-- that still gained 8 %. Then IntoAutoTrainRE(best free area) is tried from the open area (the rebirth gate
	-- is client-side, 41629): kept when exp/s rises 20 %. Then the same clicks during stage runs (the game trains
	-- in fights too, 24317): kept when exp keeps coming while farming.
	N.Boost = { i = 1, rates = {}, raws = {}, win = nil, area = nil, areaRate = nil, last = "" }
	N.TrainLadder = { 0.2, 0.15, 0.1, 0.075, 0.05 }
	N.BoostWindow = 15
	local Ladder = N.TrainLadder
	function N.trainCtrl()
		if Pr.ctrl == nil then 
			Pr.ctrl = false
			pcall(function()
				local node = ReplicatedStorage:FindFirstChild("CTRL")
				node = node and node:FindFirstChild("TrainCTRL")
				if node then
					local module = require(node)
					if type(module) == "table" and type(module.TrainOnce) == "function" then
						Pr.ctrl = module
					end
				end
			end)
		end
		return Pr.ctrl or nil
	end
	local function trainOnce()
		local ctrl = N.trainCtrl()
		if not ctrl then
			return false
		end
		pcall(function()
			LocalPlayer:SetAttribute("LastTrainTick", 0)
		end)
		return (pcall(ctrl.TrainOnce))
	end
	N.trainOnceBoost = trainOnce
	function N.boostContext()
		if not N.want("AutoTrain") or N.dead() or N.manualRunning() then
			return nil
		end
		if not N.blatant("TrainSpeed") then
			return nil
		end
		local mode = N.fightMode()
		if mode == nil and LocalPlayer:GetAttribute("AutoTrainAreaID") ~= nil then
			return "area"
		elseif mode == "Stage" then
			return "fight"
		end
		return nil
	end
	function N.trainCadence()
		local r = Pr.results.train_rate
		if r and r.result == "accepted" then
			return tonumber(r.value)
		end
		return nil
	end
	-- Ladder decision (pure): the next step while the newest one still gained 8 % on the best so far, else nil and
	-- the best step.
	function N.ladderNext(rates, i)
		local best = 1
		for k = 2, i do
			if rates[k] and rates[best] and rates[k] >= rates[best] * 1.08 then
				best = k
			end
		end
		if i >= #Ladder or (i >= 2 and best ~= i) then
			return nil, best
		end
		return i + 1, best
	end
	-- The best free (never paid) area above the best open one, and the best open one.
	function N.trainZone()
		local open = N.bestTrainArea()
		if not open then
			return nil, nil
		end
		local best
		for _, area in ipairs(N.trainAreas()) do
			if not area.pay and area.basic > open.basic and (not best or area.basic > best.basic) then
				best = area
			end
		end
		return best, open
	end
	-- Area id the training counts in: the zone when its probe is running or was accepted, else nil.
	function N.trainZoneHold(current)
		if not N.blatant("TrainSpeed") or not N.probeOpen("train_area") then
			return false
		end
		local zone = N.trainZone()
		return zone ~= nil and tonumber(current) == zone.id and (N.probeOk("train_area") or N.Boost.area ~= nil)
	end
	-- Multiplier of the area the server trains in (the accepted zone, else the area you stand in).
	function N.trainEffectiveBasic(basic)
		if N.blatant("TrainSpeed") and N.probeOk("train_area") then
			local zone = N.trainZone()
			if zone and zone.basic > (basic or 0) then
				return zone.basic
			end
		end
		return basic
	end
	-- Share of the area exp/s that keeps coming in during stage runs (0 when not accepted).
	function N.trainKeepRatio()
		if not N.want("AutoTrain") or not N.blatant("TrainSpeed") or not N.probeOk("train_keep") then
			return 0
		end
		return math.clamp(tonumber(Pr.results.train_keep.value) or 0, 0, 0.95)
	end
	local function windowStart(B, ctx)
		B.win = {
			at = os.clock(),
			power = N.power(),
			once = math.max(tonumber(N.call(N.G.Calc.CCTrainOncePower, LocalPlayer)) or 1, 1),
			area = LocalPlayer:GetAttribute("AutoTrainAreaID"),
			ctx = ctx,
		}
	end
	-- Raw exp/s and exp/s per train-once value once the window is full, nil while it runs.
	local function windowRate(B)
		local w = B.win
		local secs = os.clock() - w.at
		if secs < N.BoostWindow then
			return nil
		end
		B.win = nil
		local raw = math.max(N.power() - w.power, 0) / secs
		return raw, raw / w.once
	end
	local function ladderStep(B)
		if not N.trainCtrl() then
			N.probeDone("train_rate", false, 0, nil, "no TrainCTRL module")
			return
		end
		if not B.win then
			windowStart(B, "area")
		end
		local cadence = Ladder[B.i]
		if B.i > 1 then
			trainOnce()
		end
		local raw, perOnce = windowRate(B)
		if raw then
			B.rates[B.i], B.raws[B.i] = perOnce, raw
			log(string.format("PROBE train_rate cadence=%.3f result=%s exp/s", cadence, formatNumber(raw)))
			local nextI, best = N.ladderNext(B.rates, B.i)
			if nextI then
				B.i = nextI
			else
				local gain = B.rates[best] / math.max(B.rates[1] or 0, 1e-9)
				if (B.rates[1] or 0) <= 0 then
					gain = if B.rates[best] > 0 then 99 else 0
				end
				B.areaRate = B.raws[best]
				N.probeDone("train_rate", best > 1 and gain >= 1.1, gain, Ladder[best], string.format("cadence=%.3f", Ladder[best]))
				B.i, B.rates, B.raws = 1, {}, {}
			end
			return
		end
		task.wait(if B.i > 1 then cadence else 0.25)
	end
	local function areaStep(B, zone, open)
		local cadence = N.trainCadence()
		B.area = B.area or { step = 1 }
		local A = B.area
		if not B.win then
			windowStart(B, "area")
		end
		if cadence then
			trainOnce()
		end
		local raw = windowRate(B)
		if raw then
			if A.step == 1 then
				A.base = raw
				A.step = 2
				fire("Train/IntoAutoTrainRE", zone.id)
				task.wait(2)
				A.attr = LocalPlayer:GetAttribute("AutoTrainAreaID")
				B.win = nil
			else
				local gain = raw / math.max(A.base or 0, 1e-9)
				local accepted = (A.base or 0) > 0 and gain >= 1.2
				B.area = nil
				if accepted then
					B.areaRate = raw
				else
					fire("Train/IntoAutoTrainRE", open.id)
				end
				N.probeDone("train_area", accepted, gain, zone.id, string.format("id=%d open=%d attr=%s", zone.id, open.id, tostring(A.attr)))
			end
			return
		end
		task.wait(cadence or 0.25)
	end
	local function keepStep(B, cadence)
		if not B.win then
			windowStart(B, "fight")
		end
		trainOnce()
		local raw = windowRate(B)
		if raw then
			local ratio = raw / math.max(B.areaRate, 1e-9)
			N.probeDone(
				"train_keep",
				ratio >= 0.05,
				1 + ratio,
				string.format("%.3f", math.min(ratio, 0.95)),
				string.format("fight exp/s=%s area exp/s=%s attr=%s", formatNumber(raw), formatNumber(B.areaRate), tostring(LocalPlayer:GetAttribute("AutoTrainAreaID")))
			)
			return
		end
		task.wait(cadence)
	end
	-- One step of the training boost loop (p10). Every wait is inside, so the loop never spins.
	function N.trainBoostStep()
		local B = N.Boost
		local ctx = N.boostContext()
		if not ctx then
			B.win = nil
			task.wait(0.3)
			return
		end
		if B.win and (B.win.ctx ~= ctx or B.win.area ~= LocalPlayer:GetAttribute("AutoTrainAreaID") or N.power() < B.win.power) then
			B.win = nil -- moved, changed area or rebirthed: the window starts again
		end
		local cadence = N.trainCadence()
		if ctx == "area" then
			if N.probe("train_rate") == nil then
				ladderStep(B)
				return
			end
			local zone, open = N.trainZone()
			if zone and N.probe("train_area") == nil then
				areaStep(B, zone, open)
				return
			end
			if not cadence then
				task.wait(0.5)
				return
			end
			-- Keep measuring the area speed: the fight probe compares with it.
			if not B.win then
				windowStart(B, "area")
			end
			trainOnce()
			local raw = windowRate(B)
			if raw and raw > 0 then
				B.areaRate = raw
			end
			B.last = string.format("Training clicks every %.2f s", cadence)
			task.wait(cadence)
			return
		end
		-- Stage run: train while farming.
		if not cadence or not N.probeOpen("train_keep") then
			task.wait(0.5)
			return
		end
		if N.probe("train_keep") == nil then
			if not B.areaRate then
				task.wait(0.5)
				return
			end
			keepStep(B, cadence)
			return
		end
		trainOnce()
		task.wait(cadence)
	end

	-- (4) Tower. Floors are completed by the client: DungeonData.StartRound(r) = StartRoundRE, CompleteRound(r) =
	-- CompleteRoundRF(r) returns that floor's loot (dump 52230, DungeonManager 23803-23841). Blatant starts and
	-- completes each floor back to back from the floor the run started on, never kills anything meanwhile (so the
	-- game never completes a floor a second time) and leaves at the first floor the server does not pay.
	function N.towerFastWanted()
		return N.blatant("TowerSpeed") and N.probeOpen("tower_fast")
	end
	function N.towerFast()
		local T = N.Tower
		local round = tonumber(LocalPlayer:GetAttribute("CurrentRound"))
		local last = N.towerFloors()
		if not round or not last or round > last then
			return false
		end
		T.fastRunning = true
		local started = os.clock()
		local done, answer = 0, nil
		for r = round, last do
			if N.fightMode() ~= "Dungeon" or not alive() then
				break
			end
			setStatus(string.format("Tower floor %d: instant clear", r))
			fire("Dungeon/StartRoundRE", r)
			task.wait(0.15)
			local ok, loot = invoke("Dungeon/CompleteRoundRF", 8, r)
			if answer == nil then
				answer = brief(loot)
			end
			if not ok or type(loot) ~= "table" or next(loot) == nil then
				break
			end
			done += 1
			T.floorsDone = (T.floorsDone or 0) + 1
			log("TOWER floor", tostring(r), "instant")
		end
		local secs = math.max(os.clock() - started, 0.01)
		if N.probe("tower_fast") == nil then
			if done > 0 then
				local legit = T.perFloor or 5
				local fast = secs / done
				N.probeDone("tower_fast", true, legit / fast, nil, string.format("floors=%d in %.1fs, legit %.1fs/floor, first answer %s", done, secs, legit, tostring(answer)))
			else
				N.probeDone("tower_fast", false, 0, nil, "first answer " .. tostring(answer))
			end
		end
		T.last = string.format("Instant floors: %d paid in %.1f s", done, secs)
		log("TOWER fast", "floors", done, "from", round, "in", string.format("%.1fs", secs))
		if done > 0 then
			fire(N.R.towerExit)
			waitFor(function()
				return N.fightMode() ~= "Dungeon"
			end, 5)
		end
		T.fastRunning = false
		return done > 0
	end

	-- (5) World boss cards. WorldBossGUI.OpenBossRewardUI (dump 51518) builds 8 cards, each click fires
	-- TryClaimBossRewardRE(k); ShowCardVFX writes the owner's UserID on the card. Blatant clicks all 8 and keeps
	-- doing so only when more than one card comes out as yours.
	function N.bossCardsMine()
		local mine, seen = 0, 0
		pcall(function()
			local cards = LocalPlayer.PlayerGui.BossFight.BossReward.Cards
			for _, card in ipairs(cards:GetChildren()) do
				local owner = card:GetAttribute("UserID")
				if owner ~= nil then
					seen += 1
					if owner == LocalPlayer.UserId then
						mine += 1
					end
				end
			end
		end)
		return mine, seen
	end
	function N.bossCards()
		if not (N.blatant("BossCards") and N.probeOpen("boss_cards")) then
			fire(N.R.bossCard, "1")
			return 1
		end
		for k = 1, 8 do
			fire(N.R.bossCard, tostring(k))
			task.wait(0.3)
		end
		task.wait(2)
		local mine, seen = N.bossCardsMine()
		if N.probe("boss_cards") == nil then
			if seen == 0 then
				log("PROBE boss_cards result=unknown, no card owners shown")
			else
				N.probeDone("boss_cards", mine >= 2, mine, mine, string.format("cards=%d of %d shown", mine, seen))
			end
		end
		return mine
	end
end
do
	-- One mode: the fastest that works (owner 2026-10-06). The Smart Planner always uses the Blatant way of every
	-- activity (instant pickup, fast training clicks, instant floors, every boss card, insta-kill) and ignores the
	-- dropdowns. The dropdowns stay for players who turn single toggles on; their default is Blatant. The only
	-- fallback is a real server answer: a rejected probe (p05_probes) turns that Blatant way off for this game
	-- version and the game's own way is used; a new PlaceVersion tries the fast way again.
	function N.blatant(option)
		if on("SmartPlanner") then
			return true
		end
		return string.sub(optionText(option, "Blatant"), 1, 7) == "Blatant"
	end
	-- Insta-kill for the aura: the planner always, otherwise what the dropdown says.
	function N.auraInsta()
		if on("SmartPlanner") then
			return true
		end
		return optionText("AuraMode", "Insta-kill") == "Insta-kill"
	end
end
local Window, Tabs, Labels
do
	do
		local setIdentity = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity)
		if setIdentity then
			pcall(setIdentity, 8)
		end
	end
	Window = Library:CreateWindow({})
	function N.addTab(name, icon, description)
		if Window.AddInfoTab then
			return Window:AddTab({ Name = name, Icon = icon, Description = description })
		end
		return Window:AddTab(name, icon)
	end
	Tabs = {}
	if Window.AddInfoTab then
		pcall(function()
			Tabs.Info = Window:AddInfoTab({
				Discord = Discord,
				DiscordAvatar = "corvus-square",
				DiscordBanner = "corvus-banner",
				DiscordTitle = "Lymn",
				DiscordDescription = "Keyless scripts, updates and support",
				Feedback = function(Box)
					Tabs.FeedbackBox = Box
				end,
			})
		end)
	end
	Tabs.Main = N.addTab("Main", "house", "Quick start, status and what comes next")
	Tabs.Farm = N.addTab("Farm", "swords", "Stages, training, tower, world boss, Kill Aura and player")
	Tabs.Forge = N.addTab("Forge", "hammer", "Forging, best gear and selling")
	Tabs.Upgrades = N.addTab("Upgrades", "trending-up", "Upgrades, rebirth, gear enhance, potions and class rolls")
	Tabs.Rewards = N.addTab("Rewards", "gift", "Gifts, season, index, quests and codes")
	Tabs.Stats = N.addTab("Stats", "chart-column", "Session progress, rates and Discord webhook posts")
	-- Packed tabs: the webhook settings live in the Stats tab.
	Tabs.Webhook = Tabs.Stats
	if Window.AddMiscTab then
		pcall(function()
			Tabs.Misc = Window:AddMiscTab({ Description = "Performance, AFK and connection", RejoinScript = LoaderScript })
		end)
	end
	Labels = {}
	do
		local QuickBox = Tabs.Main:AddLeftGroupbox("Quick Start", "sparkles")
		-- No master switch: every automation is its own toggle. The list is what Stop Everything switches off.
		N.AllAutoToggles2 = {
			"SmartPlanner", "KillAura", "GodMode", "Untouchable", "AutoStages", "AutoSuperLoot", "AutoTrain", "AutoForge", "AutoEquip", "AutoSellGear", "AutoUpgrade",
			"AutoEnhance", "AutoRebirth", "AutoTower", "AutoWorldBoss", "AutoOnline", "AutoOffline", "AutoFriend", "AutoIndex", "AutoSeason",
			"AutoSeasonLuck", "AutoSeasonShop", "AutoTowerTicket", "AutoQuests", "AutoUpdateRewards", "AutoPotions", "AutoClassRoll", "AutoCodes",
		}
		QuickBox:AddToggle("SmartPlanner", {
			Text = "Smart Planner",
			Default = false,
			Tooltip = "Runs the whole loop by profit: stage runs, training and rebirths, tower, world boss, forging, best gear, selling weak gear, upgrades, enhance, class rolls and season spending. It always uses the fastest way of every action (the mode dropdowns do not apply) and keeps your Protected Items safe. Your other toggles are not changed",
		})
		-- Quick Start mirrors: the same switch as in its own tab, both ways (the tab toggle is the real one).
		N.QuickMirrors = {
			{ "Q_AutoStages", "AutoStages", "Auto Farm Stages" },
			{ "Q_KillAura", "KillAura", "Kill Aura" },
			{ "Q_AutoTrain", "AutoTrain", "Auto Train" },
			{ "Q_AutoForge", "AutoForge", "Auto Forge" },
			{ "Q_AutoRebirth", "AutoRebirth", "Auto Rebirth" },
		}
		for _, pair in ipairs(N.QuickMirrors) do
			local real = pair[2]
			QuickBox:AddToggle(pair[1], {
				Text = pair[3],
				Default = false,
				Tooltip = "Same switch as " .. pair[3] .. " in its own tab",
				Callback = function(v)
					local t = Toggles[real]
					if t and t.Value ~= v then
						t:SetValue(v)
					end
				end,
			})
			pcall(function()
				SaveManager.Ignore[pair[1]] = true
			end)
		end
		function N.syncMirrors()
			for _, pair in ipairs(N.QuickMirrors) do
				local m, r = Toggles[pair[1]], Toggles[pair[2]]
				if m and r and m.Value ~= r.Value then
					m:SetValue(r.Value)
				end
			end
		end
		task.spawn(function()
			while alive() do
				pcall(N.syncMirrors)
				task.wait(0.25)
			end
		end)
		QuickBox:AddButton({
			Text = "Stop Everything",
			Tooltip = "Turns every automation off",
			Func = function()
				N.stopAll()
			end,
		})
		QuickBox:AddButton({
			Text = "Reset Hub Options",
			Tooltip = "Puts every toggle, dropdown, slider and input back to its default. Saved configs are not deleted",
			Func = function()
				N.askReset()
			end,
		})
		QuickBox:AddLabel({
			Text = '<font transparency="0.35">Smart Planner runs everything by profit. Without it every switch works on its own. Nothing turns on by itself.</font>',
			DoesWrap = true,
		})
		-- Reset Hub Options: every toggle, dropdown, slider and input back to the default it was registered with. Saved configs stay.
		function N.resetOptions()
			local ignore = (SaveManager and SaveManager.Ignore) or {}
			local function skip(name)
				return ignore[name] == true or name == "MenuKeybind" or string.find(name, "^SaveManager") ~= nil or string.find(name, "^Lymn") ~= nil or string.find(name, "^ThemeManager") ~= nil
			end
			N.quiet = true
			local changed = 0
			for name, toggle in pairs(Toggles) do
				local default = toggle.Default
				if not skip(name) and type(default) == "boolean" and toggle.Value ~= default then
					pcall(toggle.SetValue, toggle, default)
					changed += 1
				end
			end
			for name, option in pairs(Options) do
				local kind = option.Type
				local default = option.Default
				if not skip(name) and default ~= nil and kind ~= "KeyPicker" and kind ~= "ColorPicker" then
					local value = default
					if type(default) == "table" and option.Multi then
						value = {}
						for k, v in pairs(default) do
							if type(k) == "number" then
								value[v] = true
							elseif v then
								value[k] = true
							end
						end
					elseif type(default) == "table" then
						value = default[1]
					end
					pcall(option.SetValue, option, value)
					changed += 1
				end
			end
			N.quiet = false
			log("RESET options to defaults", "controls", changed)
			notify("Lymn", "All hub options are back to their defaults. Saved configs are untouched", 5)
		end
		function N.askReset()
			Library:ShowConfirmPrompt({
				Title = "Reset Hub Options",
				Text = "Reset all options to defaults?",
				Warning = "Saved configs are not deleted",
				ConfirmText = "Reset",
				CancelText = "Cancel",
				OnConfirm = function()
					N.resetOptions()
				end,
			})
		end
		local StatusBox = Tabs.Main:AddRightGroupbox("Status", "activity")
		Labels.Status = StatusBox:AddLabel({ Text = "Idle", DoesWrap = true })
		Labels.Info = StatusBox:AddLabel({ Text = "-", DoesWrap = true })
		StatusBox:AddButton({
			Text = "Bank Ores Now",
			Func = function()
				task.spawn(N.bank, "button")
			end,
		})
		local NextBox = Tabs.Main:AddRightGroupbox("Up next", "list-checks")
		Labels.Next = NextBox:AddLabel({ Text = "-", DoesWrap = true })
		local StageBox = Tabs.Farm:AddLeftGroupbox("Stage Farm", "swords")
		StageBox:AddToggle("AutoStages", {
			Text = "Auto Farm Stages",
			Default = false,
			Tooltip = "Runs the stages in order up to the best one you can clear, picks up every ore and banks the pack when it is full",
		})
		StageBox:AddDropdown("StageMode", {
			Text = "Deepest Stage",
			Values = { "Auto (by power)", "Pick a stage" },
			Default = "Auto (by power)",
			Tooltip = "Auto compares your power with the game's recommended power of every stage",
		})
		StageBox:AddSlider("StageFixed", { Text = "Picked Stage", Default = 3, Min = 1, Max = 27, Rounding = 0 })
		StageBox:AddSlider("StageMargin", {
			Text = "Power Needed",
			Default = 100,
			Min = 25,
			Max = 300,
			Rounding = 0,
			Suffix = "% of recommended",
			Tooltip = "100% = only stages your power meets. Lower is braver, higher is safer",
		})
		StageBox:AddSlider("BankHP", {
			Text = "Bank Ores Below",
			Default = 35,
			Min = 0,
			Max = 90,
			Rounding = 0,
			Suffix = "% HP",
			Tooltip = "Dying loses every ore in the pack, so the hub banks them and leaves when your HP drops this low",
		})
		StageBox:AddDropdown("PickOres", {
			Text = "Pick Ores On",
			Values = { "Deepest stage only", "Every stage" },
			Default = "Deepest stage only",
			Tooltip = "Deeper stages drop much better ores and the pack is small, so only the deepest stage of each run fills it",
		})
		StageBox:AddDropdown("PickRarities", {
			Text = "Pick Up Ores",
			Values = N.RarityOrder,
			Default = N.RarityOrder,
			Multi = true,
			AllowNull = true,
			Tooltip = "Only ores of the picked rarities go into your pack. Untick the low ones to keep the pack for the good drops",
		})
		StageBox:AddDropdown("LootSpeed", {
			Text = "Ore Pickup",
			Values = N.SpeedValues.LootSpeed,
			Default = N.SpeedValues.LootSpeed[1],
			Tooltip = "Blatant (default) takes the ores of the deepest stage straight from the server as soon as they spawn, no walking to the drops. The hub checks the first bank and goes back to walking if the server does not pay them",
		})
		StageBox:AddSlider("StuckSeconds", { Text = "Give Up On A Stage After", Default = 20, Min = 5, Max = 120, Rounding = 0, Suffix = " s without damage" })
		local SuperBox = Tabs.Farm:AddLeftGroupbox("Super Loot", "gem")
		SuperBox:AddToggle("AutoSuperLoot", {
			Text = "Hunt Super Loot Runners",
			Default = false,
			Tooltip = "Every 12 / 30 / 45 minutes a runner with a Legendary / Eternal / Secret ore appears on a stage. The hub goes there, kills it in about 2 seconds and picks the ore up. Needs Auto Farm Stages, and only stages your run can reach",
		})
		Labels.Super = SuperBox:AddLabel({ Text = "-", DoesWrap = true })
		local AuraBox = Tabs.Farm:AddRightGroupbox("Kill Aura", "zap")
		AuraBox:AddToggle("KillAura", {
			Text = "Kill Aura",
			Default = false,
			Tooltip = "Hits every enemy in range many times a second, in stages and the tower. Insta-kill by default, works with weak weapons too",
		})
		AuraBox:AddDropdown("AuraMode", {
			Text = "Damage",
			Values = { "Insta-kill", "Real damage" },
			Default = "Insta-kill",
			Tooltip = "Insta-kill finishes stage and tower enemies at once (they only exist on your screen). Real damage hits with your own weapon damage",
		})
		AuraBox:AddSlider("AuraRange", { Text = "Range", Default = 500, Min = 10, Max = 500, Rounding = 0, Suffix = " studs", Tooltip = "500 hits every enemy of the stage you are on" })
		AuraBox:AddSlider("AuraSpeed", { Text = "Hit Every", Default = 0.1, Min = 0.1, Max = 1, Rounding = 2, Suffix = " s" })
		local MapBox = Tabs.Farm:AddRightGroupbox("Stages For Your Power", "map")
		Labels.Stages = MapBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local ForgeBox = Tabs.Forge:AddLeftGroupbox("Auto Forge", "hammer")
		ForgeBox:AddToggle("AutoForge", {
			Text = "Auto Forge",
			Default = false,
			Tooltip = "Forges at the forge table whenever you have enough ores, strongest ores first for the best quality",
		})
		ForgeBox:AddDropdown("ForgeType", {
			Text = "Forge",
			Values = { "Auto (best value)", "Alternate", "Weapon", "Armor" },
			Default = "Auto (best value)",
			Tooltip = "Auto prices every kind and ore count with the game's own forge odds (the training the item adds, or its sale price) and sells the ores instead when that pays more. The slider below is for the other modes",
		})
		ForgeBox:AddSlider("ForgeOres", {
			Text = "Ores Per Forge",
			Default = 8,
			Min = 4,
			Max = 23,
			Rounding = 0,
			Tooltip = "More ores give bigger items: weapons 4 (Katana) to 13 (Great sword), armor 4 (light hat) to 23 (heavy armor)",
		})
		ForgeBox:AddDropdown("ForgeKeepRarities", {
			Text = "Never Forge These Ores",
			Values = N.RarityOrder,
			Default = { "Infinite", "Exclusive" },
			Multi = true,
			AllowNull = true,
			Tooltip = "Pick any rarities: ores of the picked rarities always stay in your backpack",
		})
		ForgeBox:AddButton({
			Text = "Forge Now",
			Func = function()
				task.spawn(N.runManual, function()
					local count = N.forgeStep(10)
					notify("Forge", if count > 0 then "Forged " .. count .. " items" else "Not enough ores", 4)
				end)
			end,
		})
		Labels.Forge = ForgeBox:AddLabel({ Text = "-", DoesWrap = true })
		-- Protected items: ores, gear, Season Coins and potions picked here are never sold, forged, enhanced or spent by any toggle.
		local ProtectBox = Tabs.Forge:AddLeftGroupbox("Protected Items", "shield-check")
		ProtectBox:AddDropdown("FarmExclude", {
			Text = "Protected items",
			Values = N.ExcludeValues,
			Default = N.ExcludeDefault,
			Multi = true,
			AllowNull = true,
			Tooltip = "Never sold, forged, enhanced or spent by any toggle or the Smart Planner: ores and gear of the picked tiers, Season Coins (no Season Shop buys) and potions (none used)",
		})
		local GearBox = Tabs.Forge:AddRightGroupbox("Best Gear", "shield")
		GearBox:AddToggle("AutoEquip", { Text = "Auto Equip Best Gear", Default = false, Tooltip = "Weapon, armor and hat, scored with the game's own stat formula" })
		Labels.Gear = GearBox:AddLabel({ Text = "-", DoesWrap = true })
		local SellBox = Tabs.Forge:AddRightGroupbox("Selling", "badge-dollar-sign")
		SellBox:AddToggle("AutoSellGear", {
			Text = "Auto Sell Weak Gear",
			Default = false,
			Tooltip = "Sells forged gear worse than what you keep. Never sells equipped, locked or kept rarities",
		})
		SellBox:AddSlider("SellKeepBest", { Text = "Also Keep Best", Default = 2, Min = 0, Max = 20, Rounding = 0, Suffix = " per kind" })
		SellBox:AddDropdown("SellKeepRarity", { Text = "Always Keep From", Values = N.RarityOrder, Default = "Legendary" })
		SellBox:AddDropdown("SellOresBelow", {
			Text = "Sell Ores Below",
			Values = { "Off", "UnCommon", "Rare", "Epic", "Legendary" },
			Default = "Off",
			Tooltip = "Sells ores under this rarity for coins. Off keeps every ore for forging",
		})
		Labels.Sell = SellBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local TrainBox = Tabs.Farm:AddLeftGroupbox("Training", "dumbbell")
		TrainBox:AddToggle("AutoTrain", {
			Text = "Auto Train",
			Default = false,
			Tooltip = "Stands in the best training area you unlocked, the game trains by itself there. With Auto Farm Stages on it trains after every stage run for as long as that run took. Smart Planner splits the time by profit instead",
		})
		local areaNames = { "Best open" }
		for _, area in ipairs(N.trainAreas()) do
			if not area.pay then
				table.insert(areaNames, string.format("Area %d (x%s, rebirth %d)", area.id, formatNumber(area.basic), area.need))
			end
		end
		TrainBox:AddDropdown("TrainArea", { Text = "Area", Values = areaNames, Default = "Best open" })
		TrainBox:AddDropdown("TrainSpeed", {
			Text = "Training Speed",
			Values = N.SpeedValues.TrainSpeed,
			Default = N.SpeedValues.TrainSpeed[1],
			Tooltip = "Blatant (default): the fastest training clicks the server still counts, the best free area, and training keeps going training during stage runs. Anything that does not add exp goes back to the game's own speed",
		})
		Labels.Train = TrainBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local TowerBox = Tabs.Farm:AddLeftGroupbox("Frostbound Tower", "castle")
		TowerBox:AddToggle("AutoTower", {
			Text = "Auto Tower",
			Default = false,
			Tooltip = "Uses your Tower Tickets: enters, clears floor after floor and collects the rewards. Opens at rebirth 2",
		})
		TowerBox:AddDropdown("TowerStart", { Text = "Start At", Values = { "Highest unlocked", "Floor 1" }, Default = "Highest unlocked" })
		TowerBox:AddDropdown("TowerSpeed", {
			Text = "Floor Speed",
			Values = N.SpeedValues.TowerSpeed,
			Default = N.SpeedValues.TowerSpeed[1],
			Tooltip = "Blatant (default) completes floor after floor right away and leaves at the first floor the server does not pay. If it pays none, the hub fights the floors as usual",
		})
		Labels.Tower = TowerBox:AddLabel({ Text = "-", DoesWrap = true })
		local BossBox = Tabs.Farm:AddRightGroupbox("World Boss", "skull")
		BossBox:AddToggle("AutoWorldBoss", {
			Text = "Auto World Boss",
			Default = false,
			Tooltip = "Joins every world boss, fights it and picks a reward card. Stage runs wait while it is up",
		})
		BossBox:AddDropdown("BossCards", {
			Text = "Reward Cards",
			Values = N.SpeedValues.BossCards,
			Default = N.SpeedValues.BossCards[1],
			Tooltip = "Blatant (default) clicks all 8 reward cards. If the server gives you only one, the next bosses get a single click",
		})
		Labels.Boss = BossBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local UpgradeBox = Tabs.Upgrades:AddLeftGroupbox("Upgrades", "arrow-big-up")
		UpgradeBox:AddToggle("AutoUpgrade", { Text = "Auto Buy Upgrades", Default = false, Tooltip = "Buys the upgrade that adds the most coins per second per coin spent: more pack slots, faster training or more luck" })
		UpgradeBox:AddDropdown("UpgradeKinds", {
			Text = "Upgrades (none = all)",
			Values = { "Ore Pack", "Train", "Luck" },
			Default = { "Ore Pack", "Train", "Luck" },
			Multi = true,
			AllowNull = true,
		})
		Labels.Upgrades = UpgradeBox:AddLabel({ Text = "-", DoesWrap = true })
		local RebirthBox = Tabs.Upgrades:AddRightGroupbox("Rebirth", "refresh-cw")
		RebirthBox:AddToggle("AutoRebirth", {
			Text = "Auto Rebirth",
			Default = false,
			Tooltip = "Rebirths as soon as your level allows it. Each rebirth multiplies training and coins and opens better areas",
		})
		Labels.Rebirth = RebirthBox:AddLabel({ Text = "-", DoesWrap = true })
		local EnhanceBox = Tabs.Upgrades:AddLeftGroupbox("Gear Enhance", "hammer")
		EnhanceBox:AddToggle("AutoEnhance", {
			Text = "Auto Enhance Equipped Gear",
			Default = false,
			Tooltip = "Enhances your equipped weapon and hat when a try is worth its coins (training gained x success chance). Opens at rebirth 6",
		})
		EnhanceBox:AddSlider("EnhanceMax", {
			Text = "Enhance Up To",
			Default = 20,
			Min = 1,
			Max = 20,
			Rounding = 0,
			Prefix = "+",
			Tooltip = "Only a ceiling: a try is bought when its chance x the training it adds beats every other use of the coins. From +6 a failed try can lower the item, Protection Scrolls are used then",
		})
		Labels.Enhance = EnhanceBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local RewardBox = Tabs.Rewards:AddLeftGroupbox("Rewards", "gift")
		RewardBox:AddToggle("AutoOnline", { Text = "Claim Online Gifts", Default = false })
		do
			local FPlayers = game:GetService("Players")
			local FTeleport = game:GetService("TeleportService")
			local F = { on = false, asked = {}, friend = {}, sent = 0, lastSend = -1e9, lastLog = "", lastLogAt = -1e9 }
			local function friendBoost()
				local v = LocalPlayer:GetAttribute("FriendNumber")
				if type(v) == "number" then return "+" .. math.floor(v * 10 + 0.5) .. "%" end
				return "?"
			end
			local function isFriend(p)
				if F.friend[p.UserId] then return true, true end
				local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
				if ok and res then F.friend[p.UserId] = true end
				return ok and res, ok
			end
			local function friendPump()
				if not F.on then return end
				for _, p in ipairs(FPlayers:GetPlayers()) do
					if p ~= LocalPlayer and not F.asked[p.UserId] and not F.friend[p.UserId] then
						local yes, ok = isFriend(p)
						if ok and not yes then
							if os.clock() - F.lastSend < 10 then return end
							F.asked[p.UserId] = true
							F.lastSend = os.clock()
							if pcall(function() LocalPlayer:RequestFriendship(p) end) then F.sent += 1 end
							return
						end
					end
				end
			end
			local function friendLog()
				local n = 0
				for _, p in ipairs(FPlayers:GetPlayers()) do
					if p ~= LocalPlayer and isFriend(p) then n += 1 end
				end
				local boost = friendBoost()
				local key = F.sent .. "/" .. n .. "/" .. tostring(boost)
				if key ~= F.lastLog and os.clock() - F.lastLogAt >= 60 then
					F.lastLog = key
					F.lastLogAt = os.clock()
					log("FRIEND sent=" .. F.sent .. " friends=" .. n .. " boost=" .. tostring(boost))
				end
			end
			pcall(function()
				Library:GiveSignal(FPlayers.PlayerAdded:Connect(function()
					task.delay(2, function() pcall(friendPump) end)
				end))
			end)
			task.spawn(function()
				local beat = 0
				while alive() do
					task.wait(10)
					beat += 1
					pcall(friendPump)
					if beat % 6 == 0 then pcall(friendLog) end
				end
			end)
			local function joinFriend()
				local ok, list = pcall(function() return LocalPlayer:GetFriendsOnline(200) end)
				if not ok or type(list) ~= "table" then
					log("FRIEND join unsupported")
					notify("Friends", "Joining a friend is not supported by this executor", 4)
					return
				end
				for _, f in ipairs(list) do
					local place, job = f.PlaceId, f.GameId
					if place and job and job ~= game.JobId and (place == game.PlaceId or f.UniverseId == game.GameId) then
						log("FRIEND join " .. tostring(f.UserName or f.DisplayName or f.VisitorId))
						notify("Friends", "Joining " .. tostring(f.UserName or "a friend"), 4)
						if not pcall(function() FTeleport:TeleportToPlaceInstance(place, job, LocalPlayer) end) then
							log("FRIEND join unsupported")
						end
						return
					end
				end
				log("FRIEND join none")
				notify("Friends", "No friend is online in this game's other servers", 4)
			end
			local FriendBox = Tabs.Rewards:AddRightGroupbox("Friends", "users")
			FriendBox:AddToggle("AutoFriend", {
				Text = "Auto Friend",
				Tooltip = "Every friend in the server gives +10%. Sends one friend request per 10 s to everyone in the server, once each",
				Default = false,
				Callback = function(v)
					F.on = v == true
				end,
			})
			FriendBox:AddButton({
				Text = "Join Friend's Server",
				Func = function()
					task.spawn(joinFriend)
				end,
			})
		end
		RewardBox:AddToggle("AutoOffline", { Text = "Claim Offline Reward", Default = false })
		RewardBox:AddToggle("AutoIndex", { Text = "Claim Index EXP And Levels", Default = false })
		RewardBox:AddToggle("AutoSeason", { Text = "Claim Season Rewards", Default = false, Tooltip = "Season pass rewards you reached and the daily season ticket" })
		RewardBox:AddToggle("AutoTowerTicket", { Text = "Claim Daily Tower Ticket", Default = false })
		RewardBox:AddToggle("AutoQuests", { Text = "Claim Event Quests", Default = false })
		RewardBox:AddToggle("AutoUpdateRewards", { Text = "Claim Update And Group Gifts", Default = false, Tooltip = "Update log gifts, and the group gift once you are in the game's group" })
		Labels.Rewards = RewardBox:AddLabel({ Text = "-", DoesWrap = true })
		local SeasonBox = Tabs.Rewards:AddRightGroupbox("Season", "ticket")
		SeasonBox:AddToggle("AutoSeasonLuck", { Text = "Spin Season Luck", Default = false, Tooltip = "Spends the Season Tickets from the daily claim and the pass on the Season Luck wheel (stones, class rolls, scrolls, Season Coins, a weapon). Never spins without tickets, so it never opens a Robux prompt" })
		SeasonBox:AddToggle("AutoSeasonShop", { Text = "Spend Season Coins", Default = false, Tooltip = "Prices every Season Shop item in coins and buys the best value per Season Coin, saving for it when needed" })
		Labels.Season = SeasonBox:AddLabel({ Text = "-", DoesWrap = true })
		local CodeBox = Tabs.Rewards:AddLeftGroupbox("Codes", "ticket")
		CodeBox:AddToggle("AutoCodes", {
			Text = "Redeem Known Codes",
			Default = false,
			Tooltip = "Fetches the list of known codes at start and every 6 hours and redeems each one once per account",
		})
		Labels.Codes = CodeBox:AddLabel({ Text = "-", DoesWrap = true })
		CodeBox:AddInput("CodeText", { Text = "Code", Placeholder = "Type a code from the game's socials", Finished = false, Default = "" })
		CodeBox:AddButton({
			Text = "Redeem",
			Func = function()
				N.redeemCode(Options.CodeText and Options.CodeText.Value)
			end,
		})
	end
	do
		local PotionBox = Tabs.Upgrades:AddRightGroupbox("Potions", "flask-conical")
		PotionBox:AddToggle("AutoPotions", { Text = "Auto Use Potions", Default = false, Tooltip = "Keeps one potion of each picked kind running while you have them" })
		PotionBox:AddDropdown("PotionKinds", {
			Text = "Potion Kinds",
			Values = { "Train", "Coin", "Luck", "Damage", "HP" },
			Default = { "Train", "Coin", "Luck", "Damage", "HP" },
			Multi = true,
			AllowNull = true,
		})
		local ClassBox = Tabs.Upgrades:AddLeftGroupbox("Class Rolls", "wand-sparkles")
		ClassBox:AddToggle("AutoClassRoll", {
			Text = "Auto Class Roll",
			Default = false,
			Tooltip = "Rerolls your equipped class slot with the rolls you have until it reaches the target. Locked slots are skipped",
		})
		ClassBox:AddDropdown("ClassTarget", {
			Text = "Stop At",
			Values = { "Auto (expected value)", "Rare", "Epic", "Legendary", "Mythic" },
			Default = "Auto (expected value)",
			Tooltip = "Auto keeps rolling only while your class is worth less than what the rolls left are expected to reach",
		})
		Labels.Class = ClassBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local PowerBox = Tabs.Farm:AddRightGroupbox("Player", "shield-plus")
		PowerBox:AddToggle("GodMode", { Text = "God Mode", Default = false, Tooltip = "Your HP becomes a trillion and stays full, nothing can kill you, so ores are never lost" })
		PowerBox:AddToggle("Untouchable", { Text = "Untouchable", Default = false, Tooltip = "Enemy attacks never hit you at all (stages, the tower and the world boss)" })
		local MoveBox = Tabs.Farm:AddRightGroupbox("Movement", "footprints")
		MoveBox:AddToggle("SpeedHack", { Text = "Walk Speed Boost", Default = false })
		MoveBox:AddSlider("WalkSpeed", { Text = "Speed", Default = 60, Min = 16, Max = 250, Rounding = 0 })
	end
end
N.StatRows = {}
do
	local function statRow(box, icon, text, size, color)
		if box.AddStat then
			local ok, stat = pcall(box.AddStat, box, { Icon = icon, Text = text, Value = "-", Size = size or 22, ValueColor = color })
			if ok and stat then
				return {
					set = function(value)
						stat:SetValue(value)
					end,
				}
			end
		end
		local label = box:AddLabel({ Text = text .. ": -", DoesWrap = true })
		return {
			set = function(value)
				label:SetText(text .. ": " .. tostring(value))
			end,
		}
	end
	local ProgressBox = Tabs.Stats:AddLeftGroupbox("Progress", "trending-up")
	N.StatRows.Power = statRow(ProgressBox, "zap", "Power", 28)
	N.StatRows.PowerGain = statRow(ProgressBox, "trending-up", "Power gained", 22, "FontColor")
	N.StatRows.Level = statRow(ProgressBox, "chevrons-up", "Level", 22)
	N.StatRows.Rebirth = statRow(ProgressBox, "refresh-cw", "Rebirth", 22)
	N.StatRows.Coins = statRow(ProgressBox, "coins", "Coins", 22, "FontColor")
	N.StatRows.Time = statRow(ProgressBox, "clock", "Session", 22, "FontColor")
	local FarmStats = Tabs.Stats:AddRightGroupbox("Farming", "swords")
	N.StatRows.Runs = statRow(FarmStats, "swords", "Runs / stages cleared", 28)
	N.StatRows.Kills = statRow(FarmStats, "skull", "Enemies killed", 22, "FontColor")
	N.StatRows.Ores = statRow(FarmStats, "gem", "Ores picked", 22)
	N.StatRows.OreRate = statRow(FarmStats, "activity", "Ores per hour", 22, "FontColor")
	N.StatRows.Banks = statRow(FarmStats, "archive", "Banked / lost runs", 22)
	N.StatRows.Forged = statRow(FarmStats, "hammer", "Forged / best", 22)
	N.StatRows.Gear = statRow(FarmStats, "shield", "Equips / sold", 22)
	N.StatRows.Events = statRow(FarmStats, "castle", "Tower runs / boss fights", 22)
	N.StatRows.Claims = statRow(FarmStats, "gift", "Rewards claimed", 22)
	N.StatRows.Extras = statRow(FarmStats, "sparkles", "Super kills / enhances / spins", 22)
	function N.drawStats()
		local elapsed = math.max(os.clock() - Session.started, 1)
		local hours = elapsed / 3600
		N.StatRows.Power.set(formatNumber(N.power()))
		N.StatRows.PowerGain.set("+" .. formatNumber(math.max(N.power() - Session.powerStart, 0)))
		N.StatRows.Level.set(string.format("%d (+%d)", N.level(), math.max(N.level() - Session.levelStart, 0)))
		N.StatRows.Rebirth.set(string.format("%d (+%d)", N.rebirth(), math.max(N.rebirth() - Session.rebirthStart, 0)))
		N.StatRows.Coins.set(formatNumber(N.coin()))
		N.StatRows.Time.set(string.format("%dh %02dm", elapsed // 3600, (elapsed % 3600) // 60))
		N.StatRows.Runs.set(formatNumber(Session.runs) .. " / " .. formatNumber(Session.stages))
		N.StatRows.Kills.set(formatNumber(Session.kills))
		N.StatRows.Ores.set(formatNumber(Session.ores))
		N.StatRows.OreRate.set(formatNumber(math.floor(Session.ores / hours)))
		N.StatRows.Banks.set(formatNumber(Session.banks) .. " / " .. formatNumber(Session.lostRuns))
		N.StatRows.Forged.set(formatNumber(Session.forged) .. " / " .. (Session.bestForge or "none"))
		N.StatRows.Gear.set(formatNumber(Session.equips) .. " / " .. formatNumber(Session.sold))
		N.StatRows.Events.set(formatNumber(Session.towerRuns) .. " / " .. formatNumber(Session.bossFights))
		N.StatRows.Claims.set(formatNumber(Session.claims))
		N.StatRows.Extras.set(formatNumber(Session.superKills) .. " / " .. formatNumber(Session.enhances) .. " / " .. formatNumber(Session.seasonSpins))
	end
end
local Debug = {}
do
	function Debug.perfText()
		local last = Perf.last
		if not last then
			return "no sample yet"
		end
		return string.format(
			"fps %d, worst frame %dms, hitches %d, freezes %d, Lymn used %dms in %ds (%.2f%%), ping %sms, memory %sMB",
			math.floor(last.fps + 0.5),
			math.floor(last.worst * 1000),
			last.hitches,
			last.freezes,
			math.floor(last.hub * 1000),
			math.floor(last.span),
			last.hub / math.max(last.span, 1) * 100,
			tostring(last.ping),
			tostring(last.memory)
		)
	end
	function Debug.running()
		local running = {}
		for name, toggle in pairs(Toggles) do
			if type(toggle) == "table" and toggle.Value == true and string.sub(name, 1, 4) == "Auto" then
				table.insert(running, name)
			end
		end
		table.sort(running)
		return running
	end
	function Debug.header()
		local elapsed = math.floor(os.clock() - Session.started)
		local executor = "?"
		pcall(function()
			executor = table.concat({ identifyexecutor() }, " ")
		end)
		local packNow, packMax = N.pack()
		local hp, maxHp = N.hp()
		local lines = {
			"Lymn debug log  |  " .. GameName,
			string.format(
				"Player %s (@%s)  |  executor %s  |  place %s  |  %s",
				LocalPlayer.DisplayName,
				LocalPlayer.Name,
				executor,
				tostring(game.PlaceId),
				os.date("%Y-%m-%d %H:%M:%S")
			),
			string.format(
				"Session %dh %02dm  |  runs %d  |  stages %d  |  kills %d  |  ores %d  |  banks %d  |  deaths %d (lost runs %d)  |  forged %d  |  equips %d  |  sold %d  |  upgrades %d  |  rebirths %d  |  tower %d  |  boss %d  |  super %d  |  enhance %d  |  spins %d  |  shop %d",
				elapsed // 3600,
				(elapsed % 3600) // 60,
				Session.runs,
				Session.stages,
				Session.kills,
				Session.ores,
				Session.banks,
				Session.deaths,
				Session.lostRuns,
				Session.forged,
				Session.equips,
				Session.sold,
				Session.upgrades,
				Session.rebirths,
				Session.towerRuns,
				Session.bossFights,
				Session.superKills,
				Session.enhances,
				Session.seasonSpins,
				Session.shopBuys
			),
			"Status: " .. tostring(Status),
			"Running: " .. table.concat(Debug.running(), ", "),
			string.format(
				"Game: power %s, level %d, rebirth %d, coins %s, stage target %d, fight %s, stage %d, pack %d/%d, hp %d/%d, ores %d, tickets %d, data pushes %d",
				formatNumber(N.power()),
				N.level(),
				N.rebirth(),
				formatNumber(N.coin()),
				N.stageTarget(),
				tostring(N.fightMode()),
				N.Fight.stage,
				packNow,
				packMax,
				math.floor(hp),
				math.floor(maxHp),
				N.oreTotal(),
				N.towerTickets(),
				N.Store.pushes
			),
			"Perf: " .. Debug.perfText(),
			(function()
				local Pl = N.Plan
				if not Pl then
					return "Plan: -"
				end
				return string.format(
					"Plan: %s | %s | coins/s %s, exp unit %s, clear %ss, pick %ss, run fit %s (%d runs), farm share %d%%",
					Pl.text ~= "" and Pl.text or "-",
					Pl.spendText ~= "" and Pl.spendText or "-",
					formatNumber(Pl.coin.rate or 0),
					formatNumber(Pl.exp.unit or 0),
					string.format("%.1f", Pl.clearSec or 0),
					string.format("%.2f", Pl.pickSec or 0),
					string.format("%.2f", Pl.runFit or 0),
					Pl.runs,
					math.floor(N.farmShare() * 100)
				)
			end)(),
			"Problems (" .. Log.problemCount .. "): " .. (if #Log.problems > 0 then table.concat(Log.problems, " | ") else "none"),
			string.rep("-", 70),
		}
		return table.concat(lines, "\n")
	end
	Log.header = Debug.header
end
N.AllAutoToggles = {
	"SmartPlanner",
	"KillAura",
	"GodMode",
	"Untouchable",
	"SpeedHack",
	"AutoStages",
	"AutoTrain",
	"AutoForge",
	"AutoSellGear",
	"AutoUpgrade",
	"AutoRebirth",
	"AutoTower",
	"AutoWorldBoss",
	"AutoSuperLoot",
	"AutoEnhance",
	"AutoPotions",
	"AutoClassRoll",
}
do
	function N.manualRunning()
		return N.Manual.running
	end
	function N.runManual(fn, ...)
		if N.Manual.running then
			notify("Lymn", "Still busy with the last action", 3)
			return
		end
		N.Manual.running = true
		local ok, err = pcall(fn, ...)
		N.Manual.running = false
		if not ok then
			log("ERROR", "manual action", tostring(err))
		end
	end
	function N.stopAll()
		for _, list in ipairs({ N.AllAutoToggles, N.AllAutoToggles2 or {} }) do
			for _, name in ipairs(list) do
				local toggle = Toggles[name]
				if toggle and toggle.Value then
					toggle:SetValue(false)
				end
			end
		end
		notify("Lymn", "Everything is off", 3)
	end
end
do
	local KeepOnTeleport = false
	local function queueSelf()
		local queue = queue_on_teleport or (typeof(syn) == "table" and syn.queue_on_teleport) or queueonteleport
		if type(queue) ~= "function" or INSTANCE.queued then
			return INSTANCE.queued == true
		end
		INSTANCE.queued = pcall(
			queue,
			table.concat({
				"if not game:IsLoaded() then game.Loaded:Wait() end",
				"if game.GameId ~= " .. tostring(game.GameId) .. " then return end",
				LoaderScript,
			}, "\n")
		)
		return INSTANCE.queued
	end
	if false then
		pcall(function()
			local ExecBox = Tabs.Misc:AddRightGroupbox("Auto Execute", "zap")
			ExecBox:AddToggle("KeepOnTeleport", {
				Text = "Keep after teleport",
				Default = false,
				Tooltip = "When the game moves you to another server the hub starts again there",
				Callback = function(value)
					KeepOnTeleport = value
				end,
			})
			ExecBox:AddButton({
				Text = "Copy loader",
				Func = function()
					local copied = setclipboard and pcall(setclipboard, LoaderScript)
					notify("Loader", if copied then "Copied, put it in your executor's autoexec folder to start the hub on join" else LoaderScript, 6)
				end,
			})
			Library:GiveSignal(LocalPlayer.OnTeleport:Connect(function(state)
				if state == Enum.TeleportState.Started and KeepOnTeleport then
					queueSelf()
				end
			end))
		end)
	end
end
do
	local FeedbackWebhook = ""
	local Hook = { queue = {}, sent = 0, feedbackAt = -1e9, feedbackCount = 0 }
	local function httpRequest(options)
		local fn = (typeof(syn) == "table" and syn.request) or (typeof(http) == "table" and http.request) or http_request or request
		if type(fn) ~= "function" then
			return nil
		end
		local ok, response = pcall(fn, options)
		return if ok then response else nil
	end
	local function validWebhook(url)
		return type(url) == "string"
			and (
					url:find("^https://discord%.com/api/webhooks/")
					or url:find("^https://discordapp%.com/api/webhooks/")
					or url:find("^https://canary%.discord%.com/api/webhooks/")
					or url:find("^https://ptb%.discord%.com/api/webhooks/")
				)
				~= nil
	end
	local function postWebhook(url, payload)
		if not validWebhook(url) then
			return false, 0
		end
		local response = httpRequest({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
		local code = response and tonumber(response.StatusCode) or 0
		return code >= 200 and code < 300, code
	end
	local GameLink = "https://www.roblox.com/games/" .. tostring(game.PlaceId)
	local function gameField()
		return { name = "Game", value = "[" .. GameName .. "](" .. GameLink .. ")", inline = true }
	end
	local function playerField()
		if Toggles.WebhookHideName and Toggles.WebhookHideName.Value then
			return "Hidden"
		end
		return "||" .. LocalPlayer.Name .. "||"
	end
	local function queueEmbed(embed)
		if #Hook.queue < 30 then
			embed.footer = embed.footer or { text = "Lymn  \u{00B7}  " .. GameName }
			embed.timestamp = embed.timestamp or DateTime.now():ToIsoDate()
			table.insert(Hook.queue, embed)
		end
	end
	local function hookOn()
		return Toggles.WebhookOn and Toggles.WebhookOn.Value
	end
	local function colorOf(hex)
		local ok, color = pcall(Color3.fromHex, hex)
		if not ok then
			return 16762930
		end
		return math.floor(color.R * 255) * 65536 + math.floor(color.G * 255) * 256 + math.floor(color.B * 255)
	end
		local function reportEmbed(title)
			local elapsed = math.max(os.clock() - Session.started, 60)
			return {
				title = title,
				color = 6344854,
				fields = {
					{ name = "Power", value = formatNumber(N.power()), inline = true },
					{ name = "Level", value = tostring(N.level()), inline = true },
					{ name = "Rebirth", value = tostring(N.rebirth()), inline = true },
					{ name = "Coins", value = formatNumber(N.coin()), inline = true },
					{ name = "Best stage", value = tostring(Session.bestStage), inline = true },
					{ name = "Ores picked", value = formatNumber(Session.ores), inline = true },
					{ name = "Forged", value = formatNumber(Session.forged) .. (if Session.bestForge then " (best " .. Session.bestForge .. ")" else ""), inline = true },
					{ name = "Session", value = string.format("%dh %02dm", elapsed // 3600, (elapsed % 3600) // 60), inline = true },
					{ name = "Player", value = playerField(), inline = true },
				},
			}
		end
		N.Events.forged = function(rarity, name)
			if hookOn() and N.rarityRank(rarity) >= N.rarityRank(optionText("WebhookForgeRarity", "Legendary")) then
				queueEmbed({
					title = "\u{2726}  Forged " .. rarity .. " " .. name,
					description = string.format("Forge number **%d** this session.", Session.forged),
					color = colorOf(N.rarityColor(rarity)),
					fields = {
						{ name = "Power", value = formatNumber(N.power()), inline = true },
						{ name = "Player", value = playerField(), inline = true },
					},
				})
			end
		end
		N.Events.rebirth = function(level)
			if hookOn() and on("WebhookRebirths") then
				queueEmbed({
					title = "\u{2726}  Rebirth " .. tostring(level),
					description = "Training and coin multipliers went up.",
					color = 16762930,
					fields = { { name = "Player", value = playerField(), inline = true } },
				})
			end
		end
		N.Events.upgraded = function(name, level, price)
			if hookOn() and on("WebhookUpgrades") then
				queueEmbed({
					title = "\u{2726}  " .. name .. " upgraded to level " .. tostring(level),
					description = "Paid **" .. formatNumber(price) .. "** coins.",
					color = 8454016,
					fields = { { name = "Player", value = playerField(), inline = true } },
				})
			end
		end
		N.Events.lostRun = function(stage)
			if hookOn() and on("WebhookDeaths") then
				queueEmbed({
					title = "\u{2726}  Died on stage " .. tostring(stage),
					description = "The ores in the pack were lost. Lymn lowers the stage for a while.",
					color = 16739978,
					fields = { { name = "Player", value = playerField(), inline = true } },
				})
			end
		end
	task.spawn(function()
		local lastReport = os.clock()
		while alive() do
			task.wait(2.5)
			pcall(function()
				local url = Options.WebhookUrl and Options.WebhookUrl.Value
				local enabled = hookOn() and validWebhook(url)
				local every = (Options.WebhookReport and Options.WebhookReport.Value or 0) * 60
				if enabled and every > 0 and os.clock() - lastReport >= every then
					lastReport = os.clock()
					queueEmbed(reportEmbed("\u{2726}  Farm report"))
				end
				if not enabled then
					table.clear(Hook.queue)
					return
				end
				local embed = table.remove(Hook.queue, 1)
				if embed then
					embed.author = { name = GameName }
					if postWebhook(url, { username = "Lymn", allowed_mentions = { parse = {} }, embeds = { embed } }) then
						Hook.sent += 1
					end
				end
			end)
		end
	end)
	local function sendFeedback(kind, text, anonymous)
		if FeedbackWebhook == "" then
			notify("Feedback", "Send it on our Discord: " .. Discord, 6)
			return
		end
		if os.clock() - Hook.feedbackAt < 90 then
			notify("Feedback", "Please wait " .. math.ceil(90 - (os.clock() - Hook.feedbackAt)) .. "s before sending again", 4)
			return
		end
		if Hook.feedbackCount >= 6 then
			notify("Feedback", "You sent 6 messages this session, thanks! Use our Discord for more", 5)
			return
		end
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if #text < 8 then
			notify("Feedback", "Write at least a few words", 4)
			return
		end
		text = text:sub(1, 1000):gsub("@", "@\u{200B}")
		Hook.feedbackAt = os.clock()
		Hook.feedbackCount += 1
		notify("Feedback", "Sending...", 2)
		task.spawn(function()
			local executor = "Unknown"
			pcall(function()
				executor = table.concat({ identifyexecutor() }, " ")
			end)
			local colors = { Idea = 7995310, Bug = 16739978, Question = 6275327, Other = 14146792 }
			pcall(Library.PostFeedback, kind, text, anonymous, executor)
			local ok = postWebhook(FeedbackWebhook, {
				username = "Lymn Feedback",
				allowed_mentions = { parse = {} },
				embeds = {
					{
						author = { name = GameName, url = GameLink },
						title = "\u{2726}  " .. kind .. "  \u{00B7}  " .. GameName,
						description = text,
						color = colors[kind] or 14146792,
						fields = {
							{
								name = "From",
								value = if anonymous then "Anonymous" else string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name),
								inline = true,
							},
							gameField(),
							{ name = "Executor", value = executor, inline = true },
							{ name = "Status", value = tostring(Status):sub(1, 200), inline = false },
						},
						footer = { text = "Lymn feedback  \u{00B7}  " .. GameName },
						timestamp = DateTime.now():ToIsoDate(),
					},
				},
			})
			notify("Feedback", if ok then "Thanks! Lymn got your message." else "Could not send, try again later", 5)
		end)
	end
	pcall(function()
		local holder = Tabs.Misc or Tabs.Main
		local PerfBox = holder:AddLeftGroupbox("Performance", "gauge")
		Labels.Perf = PerfBox:AddLabel({ Text = "Measuring...", DoesWrap = true })
	end)
	if Tabs.Webhook then
		pcall(function()
			local HookBox = Tabs.Webhook:AddLeftGroupbox("Discord Webhook", "webhook")
				HookBox:AddToggle("WebhookOn", {
					Text = "Post to Discord",
					Default = false,
					Tooltip = "Posts rare forges, rebirths, upgrades, lost runs and a timed report to your own webhook",
				})
				HookBox:AddInput("WebhookUrl", { Text = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", Finished = true, Default = "" })
				HookBox:AddDropdown("WebhookForgeRarity", {
					Text = "Post forges from",
					Values = N.RarityOrder,
					Default = "Legendary",
				})
				HookBox:AddToggle("WebhookRebirths", { Text = "Rebirths", Default = true })
				HookBox:AddToggle("WebhookUpgrades", { Text = "Upgrades bought", Default = false })
				HookBox:AddToggle("WebhookDeaths", { Text = "Lost runs", Default = true })
			HookBox:AddSlider("WebhookReport", {
				Text = "Report every",
				Default = 30,
				Min = 0,
				Max = 180,
				Rounding = 0,
				Suffix = " min",
				HideMax = true,
				Tooltip = "0 turns the timed report off",
			})
			HookBox:AddToggle("WebhookHideName", { Text = "Hide my username", Default = false })
			HookBox:AddButton({
				Text = "Send test",
				Func = function()
					local url = Options.WebhookUrl and Options.WebhookUrl.Value
					if not validWebhook(url) then
						notify("Webhook", "Paste a Discord webhook URL first", 4)
						return
					end
					task.spawn(function()
						local embed = reportEmbed("\u{2726}  Test from Lymn")
						embed.author = { name = GameName }
						embed.footer = { text = "Lymn  \u{00B7}  " .. GameName }
						local ok, code = postWebhook(url, { username = "Lymn", allowed_mentions = { parse = {} }, embeds = { embed } })
						notify("Webhook", if ok then "Test sent" else "Discord answered " .. tostring(code), 4)
					end)
				end,
			})
		end)
	end
	if false then
		pcall(function()
			local StartBox = Tabs.Info:AddLeftGroupbox("Quick Start", "wand-sparkles")
			StartBox:AddLabel({
				Text = '<font transparency="0.4">Tell Lymn what to do in a few taps. Everything can be changed later.</font>',
				DoesWrap = true,
			})
			StartBox:AddButton({
				Text = "Open quick setup",
				Func = function()
					pcall(N.openWizard)
				end,
			})
			local FeedbackBox = Tabs.FeedbackBox or Tabs.Info:AddLeftGroupbox("Feedback", "message-square")
			FeedbackBox:AddDropdown("FeedbackType", { Text = "Type", Values = { "Idea", "Bug", "Question", "Other" }, Default = "Idea" })
			FeedbackBox:AddInput("FeedbackText", { Text = "Message", Placeholder = "Tell Lymn what to add or fix...", Finished = false, Default = "" })
			FeedbackBox:AddToggle("FeedbackAnon", { Text = "Send anonymously", Default = false })
			FeedbackBox:AddButton({
				Text = "Send feedback",
				Func = function()
					sendFeedback(Options.FeedbackType.Value, Options.FeedbackText.Value, Toggles.FeedbackAnon.Value)
					pcall(Options.FeedbackText.SetValue, Options.FeedbackText, "")
				end,
			})
		end)
	end
end
do
	-- Profit engine v2 (CLAUDE.md.txt 8.00). Every time option (training, a stage run at each depth, the tower, the
	-- world boss) and every money option (upgrades, gear enhance, forge choice, Season Shop, class rolls) is turned
	-- into one unit: coins of value, per second of time or per coin spent. Horizon H = 4 h: lump values are what
	-- they earn in the next 4 h, purchases must pay back within 24 h. Rebirth value only counts the
	-- farming that really follows it (the training share below), never 24 h of farming that never happens.
	-- Everything here runs only while "Smart Planner" (Main) is on; the manual toggles keep their own simple rules.
	--   coins:   income = ore sale price x the game's Coin boost (BalanceUtils.GetStatsBoost "Coin", rebirth CoinBasic
	--            inside), ore odds from Stage.Loots / Stage.OreLoots with the game's own luck rule (rows <= 1000
	--            weight get x luck x 1.3, Stage.Helper.GetRandRootID).
	--   rebirth: worth the extra coin boost on the farming that follows within the horizon, plus its tower tickets, plus a newly
	--            opened training area. Exp to the next rebirth = Level.GetTotalPower(need) - (level exp + Eco.power).
	--   training speed: x(1+g) on the exp rate gives ln(1+g)/ln(q) more rebirths in the horizon, where q is how much the
	--            next rebirth costs more than this one after its own exp boost (Level and Rebirth configs). Weapons,
	--            hats, Train upgrades, enhance levels, class rolls and Train potions are valued this way.
	-- Rates are measured live (moving averages): coins earned per second, exp per second while training, seconds
	-- per stage clear and per ore pick, the whole run against the model, tower and boss value per second. An option
	-- that was never measured is tried once ("explore") instead of being guessed.
	local P = {
		H = 14400,
		Payback = 86400, -- purchases must pay back within a day
		ShareWindow = 3600, -- the measured train/farm split forgets older time over about an hour
		target = 0.5, -- training share the planner aims for (recomputed every refresh)
		trainTurn = false,
		why = "",
		whyKey = "",
		whyAt = -1e9,
		Respawn = 30, -- the game respawns a cleared stage 30 s later (StageManager: RebirthTick = ServerTime + 30)
		at = -1e9,
		logAt = -1e9,
		lastKey = "",
		options = {},
		best = nil,
		stage = nil,
		text = "",
		spendText = "",
		spendKey = "",
		coin = { last = nil, window = 0, windowAt = nil, rate = nil, earned = 0 },
		exp = { last = nil, lastAt = nil, unit = nil },
		clearSec = nil,
		pickSec = nil,
		runFit = nil,
		runs = 0,
		act = {},
		share = { train = 0, farm = 0 },
		shareAt = nil,
		mode = nil,
		modeSnap = nil,
		forge = { at = -1e9, choice = nil, lift = 1 },
	}
	N.Plan = P
	local function ema(old, new, alpha)
		if old == nil then
			return new
		end
		return old + (alpha or 0.25) * (new - old)
	end
	local function num(value, default)
		value = tonumber(value)
		if value == nil or value ~= value or value == math.huge or value == -math.huge then
			return default
		end
		return value
	end
	P.ema = ema
	local function split(text)
		local out = {}
		for piece in string.gmatch(tostring(text or ""), "[^,]+") do
			table.insert(out, (string.gsub(piece, "^%s+", "")))
		end
		return out
	end
	-- Game multipliers -------------------------------------------------------------------------------------------
	function N.coinMult()
		local boost = num(N.call(N.G.Balance.GetStatsBoost, LocalPlayer, "Coin"), nil)
		if boost and boost > 0 then
			return boost
		end
		return num(N.call(N.G.Rebirth.GetCoinBasic, N.rebirth()), 1)
	end
	local function upgradeNumber(kind)
		local data = N.store("Upgrade")[kind]
		local level = tonumber(type(data) == "table" and data.Level) or 0
		local row = (N.G.Upgrade[kind] or {})[level]
		return num(type(row) == "table" and row.Number, 0)
	end
	N.upgradeNumber = upgradeNumber
	function N.luckMult()
		local boost = num(N.call(N.G.Balance.GetStatsBoost, LocalPlayer, "Luck"), nil)
		if boost and boost > 0 then
			return boost
		end
		return 1 + upgradeNumber("Luck")
	end
	local function expBasic(r)
		return num(N.call(N.G.Rebirth.GetExpBasic, r), 1)
	end
	local function coinBasic(r)
		return num(N.call(N.G.Rebirth.GetCoinBasic, r), 1)
	end
	local function totalExp(level)
		return num(N.call(N.G.Level.GetTotalPower, level), 0)
	end
	local function areaBasic(id)
		local row = N.G.TrainArea[id]
		return num(type(row) == "table" and row.Basic, 1)
	end
	local function bestAreaAt(rebirth)
		local best = 1
		for _, area in ipairs(N.trainAreas()) do
			if not area.pay and area.need <= rebirth and area.basic > best then
				best = area.basic
			end
		end
		return best
	end
	-- Ore odds per stage -----------------------------------------------------------------------------------------
	local LootCache = {}
	function N.lootOreEV(lootId)
		if LootCache[lootId] then
			return LootCache[lootId].price, LootCache[lootId].power, LootCache[lootId].ores
		end
		local row = N.G.OreLoots[lootId]
		if type(row) ~= "table" then
			return nil
		end
		local ids, chances = split(row.OreTab), split(row.Chance)
		local total, price, power, ores = 0, 0, 0, {}
		for i, id in ipairs(ids) do
			local c = num(chances[i], 0)
			if c > 0 then
				total += c
				price += c * num(N.call(N.G.Ore.GetSellPrice, id), 0)
				power += c * num(N.call(N.G.Ore.GetPower, id), 0)
				ores[id] = c
			end
		end
		if total <= 0 then
			return nil
		end
		LootCache[lootId] = { price = price / total, power = power / total, ores = ores }
		return price / total, power / total, ores
	end
	-- Expected sale price of one ore from stage d (before the Coin boost), ores per clear, and the ore mix of the
	-- loot row that drops most often (used to price what the forge makes from this stage).
	function N.stageOreEV(d, luck)
		local row = N.G.StageLoots["Stage_" .. tostring(d)]
		if type(row) ~= "table" or row.LootTab == nil then
			return nil
		end
		luck = luck or N.luckMult()
		local loots, chances = split(row.LootTab), split(row.Chance)
		local total, sum, mainW, main = 0, 0, -1, nil
		for i, lootId in ipairs(loots) do
			local w = num(chances[i], 0)
			if w > 0 then
				local raw = w
				if w <= 1000 then
					w = w * luck * 1.3
				end
				local price, _, ores = N.lootOreEV(lootId)
				if price then
					total += w
					sum += w * price
					if raw > mainW then
						mainW, main = raw, ores
					end
				end
			end
		end
		if total <= 0 then
			return nil
		end
		return sum / total, num(row.LootNumber, 6), main
	end
	-- Live measurements -------------------------------------------------------------------------------------------
	function N.planNoteClear(seconds)
		if seconds and seconds > 0 and seconds < 120 then
			P.clearSec = ema(P.clearSec, seconds, 0.2)
		end
	end
	function N.planNotePick(seconds)
		if seconds and seconds > 0 and seconds < 20 then
			P.pickSec = ema(P.pickSec, seconds, 0.2)
		end
	end
	-- Seconds for one run to stage d with a pack of cap: clear stages 1..d, then clear d again after each 30 s
	-- respawn until the pack is full, plus every pick. The measured runs scale the model (runFit).
	function N.runModel(d, cap)
		if not P.clearSec or not P.pickSec then
			return nil
		end
		local _, perClear = N.stageOreEV(d)
		perClear = math.max(perClear or 6, 1)
		local clears = math.ceil(cap / perClear)
		return d * P.clearSec + (clears - 1) * (P.Respawn + P.clearSec) + cap * P.pickSec
	end
	function N.planNoteRun(d, seconds, ores)
		local _, cap = N.pack()
		local model = N.runModel(d, math.max(ores or cap, 1))
		if model and seconds and seconds > 0 and (ores or 0) > 0 then
			P.runFit = ema(P.runFit, math.clamp(seconds / model, 0.3, 5), 0.3)
			P.runs += 1
		end
	end
	-- Coins earned per second (spending is not income), exp per second while training, and the time split.
	local function sample()
		local now = os.clock()
		local coin = N.coin()
		local C = P.coin
		C.windowAt = C.windowAt or now
		if C.last and coin > C.last then
			C.window += coin - C.last
			C.earned += coin - C.last
		end
		C.last = coin
		local area = tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID"))
		local mode = N.fightMode()
		local raw = if P.shareAt then math.clamp(now - P.shareAt, 0, 60) else 0
		local dt = math.min(raw, 5)
		P.shareAt = now
		-- The split forgets old time (about an hour), so the planner steers the share it is producing now.
		local keep = math.max(1 - dt / P.ShareWindow, 0)
		P.share.farm *= keep
		P.share.train *= keep
		if mode == "Stage" then
			P.share.farm += dt
			C.farmSecs = (C.farmSecs or 0) + raw
		elseif mode == nil and area then
			P.share.train += dt
		else
			C.farmSecs = (C.farmSecs or 0) + raw -- walking, banking, forging: part of the farm loop
		end
		if now - C.windowAt >= 60 then
			-- Coins per second of FARMING (training seconds are not counted): the same unit on both sides of the
			-- train/farm choice. A window with almost no farming keeps the last measurement.
			local farmed = C.farmSecs or 0
			if farmed >= 20 then
				C.rate = ema(C.rate, C.window / farmed, 0.3)
			elseif C.rate == nil and now - C.windowAt >= 60 and farmed > 0 then
				C.rate = C.window / farmed
			end
			C.farmSecs = 0
			C.window = 0
			C.windowAt = now
		end
		local E = P.exp
		local power = N.power()
		if mode == nil and area then
			if E.last and E.lastAt and power >= E.last and now - E.lastAt >= 5 then
				local rate = (power - E.last) / (now - E.lastAt)
				if rate > 0 then
					-- The area the server trains in (an accepted Blatant zone counts with its own multiplier).
					local basic = if N.trainEffectiveBasic then N.trainEffectiveBasic(areaBasic(area)) else areaBasic(area)
					E.unit = ema(E.unit, rate / (basic * expBasic(N.rebirth())), 0.3)
				end
				E.last, E.lastAt = power, now
			elseif not E.last or power < E.last then
				E.last, E.lastAt = power, now
			end
		else
			E.last, E.lastAt = nil, nil
		end
		-- Tower and world boss: value = coins earned + ore value gained during the visit, per second inside.
		if mode ~= P.mode then
			if P.modeSnap and (P.mode == "Dungeon" or P.mode == "WorldBoss") then
				local snap = P.modeSnap
				local secs = now - snap.at
				if secs > 3 then
					local value = (C.earned - snap.earned) + (N.oreValue() - snap.ores) * N.coinMult()
					-- Enhance stones the visit paid (tower floors drop them), priced by the enhance they unlock.
					for id, before in pairs(snap.stones or {}) do
						local gained = N.material(id) - before
						if gained > 0 then
							value += N.seasonGoodValue({ ID = id, Type = "Material", Number = gained }) or 0
						end
					end
					local key = if P.mode == "Dungeon" then "tower" else "boss"
					local A = P.act[key] or {}
					P.act[key] = A
					A.perSec = ema(A.perSec, math.max(value, 0) / secs, 0.3)
					A.perRun = ema(A.perRun, math.max(value, 0), 0.3)
					A.secs = ema(A.secs, secs, 0.3)
					A.n = (A.n or 0) + 1
					N.planLog("PLAN measured", key, "value", math.floor(value), "in", math.floor(secs), "s")
				end
			end
			P.modeSnap = if mode == "Dungeon" or mode == "WorldBoss" then { at = now, earned = C.earned, ores = N.oreValue(), stones = { EnhantStone_1 = N.material("EnhantStone_1"), EnhantStone_2 = N.material("EnhantStone_2") } } else nil
			P.mode = mode
		end
	end
	function N.oreValue()
		local total = 0
		for _, ore in ipairs(N.ores()) do
			total += ore.price * ore.number
		end
		return total
	end
	function N.farmShare()
		local s = P.share
		if s.farm + s.train <= 0 then
			return 0.5 -- nothing measured yet: no reason to favour either
		end
		return s.farm / (s.farm + s.train)
	end
	function N.coinIncome()
		-- Measured while farming (a measured zero counts: a rebirth boosts nothing when nothing is earned, otherwise
		-- the planner trains for ever on income it never collects).
		if P.coin.rate then
			return math.max(P.coin.rate, 0)
		end
		-- Before the first minute: what the best stage run would earn.
		local best = 0
		for _, o in ipairs(P.options) do
			if o.kind == "farm" and o.gain and o.gain < math.huge then
				best = math.max(best, o.gain)
			end
		end
		return best
	end
	-- Training ---------------------------------------------------------------------------------------------------
	-- Exp per second in the best open area: measured (per area x rebirth multiplier) or the game's formula
	-- (CalculateUtils.CCTrainOncePower, one train every 0.2 s, crits x1.5).
	function N.expRate()
		local area = N.bestTrainArea()
		local basic = if area then area.basic else 1
		if N.trainEffectiveBasic then
			basic = N.trainEffectiveBasic(basic)
		end
		if P.exp.unit then
			return P.exp.unit * basic * expBasic(N.rebirth())
		end
		-- Not measured yet: the game's formula at the measured Blatant click speed (0.2 s = the game's own).
		local cadence = N.trainCadence and N.blatant("TrainSpeed") and N.trainCadence() or nil
		local clicks = if cadence and cadence > 0 then 1 / cadence else 5
		local once = num(N.call(N.G.Calc.CCTrainOncePower, LocalPlayer), nil)
		if not once or once <= 0 then
			return nil
		end
		local inArea = tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID"))
		if inArea then
			once = once / areaBasic(inArea)
		end
		local crit = math.clamp(num(N.call(N.G.Calc.CCCrit, LocalPlayer), 0), 0, 1)
		return once * basic * clicks * (1 + 0.5 * crit)
	end
	-- Exp left to the next rebirth and the cost growth q between this rebirth and the next one.
	-- Cached for one second: the forge pricing asks for it once per possible item.
	local MathCache = { at = -1e9, key = nil, value = nil }
	function N.rebirthMath()
		local key = tostring(N.rebirth()) .. ":" .. tostring(N.level()) .. ":" .. tostring(N.eco("power"))
		if MathCache.key == key and os.clock() - MathCache.at < 1 then
			return MathCache.value
		end
		local value = N.rebirthMathNow()
		MathCache.at, MathCache.key, MathCache.value = os.clock(), key, value
		return value
	end
	function N.rebirthMathNow()
		local r = N.rebirth()
		local need1 = tonumber(N.call(N.G.Rebirth.GetNeedLevel, r + 1))
		if not need1 then
			return nil
		end
		local need2 = tonumber(N.call(N.G.Rebirth.GetNeedLevel, r + 2))
		local cost1 = totalExp(need1)
		local left = math.max(cost1 - N.power(), 0)
		local q = 2
		if need2 then
			local cost2 = totalExp(need2)
			local speedUp = expBasic(r + 2) / math.max(expBasic(r + 1), 1e-9) * bestAreaAt(r + 1) / math.max(bestAreaAt(r), 1e-9)
			q = (cost2 / math.max(cost1, 1)) / math.max(speedUp, 1e-9)
		end
		return { need = need1, cost = cost1, left = left, q = math.max(q, 1.01) }
	end
	-- Coin boost of the next rebirth (+20 % at rebirth 0 shrinks to +2 % at rebirth 10: 0.2 / (1 + 0.2 r)).
	function N.rebirthBoost()
		local r = N.rebirth()
		return coinBasic(r + 1) / math.max(coinBasic(r), 1e-9) - 1
	end
	-- Coin value of the next rebirth within the horizon: the boost on the coins of the FARMING that really
	-- follows (horizon x the planned farm share), not on 24 h of farming the hub would spend training.
	function N.rebirthValue(math_)
		math_ = math_ or N.rebirthMath()
		if not math_ then
			return 0
		end
		local r = N.rebirth()
		local coinUp = N.rebirthBoost()
		local base = coinUp * N.coinIncome() * P.H * (1 - math.clamp(P.target or 0.5, 0, 0.95))
		local tickets = num(N.call(N.G.Rebirth.GetDungeonTicket, r + 1), 0)
		local tower = P.act.tower
		if tickets > 0 and tower and tower.perRun then
			base += tickets * tower.perRun
		end
		local areaUp = bestAreaAt(r + 1) / math.max(bestAreaAt(r), 1e-9)
		local extra = if areaUp > 1 then math.log(areaUp) / math.log(math_.q) else 0
		return base / (1 - math.min(extra, 0.9))
	end
	-- Coin value within the horizon of training x(1+g) faster: ln(1+g)/ln(q) more rebirths, never more than g x the
	-- rebirths that fit in the planned training time (horizon x training share) at today's speed.
	function N.trainValue(g)
		if not g or g <= 0 then
			return 0
		end
		local m = N.rebirthMath()
		local rate = N.expRate()
		if not m or not rate or rate <= 0 then
			return 0
		end
		local perDay = P.H * math.clamp(P.target or 0.5, 0.05, 0.95) / math.max(m.cost / rate, 1)
		local more = math.min(math.log(1 + g) / math.log(m.q), g * perDay)
		return more * N.rebirthValue(m)
	end
	-- Stage runs -------------------------------------------------------------------------------------------------
	-- Coins per second of a run to stage d with a pack of cap (ore sale value x Coin boost x the forge lift).
	function N.farmValue(d, cap, luck)
		local ev = N.stageOreEV(d, luck)
		local seconds = N.runModel(d, cap)
		if not ev or not seconds then
			return nil
		end
		seconds *= P.runFit or 1
		return cap / math.max(seconds, 1) * ev * N.coinMult() * math.max(P.forge.lift or 1, 1), seconds
	end
	-- The deepest stage the power allows (old rule) is the upper bound, the planner picks the best value below it.
	function N.planStage(maxStage)
		local _, cap = N.pack()
		local best, bestGain = nil, -1
		for d = math.max(1, maxStage - 4), maxStage do
			local gain = N.farmValue(d, cap)
			if gain and gain > bestGain then
				best, bestGain = d, gain
			end
		end
		return best
	end
	-- Time options -----------------------------------------------------------------------------------------------
	local function fmt(x)
		if x == math.huge then
			return "explore"
		end
		return formatNumber(x)
	end
	-- Training share. Over the horizon H the coins earned are (1-s) x H x I x (1+u)^(s x H / T), with s the share of
	-- time spent training, I the measured coins per FARMING second, u the next rebirth's coin boost and T the
	-- seconds of training one rebirth takes at the measured exp rate. The best share is s* = 1 - T / (H ln(1+u)),
	-- 0 when that is negative. I cancels out: time is compared with time (measured exp rate against measured farm
	-- income), never a hypothetical 24 h rebirth value against a measured coin rate (the old 98 % training bug).
	-- The share is capped so the farming still earns the coins the next purchases need (those that pay back faster
	-- than the rebirth), and at 95 % so coins always come in. When no rebirth is left (or none is worth it),
	-- training only pays while it opens a deeper stage soon enough.
	local function trainPlan(farmGain)
		local m = N.rebirthMath()
		local rate = N.expRate()
		local r = N.rebirth()
		local shareNow = 1 - N.farmShare()
		if not rate or rate <= 0 then
			if m then
				return { target = 0.5, turn = true, gain = math.huge, why = "training once to measure the exp rate" }
			end
			return { target = 0, turn = false, gain = 0, why = "nothing to train for" }
		end
		if m and m.left <= 0 and N.want("AutoRebirth") then
			return { target = P.target, turn = true, gain = math.huge, eta = 0, why = "rebirth " .. (r + 1) .. " level reached, rebirthing" }
		end
		local target, why, eta = 0, nil, nil
		local farmI = if farmGain and farmGain < math.huge then farmGain else 0
		local income = math.max(N.coinIncome(), farmI)
		if m and m.left > 0 then 
			local u = N.rebirthBoost()
			-- Time this rebirth still needs (the live game keeps levels through a rebirth, so the total level cost would
			-- overstate it: log 2026-10-05 showed 59m for a rebirth that takes minutes).
			local T = math.max(m.left / rate, 1)
			eta = m.left / rate
			-- Tower tickets the rebirth gives are extra coins on top of the same farming.
			local tickets = num(N.call(N.G.Rebirth.GetDungeonTicket, r + 1), 0)
			local tower = P.act.tower
			if tickets > 0 and tower and tower.perRun and income > 0 then
				u += tickets * tower.perRun / (income * P.H * 0.5)
			end
			local k = P.H * math.log(1 + math.max(u, 0)) / T
			-- Blatant train-while-farming (probe train_keep, measured ratio c of the area exp/s): the exp per second is
			-- rate x (s + c(1-s)), so the best share becomes s* = 1 - 1 / (k (1 - c)).
			local keep = if N.trainKeepRatio then N.trainKeepRatio() else 0
			if keep > 0 then
				k *= 1 - keep
			end
			target = if k > 1 then 1 - 1 / k else 0
			local payback = T / math.max(u, 1e-9)
			local need = 0
			if N.want("AutoUpgrade") or N.want("AutoEnhance") then
				for _, o in ipairs(N.spendOptions()) do
					if o.cost / math.max(o.gain, 1e-12) < payback then
						need += o.price or o.cost
					end
				end
				need -= N.coin()
			end
			local cap = 0.95
			if need > 0 then
				cap = if income > 0 then math.clamp(1 - need / income / P.H, 0, 0.95) else 0
			end
			target = math.clamp(math.min(target, cap), 0, 0.95)
			-- Purchases that pay back faster than this rebirth come first: farm their coins now when that is quicker
			-- than the rebirth's own payback.
			if need > 0 and income > 0 and need / income < payback and target > 0 then
				return { target = target, turn = false, gain = 0, eta = eta, why = string.format("farming %s coins first for upgrades that pay back faster than rebirth %d (%s of farming)", formatNumber(need), r + 1, N.longTime(need / income)) }
			end
			why = string.format(
				"rebirth %d gives +%d%% coins for %s of training, paid back after %s of farming%s",
				r + 1,
				math.floor(u * 100 + 0.5),
				N.longTime(T),
				N.longTime(payback),
				if need > 0 and cap < 0.95 then ", " .. formatNumber(need) .. " coins needed for upgrades first" else ""
			)
		end
		if target <= 0 then
			-- No rebirth worth training for: training only pays while it opens the next stage soon enough.
			local cur = N.stageTargetByPower()
			local margin = math.clamp(optionNumber("StageMargin", 100), 10, 1000) / 100
			local _, cap = N.pack()
			for _, st in ipairs(N.stageList()) do
				if st.n == cur + 1 and N.pickText("StageMode", "Auto (by power)") == "Auto (by power)" then
					local need = st.recommend * margin - N.power()
					local a, b = N.farmValue(cur, cap), N.farmValue(cur + 1, cap)
					if need > 0 and a and b and b > a then
						local t = need / rate
						local payback = t * a / (b - a)
						if payback < P.H * 0.5 then
							return { target = 0, turn = true, depth = true, gain = 0, eta = t, why = string.format("training %s to open stage %d (worth %d%% more per run, paid back after %s)", N.longTime(t), st.n, math.floor((b / a - 1) * 100), N.longTime(payback)) }
						end
					end
				end
			end
			return { target = 0, turn = false, gain = 0, eta = eta, why = why or (if m then "no rebirth pays back within " .. N.longTime(P.H) else "max rebirth reached, every open stage is farmed") }
		end
		-- Hysteresis of 2 %: the turn changes after a stretch, not every refresh.
		local turn = P.trainTurn
		if turn and shareNow >= target + 0.02 then
			turn = false
		elseif not turn and shareNow < target - 0.02 then
			turn = true
		end
		return { target = target, turn = turn, gain = 0, eta = eta, why = string.format("%s; train %d%% of the time (now %d%%)", why, math.floor(target * 100 + 0.5), math.floor(shareNow * 100 + 0.5)) }
	end
	N.trainPlan = trainPlan
	function N.planOptions()
		local list = {}
		local maxStage = N.stageTargetByPower()
		local farmGain
		if N.want("AutoStages") then
			local _, cap = N.pack()
			local any = false
			for d = math.max(1, maxStage - 4), maxStage do
				local gain, seconds = N.farmValue(d, cap)
				if gain then
					any = true
					farmGain = math.max(farmGain or 0, gain)
					table.insert(list, { key = "farm" .. d, kind = "farm", stage = d, gain = gain, eta = seconds })
				end
			end
			if not any then
				farmGain = math.huge
				table.insert(list, { key = "farm" .. maxStage, kind = "farm", stage = maxStage, gain = math.huge, eta = nil })
			end
		end
		P.trainWhy = nil
		if N.want("AutoTrain") then
			local tp = trainPlan(farmGain)
			P.target = tp.target
			P.trainTurn = tp.turn
			P.trainWhy = tp.why
			local gain = tp.gain
			if gain ~= math.huge then
				-- Ranked right above or right below the best stage run by the time split (same unit on both sides).
				if farmGain and farmGain < math.huge then
					gain = if tp.turn then farmGain * 1.0001 + 1e-9 else farmGain * 0.9999
				elseif farmGain == nil then
					gain = if tp.turn then 1 else 0
				else
					gain = 0
				end
			end
			table.insert(list, { key = "train", kind = "train", gain = gain, eta = tp.eta, depth = tp.depth })
		end
		if N.want("AutoTower") and N.towerReady() then
			local A = P.act.tower
			table.insert(list, { key = "tower", kind = "tower", gain = if A and A.perSec then A.perSec else math.huge, eta = A and A.secs })
		end
		if N.want("AutoWorldBoss") and N.bossWanted() then
			local A = P.act.boss
			table.insert(list, { key = "boss", kind = "boss", gain = if A and A.perSec then A.perSec else math.huge, eta = A and A.secs })
		end
		table.sort(list, function(a, b)
			if a.gain ~= b.gain then
				return a.gain > b.gain
			end
			return a.key < b.key
		end)
		return list
	end
	-- The planner works (and logs PLAN lines) only while Smart Planner is on.
	function N.plannerWanted()
		return on("SmartPlanner")
	end
	-- Live rates are also sampled for the manual toggles that price things by payback (no PLAN lines then).
	local MeasureToggles = { "AutoTrain", "AutoStages", "AutoTower", "AutoWorldBoss", "AutoForge", "AutoUpgrade", "AutoEnhance", "AutoClassRoll", "AutoSeasonShop" }
	function N.measureWanted()
		if on("SmartPlanner") then
			return true
		end
		for _, name in ipairs(MeasureToggles) do
			if on(name) then
				return true
			end
		end
		return false
	end
	local function decisionText(best)
		if not best then
			return "idle", "nothing to do"
		end
		local r = N.rebirth()
		if best.kind == "train" then
			if best.depth then
				return "train", P.trainWhy or "training for power"
			end
			return "train", "train toward rebirth " .. (r + 1) .. (if best.eta and best.eta > 0 then " (" .. N.longTime(best.eta) .. " left)" else "") .. ": " .. (P.trainWhy or "")
		elseif best.kind == "farm" then
			if best.gain == math.huge then
				return "farm", "farm stage " .. best.stage .. " once to measure it"
			end
			return "farm", "farm stage " .. best.stage .. " for " .. formatNumber(best.gain) .. " coins/s" .. (if P.trainWhy then ": " .. P.trainWhy else "")
		elseif best.kind == "tower" then
			return "tower", "run the tower, worth " .. (if best.gain == math.huge then "a first measurement" else formatNumber(best.gain) .. " coins/s") .. ", more than a stage run"
		end
		return "boss", "fight the world boss, worth " .. (if best.gain == math.huge then "a first measurement" else formatNumber(best.gain) .. " coins/s")
	end
	function N.planRefresh(force)
		if not N.plannerWanted() then
			return P.best
		end
		local now = os.clock()
		if not force and now - P.at < 5 then
			return P.best
		end
		P.at = now
		P.options = N.planOptions()
		P.best = P.options[1]
		local farm
		for _, o in ipairs(P.options) do
			if o.kind == "farm" then
				farm = o
				break
			end
		end
		P.stage = farm and farm.gain < math.huge and farm.stage or nil
		local best = P.best
		if best then
			local alt = {}
			for i = 2, math.min(#P.options, 3) do
				table.insert(alt, P.options[i].key .. ":" .. fmt(P.options[i].gain))
			end
			P.text = string.format(
				"best=%s gain/s=%s eta=%s alt=%s",
				best.key,
				fmt(best.gain),
				if best.eta then N.longTime(best.eta) else "?",
				if #alt > 0 then table.concat(alt, ",") else "-"
			)
			-- The raw ranking once a minute (the PLAN decision line below explains every change in words).
			if now - P.logAt > 60 then
				P.lastKey = best.key
				P.logAt = now
				N.planLog("PLAN", P.text)
			end
		else
			P.text = ""
		end
		-- The decision in plain words: on every change of what to do, else every 5 minutes.
		local key, words = decisionText(best)
		P.why = words
		if key ~= P.whyKey or now - P.whyAt > 300 then
			P.whyKey, P.whyAt = key, now
			N.planLog("PLAN decision " .. key .. ": " .. words)
		end
		return best
	end
	-- The first of the given kinds in the current ranking (nil when the planner has none of them).
	function N.planFirst(kinds)
		if not N.plannerWanted() then
			return nil
		end
		for _, o in ipairs(P.options) do
			if table.find(kinds, o.kind) then
				return o.kind
			end
		end
		return nil
	end
	function N.planTick()
		if not N.measureWanted() then
			return
		end
		local ok, err = pcall(sample)
		if not ok then
			log("ERROR", "plan sample", tostring(err))
		end
		ok, err = pcall(N.planRefresh)
		if not ok then
			log("ERROR", "plan", tostring(err))
		end
	end
	-- Gear value ---------------------------------------------------------------------------------------------------
	local function equippedValue(slot)
		local bp = N.backpack()
		local uuid = bp.equiped[slot]
		local item = uuid and bp.have[uuid]
		if type(item) == "table" then
			return N.gearScore(item, bp)
		end
		return 0
	end
	-- Coin value of owning one item: the training it adds when it beats the equipped one (weapon = Train power,
	-- hat = Train boost x(1+value), body armor only defence), else its sale price x Coin boost.
	function N.itemValue(kind, id)
		local configType = if kind == "Weapon" then "Weapon" else "Armor"
		local sale = num(N.call(N.G.Any.GetSellPrice, configType, id), 0) * N.coinMult()
		local bp = N.backpack()
		local slot = kind
		if kind ~= "Weapon" then
			slot = tostring(N.call(N.G.Armor.GetBigType, id) or kind)
		end
		local g = 0
		if slot == "Weapon" then
			local new = num(N.call(N.G.Balance.GetWeaponTrainValue, LocalPlayer, { ID = id, Type = "Weapon", Level = 0 }, bp), 0)
			local cur = math.max(equippedValue("Weapon"), 1)
			g = new / cur - 1
		elseif slot == "Hat" then
			local new = num(N.call(N.G.Balance.GetArmorValue, LocalPlayer, { ID = id, Type = "Hat", Level = 0 }, bp), 0)
			g = (1 + new) / (1 + equippedValue("Hat")) - 1
		end
		return math.max(sale, N.trainValue(g)), sale
	end
	-- Forge choice ---------------------------------------------------------------------------------------------------
	-- For every kind and ore count the game allows: the expected value of the item the game's own forge roll gives
	-- (ForgeUtils.GetForgeOreResult + GetEquPercent for every item type it can pick), per ore used, against selling
	-- the same ores. Cached 20 s.
	local function oreTable(plan)
		local have = N.backpack().have
		local out = {}
		for uuid, n in pairs(plan) do
			local item = have[uuid]
			if type(item) == "table" and item.ID then
				out[item.ID] = (out[item.ID] or 0) + n
			end
		end
		return out
	end
	function N.forgeEV(kind, count, ores)
		local FU = N.G.ForgeUtils
		if type(FU.GetForgeOreResult) ~= "function" or type(FU.GetEquPercent) ~= "function" then
			return nil
		end
		local okR, tMin, tMax = pcall(FU.GetForgeOreResult, ores)
		local okA, avg = pcall(FU.GetOreAvgPower, ores)
		if not okR or not tMin or not okA then
			return nil
		end
		local helper = if kind == "Weapon" then N.G.Weapon else N.G.Armor
		local types = N.call(helper.GetForgePercentByNumber, count)
		if type(types) ~= "table" then
			return nil
		end
		local total, chances = 0, 0
		for _, chance in pairs(types) do
			chances += math.max(num(chance, 0), 0)
		end
		if chances <= 0 then
			return nil
		end
		for kindName, chance in pairs(types) do
			chance = num(chance, 0) / chances
			chance = num(chance, 0)
			if chance > 0 then
				local okE, items = pcall(FU.GetEquPercent, kind, count, tMin, tMax, avg, kindName)
				if okE and type(items) == "table" then
					-- Normalised here, so 0..1 and 0..100 percent tables both work.
					local share, sub = 0, 0
					for id, p in pairs(items) do
						p = num(p, 0)
						if p > 0 then
							share += p
							sub += p * (N.itemValue(kind, id))
						end
					end
					if share > 0 then
						total += chance * sub / share
					end
				end
			end
		end
		return total
	end
	function N.forgeChoice(force)
		local F = P.forge
		if not force and os.clock() - F.at < 20 then
			return F.choice
		end
		F.at = os.clock()
		F.choice = nil
		local pick = N.pickText("ForgeType", "Auto (best value)")
		local kinds = if pick == "Weapon" or pick == "Armor" then { pick } else { "Weapon", "Armor" }
		local best
		for _, kind in ipairs(kinds) do
			local top = if kind == "Weapon" then 13 else 23
			for count = 4, top do
				local plan, total = N.forgePlanFor(kind, count)
				if plan and total == count then
					local ores = oreTable(plan)
					local ev = N.forgeEV(kind, count, ores)
					if ev then
						local sale = 0
						for id, n in pairs(ores) do
							sale += num(N.call(N.G.Ore.GetSellPrice, id), 0) * n
						end
						sale *= N.coinMult()
						local option = { kind = kind, count = count, plan = plan, ev = ev, perOre = ev / count, salePerOre = sale / count }
						if not best or option.perOre > best.perOre then
							best = option
						end
					end
				end
			end
		end
		F.choice = best
		if best then
			F.lift = math.max(best.perOre / math.max(best.salePerOre, 1e-9), 1)
		end
		return best
	end
	-- Money options ----------------------------------------------------------------------------------------------
	-- Every option: dI = coins per second it adds (horizon average for lump values), cost = coins. Bought in falling
	-- dI/cost order; a cheaper one is bought while saving only when it pays back before the saving is done.
	function N.upgradeGain(nextUp)
		local levels = N.G.Upgrade[nextUp.kind] or {}
		local now = levels[nextUp.level] or {}
		local delta = num(nextUp.number, 0) - num(now.Number, 0)
		if delta <= 0 then
			return 0
		end
		local d = P.stage or N.stageTargetByPower()
		if nextUp.kind == "OrePack" then
			-- A slot only pays when the pack still fills from the clears it already waits for (one more clear means a
			-- 30 s respawn), so the next few levels are looked at together: the best gain per coin of buying up
			-- to level k, priced at all k levels.
			local _, cap = N.pack()
			local a = N.farmValue(d, cap)
			if not a then
				return nil
			end
			local bestGain, bestCost, bestRatio = 0, nextUp.price, 0
			local cost, number = 0, num(now.Number, 0)
			for k = nextUp.level + 1, nextUp.level + 8 do
				local row = levels[k]
				if type(row) ~= "table" then
					break
				end
				cost += num(row.Price, math.huge)
				local b = N.farmValue(d, cap + num(row.Number, number) - num(now.Number, 0))
				local gain = if b then (b - a) * N.farmShare() else 0
				if gain > 0 and gain / math.max(cost, 1) > bestRatio then
					bestGain, bestCost, bestRatio = gain, cost, gain / math.max(cost, 1)
				end
			end
			return bestGain, bestCost
		elseif nextUp.kind == "Luck" then
			local luck = N.luckMult()
			local base = 1 + upgradeNumber("Luck")
			local a = N.stageOreEV(d, luck)
			local b = N.stageOreEV(d, luck * (base + delta) / base)
			local v = N.farmValue(d, (select(2, N.pack())))
			if not a or not b or not v then
				return nil
			end
			return v * (b / a - 1) * N.farmShare()
		elseif nextUp.kind == "Train" then
			return N.trainValue(delta / (1 + upgradeNumber("Train"))) / P.H
		end
		return 0
	end
	-- One enhance try on an equipped weapon or hat: the success chance x the training the level adds, minus the
	-- level a failure takes away from +failLevel on (assumed one level, no scroll).
	function N.enhanceGain(slot, item, step, failLevel, protect)
		if slot == "Armor" then
			return 0 -- body armor only adds defence
		end
		local config = N.call(N.G.Enhant.GetConfig) or {}
		local function boost(level)
			local row = config[level]
			return num(type(row) == "table" and row.Boost, 0)
		end
		local L = step.level
		local function gain(from, to)
			local up = (1 + boost(to)) / (1 + boost(from))
			if slot == "Weapon" then
				return up - 1
			end 
			local h = N.gearScore(item, N.backpack())
			return (1 + h * up) / (1 + h) - 1
		end
		local value = step.percent * N.trainValue(gain(L, L + 1))
		if L >= failLevel and not protect and L > 0 then
			value -= (1 - step.percent) * N.trainValue(gain(L - 1, L))
		end
		return value / P.H
	end
	function N.spendOptions()
		local list = {}
		if N.want("AutoUpgrade") then
			for _, kind in ipairs(N.UpgradeKinds) do
				if allows(Options.UpgradeKinds, N.UpgradeNames[kind]) then
					local nextUp = N.upgradeNext(kind)
					if nextUp then
						local gain, total = N.upgradeGain(nextUp)
						if gain then
							-- cost = every level the gain needs (Ore Pack look-ahead), the purchase itself is the next level
							table.insert(list, { key = "Upgrade " .. kind, kind = "upgrade", up = nextUp, cost = total or nextUp.price, price = nextUp.price, gain = gain })
						end
					end
				end
			end
		end
		if N.want("AutoEnhance") and N.rebirth() >= 6 then
			local bp = N.backpack()
			local failLevel = tonumber(N.call(N.G.Enhant.GetFailLevel)) or 6
			for _, slot in ipairs({ "Weapon", "Hat" }) do
				local uuid = bp.equiped[slot]
				local item = uuid and bp.have[uuid]
				if type(item) == "table" and N.gearExcluded(N.gearRarity(item)) then
					-- excluded tier: never enhanced
				elseif type(item) == "table" then
					local step = N.enhanceNext(item)
					if step and step.level < N.enhanceMaxLevel() and N.material("EnhantStone_1") >= step.stone1 and N.material("EnhantStone_2") >= step.stone2 then
						local protect = step.level >= failLevel and N.material("EnhantProtect") > 0
						local gain = N.enhanceGain(slot, item, step, failLevel, protect)
						table.insert(list, { key = "Enhance " .. slot .. " +" .. (step.level + 1), kind = "enhance", slot = slot, uuid = uuid, step = step, protect = protect, cost = step.coin, gain = gain })
					end
				end
			end
		end
		local keep = {}
		for _, o in ipairs(list) do
			-- Never buy what does not pay back within a day (the hub plays 24 h sessions).
			if o.gain > 0 and o.cost / o.gain <= P.Payback then
				o.perCoin = o.gain / math.max(o.cost, 1)
				table.insert(keep, o)
			end
		end
		table.sort(keep, function(a, b)
			if a.perCoin ~= b.perCoin then
				return a.perCoin > b.perCoin
			end
			return a.key < b.key
		end)
		return keep
	end
	-- Picks what to buy now (or nil while saving), logs the PLAN line for money.
	function N.spendPick()
		local list = N.spendOptions()
		local best = list[1]
		if not best then
			P.spendText = "nothing pays back within 24 h"
			P.spendNext = nil
			return nil
		end
		local coins = N.coin()
		local pick
		local eta = 0
		local function now(o)
			return o.price or o.cost
		end
		if now(best) <= coins then
			pick = best
		else
			local income = N.coinIncome()
			eta = if income > 0 then (now(best) - coins) / (income * math.max(N.farmShare(), 0.1)) else math.huge
			for i = 2, #list do
				local o = list[i]
				if now(o) <= coins and o.cost / o.gain <= eta then
					pick = o
					break
				end
			end
		end
		do
			local target = pick or best
			local what = if target.kind == "upgrade" then string.format("%s upgrade level %d", N.UpgradeNames[target.up.kind] or target.up.kind, target.up.level + 1) else string.format("%s enhance to +%d", target.slot, target.step.level + 1)
			P.spendNext = if pick then "Buy " .. what .. " now" else "Buy " .. what .. (if eta == math.huge then " when coins allow" else " in " .. N.longTime(eta))
		end
		local alt = {}
		for i = 2, math.min(#list, 3) do
			table.insert(alt, string.format("%s:%.3g", list[i].key, list[i].perCoin))
		end
		P.spendText = string.format(
			"best=%s gain/$=%.3g eta=%s alt=%s%s",
			best.key,
			best.perCoin,
			if eta == math.huge then "?" else N.longTime(eta),
			if #alt > 0 then table.concat(alt, ",") else "-",
			if pick and pick ~= best then " buying=" .. pick.key else ""
		)
		local key = best.key .. (if pick then "+" .. pick.key else "")
		if key ~= P.spendKey then
			P.spendKey = key
			N.planLog("PLAN", P.spendText)
		end
		return pick
	end
	-- Season Shop goods in coins (lump value). The 2000 coin deal sets the floor: 10 coins per Season Coin.
	function N.seasonGoodValue(row)
		local id, n = tostring(row.ID), num(row.Number, 1)
		if row.Type == "Eco" and id == "coin" then
			return n
		elseif id == "Dungeon_Ticket" then
			local A = P.act.tower
			return n * (A and A.perRun or 0)
		elseif id == "TrainPotion" then
			-- +1 to the Train factor for 300 s, used while training.
			local m = N.rebirthMath()
			local rate = N.expRate()
			if not m or not rate or rate <= 0 then
				return 0
			end
			local g = 1 / (1 + upgradeNumber("Train"))
			local gainPerSec = N.rebirthValue(m) / math.max(m.cost / rate, 1)
			return n * 300 * g * gainPerSec * (1 - N.farmShare())
		elseif id == "ClassRoll" then
			return n * N.classRollValue()
		elseif id == "EnhantStone_1" or id == "EnhantStone_2" then
			-- Worth the next enhance it unlocks when stones are what is missing.
			local bp = N.backpack()
			local best = 0
			for _, slot in ipairs({ "Weapon", "Hat" }) do
				local uuid = bp.equiped[slot]
				local item = uuid and bp.have[uuid]
				local step = type(item) == "table" and N.enhanceNext(item)
				if step then
					local need = if id == "EnhantStone_1" then step.stone1 else step.stone2
					local missing = need - N.material(id)
					if missing > 0 then
						local gain = N.enhanceGain(slot, item, step, 6, false) * P.H
						best = math.max(best, gain * math.min(n / missing, 1))
					end
				end
			end
			return best
		elseif id == "EnhantProtect" then
			local bp = N.backpack()
			local uuid = bp.equiped.Weapon
			local item = uuid and bp.have[uuid]
			local step = type(item) == "table" and N.enhanceNext(item)
			local failLevel = tonumber(N.call(N.G.Enhant.GetFailLevel)) or 6
			if step and step.level >= failLevel then
				local without = N.enhanceGain("Weapon", item, step, failLevel, false)
				local with = N.enhanceGain("Weapon", item, step, failLevel, true)
				return math.max(with - without, 0) * P.H
			end
			return 0
		elseif row.Type == "Weapon" or row.Type == "Hat" or row.Type == "Armor" then
			return n * (N.itemValue(if row.Type == "Weapon" then "Weapon" else "Armor", id))
		elseif id == "SeasonTicket" then
			return n * N.seasonSpinValue()
		end
		return 0
	end
	function N.seasonSpinValue()
		local config = N.call(N.G.Season.GetLuckConfig)
		if type(config) ~= "table" then
			return 0
		end
		local total, sum = 0, 0
		for _, prize in pairs(config) do
			if type(prize) == "table" then
				local w = num(prize.Weight, 0)
				total += w
				local value = 0
				if prize.ID == "SeasonCoin" then
					value = num(prize.Number, 0) * 10
				elseif prize.Type ~= "EnchStone" then
					value = N.seasonGoodValue(prize)
				end
				sum += w * value
			end
		end
		return if total > 0 then sum / total else 0
	end
	-- Class rolls: the class boost multiplies training (1+Train) and luck (1+Luck). A roll replaces the class, so
	-- with k rolls left the hub rolls only while the class is worth less than what k rolls are expected to reach
	-- (backward induction over the game's class weights).
	function N.classValue(classId, level)
		local boosts = N.call(N.G.Class.GetClassBoosts, classId, level or 1)
		if type(boosts) ~= "table" then
			return nil
		end
		local train = num(boosts.Train, 0)
		local luck = num(boosts.Luck, 0)
		local value = N.trainValue(train)
		if luck > 0 then
			local d = P.stage or N.stageTargetByPower()
			local l0 = N.luckMult()
			local a = N.stageOreEV(d, l0)
			local b = N.stageOreEV(d, l0 * (1 + luck))
			local v = N.farmValue(d, (select(2, N.pack())))
			if a and b and v then
				value += v * (b / a - 1) * N.farmShare() * P.H
			end
		end
		return value
	end
	local function classTable()
		local config = N.call(N.G.Class.GetConfig)
		if type(config) ~= "table" then
			return nil
		end
		local record = N.store("Class").recored
		record = if type(record) == "table" then record else {}
		local list, total = {}, 0
		for id, row in pairs(config) do
			local w = num(type(row) == "table" and row.Weight, 0)
			local rec = record[id]
			local value = N.classValue(id, tonumber(type(rec) == "table" and rec.Level) or 1)
			if w > 0 and value then
				total += w
				table.insert(list, { w = w, value = value })
			end
		end
		if total <= 0 then
			return nil
		end
		for _, c in ipairs(list) do
			c.p = c.w / total
		end
		return list
	end
	-- W[k] = expected class value when k rolls are left and used optimally.
	function N.classThreshold(k)
		local list = classTable()
		if not list or k <= 0 then
			return nil
		end
		local W = -math.huge
		for _ = 1, k do
			local e = 0
			for _, c in ipairs(list) do
				e += c.p * math.max(c.value, W)
			end
			W = e
		end
		return W
	end
	function N.classRollValue()
		local rolls = tonumber(N.store("Class").luckTimes) or 0
		local _, class = N.classNow()
		local record = N.store("Class").recored
		local rec = type(record) == "table" and record[class]
		local now = N.classValue(class, tonumber(type(rec) == "table" and rec.Level) or 1) or 0
		local a = math.max(N.classThreshold(rolls) or now, now)
		local b = math.max(N.classThreshold(rolls + 1) or now, now)
		return math.max(b - a, 0)
	end
end
do
	local function setToggles(names, args)
		local word = args and args[1] and string.lower(tostring(args[1])) or ""
		local first = Toggles[names[1]]
		local state
		if word == "on" or word == "1" or word == "true" then
			state = true
		elseif word == "off" or word == "0" or word == "false" then
			state = false
		else
			state = not (first and first.Value)
		end
		for _, name in ipairs(names) do
			local toggle = Toggles[name]
			if toggle then
				toggle:SetValue(state)
			end
		end
		return state
	end
	N.setToggles = setToggles
	local function toggleCommand(name, aliases, names, text)
		Library:AddCommand({
			Name = name,
			Aliases = aliases,
			Args = "[on/off]",
			Description = "Turns " .. text .. " on or off",
			Source = GameName,
			Callback = function(args)
				return text .. (if setToggles(names, args) then " on" else " off")
			end,
		})
	end
	if Library.AddCommand then
		pcall(function()
			toggleCommand("planner", { "smart" }, { "SmartPlanner" }, "Smart Planner")
			toggleCommand("stages", {}, { "AutoStages" }, "Auto Farm Stages")
			toggleCommand("superloot", { "super", "runner" }, { "AutoSuperLoot" }, "Super Loot hunting")
			toggleCommand("enhance", {}, { "AutoEnhance" }, "Auto Enhance Equipped Gear")
			toggleCommand("train", {}, { "AutoTrain" }, "Auto Train")
			toggleCommand("forge", {}, { "AutoForge" }, "Auto Forge")
			toggleCommand("equip", { "gear" }, { "AutoEquip" }, "Auto Equip Best Gear")
			toggleCommand("sell", {}, { "AutoSellGear" }, "Auto Sell Weak Gear")
			toggleCommand("upgrades", { "buy" }, { "AutoUpgrade" }, "Auto upgrades")
			toggleCommand("rebirth", {}, { "AutoRebirth" }, "Auto Rebirth")
			toggleCommand("tower", { "dungeon" }, { "AutoTower" }, "Auto Tower")
			toggleCommand("boss", { "worldboss" }, { "AutoWorldBoss" }, "Auto World Boss")
			Library:AddCommand({
				Name = "bank",
				Description = "Banks the ores in your pack and leaves the stage",
				Source = GameName,
				Callback = function()
					task.spawn(N.bank, "command")
					return "Banking"
				end,
			})
			Library:AddCommand({
				Name = "stop",
				Aliases = { "alloff" },
				Description = "Turns every automation off",
				Source = GameName,
				Callback = function()
					N.stopAll()
					return "Everything off"
				end,
			})
			Library:AddCommand({
				Name = "status",
				Description = "Shows what Lymn is doing",
				Source = GameName,
				Callback = function()
						local packNow, packMax = N.pack()
						return string.format(
							"%s  |  power %s  |  level %d  |  rebirth %d  |  pack %d/%d  |  %d runs, %d ores",
							Status,
							formatNumber(N.power()),
							N.level(),
							N.rebirth(),
							packNow,
							packMax,
							Session.runs,
							Session.ores
						)
				end,
			})
			Library:AddCommand({
				Name = "perf",
				Aliases = { "fps", "lag" },
				Description = "Shows how smooth the game runs and how much time Lymn takes",
				Source = GameName,
				Callback = Debug.perfText,
			})
		end)
	end
	if Library.OnUnload then
		Library:OnUnload(function()
			INSTANCE.stop = true
			log("UNLOAD")
			flushLog(true)
		end)
	end
	if Window.AddCommandsTab then
		pcall(function()
			Tabs.Commands = Window:AddCommandsTab()
		end)
	end
	if Library.SetQuickBar then
		pcall(function()
			Library:SetQuickBar({
				{ Toggle = "SmartPlanner", Icon = "sparkles", Label = "Planner" },
				{ Toggle = "AutoStages", Icon = "swords", Label = "Stages" },
				{ Toggle = "AutoTrain", Icon = "dumbbell", Label = "Train" },
				{ Toggle = "AutoForge", Icon = "hammer", Label = "Forge" },
				{ Toggle = "AutoRebirth", Icon = "refresh-cw", Label = "Rebirth" },
				{ Toggle = "AutoTower", Icon = "castle", Label = "Tower" },
			})
		end)
	end
	local SetupFlag = "Lymn/LTF_setup_done.txt"
	function N.markSetupDone()
		pcall(function()
			if makefolder and isfolder and not isfolder("Lymn") then
				makefolder("Lymn")
			end
			writefile(SetupFlag, "1")
		end)
	end
	function N.setupDone()
		local ok, done = pcall(function()
			return isfile(SetupFlag)
		end)
		return not ok or done == true
	end
	function N.openWizard()
		if not Library.ShowWizard then
			return
		end
		return Library:ShowWizard({
			SkipText = "Skip",
			FinishText = "Start",
			Steps = {
				{
					Id = "tasks",
					Title = "What should Lymn do for you?",
					Description = "Pick everything you want running. Tap again to unpick.",
					Multi = true,
					Required = true,
					Default = { "stages", "train", "events", "rewards" },
					Choices = {
						{ Id = "planner", Title = "Smart Planner", Description = "Runs the whole loop by profit: runs, training, rebirths, forge, gear, upgrades and spending", Icon = "sparkles", Color = "#ffd166" },
						{ Id = "stages", Title = "Farm stages", Description = "Fights the best stage for your power, picks every ore and banks them safely", Icon = "swords", Color = "#fab428" },
						{ Id = "train", Title = "Train", Description = "Trains in the best open area when the next rebirth pays more than a run", Icon = "dumbbell", Color = "#3ccf91" },
						{ Id = "forge", Title = "Forge and gear", Description = "Forges from your strongest ores and equips the best weapon, armor and hat", Icon = "hammer", Color = "#5fb8ff" },
						{ Id = "upgrades", Title = "Upgrades and rebirth", Description = "Ore Pack, Train and Luck upgrades, rebirths when your level allows", Icon = "arrow-big-up", Color = "#ff9a3c" },
						{ Id = "events", Title = "Tower and world boss", Description = "Uses your tower tickets and joins every world boss", Icon = "castle", Color = "#c77dff" },
						{ Id = "rewards", Title = "Claim rewards", Description = "Online gifts, offline, index, season, quests (spends nothing)", Icon = "gift", Color = "#ff5d8f" },
					},
				},
			},
			Finish = function(values)
				local chosen = type(values.tasks) == "table" and values.tasks or {}
				local groups = {
					planner = { "SmartPlanner" },
					stages = { "AutoStages", "AutoSuperLoot" },
					train = { "AutoTrain" },
					forge = { "AutoForge", "AutoEquip" },
					upgrades = { "AutoUpgrade", "AutoEnhance", "AutoRebirth" },
					events = { "AutoTower", "AutoWorldBoss" },
					rewards = { "AutoOnline", "AutoOffline", "AutoIndex", "AutoSeason", "AutoTowerTicket", "AutoQuests", "AutoUpdateRewards" },
				}
				for id, names in pairs(groups) do
					if chosen[id] then
						setToggles(names, { "on" })
					end
				end
				N.markSetupDone()

				notify("Quick setup done", "Change anything in the tabs any time", 5)
			end,
			Skipped = function()
				N.markSetupDone()
				notify("Quick setup", "Skipped. Open it again from the Info tab.", 4)
			end,
		})
	end
end
pcall(function()
	Library.RenderOverlayInfo = function()
		return string.format("power %s  \u{00B7}  rebirth %d", formatNumber(N.power()), N.rebirth())
	end
end)

-- What changed a toggle is always in the log: the saved config at start (AUTOLOAD) or the player (CLICK).
-- Changes made by the hub itself (Stop Everything, Reset Hub Options) set N.quiet and stay out of CLICK.
Library.OnAutoload = function()
	local names = {}
	for name, toggle in pairs(Toggles) do
		if toggle.Value == true and string.sub(name, 1, 2) ~= "Q_" then
			table.insert(names, name)
		end
	end
	table.sort(names)
	log("AUTOLOAD toggles=" .. (if #names > 0 then table.concat(names, ",") else "-"))
end
Library.OnUserToggle = function(name, value)
	if not N.quiet then
		log("CLICK", name .. "=" .. tostring(value))
	end
end
do
	local ErrorLogAt = {}
	local function reportError(where, err)
		local text = tostring(err)
		local first = string.match(text, "^[^\n]*") or text
		if os.clock() - (ErrorLogAt[first] or -1e9) > 30 then
			ErrorLogAt[first] = os.clock()
			log("ERROR", where, text)
			logProblem(where .. ": " .. first)
		end
		return first
	end
	local ChoreAt = {}
	local function choreDue(key, seconds)
		local now = os.clock()
		if now >= (ChoreAt[key] or 0) then
			ChoreAt[key] = now + seconds
			return true
		end
		return false
	end
	N.choreDue = choreDue
	local function anyAutoOn()
		for _, name in ipairs(N.AllAutoToggles) do
			if on(name) then
				return true
			end
		end
		return false
	end
	local function loop(name, body)
		task.spawn(function()
			while alive() do
				local ok, err = xpcall(body, debug.traceback)
				if not ok then
					setStatus("Error: " .. reportError(name, err))
					task.wait(1)
				end
				task.wait()
			end
		end)
	end
	-- Player data first. The game pushes every change afterwards; a full reload now and then is a safety net.
	if not N.loadData() then
		logProblem("Could not load the player data at start")
	end
	N.rememberStages()
	-- The movement loop owns the character: stages, tower, world boss, forging and training never overlap.
	-- Priority: whatever fight you are in, then forge, tower, world boss, a stage run, training.
	loop("main loop", function()
		if N.manualRunning() then
			task.wait(0.3)
			return
		end
		if N.dead() then
			setStatus("Dead, waiting for the respawn")
			-- Stage and boss deaths respawn by themselves after 3 s; a tower death waits for the Give up button
			-- (DungeonGiveUpBE). Live 2026-10-06: dead 280 s after the tower, hp -7, nothing ran. Press it.
			N.deadSince = N.deadSince or os.clock()
			if os.clock() - N.deadSince > 4 and os.clock() - (N.deadPress or 0) > 5 then
				N.deadPress = os.clock()
				log("RESPAWN", "dead for " .. math.floor(os.clock() - N.deadSince) .. " s, pressing Give up")
				N.bindable("Dungeon/DungeonGiveUpBE")
			end
			task.wait(0.5)
			return
		end
		N.deadSince = nil
		local mode = N.fightMode()
		if mode ~= "Dungeon" and N.Tower.inRun then
			N.towerFinished()
		end
		if mode == "Stage" then
			if N.want("AutoStages") then
				if N.want("AutoWorldBoss") and N.bossWanted() and N.Fight.run and N.planFirst({ "boss", "farm" }) ~= "farm" then
					N.bank("world boss is up")
					return
				end
				N.fightStep()
			elseif N.Fight.run then
				N.bank("stage farm turned off")
			else
				task.wait(0.5)
			end
			return
		elseif mode == "Dungeon" then
			if N.want("AutoTower") then
				N.towerStep()
			else
				task.wait(0.5)
			end
			return
		elseif mode == "WorldBoss" then
			if N.want("AutoWorldBoss") then
				N.bossStep()
			else
				task.wait(0.5)
			end
			return
		elseif mode ~= nil then
			task.wait(0.5)
			return
		end
		N.Fight.run = false
		if N.want("AutoForge") and choreDue("forge", 10) and N.forgePlan(N.forgeKind()) then
			N.forgeStep(6)
			return
		end
		-- The profit planner (p09_plan) ranks every time option by coins of value per second; the boss and the tower
		-- go first only when they rank above both a stage run and training (never measured = tried once).
		if N.want("AutoWorldBoss") and N.bossWanted() and os.clock() - N.Boss.at > 15 and N.planFirst({ "boss", "farm", "train" }) ~= "farm" and N.planFirst({ "boss", "farm", "train" }) ~= "train" then
			N.bossJoin()
			return
		end
		if N.want("AutoTower") then
			local first = N.planFirst({ "tower", "farm", "train" })
			local reason = N.towerWaitReason()
			if not reason and first ~= "farm" and first ~= "train" then
				N.towerStart()
				return
			end
			N.towerWaiting(reason or N.towerPlanReason(first))
		end
		local training = N.want("AutoTrain")
		-- A Super Loot runner is worth more than training (one Legendary+ ore for about 2 s, gone in minutes).
		local superUp = N.want("AutoStages") and N.want("AutoSuperLoot") and N.superPick() ~= nil
		local trainTurn
		if N.plannerWanted() then
			trainTurn = N.planFirst({ "farm", "train" }) == "train"
		else
			-- Without Smart Planner: after every stage run the hub trains as long as that run took (half and half).
			trainTurn = os.clock() < (N.Fight.trainUntil or 0)
		end
		if N.want("AutoStages") and (not training or superUp or not trainTurn) then
			if not N.startRun() then
				task.wait(1)
			end
			return
		end
		if training then
			N.trainStep()
			return
		end
		if not anyAutoOn() then
			setStatus("Idle")
		elseif N.want("AutoTower") and N.Tower.waitReason then
			-- Nothing else to do: say why the tower is not running instead of a stale status.
			setStatus("Tower waiting: " .. N.Tower.waitReason)
		end
		task.wait(0.5)
	end)
	-- The aura runs on its own, so it also works when you play a stage or the tower yourself.
	loop("aura", function()
		local mode = N.fightMode()
		if N.want("KillAura") and (mode == "Stage" or mode == "Dungeon") then
			N.auraStep()
			task.wait(0.05)
		else
			task.wait(0.3)
		end
	end)
	-- Blatant training clicks and their probes (p05_probes): only while Auto Train (or the planner) trains.
	loop("train boost", N.trainBoostStep)
	-- Remote-only chores: they never move the character, so they run next to the movement loop.
	loop("chores", function()
		if N.manualRunning() then
			task.wait(0.3)
			return
		end
		N.planTick()
		if N.want("AutoEquip") and choreDue("equip", 3) then
			N.equipStep()
		end
		if choreDue("sell", 5) then
			N.sellStep()
		end
		if N.want("AutoUpgrade") and choreDue("upgrade", 2) then
			N.upgradeStep()
		end
		if N.want("AutoRebirth") and choreDue("rebirth", 1) then
			N.rebirthStep()
		end
		if N.want("AutoEnhance") and choreDue("enhance", 4) then
			N.enhanceStep()
		end
		if choreDue("rewards", 5) then
			N.rewardStep()
		end
		if choreDue("potions", 6) then
			N.potionStep()
		end
		N.classStep()
		N.powerStep()
		if choreDue("reload", 180) and N.fightMode() == nil then
			N.loadData()
		end
		task.wait(0.25)
	end)
	-- "Up next" in plain words (3-5 lines); the raw planner numbers stay in the PLAN log lines.
	function N.upNextText()
		local Pl = N.Plan
		local next = {}
		local r = N.rebirth()
		local function describe(o)
			if o.kind == "train" then
				if o.eta and o.eta ~= math.huge then
					return "Train " .. N.longTime(o.eta) .. " to rebirth " .. (r + 1)
				end
				return "Train toward rebirth " .. (r + 1)
			elseif o.kind == "farm" then
				return "Farm stage " .. tostring(o.stage) .. " for ores"
			elseif o.kind == "tower" then
				return "Run the tower (tickets ready)"
			end
			return "Fight the world boss"
		end
		if N.plannerWanted() then
			for i = 1, math.min(#Pl.options, 2) do
				table.insert(next, (if i == 1 then "Now: " else "Then: ") .. describe(Pl.options[i]))
			end
			if Pl.why and Pl.why ~= "" then
				table.insert(next, "Why: " .. Pl.why)
			end
		end
		if N.want("AutoTower") and N.fightMode() ~= "Dungeon" then
			local why = N.towerWaitReason() or N.Tower.waitReason
			if why and why ~= "short pause between runs" then
				table.insert(next, "Tower waits: " .. why)
			elseif not N.plannerWanted() then
				table.insert(next, "Run the tower (" .. N.towerTickets() .. " tickets)")
			end
		end
		if Pl.spendNext and (N.want("AutoUpgrade") or N.want("AutoEnhance")) then
			table.insert(next, Pl.spendNext)
		end
		if N.want("AutoForge") then
			local kind = N.forgeKind()
			local per = math.max(N.forgeCount(kind), 1)
			local usable = 0
			for _, ore in ipairs(N.ores()) do
				if not ore.locked and not selected(Options.ForgeKeepRarities, ore.rarity) and not N.oreExcluded(ore.rarity, true) then
					usable += ore.number
				end
			end
			local times = math.floor(usable / per)
			table.insert(next, if times >= 1 then string.format("Forge %s x%d", string.lower(kind), times) else string.format("Forge %s when %d ores are ready", string.lower(kind), per))
		end
		if N.want("AutoRebirth") then
			local m = N.rebirthMath()
			if m then
				table.insert(next, "Rebirth " .. (r + 1) .. " at level " .. tostring(m.need))
			end
		end
		while #next > 5 do
			table.remove(next)
		end
		return if #next > 0 then "\u{2022} " .. table.concat(next, "\n\u{2022} ") else "Turn on Smart Planner (or Auto Farm Stages, Auto Train) to get a plan"
	end
	-- Builds every label text here, the draw thread below only copies strings.
	N.InfoText = {}
	task.spawn(function()
		while alive() do
			local started = os.clock()
			local ok, err = pcall(function()
				local I = N.InfoText
				local power = N.power()
				local packNow, packMax = N.pack()
				local hp, maxHp = N.hp()
				local target = N.stageTarget()
				I.info = string.format(
					"Power <b>%s</b>  \u{00B7}  level <b>%d</b>  \u{00B7}  rebirth <b>%d</b>\nCoins <b>%s</b>  \u{00B7}  HP %d/%d\nPack <b>%d/%d</b>  \u{00B7}  target stage <b>%d</b>  \u{00B7}  %d runs, %d ores",
					formatNumber(power),
					N.level(),
					N.rebirth(),
					formatNumber(N.coin()),
					math.floor(hp),
					math.floor(maxHp),
					packNow,
					packMax,
					target,
					Session.runs,
					Session.ores
				)
				if N.Fight.lastBank ~= "" then
					I.info ..= "\nLast bank: " .. N.Fight.lastBank
				end
				do
					local Pl = N.Plan
					local lines = {}
					if Pl.text ~= "" then
						table.insert(lines, "Time: " .. Pl.text)
					end
					if Pl.spendText ~= "" then
						table.insert(lines, "Coins: " .. Pl.spendText)
					end
					I.plan = if #lines > 0 then '<font transparency="0.3">Plan  \u{00B7}  ' .. table.concat(lines, "\n") .. "</font>" else "Plan: starting"
				end
				I.upnext = N.upNextText()
				-- Every stage with your odds: green you clear it, yellow close, red too strong for now.
				local rows = {}
				local now = os.clock()
				for _, stage in ipairs(N.stageList()) do
					local color = if power >= stage.recommend then "#60d696" elseif power * 2 >= stage.recommend then "#fab428" else "#ff6b6b"
					local mark = if stage.n == target then "  \u{25C0} farming" elseif (N.Fight.hard[stage.n] or 0) > now then "  (too strong, retry in " .. N.longTime(N.Fight.hard[stage.n] - now) .. ")" else ""
					table.insert(rows, string.format('<font color="%s">Stage %d</font>  needs %s%s', color, stage.n, formatNumber(stage.recommend), mark))
					if stage.n > target + 3 then
						break
					end
				end
				I.stages = if #rows > 0 then table.concat(rows, "\n") else "Stage data not loaded"
				local ores = N.ores()
				local kind = N.forgeKind()
				local plan, total, avg = N.forgePlan(kind)
				local top = {}
				for i = 1, math.min(#ores, 4) do
					table.insert(top, string.format('<font color="%s">%s</font> x%d', N.rarityColor(ores[i].rarity), N.itemName("Ore", ores[i].id), ores[i].number))
				end
				I.forge = string.format(
					"Ores <b>%d</b>%s\nNext: %s\nForged <b>%d</b> this session%s",
					N.oreTotal(),
					if #top > 0 then "  \u{00B7}  best: " .. table.concat(top, ", ") else "",
					if plan then string.format("%s from %d ores, avg power %s", kind, total, formatNumber(avg)) else string.format("needs %d ores for a %s (have %d)", N.forgeCount(kind), kind, total or 0),
					Session.forged,
					if #N.Forge.log > 0 then "\n" .. table.concat(N.Forge.log, "\n") else ""
				)
				local gearLines = {}
				local bp = N.backpack()
				for _, kind2 in ipairs({ "Weapon", "Armor", "Hat" }) do
					local uuid = bp.equiped[kind2]
					local item = uuid and bp.have[uuid]
					if type(item) == "table" then
						local rarity = N.gearRarity(item)
						table.insert(gearLines, string.format('%s: <font color="%s">%s</font> (%s)', kind2, N.rarityColor(rarity), N.itemName(kind2, item.ID), formatNumber(N.gearScore(item, bp))))
					else
						table.insert(gearLines, kind2 .. ": none")
					end
				end
				I.gear = table.concat(gearLines, "\n") .. string.format("\nEquipped %d upgrades this session", Session.equips)
				local plan2 = N.sellPlan()
				local why = N.Sell.why or {}
				I.sell = string.format(
					"%s\nKept: %d equipped, %d best, %d rarity, %d locked\nSold <b>%d</b> this session%s",
					if #plan2 > 0 then "Can sell <b>" .. #plan2 .. "</b> weak items" else '<font transparency="0.4">Nothing to sell right now</font>',
					why.equipped or 0,
					why.best or 0,
					why.rarity or 0,
					why.locked or 0,
					Session.sold,
					(if N.Sell.refused > 0 then "\n" .. N.Sell.refused .. " item(s) the game would not sell are skipped" else "")
							.. (if #N.Sell.log > 0 then "\nLast: " .. table.concat(N.Sell.log, ", ") else "")
				)
				local area = N.bestTrainArea()
				I.train = string.format(
					"%s\nLevel <b>%d</b>  \u{00B7}  trained %s this session%s",
					if area then string.format("Best open area: <b>%d</b> (x%s)", area.id, formatNumber(area.basic)) else "No area open",
					N.level(),
					N.longTime(Session.trainSeconds),
					if N.blatant("TrainSpeed")
						then string.format(
							"\nFast clicks: %s\nBetter area: %s\nWhile farming: %s",
							N.probeText("train_rate"),
							N.probeText("train_area"),
							N.probeText("train_keep")
						)
						else ""
				)
				if N.blatant("LootSpeed") then
					I.info ..= "\nInstant pickup: " .. N.probeText("stage_loot")
				end
				local ups = {}
				for _, kind3 in ipairs(N.UpgradeKinds) do
					local nextUp = N.upgradeNext(kind3)
					table.insert(ups, string.format("%s: %s", N.UpgradeNames[kind3], if nextUp then string.format("level %d, next %s coins", nextUp.level, formatNumber(nextUp.price)) else "max"))
				end
				I.upgrades = table.concat(ups, "\n") .. string.format("\nBought <b>%d</b> this session", Session.upgrades)
				local enh = {}
				for _, slot in ipairs({ "Weapon", "Armor", "Hat" }) do
					local uuid = bp.equiped[slot]
					local item = uuid and bp.have[uuid]
					if type(item) == "table" then
						local step = N.enhanceNext(item)
						table.insert(enh, string.format("%s +%d%s", slot, tonumber(item.Level) or 0, if step then string.format(" (next %s coins, %d stones, %d%%)", formatNumber(step.coin), step.stone1, math.floor(step.percent * 100)) else " (max)"))
					end
				end
				I.enhance = string.format(
					"%s\nStones <b>%s</b> / <b>%s</b>  \u{00B7}  scrolls <b>%d</b>  \u{00B7}  <b>%d</b> tries this session%s%s",
					if #enh > 0 then table.concat(enh, "\n") else "No gear equipped",
					formatNumber(N.material("EnhantStone_1")),
					formatNumber(N.material("EnhantStone_2")),
					N.material("EnhantProtect"),
					Session.enhances,
					if N.rebirth() < 6 then '\n<font color="#fab428">Opens at rebirth 6</font>' else "",
					if N.Enhance.last ~= "" then "\n" .. N.Enhance.last else ""
				)
				I.super = string.format(
					"Runners killed <b>%d</b> this session%s%s",
					Session.superKills,
					if N.Super.last ~= "" then "\n" .. N.Super.last else "",
					(function()
						local entry = N.superList()[1]
						if entry then
							return string.format('\n<font color="#60d696">A %s runner is up on stage %d</font>', entry.rarity, entry.stage)
						end
						return "\nNo runner right now"
					end)()
				)
				do
					local season = workspace:GetAttribute("Season")
					local mine = N.store("Season")
					mine = if season and type(mine[season]) == "table" then mine[season] else {}
					I.season = string.format(
						"Season Coins <b>%s</b>  \u{00B7}  tickets <b>%d</b>\nSpins <b>%d</b>, shop buys <b>%d</b> this session",
						formatNumber(tonumber(mine.SeasonCoin) or 0),
						tonumber(mine.SeasonTicket) or 0,
						Session.seasonSpins,
						Session.shopBuys
					)
				end
				local need = N.rebirthNeed()
				I.rebirth = if need
					then string.format("Rebirth <b>%d</b>  \u{00B7}  next at level <b>%d</b> (you are %d)", N.rebirth(), need, N.level())
					else "Max rebirth reached"
				I.tower = string.format(
					"Tickets <b>%d</b>  \u{00B7}  best floor <b>%d</b>%s\nRuns this session <b>%d</b>%s",
					N.towerTickets(),
					tonumber(N.store("Dungeon").maxRound) or 0,
					(function()
						local why = N.towerWaitReason() or (if N.want("AutoTower") and N.fightMode() ~= "Dungeon" then N.Tower.waitReason else nil)
						if why == "short pause between runs" then
							why = nil
						end
						return if why then "\n<font color=\"#fab428\">Waiting: " .. why .. "</font>" else ""
					end)(),
					Session.towerRuns,
					(if N.Tower.last ~= "" then "\n" .. N.Tower.last else "") .. (if N.blatant("TowerSpeed") then "\nInstant floors: " .. N.probeText("tower_fast") else "")
				)
				I.boss = string.format(
					"%s\nFights this session <b>%d</b>%s",
					if N.bossActive() then '<font color="#60d696">World boss is up</font>' else "No world boss right now",
					Session.bossFights,
					(if N.Boss.last ~= "" then "\n" .. N.Boss.last else "") .. (if N.blatant("BossCards") then "\nEvery card: " .. N.probeText("boss_cards") else "")
				)
				I.rewards = string.format("Claimed <b>%d</b> this session%s", Session.claims, if #N.Reward.log > 0 then "\n" .. table.concat(N.Reward.log, "\n") else "")
				local index, class, rarity = N.classNow()
				I.class = string.format(
					"Slot %s: <font color=\"%s\">%s</font> %s\nRolls left <b>%d</b>%s",
					tostring(index or "?"),
					N.rarityColor(rarity),
					rarity,
					tostring(class),
					tonumber(N.store("Class").luckTimes) or 0,
					if N.ClassRoll.last ~= "" then "\n" .. N.ClassRoll.last else ""
				)
			end)
			if not ok then
				reportError("info", err)
			end
			Perf.work.info = (Perf.work.info or 0) + (os.clock() - started)
			task.wait(0.5)
		end
	end)
	-- Auto redeem known codes: once shortly after start, then every 6 hours.
	task.spawn(function()
		task.wait(20)
		while alive() do
			if on("AutoCodes") and os.clock() - N.Codes.lastRun >= 21600 then
				local ok, err = pcall(N.codesRun)
				if not ok then
					N.Codes.running = false
					N.Codes.lastRun = os.clock()
					log("ERROR", "codes", tostring(err))
				end
			end
			task.wait(10)
		end
	end)
	local function shown(tab)
		if tab == nil or Library.Toggled == false then
			return false
		end
		return Library.ActiveTab == nil or Library.ActiveTab == tab
	end
	task.spawn(function()
		local uiErrorAt = -1e9
		local function group(fn)
			local ok, err = xpcall(fn, debug.traceback)
			if not ok and os.clock() - uiErrorAt > 30 then
				uiErrorAt = os.clock()
				local lines = {}
				for line in string.gmatch(tostring(err), "[^\n]+") do
					if #lines < 6 then
						table.insert(lines, (string.gsub(line, "^%s+", "")))
					end
				end
				log("ERROR", "ui", table.concat(lines, " | "))
			end
		end
		local frame = 0
		while alive() do
			frame += 1
			local started = os.clock()
			group(UIQueue.flush)
			if frame % 3 == 0 then
				local I = N.InfoText
				if shown(Tabs.Main) then
					group(function()
						Labels.Status:SetText(Status)
						Labels.Info:SetText(I.info or "-")
						Labels.Next:SetText(I.upnext or "-")
					end)
				end
				if shown(Tabs.Farm) then
					group(function()
						Labels.Stages:SetText(I.stages or "-")
						Labels.Super:SetText(I.super or "-")
						Labels.Train:SetText(I.train or "-")
						Labels.Tower:SetText(I.tower or "-")
						Labels.Boss:SetText(I.boss or "-")
					end)
				end
				if shown(Tabs.Forge) then
					group(function()
						Labels.Forge:SetText(I.forge or "-")
						Labels.Gear:SetText(I.gear or "-")
						Labels.Sell:SetText(I.sell or "-")
					end)
				end
				if shown(Tabs.Upgrades) then
					group(function()
						Labels.Upgrades:SetText(I.upgrades or "-")
						Labels.Rebirth:SetText(I.rebirth or "-")
						Labels.Enhance:SetText(I.enhance or "-")
						Labels.Class:SetText(I.class or "-")
					end)
				end
				if shown(Tabs.Rewards) then
					group(function()
						Labels.Rewards:SetText(I.rewards or "-")
						Labels.Season:SetText(I.season or "-")
						Labels.Codes:SetText(N.codesText())
					end)
				end
				if shown(Tabs.Stats) then
					group(N.drawStats)
				end
				if Labels.Perf and shown(Tabs.Misc) then
					group(function()
						Labels.Perf:SetText(Debug.perfText())
					end)
				end
			end
			Perf.work.ui = (Perf.work.ui or 0) + (os.clock() - started)
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		local windowStart = os.clock()
		while alive() do
			task.wait(5)
			pcall(function()
				if os.clock() - windowStart >= 30 then
					local span = os.clock() - windowStart
					windowStart = os.clock()
					local hub, parts = 0, {}
					for key, seconds in pairs(Perf.work) do
						hub += seconds
						table.insert(parts, key .. " " .. math.floor(seconds * 1000) .. "ms")
					end
					table.sort(parts)
					local ping, memory = "?", "?"
					pcall(function()
						ping = tostring(math.floor(LocalPlayer:GetNetworkPing() * 1000))
					end)
					pcall(function()
						memory = tostring(math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb()))
					end)
					Perf.last = {
						fps = if Perf.time > 0 then Perf.frames / Perf.time else 0,
						worst = Perf.worst,
						hitches = Perf.hitches,
						freezes = Perf.freezes,
						hub = hub,
						span = span,
						ping = ping,
						memory = memory,
					}
					log("PERF", Debug.perfText(), "|", table.concat(parts, ", "))
					Perf.frames, Perf.time, Perf.worst, Perf.hitches, Perf.freezes = 0, 0, 0, 0, 0
					table.clear(Perf.work)
					flushLog(false)
				end
				if Log.statusAt and os.clock() - Log.statusAt > 600 and Log.stuckAt ~= Log.statusAt and anyAutoOn() then
					Log.stuckAt = Log.statusAt
					logProblem("Stuck for 10 minutes on: " .. tostring(Status))
				end
			end)
		end
	end)
	pcall(function()
		Library:Flush()
	end)
	pcall(function()
		Tabs.Main:Show()
	end)
	Library:Notify({ Title = "Success!", Description = "Lymn loaded successfully.", Duration = 4 })

	if Library.ShowWizard and not N.setupDone() then
		task.delay(1.5, function()
			if N.want("AutoStages") or N.want("AutoTrain") then
				N.markSetupDone()
				return
			end
			if alive() then
				pcall(N.openWizard)
			end
		end)
	end
end
end, debug.traceback)
Boot.LymnBooting = nil
if not BootOk then
	local report = "[Lymn] +1 Loot To Forge failed to start:\n" .. tostring(BootError)
	warn(report)
	Boot.LymnLastError = report
	local copied = pcall(setclipboard, report)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Lymn error",
			Text = if copied
				then "Hub failed to start. The error is copied, paste it to Lymn."
				else "Hub failed to start. Press F9 and send the red [Lymn] line.",
			Duration = 20,
		})
	end)
end
