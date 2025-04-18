--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local BadgerService = ServerStorage:FindFirstChild("BadgerService")

-- thanks chatgpt for this function
function lerpToColor(numerator, denominator, colors)
	local percentage = math.min(numerator / denominator, 1)

	if #colors == 1 then
		return colors[1]
	end

	local colorIndex = math.floor(percentage * (#colors - 1)) + 1

	local factor = (percentage * (#colors - 1)) - (colorIndex - 1)

	local startColor = colors[colorIndex]
	local endColor = colors[math.min(colorIndex + 1, #colors)]

	local r = startColor.R + (endColor.R - startColor.R) * factor
	local g = startColor.G + (endColor.G - startColor.G) * factor
	local b = startColor.B + (endColor.B - startColor.B) * factor

	return Color3.new(r, g, b)
end

-- ty chatgpt again
local function roundRobin(data: {}): {}
	local playerBuckets = {}

	for _, entry in ipairs(data) do
		local playerName = entry.player.Name
		if not playerBuckets[playerName] then
			playerBuckets[playerName] = {}
		end
		table.insert(playerBuckets[playerName], entry)
	end

	local sortedPlayers = {}
	for playerName in pairs(playerBuckets) do
		table.insert(sortedPlayers, playerName)
	end
	table.sort(sortedPlayers)

	local result = {}
	local remaining = true

	while remaining do
		remaining = false
		for _, playerName in ipairs(sortedPlayers) do
			if #playerBuckets[playerName] > 0 then
				table.insert(result, table.remove(playerBuckets[playerName], 1))
				remaining = true
			end
		end
	end

	return result
end

if BadgerService and script:IsDescendantOf(ServerScriptService) then
	local self = require(BadgerService)
	local Config = self["config"]

	local function save(player: Player)
		if RunService:IsStudio() then
			return
		end
		if player.UserId < 0 or player:GetAttribute("BadgerServiceKicked") then
			return
		end
		local queue = {}
		if Config["save_queue"] then
			for _, v in pairs(self.queue) do
				if v.player == player then
					table.insert(queue, v.badgeId)
				end
			end
		end
		local success, response = pcall(function()
			self.datastore:SetAsync(tostring(player.UserId), {cache = self.owned[player], queue = queue})
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		player.Chatted:Connect(function(message: string)
			if message:lower() == "!wipe" then
				player:SetAttribute("BadgerServiceKicked", true)
				player:Kick("BadgerService cache wiped, please rejoin.")
				self.datastore:RemoveAsync(tostring(player.UserId))
			end
		end)

		local success, response = pcall(function()
			return self.datastore:GetAsync(tostring(player.UserId))
		end)
		self.cache[player] = (success and response and response["cache"]) or {}
		self.owned[player] = (success and response and response["cache"]) or {}
		if success and response ~= nil then
			for _, v in pairs(response["queue"] or {}) do
				table.insert(self.queue, {player = player, badgeId = v, timestamp = time()})
			end
		end
		if Config["debugging"] then
			print(`✅ Cache for {player.Name}: {#self.cache[player]}`)
		end
	end)

	Players.PlayerRemoving:Connect(save)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	local Remote = Instance.new("RemoteEvent")
	Remote.Parent = ReplicatedStorage
	Remote.Name = "BadgerServiceNotifier"

	if Config["show_meter"] then
		coroutine.resume(coroutine.create(function()
			while task.wait(0.1) do
				local progress = #self.done
				local rateLimit = self.getRateLimit()

				local show = (Config["hide_when_zero"] == true and progress ~= 0) or not Config["hide_when_zero"]
				local next_ = math.abs(math.clamp(math.round((self.done[1] or 0) - time()), 0, 60))

				local text = `Rate limit: {progress}/{rateLimit}`
					.. `{#self.queue > 0 and "｜Queue: " .. #self.queue or ""}`
					.. `{Config["show_next"] and #self.done > 0 and next_ > 0 and "｜Next: " .. next_ .. "s" or ""}`

				local colors = Config["colors"]
				local color = lerpToColor(progress, rateLimit, colors)

				Remote:FireAllClients(show, text, color)
			end
		end))
	end

	coroutine.resume(coroutine.create(function()
		while task.wait(0) do
			local done = self.done

			for i = #done, 1, -1 do
				local check = done[i]
				if check and time() - check >= 60 then
					table.remove(done, i)
				end
			end
		end
	end))

	coroutine.resume(coroutine.create(function()
		while task.wait(0) do
			local queue = self.queue
			local done = self.done
			local rateLimit = self.getRateLimit()

			if #done < rateLimit then
				if #queue > 0 then
					local ready = rateLimit - #done

					local pool = (Config["share"] and roundRobin(queue)) or queue
					local indexes = {}
					local amount = rateLimit - #done

					for i = 1, ready do
						if pool[i] then
							table.insert(indexes, table.find(queue, pool[i]))
						else
							break
						end
					end

					table.sort(indexes, function(a, b)
						return a > b
					end)

					local registered = {}

					for i, index in pairs(indexes) do
						local check = queue[index]
						if check then
							if check.player:IsDescendantOf(Players) then
								local registry = `{check.player.UserId}-{check.badgeId}`
								if not table.find(registered, registry) then
									self.grant(check.player, check.badgeId)
									table.insert(registered, registry)
									table.insert(done, time() + 60)
								end
							end
							table.remove(queue, index)
						end
					end
				end
			end

			for i = #queue, 1, -1 do
				local check = queue[i]
				if check then
					if not check.player:IsDescendantOf(Players) then
						table.remove(queue, i)
					end
				end
			end
		end
	end))

	coroutine.resume(coroutine.create(function()
		while task.wait(60) do
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end))
else
	warn("I have no idea how you failed to follow basic instructions but BadgerService isn't set up properly so um fix that please")
end
