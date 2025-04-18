for _, v in pairs(game:GetDescendants()) do
	if (v ~= script and v.Name ~= "BadgerService") and table.find({"Script", "ModuleScript"}, v.ClassName) then
		local src = v.Source .. "\n"
		local changes = {}
		local hasAwardBadge = false

		for line in src:gmatch("(.-)\n") do
			local indent, trimmed = line:match("^(%s*)(.-)%s*$")
			if trimmed:find("AwardBadge%(") then
				local newLine = trimmed:gsub("^(.*)AwardBadge%((.-)%)", function(_, args)
					return string.format('require(game:GetService("ServerStorage"):FindFirstChild("BadgerService")).award(%s)', args)
				end)
				table.insert(changes, indent .. newLine)
				hasAwardBadge = true
			elseif trimmed:find("BadgeAward:Fire%(") then
				local newLine = trimmed:gsub("^(.*)BadgeAward:Fire%((.-)%)", function(_, args)
					return string.format('require(game:GetService("ServerStorage"):FindFirstChild("BadgerService")).award(%s)', args)
				end)
				table.insert(changes, indent .. newLine)
				hasAwardBadge = true
			else
				table.insert(changes, line)
			end
		end

		local modifiedSrc = table.concat(changes, "\n")

		if hasAwardBadge then
			local newScript = Instance.new(v.ClassName)
			newScript.Name = v.Name
			if newScript:IsA("Script") then
				newScript.Enabled = v.Enabled
			end
			newScript.Source = modifiedSrc
			newScript.Parent = v.Parent
			for _, child in ipairs(v:GetChildren()) do
				child.Parent = newScript
			end
			v:Destroy()
			print(`ℹ️ Migrated {newScript:GetFullName()}`)
		end
	end
end

local BadgerServiceLoader = Instance.new("Script")
BadgerServiceLoader.Name = "BadgerServiceLoader"
BadgerServiceLoader.Source = "--!nocheck\nlocal ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\nlocal ServerStorage = game:GetService(\"ServerStorage\")\nlocal ServerScriptService = game:GetService(\"ServerScriptService\")\nlocal RunService = game:GetService(\"RunService\")\nlocal Players = game:GetService(\"Players\")\nlocal BadgerService = ServerStorage:FindFirstChild(\"BadgerService\")\n\n-- thanks chatgpt for this function\nfunction lerpToColor(numerator, denominator, colors)\n\tlocal percentage = math.min(numerator / denominator, 1)\n\n\tif #colors == 1 then\n\t\treturn colors[1]\n\tend\n\n\tlocal colorIndex = math.floor(percentage * (#colors - 1)) + 1\n\n\tlocal factor = (percentage * (#colors - 1)) - (colorIndex - 1)\n\n\tlocal startColor = colors[colorIndex]\n\tlocal endColor = colors[math.min(colorIndex + 1, #colors)]\n\n\tlocal r = startColor.R + (endColor.R - startColor.R) * factor\n\tlocal g = startColor.G + (endColor.G - startColor.G) * factor\n\tlocal b = startColor.B + (endColor.B - startColor.B) * factor\n\n\treturn Color3.new(r, g, b)\nend\n\n-- ty chatgpt again\nlocal function roundRobin(data: {}): {}\n\tlocal playerBuckets = {}\n\n\tfor _, entry in ipairs(data) do\n\t\tlocal playerName = entry.player.Name\n\t\tif not playerBuckets[playerName] then\n\t\t\tplayerBuckets[playerName] = {}\n\t\tend\n\t\ttable.insert(playerBuckets[playerName], entry)\n\tend\n\n\tlocal sortedPlayers = {}\n\tfor playerName in pairs(playerBuckets) do\n\t\ttable.insert(sortedPlayers, playerName)\n\tend\n\ttable.sort(sortedPlayers)\n\n\tlocal result = {}\n\tlocal remaining = true\n\n\twhile remaining do\n\t\tremaining = false\n\t\tfor _, playerName in ipairs(sortedPlayers) do\n\t\t\tif #playerBuckets[playerName] > 0 then\n\t\t\t\ttable.insert(result, table.remove(playerBuckets[playerName], 1))\n\t\t\t\tremaining = true\n\t\t\tend\n\t\tend\n\tend\n\n\treturn result\nend\n\nif BadgerService and script:IsDescendantOf(ServerScriptService) then\n\tlocal self = require(BadgerService)\n\tlocal Config = self[\"config\"]\n\n\tlocal function save(player: Player)\n\t\tif RunService:IsStudio() then\n\t\t\treturn\n\t\tend\n\t\tif player.UserId < 0 or player:GetAttribute(\"BadgerServiceKicked\") then\n\t\t\treturn\n\t\tend\n\t\tlocal queue = {}\n\t\tif Config[\"save_queue\"] then\n\t\t\tfor _, v in pairs(self.queue) do\n\t\t\t\tif v.player == player then\n\t\t\t\t\ttable.insert(queue, v.badgeId)\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\tlocal success, response = pcall(function()\n\t\t\tself.datastore:SetAsync(tostring(player.UserId), {cache = self.owned[player], queue = queue})\n\t\tend)\n\tend\n\n\tPlayers.PlayerAdded:Connect(function(player: Player)\n\t\tplayer.Chatted:Connect(function(message: string)\n\t\t\tif message:lower() == \"!wipe\" then\n\t\t\t\tplayer:SetAttribute(\"BadgerServiceKicked\", true)\n\t\t\t\tplayer:Kick(\"BadgerService cache wiped, please rejoin.\")\n\t\t\t\tself.datastore:RemoveAsync(tostring(player.UserId))\n\t\t\tend\n\t\tend)\n\n\t\tlocal success, response = pcall(function()\n\t\t\treturn self.datastore:GetAsync(tostring(player.UserId))\n\t\tend)\n\t\tself.cache[player] = (success and response and response[\"cache\"]) or {}\n\t\tself.owned[player] = (success and response and response[\"cache\"]) or {}\n\t\tif success and response ~= nil then\n\t\t\tfor _, v in pairs(response[\"queue\"] or {}) do\n\t\t\t\ttable.insert(self.queue, {player = player, badgeId = v, timestamp = time()})\n\t\t\tend\n\t\tend\n\t\tif Config[\"debugging\"] then\n\t\t\tprint(`\u{2705} Cache for {player.Name}: {#self.cache[player]}`)\n\t\tend\n\tend)\n\n\tPlayers.PlayerRemoving:Connect(save)\n\n\tgame:BindToClose(function()\n\t\tfor _, player in Players:GetPlayers() do\n\t\t\tsave(player)\n\t\tend\n\tend)\n\n\tlocal Remote = Instance.new(\"RemoteEvent\")\n\tRemote.Parent = ReplicatedStorage\n\tRemote.Name = \"BadgerServiceNotifier\"\n\n\tif Config[\"show_meter\"] then\n\t\tcoroutine.resume(coroutine.create(function()\n\t\t\twhile task.wait(0.1) do\n\t\t\t\tlocal progress = #self.done\n\t\t\t\tlocal rateLimit = self.getRateLimit()\n\n\t\t\t\tlocal show = (Config[\"hide_when_zero\"] == true and progress ~= 0) or not Config[\"hide_when_zero\"]\n\t\t\t\tlocal next_ = math.abs(math.clamp(math.round((self.done[1] or 0) - time()), 0, 60))\n\n\t\t\t\tlocal text = `Rate limit: {progress}/{rateLimit}`\n\t\t\t\t\t.. `{#self.queue > 0 and \"\u{ff5c}Queue: \" .. #self.queue or \"\"}`\n\t\t\t\t\t.. `{Config[\"show_next\"] and #self.done > 0 and next_ > 0 and \"\u{ff5c}Next: \" .. next_ .. \"s\" or \"\"}`\n\n\t\t\t\tlocal colors = Config[\"colors\"]\n\t\t\t\tlocal color = lerpToColor(progress, rateLimit, colors)\n\n\t\t\t\tRemote:FireAllClients(show, text, color)\n\t\t\tend\n\t\tend))\n\tend\n\n\tcoroutine.resume(coroutine.create(function()\n\t\twhile task.wait(0) do\n\t\t\tlocal done = self.done\n\n\t\t\tfor i = #done, 1, -1 do\n\t\t\t\tlocal check = done[i]\n\t\t\t\tif check and time() - check >= 60 then\n\t\t\t\t\ttable.remove(done, i)\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\tend))\n\n\tcoroutine.resume(coroutine.create(function()\n\t\twhile task.wait(0) do\n\t\t\tlocal queue = self.queue\n\t\t\tlocal done = self.done\n\t\t\tlocal rateLimit = self.getRateLimit()\n\n\t\t\tif #done < rateLimit then\n\t\t\t\tif #queue > 0 then\n\t\t\t\t\tlocal ready = rateLimit - #done\n\n\t\t\t\t\tlocal pool = (Config[\"share\"] and roundRobin(queue)) or queue\n\t\t\t\t\tlocal indexes = {}\n\t\t\t\t\tlocal amount = rateLimit - #done\n\n\t\t\t\t\tfor i = 1, ready do\n\t\t\t\t\t\tif pool[i] then\n\t\t\t\t\t\t\ttable.insert(indexes, table.find(queue, pool[i]))\n\t\t\t\t\t\telse\n\t\t\t\t\t\t\tbreak\n\t\t\t\t\t\tend\n\t\t\t\t\tend\n\n\t\t\t\t\ttable.sort(indexes, function(a, b)\n\t\t\t\t\t\treturn a > b\n\t\t\t\t\tend)\n\n\t\t\t\t\tlocal registered = {}\n\n\t\t\t\t\tfor i, index in pairs(indexes) do\n\t\t\t\t\t\tlocal check = queue[index]\n\t\t\t\t\t\tif check then\n\t\t\t\t\t\t\tif check.player:IsDescendantOf(Players) then\n\t\t\t\t\t\t\t\tlocal registry = `{check.player.UserId}-{check.badgeId}`\n\t\t\t\t\t\t\t\tif not table.find(registered, registry) then\n\t\t\t\t\t\t\t\t\tself.grant(check.player, check.badgeId)\n\t\t\t\t\t\t\t\t\ttable.insert(registered, registry)\n\t\t\t\t\t\t\t\t\ttable.insert(done, time() + 60)\n\t\t\t\t\t\t\t\tend\n\t\t\t\t\t\t\tend\n\t\t\t\t\t\t\ttable.remove(queue, index)\n\t\t\t\t\t\tend\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\n\t\t\tfor i = #queue, 1, -1 do\n\t\t\t\tlocal check = queue[i]\n\t\t\t\tif check then\n\t\t\t\t\tif not check.player:IsDescendantOf(Players) then\n\t\t\t\t\t\ttable.remove(queue, i)\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\tend))\n\n\tcoroutine.resume(coroutine.create(function()\n\t\twhile task.wait(60) do\n\t\t\tfor _, player in Players:GetPlayers() do\n\t\t\t\tsave(player)\n\t\t\tend\n\t\tend\n\tend))\nelse\n\twarn(\"I have no idea how you failed to follow basic instructions but BadgerService isn't set up properly so um fix that please\")\nend\n"

BadgerServiceLoader.Parent = game:GetService("ServerScriptService")

local BadgerService = Instance.new("ModuleScript")
BadgerService.Name = "BadgerService"
BadgerService.Source = "--!nocheck\nlocal BadgeService = game:GetService(\"BadgeService\")\nlocal DataStoreService = game:GetService(\"DataStoreService\")\nlocal DataStore = DataStoreService:GetDataStore(\"BadgerService-INKTHIRSTY\")\nlocal Players = game:GetService(\"Players\")\n\ntype queue_entry = {player: Player, badgeId: number, timestamp: number}\n\ntype handler_ = {\n\tconfig: any,\n\tcache: {[string]: {[number]: number}},\n\towned: {[string]: {[number]: number}},\n\tqueue: {[number]: queue_entry},\n\tdone: {[number]: any},\n\tgetRateLimit: () -> number,\n\tcheck: () -> boolean | nil,\n\tappend: () -> (),\n\taward: () -> (),\n\tgrant: () -> (),\n\tdatastore: DataStore\n}\n\nlocal Config = require(script.Config)\n\nlocal handler: handler_ = {\n\tconfig = Config,\n\tcache = {},\n\towned = {},\n\tqueue = {},\n\tdone = {},\n\tdatastore = DataStore\n}\n\nfunction handler.getRateLimit()\n\treturn 50 + 35 * #Players:GetPlayers()\nend\n\nfunction handler.check(player: Player, badgeId: number): boolean\n\tlocal userId = tostring(player.UserId)\n\tif table.find(handler.cache[player], badgeId) then\n\t\tif Config[\"debugging\"] then\n\t\t\tprint(`\u{274c} {badgeId} already in cache`)\n\t\tend\n\t\treturn true\n\telse\n\t\tif not table.find(handler.cache[player], badgeId) then\n\t\t\tif Config[\"debugging\"] then\n\t\t\t\tprint(`\u{2705} Added {badgeId} to cache`)\n\t\t\tend\n\t\t\ttable.insert(handler.cache[player], badgeId)\n\t\tend\n\t\tif Config[\"check_for_ownership\"] then\n\t\t\tlocal success, result = pcall(function()\n\t\t\t\t-- harsh rate limit but I add this anyway\n\t\t\t\treturn BadgeService:UserHasBadgeAsync(player.UserId, badgeId)\n\t\t\tend)\n\t\t\tif success and result == true then\n\t\t\t\tif not table.find(handler.owned[player], badgeId) then\n\t\t\t\t\tif Config[\"debugging\"] then\n\t\t\t\t\t\tprint(`\u{2705} Added {badgeId} to owned`)\n\t\t\t\t\tend\n\t\t\t\t\ttable.insert(handler.owned[player], badgeId)\n\t\t\t\tend\n\t\t\t\treturn true\n\t\t\tend\n\t\tend\n\tend\n\treturn false\nend\n\nfunction handler.append(player: Player, badgeId: number): ()\n\t-- check if they own badge before doing this\n\tlocal check = handler.check(player, badgeId)\n\tif not check then\n\t\tlocal entry: queue_entry = {\n\t\t\tplayer = player,\n\t\t\tbadgeId = badgeId,\n\t\t\ttimestamp = time()\n\t\t}\n\t\ttable.insert(handler.queue, entry)\n\tend\nend\n\nfunction search(name: string): Player\n\tfor _, player in pairs(Players:GetPlayers()) do\n\t\tif player.Name:lower() == name:lower() then\n\t\t\treturn player\n\t\tend\n\tend\n\treturn\nend\n\nfunction handler.award(player: Player | any, badgeId: number): ()\n\tplayer = (typeof(player) == \"Instance\" and player) or (typeof(player) ~= \"Instance\" and Players:GetPlayerByUserId(player)) or search(player)\n\tif not player then\n\t\twarn(\"\u{26a0}\u{fe0f} Player not found!\")\n\t\treturn\n\tend\n\tif not handler.cache[player] then\n\t\tif Config[\"debugging\"] then\n\t\t\tprint(`\u{26a0}\u{fe0f} Cache for {player.Name} not found!`)\n\t\tend\n\t\trepeat task.wait() until handler.cache[player] or not player:IsDescendantOf(Players)\n\tend\n\tif player:IsDescendantOf(Players) then\n\t\thandler.append(player, badgeId)\n\tend\nend\n\nfunction handler.grant(player: Player, badgeId: number): ()\n\ttask.spawn(function()\n\t\tlocal success, response = pcall(function()\n\t\t\tBadgeService:AwardBadge(player.UserId, badgeId)\n\t\tend)\n\t\tif success then\n\t\t\tlocal cache = handler.owned[player]\n\t\t\tif not table.find(cache, badgeId) then\n\t\t\t\tif Config[\"debugging\"] then\n\t\t\t\t\tprint(`\u{2705} Added {badgeId} to owned`)\n\t\t\t\tend\n\t\t\t\ttable.insert(cache, badgeId)\n\t\t\tend\n\t\telse\n\t\t\twarn(response)\n\t\t\tlocal entry: queue_entry = {\n\t\t\t\tplayer = player,\n\t\t\t\tbadgeId = badgeId,\n\t\t\t\ttimestamp = time()\n\t\t\t}\n\t\t\ttable.insert(handler.queue, entry)\n\t\tend\n\tend)\nend\n\nreturn handler\n-- sorry karen u get the handler not the manager"

local Config = Instance.new("ModuleScript")
Config.Name = "Config"
Config.Source = "--!strict\ntype conf = {\n\tcolors: {[number]: Color3}?,\n}\n\nlocal config: conf = {\n\tsave_queue = true, -- save unawarded badges to a queue so the player can get them when rejoining\n\tshow_meter = true, -- show the rate limit meter on screens (or you could just delete the notifier)\n\thide_when_zero = true, -- hide when rate limit is 0\n\tshare = true, -- distribute badges equally (look up \"round robin\" if you don't understand)\n\tdebugging = false, -- I only added this for myself but you're adding this to a badge walk, 90% of your game is prints\n\tcheck_for_ownership = false, -- check if the user has the badge before attempting to award, I would only recommend turning this on if you're migrating\n\tshow_next = true, -- timer for next badge availability\n\tcolors = { -- this is just for the progress meter\n\t\tColor3.fromRGB(46, 204, 113),\n\t\tColor3.fromRGB(241, 196, 15),\n\t\tColor3.fromRGB(230, 126, 34),\n\t\tColor3.fromRGB(231, 54, 54),\n\t},\n}\n\nreturn config"
Config.Parent = BadgerService

BadgerService.Parent = game:GetService("ServerStorage")

local RATELIMITNOTIFIER = Instance.new("ScreenGui")
RATELIMITNOTIFIER.Name = "RATE LIMIT NOTIFIER"
RATELIMITNOTIFIER.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
RATELIMITNOTIFIER.ResetOnSpawn = false

local TextLabel = Instance.new("TextLabel")
TextLabel.AnchorPoint = Vector2.new(0.5, 1)
TextLabel.Size = UDim2.new(1, 0, 0.04, 0)
TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.BackgroundTransparency = 1
TextLabel.Position = UDim2.new(0.5, 0, 1, 0)
TextLabel.BorderSizePixel = 0
TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.FontSize = Enum.FontSize.Size14
TextLabel.TextSize = 14
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.Text = "Rate limit: 0/85"
TextLabel.TextWrapped = true
TextLabel.TextWrap = true
TextLabel.Font = Enum.Font.Montserrat
TextLabel.TextScaled = true
TextLabel.Parent = RATELIMITNOTIFIER

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2
UIStroke.Parent = TextLabel

local UITextSizeConstraint = Instance.new("UITextSizeConstraint")
UITextSizeConstraint.MaxTextSize = 40
UITextSizeConstraint.Parent = TextLabel

local LocalScript = Instance.new("LocalScript")
LocalScript.Source = "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\n\nlocal Remote: RemoteEvent = ReplicatedStorage:WaitForChild(\"BadgerServiceNotifier\")\n\nlocal ui = script.Parent\nlocal label = script.Parent.TextLabel\n\nui.Enabled = false\n\nRemote.OnClientEvent:Connect(function(show: boolean, text: string, color: Color3)\n\tlabel.Text = text\n\tlabel.TextColor3 = color\n\tui.Enabled = show\nend)"
LocalScript.Parent = RATELIMITNOTIFIER

RATELIMITNOTIFIER.Parent = game:GetService("StarterGui")

print("✅ BadgerService successfully installed")
