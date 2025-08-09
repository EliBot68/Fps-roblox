-- AdminReviewTool.server.lua
-- Admin review tooling for match replays and anti-cheat

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchRecording = require(script.Parent.MatchRecording)
local AntiCheat = require(script.Parent.AntiCheat)
local Logging = require(ReplicatedStorage.Shared.Logging)

local AdminReviewTool = {}

-- DataStores
local reviewStore = DataStoreService:GetDataStore("AdminReviews")
local punishmentStore = DataStoreService:GetDataStore("AdminPunishments")

-- Admin permissions
local ADMIN_RANKS = {
	moderator = 100,
	admin = 200,
	super_admin = 300
}

local REVIEW_ACTIONS = {
	"no_action",
	"warning",
	"temporary_ban", 
	"permanent_ban",
	"shadowban",
	"reset_stats"
}

-- RemoteEvents
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local AdminRemote = Instance.new("RemoteEvent")
AdminRemote.Name = "AdminRemote"
AdminRemote.Parent = RemoteRoot

function AdminReviewTool.IsAdmin(player)
	-- Check if player has admin permissions
	local rank = player:GetRankInGroup(0) -- Placeholder group check
	return rank >= ADMIN_RANKS.moderator
end

function AdminReviewTool.GetAdminLevel(player)
	local rank = player:GetRankInGroup(0)
	
	if rank >= ADMIN_RANKS.super_admin then
		return "super_admin"
	elseif rank >= ADMIN_RANKS.admin then
		return "admin"
	elseif rank >= ADMIN_RANKS.moderator then
		return "moderator"
	else
		return "none"
	end
end

function AdminReviewTool.GetPendingReviews(adminPlayer, filters)
	if not AdminReviewTool.IsAdmin(adminPlayer) then
		return {}
	end
	
	filters = filters or {}
	local reviews = {}
	
	-- Get suspicious matches from MatchRecording
	local suspiciousMatches = MatchRecording.GetSuspiciousMatches(50)
	
	for _, match in ipairs(suspiciousMatches) do
		if not match.flags.adminReviewed then
			local review = {
				id = match.id,
				type = "suspicious_match",
				priority = AdminReviewTool.CalculatePriority(match),
				data = {
					matchId = match.id,
					duration = match.duration,
					playerCount = #match.players,
					flags = match.flags,
					created = match.startTime
				},
				status = "pending"
			}
			
			-- Apply filters
			if AdminReviewTool.MatchesFilters(review, filters) then
				table.insert(reviews, review)
			end
		end
	end
	
	-- Sort by priority
	table.sort(reviews, function(a, b) return a.priority > b.priority end)
	
	return reviews
end

function AdminReviewTool.CalculatePriority(match)
	local priority = 0
	
	-- Base priority factors
	if match.flags.suspicious then
		priority = priority + 50
	end
	
	-- Check player statistics for severity
	for _, playerData in pairs(match.players) do
		if playerData.flags.aimbotSuspected then
			priority = priority + 30
		end
		if playerData.flags.speedHacking then
			priority = priority + 25
		end
		if playerData.flags.highAccuracy then
			priority = priority + 15
		end
		
		-- High kill/death ratios
		if playerData.statistics.kdr > 10 then
			priority = priority + 20
		end
		
		-- Unrealistic accuracy
		if playerData.statistics.accuracy > 90 then
			priority = priority + 25
		end
	end
	
	-- Time factor (older reports get slightly higher priority)
	local age = os.time() - match.startTime
	priority = priority + math.min(age / 3600, 10) -- Max 10 points for age
	
	return priority
end

function AdminReviewTool.MatchesFilters(review, filters)
	if filters.type and review.type ~= filters.type then
		return false
	end
	
	if filters.minPriority and review.priority < filters.minPriority then
		return false
	end
	
	if filters.maxAge then
		local age = os.time() - review.data.created
		if age > filters.maxAge then
			return false
		end
	end
	
	return true
end

function AdminReviewTool.GetMatchDetails(matchId)
	local match = MatchRecording.GetMatch(matchId)
	if not match then
		return nil
	end
	
	-- Enhance match data with analysis
	local analysis = AdminReviewTool.AnalyzeMatch(match)
	
	return {
		match = match,
		analysis = analysis,
		playerProfiles = AdminReviewTool.GetPlayerProfiles(match.players),
		timeline = AdminReviewTool.CreateMatchTimeline(match)
	}
end

function AdminReviewTool.AnalyzeMatch(match)
	local analysis = {
		overallSuspicionLevel = 0,
		suspiciousPlayers = {},
		anomalies = {},
		recommendations = {}
	}
	
	-- Analyze each player
	for userId, playerData in pairs(match.players) do
		local playerAnalysis = AdminReviewTool.AnalyzePlayer(playerData)
		
		if playerAnalysis.suspicionLevel > 0.7 then
			table.insert(analysis.suspiciousPlayers, {
				userId = userId,
				name = playerData.name,
				suspicionLevel = playerAnalysis.suspicionLevel,
				reasons = playerAnalysis.reasons
			})
		end
		
		analysis.overallSuspicionLevel = analysis.overallSuspicionLevel + playerAnalysis.suspicionLevel
	end
	
	-- Normalize overall suspicion
	analysis.overallSuspicionLevel = analysis.overallSuspicionLevel / #match.players
	
	-- Generate recommendations
	if analysis.overallSuspicionLevel > 0.8 then
		table.insert(analysis.recommendations, "Immediate investigation recommended")
	elseif analysis.overallSuspicionLevel > 0.6 then
		table.insert(analysis.recommendations, "Monitor players in future matches")
	end
	
	if #analysis.suspiciousPlayers > 0 then
		table.insert(analysis.recommendations, "Review individual player statistics")
	end
	
	return analysis
end

function AdminReviewTool.AnalyzePlayer(playerData)
	local analysis = {
		suspicionLevel = 0,
		reasons = {}
	}
	
	local stats = playerData.statistics
	
	-- Accuracy analysis
	if stats.accuracy > 95 and stats.shots > 20 then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.4
		table.insert(analysis.reasons, "Unrealistic accuracy: " .. math.floor(stats.accuracy) .. "%")
	elseif stats.accuracy > 85 and stats.shots > 50 then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.3
		table.insert(analysis.reasons, "Very high accuracy: " .. math.floor(stats.accuracy) .. "%")
	end
	
	-- Kill/death ratio analysis
	if stats.kdr > 20 then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.4
		table.insert(analysis.reasons, "Extreme K/D ratio: " .. math.floor(stats.kdr * 100) / 100)
	elseif stats.kdr > 10 then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.2
		table.insert(analysis.reasons, "Very high K/D ratio: " .. math.floor(stats.kdr * 100) / 100)
	end
	
	-- Headshot percentage
	if stats.headshots > stats.kills * 0.8 and stats.kills > 5 then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.3
		table.insert(analysis.reasons, "Extremely high headshot percentage")
	end
	
	-- Movement analysis (if available)
	if playerData.flags.speedHacking then
		analysis.suspicionLevel = analysis.suspicionLevel + 0.5
		table.insert(analysis.reasons, "Suspicious movement patterns detected")
	end
	
	-- Cap at 1.0
	analysis.suspicionLevel = math.min(analysis.suspicionLevel, 1.0)
	
	return analysis
end

function AdminReviewTool.GetPlayerProfiles(players)
	local profiles = {}
	
	for userId, playerData in pairs(players) do
		-- This would integrate with player statistics system
		profiles[userId] = {
			name = playerData.name,
			accountAge = 0, -- Would get from player data
			totalMatches = 0,
			overallKDR = 0,
			overallAccuracy = 0,
			previousFlags = {},
			joinDate = 0
		}
	end
	
	return profiles
end

function AdminReviewTool.CreateMatchTimeline(match)
	local timeline = {}
	
	-- Sort events by timestamp
	local events = {}
	for _, event in ipairs(match.events) do
		table.insert(events, event)
	end
	
	table.sort(events, function(a, b) return a.timestamp < b.timestamp end)
	
	-- Create timeline entries
	for _, event in ipairs(events) do
		table.insert(timeline, {
			time = event.timestamp,
			type = event.type,
			description = AdminReviewTool.FormatEventDescription(event),
			suspicion = AdminReviewTool.GetEventSuspicionLevel(event)
		})
	end
	
	return timeline
end

function AdminReviewTool.FormatEventDescription(event)
	if event.type == "player_kill" then
		return string.format("Player killed another player with %s", event.data.weapon or "unknown weapon")
	elseif event.type == "weapon_fire" then
		return "Player fired weapon"
	elseif event.type == "weapon_hit" then
		return string.format("Player hit target for %d damage", event.data.damage or 0)
	else
		return "Unknown event"
	end
end

function AdminReviewTool.GetEventSuspicionLevel(event)
	-- Return suspicion level for specific events
	if event.type == "weapon_hit" and event.data.headshot then
		return 0.2 -- Headshots are slightly suspicious in aggregate
	end
	
	return 0
end

function AdminReviewTool.SubmitReview(adminPlayer, reviewData)
	if not AdminReviewTool.IsAdmin(adminPlayer) then
		return false, "Insufficient permissions"
	end
	
	local adminLevel = AdminReviewTool.GetAdminLevel(adminPlayer)
	local action = reviewData.action
	
	-- Check if admin has permission for this action
	if not AdminReviewTool.CanPerformAction(adminLevel, action) then
		return false, "Insufficient permissions for this action"
	end
	
	-- Create review record
	local review = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		matchId = reviewData.matchId,
		adminId = adminPlayer.UserId,
		adminName = adminPlayer.Name,
		adminLevel = adminLevel,
		action = action,
		targetPlayer = reviewData.targetPlayer,
		reason = reviewData.reason or "",
		evidence = reviewData.evidence or {},
		timestamp = os.time(),
		notes = reviewData.notes or ""
	}
	
	-- Save review
	pcall(function()
		reviewStore:SetAsync(review.id, review)
	end)
	
	-- Execute punishment if applicable
	if action ~= "no_action" then
		AdminReviewTool.ExecutePunishment(review)
	end
	
	-- Mark match as reviewed
	MatchRecording.FlagForReview(reviewData.matchId, "admin_reviewed")
	
	Logging.Event("AdminReviewSubmitted", {
		reviewId = review.id,
		admin = adminPlayer.UserId,
		action = action,
		target = reviewData.targetPlayer
	})
	
	return true, "Review submitted successfully"
end

function AdminReviewTool.CanPerformAction(adminLevel, action)
	local permissions = {
		moderator = { "no_action", "warning" },
		admin = { "no_action", "warning", "temporary_ban", "reset_stats" },
		super_admin = REVIEW_ACTIONS -- All actions
	}
	
	local allowedActions = permissions[adminLevel] or {}
	return table.find(allowedActions, action) ~= nil
end

function AdminReviewTool.ExecutePunishment(review)
	local targetUserId = review.targetPlayer
	local action = review.action
	
	local punishment = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		targetUserId = targetUserId,
		adminId = review.adminId,
		action = action,
		reason = review.reason,
		timestamp = os.time(),
		reviewId = review.id,
		active = true
	}
	
	-- Set duration for temporary actions
	if action == "temporary_ban" then
		punishment.duration = 7 * 24 * 3600 -- 7 days
		punishment.expiresAt = os.time() + punishment.duration
	end
	
	-- Save punishment
	pcall(function()
		punishmentStore:SetAsync(punishment.id, punishment)
	end)
	
	-- Apply punishment immediately if player is online
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		AdminReviewTool.ApplyPunishmentToPlayer(targetPlayer, punishment)
	end
	
	Logging.Event("PunishmentExecuted", {
		punishmentId = punishment.id,
		target = targetUserId,
		action = action,
		admin = review.adminId
	})
end

function AdminReviewTool.ApplyPunishmentToPlayer(player, punishment)
	local action = punishment.action
	
	if action == "warning" then
		-- Send warning message
		AdminRemote:FireClient(player, "AdminWarning", {
			message = "You have received an admin warning: " .. punishment.reason,
			timestamp = punishment.timestamp
		})
	elseif action == "temporary_ban" or action == "permanent_ban" then
		-- Kick player with ban message
		local message = action == "temporary_ban" and 
			"You have been temporarily banned. Reason: " .. punishment.reason or
			"You have been permanently banned. Reason: " .. punishment.reason
		
		player:Kick(message)
	elseif action == "shadowban" then
		-- Implement shadowban (restrict certain features)
		AdminRemote:FireClient(player, "Shadowban", {
			restrictions = { "matchmaking", "chat", "social" }
		})
	elseif action == "reset_stats" then
		-- Reset player statistics
		-- This would integrate with player stats system
		AdminRemote:FireClient(player, "StatsReset", {
			message = "Your statistics have been reset by an administrator."
		})
	end
end

-- Handle client requests
AdminRemote.OnServerEvent:Connect(function(player, action, data)
	if not AdminReviewTool.IsAdmin(player) then
		return
	end
	
	if action == "GetPendingReviews" then
		local reviews = AdminReviewTool.GetPendingReviews(player, data.filters)
		AdminRemote:FireClient(player, "PendingReviews", reviews)
		
	elseif action == "GetMatchDetails" then
		local details = AdminReviewTool.GetMatchDetails(data.matchId)
		AdminRemote:FireClient(player, "MatchDetails", details)
		
	elseif action == "SubmitReview" then
		local success, message = AdminReviewTool.SubmitReview(player, data)
		AdminRemote:FireClient(player, "ReviewResult", { success = success, message = message })
		
	elseif action == "GetPlayerHistory" then
		-- Return player's punishment/review history
		local history = AdminReviewTool.GetPlayerHistory(data.playerId)
		AdminRemote:FireClient(player, "PlayerHistory", history)
	end
end)

function AdminReviewTool.GetPlayerHistory(playerId)
	-- This would query punishment and review history
	-- For now, return empty array as placeholder
	return {}
end

return AdminReviewTool
