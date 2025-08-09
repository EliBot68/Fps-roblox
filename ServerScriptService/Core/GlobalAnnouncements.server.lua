-- GlobalAnnouncements.server.lua
-- Global announcements using MessagingService

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Logging = require(ReplicatedStorage.Shared.Logging)

local GlobalAnnouncements = {}

-- DataStore for persistent announcements
local announcementsStore = DataStoreService:GetDataStore("GlobalAnnouncements")

-- Local announcement cache
local activeAnnouncements = {}

-- RemoteEvent for client notifications
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local AnnouncementRemote = Instance.new("RemoteEvent")
AnnouncementRemote.Name = "AnnouncementRemote"
AnnouncementRemote.Parent = RemoteRoot

-- Announcement types and styling
local ANNOUNCEMENT_TYPES = {
	info = { color = Color3.fromRGB(100, 150, 255), icon = "ℹ️" },
	warning = { color = Color3.fromRGB(255, 200, 100), icon = "⚠️" },
	event = { color = Color3.fromRGB(150, 255, 100), icon = "🎉" },
	maintenance = { color = Color3.fromRGB(255, 100, 100), icon = "🔧" },
	update = { color = Color3.fromRGB(200, 100, 255), icon = "🆕" }
}

function GlobalAnnouncements.CreateAnnouncement(config)
	local announcement = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		title = config.title or "Announcement",
		message = config.message or "",
		type = config.type or "info",
		priority = config.priority or 1, -- 1=low, 2=normal, 3=high, 4=critical
		duration = config.duration or 10, -- seconds to display
		targetAudience = config.targetAudience or "all", -- all, premium, ranked, etc.
		startTime = config.startTime or os.time(),
		endTime = config.endTime or (os.time() + 86400), -- 24 hours default
		persistent = config.persistent or false, -- Show to players who join later
		serverBroadcast = config.serverBroadcast or true, -- Broadcast to all servers
		created = os.time(),
		creator = config.creator or "System"
	}
	
	-- Validate announcement type
	if not ANNOUNCEMENT_TYPES[announcement.type] then
		announcement.type = "info"
	end
	
	-- Store persistently if needed
	if announcement.persistent then
		pcall(function()
			announcementsStore:SetAsync(announcement.id, announcement)
		end)
	end
	
	-- Add to local cache
	activeAnnouncements[announcement.id] = announcement
	
	-- Broadcast to all servers if enabled
	if announcement.serverBroadcast then
		GlobalAnnouncements.BroadcastToAllServers(announcement)
	else
		-- Just send to current server
		GlobalAnnouncements.SendToServer(announcement)
	end
	
	Logging.Event("AnnouncementCreated", {
		id = announcement.id,
		type = announcement.type,
		priority = announcement.priority,
		audience = announcement.targetAudience
	})
	
	return announcement
end

function GlobalAnnouncements.BroadcastToAllServers(announcement)
	local message = {
		type = "GlobalAnnouncement",
		data = announcement
	}
	
	pcall(function()
		MessagingService:PublishAsync("GlobalAnnouncements", message)
	end)
end

function GlobalAnnouncements.SendToServer(announcement)
	-- Filter players based on target audience
	local targetPlayers = GlobalAnnouncements.GetTargetPlayers(announcement.targetAudience)
	
	-- Send to each target player
	for _, player in ipairs(targetPlayers) do
		AnnouncementRemote:FireClient(player, "NewAnnouncement", {
			announcement = announcement,
			styling = ANNOUNCEMENT_TYPES[announcement.type]
		})
	end
	
	Logging.Event("AnnouncementSent", {
		id = announcement.id,
		recipients = #targetPlayers
	})
end

function GlobalAnnouncements.GetTargetPlayers(audience)
	local players = {}
	
	for _, player in ipairs(Players:GetPlayers()) do
		local include = false
		
		if audience == "all" then
			include = true
		elseif audience == "premium" then
			include = player.MembershipType == Enum.MembershipType.Premium
		elseif audience == "new" then
			-- Players with accounts less than 30 days old
			include = player.AccountAge < 30
		elseif audience == "ranked" then
			-- Players who have played ranked matches
			-- Would integrate with RankManager
			include = true -- Placeholder
		elseif audience == "high_rank" then
			-- High-ranked players only
			-- Would check player rank
			include = false -- Placeholder
		elseif audience == "staff" then
			-- Staff members only
			include = player:GetRankInGroup(0) >= 100 -- Placeholder
		end
		
		if include then
			table.insert(players, player)
		end
	end
	
	return players
end

function GlobalAnnouncements.RemoveAnnouncement(announcementId)
	local announcement = activeAnnouncements[announcementId]
	if not announcement then return false end
	
	-- Remove from cache
	activeAnnouncements[announcementId] = nil
	
	-- Remove from persistent store
	if announcement.persistent then
		pcall(function()
			announcementsStore:RemoveAsync(announcementId)
		end)
	end
	
	-- Notify clients to remove announcement
	for _, player in ipairs(Players:GetPlayers()) do
		AnnouncementRemote:FireClient(player, "RemoveAnnouncement", announcementId)
	end
	
	Logging.Event("AnnouncementRemoved", { id = announcementId })
	return true
end

function GlobalAnnouncements.LoadPersistentAnnouncements()
	-- Load persistent announcements from DataStore
	local success, result = pcall(function()
		return announcementsStore:ListKeysAsync("", 100)
	end)
	
	if not success then return end
	
	local items = result:GetCurrentPage()
	for _, item in ipairs(items) do
		local success, announcement = pcall(function()
			return announcementsStore:GetAsync(item.KeyName)
		end)
		
		if success and announcement then
			-- Check if announcement is still active
			local now = os.time()
			if now >= announcement.startTime and now <= announcement.endTime then
				activeAnnouncements[announcement.id] = announcement
			elseif now > announcement.endTime then
				-- Clean up expired announcements
				pcall(function()
					announcementsStore:RemoveAsync(item.KeyName)
				end)
			end
		end
	end
end

function GlobalAnnouncements.SendWelcomeAnnouncements(player)
	-- Send persistent announcements to newly joined players
	for _, announcement in pairs(activeAnnouncements) do
		if announcement.persistent then
			local targetPlayers = GlobalAnnouncements.GetTargetPlayers(announcement.targetAudience)
			if table.find(targetPlayers, player) then
				AnnouncementRemote:FireClient(player, "NewAnnouncement", {
					announcement = announcement,
					styling = ANNOUNCEMENT_TYPES[announcement.type]
				})
			end
		end
	end
end

-- Listen for cross-server announcements
local function onAnnouncementMessage(message)
	if message.Data and message.Data.type == "GlobalAnnouncement" then
		local announcement = message.Data.data
		activeAnnouncements[announcement.id] = announcement
		GlobalAnnouncements.SendToServer(announcement)
	end
end

pcall(function()
	MessagingService:SubscribeAsync("GlobalAnnouncements", onAnnouncementMessage)
end)

-- Send announcements to new players
Players.PlayerAdded:Connect(function(player)
	-- Small delay to ensure client is ready
	wait(2)
	GlobalAnnouncements.SendWelcomeAnnouncements(player)
end)

-- Handle client requests
AnnouncementRemote.OnServerEvent:Connect(function(player, action, data)
	-- Only allow admins to manage announcements
	if player:GetRankInGroup(0) < 100 then return end
	
	if action == "CreateAnnouncement" then
		local announcement = GlobalAnnouncements.CreateAnnouncement(data)
		AnnouncementRemote:FireClient(player, "AnnouncementCreated", announcement)
	elseif action == "RemoveAnnouncement" then
		local success = GlobalAnnouncements.RemoveAnnouncement(data.id)
		AnnouncementRemote:FireClient(player, "AnnouncementRemoved", { success = success, id = data.id })
	elseif action == "GetActiveAnnouncements" then
		AnnouncementRemote:FireClient(player, "ActiveAnnouncements", activeAnnouncements)
	end
end)

-- Clean up expired announcements periodically
local function cleanupExpiredAnnouncements()
	local now = os.time()
	local toRemove = {}
	
	for id, announcement in pairs(activeAnnouncements) do
		if now > announcement.endTime then
			table.insert(toRemove, id)
		end
	end
	
	for _, id in ipairs(toRemove) do
		GlobalAnnouncements.RemoveAnnouncement(id)
	end
end

-- Run cleanup every 5 minutes
spawn(function()
	while true do
		wait(300)
		cleanupExpiredAnnouncements()
	end
end)

-- Load persistent announcements on startup
GlobalAnnouncements.LoadPersistentAnnouncements()

-- Predefined system announcements
function GlobalAnnouncements.SystemMaintenance(startTime, duration)
	return GlobalAnnouncements.CreateAnnouncement({
		title = "Scheduled Maintenance",
		message = "Server maintenance scheduled. Expect brief disconnections.",
		type = "maintenance",
		priority = 4,
		duration = 15,
		startTime = startTime,
		endTime = startTime + duration,
		persistent = true,
		targetAudience = "all"
	})
end

function GlobalAnnouncements.NewFeature(featureName, description)
	return GlobalAnnouncements.CreateAnnouncement({
		title = "New Feature: " .. featureName,
		message = description,
		type = "update",
		priority = 2,
		duration = 12,
		persistent = true,
		targetAudience = "all"
	})
end

function GlobalAnnouncements.SeasonalEvent(eventName, details)
	return GlobalAnnouncements.CreateAnnouncement({
		title = "🎉 " .. eventName,
		message = details,
		type = "event",
		priority = 3,
		duration = 15,
		persistent = true,
		targetAudience = "all"
	})
end

return GlobalAnnouncements
