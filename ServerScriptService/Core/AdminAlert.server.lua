-- AdminAlert.server.lua
-- Enterprise-grade admin notification and alert system
-- Integrates with AntiExploit and provides real-time admin dashboards

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Import dependencies
local Logging = require(ReplicatedStorage.Shared.Logging)

local AdminAlert = {}
AdminAlert.__index = AdminAlert

-- Type definitions
export type AlertLevel = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"

export type Alert = {
	id: string,
	alertType: string,
	level: AlertLevel,
	message: string,
	data: {[string]: any}?,
	timestamp: number,
	acknowledged: boolean,
	acknowledgedBy: number?,
	acknowledgedAt: number?
}

export type AdminUser = {
	userId: number,
	username: string,
	permissions: {string},
	lastSeen: number,
	alertPreferences: {[string]: boolean}
}

-- Enterprise configuration
local ADMIN_ALERT_CONFIG = {
	-- Admin user IDs (configure with your admin user IDs)
	adminUserIds = {
		123456789, -- Replace with actual admin user IDs
		987654321  -- Add more admin IDs as needed
	},
	
	-- Alert levels and their properties
	alertLevels = {
		LOW = {
			color = Color3.new(0, 1, 0),        -- Green
			soundId = "rbxasset://sounds/button.mp3",
			priority = 1,
			autoAcknowledgeTime = 300           -- 5 minutes
		},
		MEDIUM = {
			color = Color3.new(1, 1, 0),        -- Yellow
			soundId = "rbxasset://sounds/impact_notification.mp3",
			priority = 2,
			autoAcknowledgeTime = 600           -- 10 minutes
		},
		HIGH = {
			color = Color3.new(1, 0.5, 0),      -- Orange
			soundId = "rbxasset://sounds/notification.mp3",
			priority = 3,
			autoAcknowledgeTime = 1800          -- 30 minutes
		},
		CRITICAL = {
			color = Color3.new(1, 0, 0),        -- Red
			soundId = "rbxasset://sounds/bomb_owngoal.mp3",
			priority = 4,
			autoAcknowledgeTime = nil           -- Manual acknowledgment only
		}
	},
	
	-- UI configuration
	ui = {
		alertDisplayTime = 10,                   -- Seconds to show alert
		maxVisibleAlerts = 5,                    -- Max alerts shown at once
		alertFadeTime = 2,                       -- Fade animation time
		dashboardUpdateInterval = 1,             -- Dashboard refresh rate
		alertHistoryLimit = 100                  -- Max alerts to keep in history
	},
	
	-- External notification settings
	externalNotifications = {
		webhookEnabled = false,                  -- Discord/Slack webhook
		webhookUrl = "",                         -- Configure if using webhooks
		emailEnabled = false,                    -- Email notifications
		smsEnabled = false                       -- SMS notifications (if implemented)
	}
}

-- System state
local systemState = {
	activeAlerts = {},
	alertHistory = {},
	adminUsers = {},
	connectedAdmins = {},
	alertMetrics = {
		totalAlerts = 0,
		alertsByType = {},
		alertsByLevel = {},
		averageResponseTime = 0,
		acknowledgmentRate = 0
	},
	isInitialized = false
}

-- Remote events for admin communication
local remoteEvents = {
	adminAlertReceived = nil,
	adminAcknowledgeAlert = nil,
	adminDashboardUpdate = nil
}

-- Initialize AdminAlert system
function AdminAlert.new()
	local self = setmetatable({}, AdminAlert)
	
	-- Dependencies (injected by Service Locator)
	self.logger = nil
	
	-- Initialize admin users
	self:InitializeAdminUsers()
	
	-- Create remote events
	self:CreateRemoteEvents()
	
	-- Start monitoring systems
	self:StartAlertMonitoring()
	
	systemState.isInitialized = true
	
	return self
end

-- Set logger dependency (injected by Service Locator)
function AdminAlert:SetLogger(logger)
	self.logger = logger
	if self.logger then
		self.logger.Info("AdminAlert", "Logger dependency injected successfully")
	end
end

-- Initialize admin users and their permissions
function AdminAlert:InitializeAdminUsers()
	for _, userId in ipairs(ADMIN_ALERT_CONFIG.adminUserIds) do
		systemState.adminUsers[userId] = {
			userId = userId,
			username = "Unknown", -- Will be updated when they join
			permissions = {"VIEW_ALERTS", "ACKNOWLEDGE_ALERTS", "SYSTEM_MONITORING"},
			lastSeen = 0,
			alertPreferences = {
				SECURITY_THREAT = true,
				PERFORMANCE_ISSUE = true,
				SYSTEM_ERROR = true,
				MULTIPLE_CRITICAL_THREATS = true,
				PLAYER_REPORT = true
			}
		}
	end
end

-- Create remote events for admin communication
function AdminAlert:CreateRemoteEvents()
	-- Create RemoteEvents folder if it doesn't exist
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then
		remoteEventsFolder = Instance.new("Folder")
		remoteEventsFolder.Name = "RemoteEvents"
		remoteEventsFolder.Parent = ReplicatedStorage
	end
	
	-- Create AdminEvents subfolder
	local adminEventsFolder = remoteEventsFolder:FindFirstChild("AdminEvents")
	if not adminEventsFolder then
		adminEventsFolder = Instance.new("Folder")
		adminEventsFolder.Name = "AdminEvents"
		adminEventsFolder.Parent = remoteEventsFolder
	end
	
	-- Create remote events
	remoteEvents.adminAlertReceived = Instance.new("RemoteEvent")
	remoteEvents.adminAlertReceived.Name = "AdminAlertReceived"
	remoteEvents.adminAlertReceived.Parent = adminEventsFolder
	
	remoteEvents.adminAcknowledgeAlert = Instance.new("RemoteEvent")
	remoteEvents.adminAcknowledgeAlert.Name = "AdminAcknowledgeAlert"
	remoteEvents.adminAcknowledgeAlert.Parent = adminEventsFolder
	
	remoteEvents.adminDashboardUpdate = Instance.new("RemoteEvent")
	remoteEvents.adminDashboardUpdate.Name = "AdminDashboardUpdate"
	remoteEvents.adminDashboardUpdate.Parent = adminEventsFolder
	
	-- Connect remote events
	remoteEvents.adminAcknowledgeAlert.OnServerEvent:Connect(function(player, alertId)
		self:HandleAlertAcknowledgment(player, alertId)
	end)
	
	if self.logger then
		self.logger.Info("AdminAlert", "Remote events created successfully")
	end
end

-- Send alert to administrators
function AdminAlert:SendAlert(alertType: string, message: string, data: {[string]: any}?): string
	local alertLevel = self:DetermineAlertLevel(alertType, data)
	
	local alert: Alert = {
		id = HttpService:GenerateGUID(false),
		alertType = alertType,
		level = alertLevel,
		message = message,
		data = data or {},
		timestamp = tick(),
		acknowledged = false,
		acknowledgedBy = nil,
		acknowledgedAt = nil
	}
	
	-- Store alert
	systemState.activeAlerts[alert.id] = alert
	table.insert(systemState.alertHistory, alert)
	
	-- Trim alert history
	if #systemState.alertHistory > ADMIN_ALERT_CONFIG.ui.alertHistoryLimit then
		table.remove(systemState.alertHistory, 1)
	end
	
	-- Update metrics
	self:UpdateAlertMetrics(alert)
	
	-- Log alert
	if self.logger then
		local logLevel = alertLevel == "CRITICAL" and "Error" or alertLevel == "HIGH" and "Warn" or "Info"
		self.logger[logLevel](self.logger, "AdminAlert", "Alert sent: " .. alertType, {
			alertId = alert.id,
			level = alertLevel,
			message = message,
			data = data
		})
	end
	
	-- Send to connected admins
	self:NotifyConnectedAdmins(alert)
	
	-- Send external notifications if configured
	self:SendExternalNotifications(alert)
	
	-- Auto-acknowledge low priority alerts
	if alertLevel == "LOW" then
		task.spawn(function()
			task.wait(ADMIN_ALERT_CONFIG.alertLevels.LOW.autoAcknowledgeTime)
			if not alert.acknowledged then
				self:AcknowledgeAlert(alert.id, nil) -- Auto-acknowledge
			end
		end)
	end
	
	return alert.id
end

-- Determine alert level based on type and data
function AdminAlert:DetermineAlertLevel(alertType: string, data: {[string]: any}?): AlertLevel
	-- Critical alerts
	if alertType == "MULTIPLE_CRITICAL_THREATS" or 
	   alertType == "SYSTEM_FAILURE" or
	   alertType == "DATA_CORRUPTION" or
	   (data and data.severity and data.severity >= 10) then
		return "CRITICAL"
	end
	
	-- High priority alerts
	if alertType == "SECURITY_THREAT" or
	   alertType == "PERFORMANCE_DEGRADATION" or
	   alertType == "ANTI_EXPLOIT_BAN" or
	   (data and data.severity and data.severity >= 8) then
		return "HIGH"
	end
	
	-- Medium priority alerts
	if alertType == "SUSPICIOUS_ACTIVITY" or
	   alertType == "RATE_LIMIT_EXCEEDED" or
	   alertType == "PLAYER_REPORT" or
	   (data and data.severity and data.severity >= 5) then
		return "MEDIUM"
	end
	
	-- Default to low priority
	return "LOW"
end

-- Notify all connected administrators
function AdminAlert:NotifyConnectedAdmins(alert: Alert)
	local alertConfig = ADMIN_ALERT_CONFIG.alertLevels[alert.level]
	
	for userId, _ in pairs(systemState.connectedAdmins) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			-- Check if admin wants this type of alert
			local adminUser = systemState.adminUsers[userId]
			if adminUser and adminUser.alertPreferences[alert.alertType] then
				-- Send alert to admin client
				remoteEvents.adminAlertReceived:FireClient(player, {
					id = alert.id,
					alertType = alert.alertType,
					level = alert.level,
					message = alert.message,
					timestamp = alert.timestamp,
					color = alertConfig.color,
					soundId = alertConfig.soundId,
					priority = alertConfig.priority
				})
				
				if self.logger then
					self.logger.Info("AdminAlert", "Alert sent to admin", {
						admin = player.Name,
						alertId = alert.id,
						alertType = alert.alertType
					})
				end
			end
		end
	end
end

-- Handle alert acknowledgment from admins
function AdminAlert:HandleAlertAcknowledgment(player: Player, alertId: string)
	-- Verify player is admin
	if not self:IsPlayerAdmin(player) then
		if self.logger then
			self.logger.Warn("AdminAlert", "Non-admin attempted to acknowledge alert", {
				player = player.Name,
				alertId = alertId
			})
		end
		return
	end
	
	self:AcknowledgeAlert(alertId, player.UserId)
end

-- Acknowledge an alert
function AdminAlert:AcknowledgeAlert(alertId: string, adminUserId: number?)
	local alert = systemState.activeAlerts[alertId]
	if not alert then
		if self.logger then
			self.logger.Warn("AdminAlert", "Attempted to acknowledge non-existent alert", {
				alertId = alertId,
				adminUserId = adminUserId
			})
		end
		return false
	end
	
	if alert.acknowledged then
		return false -- Already acknowledged
	end
	
	-- Mark as acknowledged
	alert.acknowledged = true
	alert.acknowledgedBy = adminUserId
	alert.acknowledgedAt = tick()
	
	-- Remove from active alerts
	systemState.activeAlerts[alertId] = nil
	
	-- Log acknowledgment
	if self.logger then
		local adminName = adminUserId and Players:GetPlayerByUserId(adminUserId) and Players:GetPlayerByUserId(adminUserId).Name or "System"
		self.logger.Info("AdminAlert", "Alert acknowledged", {
			alertId = alertId,
			acknowledgedBy = adminName,
			responseTime = alert.acknowledgedAt - alert.timestamp
		})
	end
	
	-- Update metrics
	self:UpdateAcknowledgmentMetrics(alert)
	
	-- Notify all admins of acknowledgment
	for userId, _ in pairs(systemState.connectedAdmins) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			remoteEvents.adminDashboardUpdate:FireClient(player, {
				type = "ALERT_ACKNOWLEDGED",
				alertId = alertId,
				acknowledgedBy = adminUserId
			})
		end
	end
	
	return true
end

-- Check if player is an administrator
function AdminAlert:IsPlayerAdmin(player: Player): boolean
	return systemState.adminUsers[player.UserId] ~= nil
end

-- Handle admin player joining
function AdminAlert:HandleAdminJoining(player: Player)
	if not self:IsPlayerAdmin(player) then return end
	
	-- Update admin info
	local adminUser = systemState.adminUsers[player.UserId]
	adminUser.username = player.Name
	adminUser.lastSeen = tick()
	
	-- Add to connected admins
	systemState.connectedAdmins[player.UserId] = true
	
	-- Send current dashboard state
	self:SendDashboardUpdate(player)
	
	-- Send active alerts
	for _, alert in pairs(systemState.activeAlerts) do
		if adminUser.alertPreferences[alert.alertType] then
			local alertConfig = ADMIN_ALERT_CONFIG.alertLevels[alert.level]
			remoteEvents.adminAlertReceived:FireClient(player, {
				id = alert.id,
				alertType = alert.alertType,
				level = alert.level,
				message = alert.message,
				timestamp = alert.timestamp,
				color = alertConfig.color,
				soundId = alertConfig.soundId,
				priority = alertConfig.priority
			})
		end
	end
	
	if self.logger then
		self.logger.Info("AdminAlert", "Administrator connected", {
			admin = player.Name,
			userId = player.UserId,
			activeAlerts = #systemState.activeAlerts
		})
	end
end

-- Handle admin player leaving
function AdminAlert:HandleAdminLeaving(player: Player)
	if not self:IsPlayerAdmin(player) then return end
	
	-- Update admin info
	local adminUser = systemState.adminUsers[player.UserId]
	adminUser.lastSeen = tick()
	
	-- Remove from connected admins
	systemState.connectedAdmins[player.UserId] = nil
	
	if self.logger then
		self.logger.Info("AdminAlert", "Administrator disconnected", {
			admin = player.Name,
			userId = player.UserId
		})
	end
end

-- Send dashboard update to admin
function AdminAlert:SendDashboardUpdate(player: Player)
	if not self:IsPlayerAdmin(player) then return end
	
	local dashboardData = {
		type = "DASHBOARD_UPDATE",
		activeAlerts = #systemState.activeAlerts,
		metrics = systemState.alertMetrics,
		systemStatus = self:GetSystemStatus(),
		recentAlerts = self:GetRecentAlerts(10), -- Last 10 alerts
		timestamp = tick()
	}
	
	remoteEvents.adminDashboardUpdate:FireClient(player, dashboardData)
end

-- Get system status for dashboard
function AdminAlert:GetSystemStatus(): {[string]: any}
	return {
		uptime = tick() - (systemState.alertMetrics.systemStartTime or tick()),
		connectedAdmins = #systemState.connectedAdmins,
		activeAlerts = #systemState.activeAlerts,
		systemHealth = self:CalculateSystemHealth()
	}
end

-- Calculate overall system health score
function AdminAlert:CalculateSystemHealth(): number
	local health = 100
	
	-- Reduce health based on active critical/high alerts
	for _, alert in pairs(systemState.activeAlerts) do
		if alert.level == "CRITICAL" then
			health -= 20
		elseif alert.level == "HIGH" then
			health -= 10
		elseif alert.level == "MEDIUM" then
			health -= 5
		end
	end
	
	-- Consider alert rate
	local recentAlerts = self:GetRecentAlerts(60) -- Last minute
	if #recentAlerts > 10 then
		health -= 15 -- High alert volume
	end
	
	return math.max(0, health)
end

-- Get recent alerts
function AdminAlert:GetRecentAlerts(maxCount: number): {Alert}
	local recentAlerts = {}
	local currentTime = tick()
	
	-- Get alerts from last hour, sorted by timestamp
	for i = #systemState.alertHistory, 1, -1 do
		local alert = systemState.alertHistory[i]
		if currentTime - alert.timestamp < 3600 then -- Last hour
			table.insert(recentAlerts, alert)
			if #recentAlerts >= maxCount then
				break
			end
		end
	end
	
	return recentAlerts
end

-- Update alert metrics
function AdminAlert:UpdateAlertMetrics(alert: Alert)
	local metrics = systemState.alertMetrics
	
	metrics.totalAlerts += 1
	metrics.alertsByType[alert.alertType] = (metrics.alertsByType[alert.alertType] or 0) + 1
	metrics.alertsByLevel[alert.level] = (metrics.alertsByLevel[alert.level] or 0) + 1
end

-- Update acknowledgment metrics
function AdminAlert:UpdateAcknowledgmentMetrics(alert: Alert)
	local metrics = systemState.alertMetrics
	local responseTime = alert.acknowledgedAt - alert.timestamp
	
	-- Update average response time
	if metrics.totalAcknowledged then
		metrics.averageResponseTime = ((metrics.averageResponseTime * metrics.totalAcknowledged) + responseTime) / (metrics.totalAcknowledged + 1)
		metrics.totalAcknowledged += 1
	else
		metrics.averageResponseTime = responseTime
		metrics.totalAcknowledged = 1
	end
	
	-- Update acknowledgment rate
	metrics.acknowledgmentRate = metrics.totalAcknowledged / metrics.totalAlerts
end

-- Send external notifications (webhooks, email, etc.)
function AdminAlert:SendExternalNotifications(alert: Alert)
	if not ADMIN_ALERT_CONFIG.externalNotifications.webhookEnabled then return end
	
	-- This would implement webhook notifications to Discord/Slack
	-- Example implementation would go here
	task.spawn(function()
		local success, error = pcall(function()
			-- Implement webhook logic here
			-- HttpService:PostAsync(webhookUrl, webhookData)
		end)
		
		if not success and self.logger then
			self.logger.Error("AdminAlert", "Failed to send external notification", {
				alertId = alert.id,
				error = error
			})
		end
	end)
end

-- Start alert monitoring systems
function AdminAlert:StartAlertMonitoring()
	-- Dashboard update loop
	task.spawn(function()
		while systemState.isInitialized do
			task.wait(ADMIN_ALERT_CONFIG.ui.dashboardUpdateInterval)
			
			-- Send dashboard updates to all connected admins
			for userId, _ in pairs(systemState.connectedAdmins) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					self:SendDashboardUpdate(player)
				end
			end
		end
	end)
	
	-- Auto-acknowledgment monitoring
	task.spawn(function()
		while systemState.isInitialized do
			task.wait(30) -- Check every 30 seconds
			
			local currentTime = tick()
			for alertId, alert in pairs(systemState.activeAlerts) do
				if not alert.acknowledged then
					local alertConfig = ADMIN_ALERT_CONFIG.alertLevels[alert.level]
					if alertConfig.autoAcknowledgeTime then
						local alertAge = currentTime - alert.timestamp
						if alertAge > alertConfig.autoAcknowledgeTime then
							self:AcknowledgeAlert(alertId, nil) -- Auto-acknowledge
						end
					end
				end
			end
		end
	end)
end

-- Get comprehensive alert metrics
function AdminAlert:GetAlertMetrics(): {[string]: any}
	return {
		totalAlerts = systemState.alertMetrics.totalAlerts,
		activeAlerts = #systemState.activeAlerts,
		alertsByType = systemState.alertMetrics.alertsByType,
		alertsByLevel = systemState.alertMetrics.alertsByLevel,
		averageResponseTime = systemState.alertMetrics.averageResponseTime,
		acknowledgmentRate = systemState.alertMetrics.acknowledgmentRate,
		connectedAdmins = #systemState.connectedAdmins,
		systemHealth = self:CalculateSystemHealth()
	}
end

-- Initialize the system
function AdminAlert:Initialize()
	if systemState.isInitialized then
		if self.logger then
			self.logger.Warn("AdminAlert", "System already initialized")
		end
		return
	end
	
	-- Connect player events
	Players.PlayerAdded:Connect(function(player)
		self:HandleAdminJoining(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:HandleAdminLeaving(player)
	end)
	
	-- Handle players already in game
	for _, player in pairs(Players:GetPlayers()) do
		self:HandleAdminJoining(player)
	end
	
	-- Initialize metrics
	systemState.alertMetrics.systemStartTime = tick()
	
	systemState.isInitialized = true
	
	if self.logger then
		self.logger.Info("AdminAlert", "Enterprise Admin Alert system initialized", {
			adminCount = #ADMIN_ALERT_CONFIG.adminUserIds,
			connectedAdmins = #systemState.connectedAdmins
		})
	end
end

return AdminAlert
