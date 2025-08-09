-- LobbyManager.server.lua
-- Enterprise-level touchpad teleportation system with comprehensive monitoring

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Logging = require(ReplicatedStorage.Shared.Logging)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local LobbyManager = {}

-- Enterprise configuration with comprehensive settings
local TOUCHPAD_CONFIG = {
	position = Vector3.new(0, 5, 25), -- Lowered from 10 to 5
	baseSize = Vector3.new(20, 2, 20),
	activationSize = Vector3.new(18, 1, 18),
	cooldownTime = 2,
	maxConcurrentTeleports = 10, -- Enterprise limit
	teleportTimeout = 30, -- Auto-cleanup stuck teleports
	healthCheckInterval = 5, -- Monitor system health
	metricsEnabled = true
}

-- Enterprise metrics tracking
local TouchpadMetrics = {
	totalTeleports = 0,
	failedTeleports = 0,
	rateLimitedRequests = 0,
	averageResponseTime = 0,
	peakConcurrentUsers = 0,
	systemStartTime = tick()
}

-- Enterprise state management with comprehensive tracking
local touchpadState = {
	cooldowns = {},
	teleportInProgress = {},
	teleportStartTimes = {}, -- Track teleport durations
	sessionIds = {}, -- Unique session tracking
	healthStatus = "OPERATIONAL", -- System health monitoring
	lastHealthCheck = tick(),
	concurrentUsers = 0,
	connectionsCleaned = false
}

-- Create the base platform
function LobbyManager.CreateTouchpadBase()
	local touchpadBase = Instance.new("Part")
	touchpadBase.Name = "PracticeTeleportTouchpad"
	touchpadBase.Size = TOUCHPAD_CONFIG.baseSize
	touchpadBase.Position = TOUCHPAD_CONFIG.position
	touchpadBase.Material = Enum.Material.Neon
	touchpadBase.Color = Color3.new(0, 0.5, 1)
	touchpadBase.Anchored = true
	touchpadBase.CanCollide = true
	touchpadBase.Parent = workspace
	
	-- Add lighting
	local light = Instance.new("PointLight")
	light.Color = Color3.new(0, 0.5, 1)
	light.Brightness = 10
	light.Range = 100
	light.Parent = touchpadBase
	
	print("[LobbyManager] Created touchpad base at:", touchpadBase.Position)
	return touchpadBase
end

-- Create the activation pad
function LobbyManager.CreateActivationPad()
	local activationPad = Instance.new("Part")
	activationPad.Name = "ActivationPad"
	activationPad.Size = TOUCHPAD_CONFIG.activationSize
	activationPad.Position = Vector3.new(TOUCHPAD_CONFIG.position.X, TOUCHPAD_CONFIG.position.Y + 1.5, TOUCHPAD_CONFIG.position.Z)
	activationPad.Material = Enum.Material.Neon
	activationPad.Color = Color3.new(0, 1, 1)
	activationPad.Anchored = true
	activationPad.CanCollide = false
	activationPad.Parent = workspace
	
	-- Add bright lighting
	local light = Instance.new("PointLight")
	light.Color = Color3.new(0, 1, 1)
	light.Brightness = 15
	light.Range = 100
	light.Parent = activationPad
	
	print("[LobbyManager] Created activation pad at:", activationPad.Position)
	return activationPad
end

-- Create display
function LobbyManager.CreateDisplay(activationPad)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 600, 0, 300)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.LightInfluence = 0
	billboard.Parent = activationPad
	
	local mainLabel = Instance.new("TextLabel")
	mainLabel.Size = UDim2.new(1, 0, 0.5, 0)
	mainLabel.Position = UDim2.new(0, 0, 0, 0)
	mainLabel.BackgroundTransparency = 1
	mainLabel.Text = "PRACTICE RANGE TELEPORTER"
	mainLabel.TextColor3 = Color3.new(1, 1, 1)
	mainLabel.TextScaled = true
	mainLabel.Font = Enum.Font.SourceSansBold
	mainLabel.TextStrokeTransparency = 0
	mainLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	mainLabel.Parent = billboard
	
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.5, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "WALK ON PLATFORM TO TELEPORT"
	statusLabel.TextColor3 = Color3.new(0, 1, 0)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.SourceSansBold
	statusLabel.TextStrokeTransparency = 0
	statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	statusLabel.Parent = billboard
	
	return statusLabel
end

-- Enterprise touch event handler with comprehensive validation and monitoring
function LobbyManager.HandleTouch(hit, statusLabel)
	local startTime = tick()
	local sessionId = HttpService:GenerateGUID(false)
	
	-- Comprehensive input validation
	if not hit or not hit.Parent then 
		return 
	end
	
	local character = hit.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)
	
	-- Multi-layer player validation
	if not player or not humanoid or not character:FindFirstChild("HumanoidRootPart") then 
		return 
	end
	
	-- Enterprise health check
	if touchpadState.healthStatus ~= "OPERATIONAL" then
		statusLabel.Text = "SYSTEM MAINTENANCE - PLEASE WAIT"
		statusLabel.TextColor3 = Color3.new(1, 0.5, 0)
		Logging.Warn("LobbyManager", "Touch rejected - system not operational", {
			player = player.Name,
			healthStatus = touchpadState.healthStatus
		})
		return
	end
	
	print("[LobbyManager] Enterprise touch detected from player:", player.Name, "Session:", sessionId)
	
	local userId = player.UserId
	local currentTime = tick()
	
	-- Update concurrent user tracking
	touchpadState.concurrentUsers = touchpadState.concurrentUsers + 1
	TouchpadMetrics.peakConcurrentUsers = math.max(TouchpadMetrics.peakConcurrentUsers, touchpadState.concurrentUsers)
	
	-- Enterprise cooldown validation with detailed logging
	if touchpadState.cooldowns[userId] and currentTime - touchpadState.cooldowns[userId] < TOUCHPAD_CONFIG.cooldownTime then
		touchpadState.concurrentUsers = touchpadState.concurrentUsers - 1
		Logging.Info("LobbyManager", "Player on cooldown", {
			player = player.Name,
			remainingCooldown = TOUCHPAD_CONFIG.cooldownTime - (currentTime - touchpadState.cooldowns[userId]),
			sessionId = sessionId
		})
		return
	end
	
	-- Check for stuck teleports and auto-cleanup
	if touchpadState.teleportInProgress[userId] then 
		local teleportStartTime = touchpadState.teleportStartTimes[userId]
		if teleportStartTime and currentTime - teleportStartTime > TOUCHPAD_CONFIG.teleportTimeout then
			-- Auto-cleanup stuck teleport
			touchpadState.teleportInProgress[userId] = false
			touchpadState.teleportStartTimes[userId] = nil
			TouchpadMetrics.failedTeleports = TouchpadMetrics.failedTeleports + 1
			Logging.Warn("LobbyManager", "Auto-cleaned stuck teleport", {
				player = player.Name,
				stuckDuration = currentTime - teleportStartTime,
				sessionId = sessionId
			})
		else
			touchpadState.concurrentUsers = touchpadState.concurrentUsers - 1
			return 
		end
	end
	
	-- Enterprise concurrent teleport limiting
	local activeTeleports = 0
	for _, inProgress in pairs(touchpadState.teleportInProgress) do
		if inProgress then activeTeleports = activeTeleports + 1 end
	end
	
	if activeTeleports >= TOUCHPAD_CONFIG.maxConcurrentTeleports then
		touchpadState.concurrentUsers = touchpadState.concurrentUsers - 1
		statusLabel.Text = "SYSTEM BUSY - PLEASE WAIT"
		statusLabel.TextColor3 = Color3.new(1, 0.5, 0)
		Logging.Warn("LobbyManager", "Max concurrent teleports reached", {
			player = player.Name,
			activeTeleports = activeTeleports,
			maxAllowed = TOUCHPAD_CONFIG.maxConcurrentTeleports,
			sessionId = sessionId
		})
		return
	end
	
	-- Enterprise rate limiting with detailed metrics
	if not RateLimiter.CheckLimit(player, "TeleportTouchpad", 0.5) then
		touchpadState.concurrentUsers = touchpadState.concurrentUsers - 1
		TouchpadMetrics.rateLimitedRequests = TouchpadMetrics.rateLimitedRequests + 1
		statusLabel.Text = "RATE LIMITED - PLEASE WAIT"
		statusLabel.TextColor3 = Color3.new(1, 0.5, 0)
		
		Logging.Info("LobbyManager", "Player rate limited", {
			player = player.Name,
			totalRateLimited = TouchpadMetrics.rateLimitedRequests,
			sessionId = sessionId
		})
		
		task.spawn(function()
			task.wait(2)
			statusLabel.Text = "WALK ON PLATFORM TO TELEPORT"
			statusLabel.TextColor3 = Color3.new(0, 1, 0)
		end)
		return
	end
	
	print("[LobbyManager] Enterprise teleport initiated for:", player.Name, "Session:", sessionId)
	
	-- Set enterprise state tracking
	touchpadState.cooldowns[userId] = currentTime
	touchpadState.teleportInProgress[userId] = true
	touchpadState.teleportStartTimes[userId] = currentTime
	touchpadState.sessionIds[userId] = sessionId
	
	-- Update display with professional messaging
	statusLabel.Text = "🚀 TELEPORTING " .. player.Name:upper()
	statusLabel.TextColor3 = Color3.new(1, 1, 0)
	
	-- Enterprise teleport execution with comprehensive error handling
	task.spawn(function()
		task.wait(0.5)
		
		local teleportSuccess = false
		local errorMessage = nil
		
		local success, result = pcall(function()
			local PracticeMapManager = require(game.ServerScriptService.Core:WaitForChild("PracticeMapManager"))
			return PracticeMapManager.TeleportToPractice(player)
		end)
		
		if success then
			teleportSuccess = true
			TouchpadMetrics.totalTeleports = TouchpadMetrics.totalTeleports + 1
			
			-- Calculate response time metrics
			local responseTime = tick() - startTime
			TouchpadMetrics.averageResponseTime = (TouchpadMetrics.averageResponseTime + responseTime) / 2
			
			Logging.Info("LobbyManager", "Enterprise teleport successful", {
				player = player.Name,
				responseTime = responseTime,
				totalTeleports = TouchpadMetrics.totalTeleports,
				sessionId = sessionId
			})
		else
			teleportSuccess = false
			errorMessage = tostring(result)
			TouchpadMetrics.failedTeleports = TouchpadMetrics.failedTeleports + 1
			
			Logging.Error("LobbyManager", "Enterprise teleport failed", {
				player = player.Name,
				error = errorMessage,
				totalFailures = TouchpadMetrics.failedTeleports,
				sessionId = sessionId
			})
		end
		
		-- Enterprise state cleanup and user feedback
		if not teleportSuccess then
			statusLabel.Text = "⚠️ TELEPORT FAILED - TRY AGAIN"
			statusLabel.TextColor3 = Color3.new(1, 0, 0)
		end
		
		-- Reset enterprise state with delay
		task.wait(1)
		touchpadState.teleportInProgress[userId] = false
		touchpadState.teleportStartTimes[userId] = nil
		touchpadState.sessionIds[userId] = nil
		touchpadState.concurrentUsers = math.max(0, touchpadState.concurrentUsers - 1)
		
		statusLabel.Text = "✅ WALK ON PLATFORM TO TELEPORT"
		statusLabel.TextColor3 = Color3.new(0, 1, 0)
	end)
end

-- Enterprise health monitoring system
function LobbyManager.PerformHealthCheck()
	local currentTime = tick()
	local healthIssues = {}
	
	-- Check for stuck teleports
	local stuckTeleports = 0
	for userId, startTime in pairs(touchpadState.teleportStartTimes) do
		if currentTime - startTime > TOUCHPAD_CONFIG.teleportTimeout then
			stuckTeleports = stuckTeleports + 1
		end
	end
	
	if stuckTeleports > 0 then
		table.insert(healthIssues, "Stuck teleports detected: " .. stuckTeleports)
	end
	
	-- Check failure rate
	local totalOperations = TouchpadMetrics.totalTeleports + TouchpadMetrics.failedTeleports
	if totalOperations > 10 then
		local failureRate = TouchpadMetrics.failedTeleports / totalOperations
		if failureRate > 0.1 then -- More than 10% failure rate
			table.insert(healthIssues, "High failure rate: " .. string.format("%.1f%%", failureRate * 100))
		end
	end
	
	-- Update health status
	if #healthIssues > 0 then
		touchpadState.healthStatus = "DEGRADED"
		Logging.Warn("LobbyManager", "System health degraded", {
			issues = healthIssues,
			metrics = TouchpadMetrics
		})
	else
		touchpadState.healthStatus = "OPERATIONAL"
	end
	
	touchpadState.lastHealthCheck = currentTime
	
	-- Log health status periodically
	if currentTime - TouchpadMetrics.systemStartTime > 60 then -- After 1 minute of operation
		Logging.Info("LobbyManager", "Enterprise health check completed", {
			status = touchpadState.healthStatus,
			uptime = currentTime - TouchpadMetrics.systemStartTime,
			metrics = TouchpadMetrics,
			concurrentUsers = touchpadState.concurrentUsers
		})
	end
end

-- Enterprise metrics reporting
function LobbyManager.GetSystemMetrics()
	local uptime = tick() - TouchpadMetrics.systemStartTime
	local successRate = 0
	
	local totalOperations = TouchpadMetrics.totalTeleports + TouchpadMetrics.failedTeleports
	if totalOperations > 0 then
		successRate = TouchpadMetrics.totalTeleports / totalOperations
	end
	
	return {
		uptime = uptime,
		healthStatus = touchpadState.healthStatus,
		totalTeleports = TouchpadMetrics.totalTeleports,
		failedTeleports = TouchpadMetrics.failedTeleports,
		successRate = successRate,
		averageResponseTime = TouchpadMetrics.averageResponseTime,
		peakConcurrentUsers = TouchpadMetrics.peakConcurrentUsers,
		currentConcurrentUsers = touchpadState.concurrentUsers,
		rateLimitedRequests = TouchpadMetrics.rateLimitedRequests
	}
end

-- Setup touch detection
function LobbyManager.SetupTouchDetection(touchpadBase, activationPad, statusLabel)
	print("[LobbyManager] Setting up touch detection...")
	
	local function onTouch(hit)
		LobbyManager.HandleTouch(hit, statusLabel)
	end
	
	touchpadBase.Touched:Connect(onTouch)
	activationPad.Touched:Connect(onTouch)
	
	print("[LobbyManager] Touch events connected")
end

-- Create the main system
function LobbyManager.CreateTouchpadSystem()
	print("[LobbyManager] Creating touchpad system at position:", TOUCHPAD_CONFIG.position)
	
	local touchpadBase = LobbyManager.CreateTouchpadBase()
	local activationPad = LobbyManager.CreateActivationPad()
	local statusLabel = LobbyManager.CreateDisplay(activationPad)
	
	LobbyManager.SetupTouchDetection(touchpadBase, activationPad, statusLabel)
	
	-- Add pulsing animation
	local pulseAnimation = TweenService:Create(activationPad,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Transparency = 0.3}
	)
	pulseAnimation:Play()
	
	print("[LobbyManager] Touchpad system created successfully!")
end

-- Enterprise initialization with comprehensive monitoring
function LobbyManager.Initialize()
	print("[LobbyManager] 🏢 Initializing Enterprise Lobby Manager...")
	
	-- Initialize system metrics
	TouchpadMetrics.systemStartTime = tick()
	touchpadState.healthStatus = "OPERATIONAL"
	
	-- Create the touchpad system
	LobbyManager.CreateTouchpadSystem()
	
	-- Start enterprise health monitoring
	if TOUCHPAD_CONFIG.metricsEnabled then
		task.spawn(function()
			while not touchpadState.connectionsCleaned do
				LobbyManager.PerformHealthCheck()
				task.wait(TOUCHPAD_CONFIG.healthCheckInterval)
			end
		end)
		
		print("[LobbyManager] ✅ Enterprise health monitoring started")
	end
	
	-- Setup graceful shutdown
	game.BindToClose(function()
		touchpadState.connectionsCleaned = true
		local metrics = LobbyManager.GetSystemMetrics()
		Logging.Info("LobbyManager", "Enterprise system shutdown", {
			finalMetrics = metrics,
			uptime = metrics.uptime
		})
		print("[LobbyManager] 🔒 Enterprise system shutdown completed")
	end)
	
	-- Log successful initialization
	Logging.Info("LobbyManager", "Enterprise Lobby Manager initialized", {
		position = TOUCHPAD_CONFIG.position,
		config = TOUCHPAD_CONFIG,
		systemTime = TouchpadMetrics.systemStartTime
	})
	
	print("[LobbyManager] ✅ Enterprise Lobby Manager initialized successfully!")
	print("[LobbyManager] 📊 Metrics tracking:", TOUCHPAD_CONFIG.metricsEnabled and "ENABLED" or "DISABLED")
	print("[LobbyManager] 🏥 Health monitoring:", TOUCHPAD_CONFIG.healthCheckInterval .. "s intervals")
	print("[LobbyManager] 🚀 System ready for enterprise operations!")
end

-- Auto-start
LobbyManager.Initialize()

return LobbyManager
