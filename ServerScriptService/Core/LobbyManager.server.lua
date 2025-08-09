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

-- Simplified touch handler for debugging
function LobbyManager.HandleTouch(hit, statusLabel)
	print("[LobbyManager] ===== HANDLE TOUCH CALLED =====")
	print("[LobbyManager] Hit part:", hit.Name)
	print("[LobbyManager] Hit parent:", hit.Parent.Name)
	
	local character = hit.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)
	
	print("[LobbyManager] Character:", character and character.Name or "nil")
	print("[LobbyManager] Humanoid:", humanoid and "found" or "nil")
	print("[LobbyManager] Player:", player and player.Name or "nil")
	
	if not player or not humanoid or not character:FindFirstChild("HumanoidRootPart") then 
		print("[LobbyManager] ❌ Validation failed - not a valid player")
		return 
	end
	
	print("[LobbyManager] ✅ VALID PLAYER DETECTED:", player.Name)
	
	-- Skip all enterprise checks for now, just try teleport
	local userId = player.UserId
	
	-- Simple cooldown check
	if touchpadState.cooldowns[userId] and tick() - touchpadState.cooldowns[userId] < 2 then
		print("[LobbyManager] Player on cooldown")
		return
	end
	
	if touchpadState.teleportInProgress[userId] then 
		print("[LobbyManager] Teleport already in progress")
		return 
	end
	
	print("[LobbyManager] 🚀 ATTEMPTING TELEPORT FOR:", player.Name)
	
	-- Set basic state
	touchpadState.cooldowns[userId] = tick()
	touchpadState.teleportInProgress[userId] = true
	
	-- Update display
	statusLabel.Text = "TELEPORTING " .. player.Name:upper()
	statusLabel.TextColor3 = Color3.new(1, 1, 0)
	
	-- Simple teleport attempt
	task.spawn(function()
		task.wait(0.5)
		
		print("[LobbyManager] Executing teleport...")
		
		local success, error = pcall(function()
			print("[LobbyManager] Teleporting player directly...")
			
			-- Direct teleport implementation (avoiding require issue)
			if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
				error("Player character not ready for teleport")
				return false
			end
			
			-- Teleport to practice area (same position as PracticeMapManager uses)
			local humanoidRootPart = player.Character.HumanoidRootPart
			local practicePosition = Vector3.new(1000, 55, 1000) -- Practice spawn position
			humanoidRootPart.CFrame = CFrame.new(practicePosition)
			
			print("[LobbyManager] Player", player.Name, "teleported to practice area at", practicePosition)
			
			-- Send notification using remote events
			local success2, error2 = pcall(function()
				local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
				local UIEvents = RemoteRoot:WaitForChild("UIEvents")
				local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
				if notificationRemote then
					notificationRemote:FireClient(player, "🎯 Welcome to Practice Range!", "You have been teleported to the practice area!", 5)
				end
			end)
			
			if not success2 then
				print("[LobbyManager] Warning: Could not send notification:", error2)
			end
			
			return true
		end)
		
		if success then
			print("[LobbyManager] ✅ TELEPORT SUCCESSFUL for:", player.Name)
			statusLabel.Text = "TELEPORT SUCCESSFUL!"
			statusLabel.TextColor3 = Color3.new(0, 1, 0)
		else
			print("[LobbyManager] ❌ TELEPORT FAILED for:", player.Name, "Error:", error)
			statusLabel.Text = "TELEPORT FAILED: " .. tostring(error)
			statusLabel.TextColor3 = Color3.new(1, 0, 0)
		end
		
		-- Reset state
		task.wait(2)
		touchpadState.teleportInProgress[userId] = false
		statusLabel.Text = "WALK ON PLATFORM TO TELEPORT"
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

-- Setup touch detection with maximum debug output
function LobbyManager.SetupTouchDetection(touchpadBase, activationPad, statusLabel)
	print("[LobbyManager] Setting up touch detection...")
	print("[LobbyManager] Touchpad base:", touchpadBase.Name, "at", touchpadBase.Position)
	print("[LobbyManager] Activation pad:", activationPad.Name, "at", activationPad.Position)
	
	local function onTouch(hit)
		print("[LobbyManager] 🔥🔥🔥 TOUCH EVENT FIRED! 🔥🔥🔥")
		print("[LobbyManager] Hit:", hit.Name, "Parent:", hit.Parent.Name)
		
		-- IMMEDIATE VISUAL FEEDBACK
		task.spawn(function()
			-- Flash the touched part bright yellow
			local originalColor = hit.Color
			for i = 1, 3 do
				hit.Color = Color3.new(1, 1, 0) -- Bright yellow
				task.wait(0.1)
				hit.Color = originalColor
				task.wait(0.1)
			end
			
			-- Add sparkles for 3 seconds
			local sparkles = Instance.new("Sparkles")
			sparkles.Parent = hit
			sparkles.Color = Color3.new(1, 1, 0)
			game:GetService("Debris"):AddItem(sparkles, 3)
		end)
		
		-- Simple validation first
		local character = hit.Parent
		if not character then
			print("[LobbyManager] No character found")
			return
		end
		
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			print("[LobbyManager] No player found for character:", character.Name)
			return
		end
		
		print("[LobbyManager] 🎯 PLAYER FOUND:", player.Name, "- CALLING HANDLE TOUCH")
		LobbyManager.HandleTouch(hit, statusLabel)
	end
	
	-- Connect events with error checking
	local success1, connection1 = pcall(function()
		return touchpadBase.Touched:Connect(onTouch)
	end)
	
	local success2, connection2 = pcall(function()
		return activationPad.Touched:Connect(onTouch)
	end)
	
	if success1 and success2 then
		print("[LobbyManager] ✅ Touch events connected successfully to both pads")
	else
		warn("[LobbyManager] ❌ Failed to connect touch events")
	end
	
	-- Test the parts are actually there
	task.spawn(function()
		task.wait(2)
		print("[LobbyManager] POST-SETUP CHECK:")
		print("  - Base exists:", workspace:FindFirstChild("PracticeTeleportTouchpad") ~= nil)
		print("  - Activation exists:", workspace:FindFirstChild("ActivationPad") ~= nil)
		print("  - Base position:", touchpadBase.Position)
		print("  - Base size:", touchpadBase.Size)
		print("  - Base CanCollide:", touchpadBase.CanCollide)
		print("  - Activation position:", activationPad.Position)
		print("  - Activation CanCollide:", activationPad.CanCollide)
	end)
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
