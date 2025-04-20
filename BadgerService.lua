--!nocheck
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local DataStore = DataStoreService:GetDataStore("BadgerService-INKTHIRSTY")
local Players = game:GetService("Players")

type queue_entry = {player: Player, badgeId: number, timestamp: number}

type handler_ = {
	config: any,
	cache: {[string]: {[number]: number}},
	owned: {[string]: {[number]: number}},
	queue: {[number]: queue_entry},
	done: {[number]: any},
	getRateLimit: () -> number,
	check: () -> boolean | nil,
	append: () -> (),
	award: () -> (),
	grant: () -> (),
	datastore: DataStore
}

local Config = require(script.Config)

local handler: handler_ = {
	config = Config,
	cache = {},
	owned = {},
	queue = {},
	done = {},
	datastore = DataStore
}

function handler.getRateLimit()
	return 50 + 35 * #Players:GetPlayers()
end

function handler.check(player: Player, badgeId: number): boolean
	local userId = tostring(player.UserId)
	if table.find(handler.cache[player], badgeId) then
		if Config["debugging"] then
			print(`❌ {badgeId} already in cache`)
		end
		return true
	else
		if not table.find(handler.cache[player], badgeId) then
			if Config["debugging"] then
				print(`✅ Added {badgeId} to cache`)
			end
			table.insert(handler.cache[player], badgeId)
		end
		if Config["check_for_ownership"] then
			local success, result = pcall(function()
				-- harsh rate limit but I add this anyway
				return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
			end)
			if success and result == true then
				if not table.find(handler.owned[player], badgeId) then
					if Config["debugging"] then
						print(`✅ Added {badgeId} to owned`)
					end
					table.insert(handler.owned[player], badgeId)
				end
				return true
			end
		end
	end
	return false
end

function handler.append(player: Player, badgeId: number): ()
	-- check if they own badge before doing this
	local check = handler.check(player, badgeId)
	if not check then
		local entry: queue_entry = {
			player = player,
			badgeId = badgeId,
			timestamp = time()
		}
		table.insert(handler.queue, entry)
	end
end

function search(name: string): Player
	for _, player in pairs(Players:GetPlayers()) do
		if player.Name:lower() == name:lower() then
			return player
		end
	end
	return
end

function handler.award(player: Player | any, badgeId: number): ()
	player = (typeof(player) == "Instance" and player) or (typeof(player) ~= "Instance" and Players:GetPlayerByUserId(player)) or search(player)
	if not player then
		warn("⚠️ Player not found!")
		return
	end
	if not handler.cache[player] then
		if Config["debugging"] then
			print(`⚠️ Cache for {player.Name} not found!`)
		end
		repeat task.wait() until handler.cache[player] or not player:IsDescendantOf(Players)
	end
	if player:IsDescendantOf(Players) then
		handler.append(player, badgeId)
	end
end

function handler.grant(player: Player, badgeId: number): ()
	task.spawn(function()
		local success, response = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if success then
			local cache = handler.owned[player]
			if not table.find(cache, badgeId) then
				if Config["debugging"] then
					print(`✅ Added {badgeId} to owned`)
				end
				table.insert(cache, badgeId)
			end
		else
			warn(response)
			local entry: queue_entry = {
				player = player,
				badgeId = badgeId,
				timestamp = time()
			}
			table.insert(handler.queue, entry)
		end
	end)
end

handler.__index = handler
return setmetatable({}, handler)
-- sorry karen u get the handler not the manager
