-- ClientManager.client.lua
-- Enterprise client-side system coordinator with performance optimization

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for essential shared modules
local GameConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
local Logging = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logging")
local WeaponConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig")
local Utilities = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilities")
local PerformanceOptimizer = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerformanceOptimizer")
local BatchProcessor = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BatchProcessor")

-- Initialize performance systems
PerformanceOptimizer.Initialize()
BatchProcessor.Initialize()

-- Client systems
local ClientManager = {}

-- System modules
local systems = {
	UIManager = nil,
	InputManager = nil,
	AudioManager = nil,
	EffectsManager = nil,
	NetworkClient = nil,
	PerformanceMonitor = nil,
	SettingsManager = nil
}

-- Client state
local clientState = {
	gameState = "connecting",
	playerStats = {},
	currentMatch = nil,
	networkQuality = "unknown",
	performance = {
		fps = 60,
		ping = 0,
		frameDrops = 0
	},
	settings = {
		masterVolume = 1.0,
		mouseSensitivity = 1.0,
		graphics = "auto"
	}
}

-- Remote event connections
-- Connection management for cleanup
local connections = {}
local remoteConnections = {}

function ClientManager.Initialize()
	print("[ClientManager] Initializing enterprise client systems...")
	
	-- Initialize core systems
	ClientManager.InitializeCoreSystems()
	
	-- Set up remote event handlers
	ClientManager.SetupRemoteHandlers()
	
	-- Start client monitoring
	ClientManager.StartPerformanceMonitoring()
	ClientManager.StartNetworkMonitoring()
	
	-- Initialize UI
	ClientManager.InitializeUI()
	
	-- Set up input handling
	ClientManager.SetupInputHandling()
	
	-- Load user settings
	ClientManager.LoadUserSettings()
	
	print("[ClientManager] ✓ Client initialization complete")
end

function ClientManager.InitializeCoreSystems()
	-- UI Management System
	systems.UIManager = {
		updateStats = function(stats)
			clientState.playerStats = stats
			ClientManager.UpdateHUD()
		end,
		
		updateGameState = function(newState, data)
			local oldState = clientState.gameState
			clientState.gameState = newState
			
		-- Handle state-specific UI changes
		if newState == "match_active" then
			ClientManager.ShowMatchHUD()
		elseif newState == "lobby" then
			-- DISABLED: LobbyUI temporarily disabled for practice map testing
			-- ClientManager.ShowLobbyUI()
			print("[ClientManager] Lobby state active - Practice Mode")
		elseif newState == "match_ending" then
			ClientManager.ShowMatchResults(data)
		end			print("[ClientManager] Game state: " .. oldState .. " → " .. newState)
		end,
		
		showNotification = function(message, type, duration)
			ClientManager.CreateNotification(message, type or "info", duration or 3)
		end
	}
	
	-- Input Management System
	systems.InputManager = {
		mouseSettings = {
			sensitivity = 1.0,
			invertY = false
		},
		
		keyBindings = {
			reload = Enum.KeyCode.R,
			sprint = Enum.KeyCode.LeftShift,
			crouch = Enum.KeyCode.LeftControl,
			jump = Enum.KeyCode.Space,
			weapon1 = Enum.KeyCode.One,
			weapon2 = Enum.KeyCode.Two,
			weapon3 = Enum.KeyCode.Three,
			weapon4 = Enum.KeyCode.Four
		}
	}
	
	-- Audio Management System
	systems.AudioManager = {
		masterVolume = 1.0,
		sfxVolume = 1.0,
		musicVolume = 0.7,
		
		playSound = function(soundId, volume, pitch)
			-- Implementation for playing sounds
		end,
		
		setMasterVolume = function(volume)
			systems.AudioManager.masterVolume = math.clamp(volume, 0, 1)
			SoundService.Volume = systems.AudioManager.masterVolume
		end
	}
	
	-- Effects Management System
	systems.EffectsManager = {
		createMuzzleFlash = function(position, direction)
			-- Create muzzle flash effect
		end,
		
		createHitEffect = function(position, surfaceType)
			-- Create hit/impact effect
		end,
		
		createBloodEffect = function(position)
			-- Create blood splatter effect
		end
	}
	
	-- Network Client System
	systems.NetworkClient = {
		connectionQuality = "unknown",
		ping = 0,
		packetLoss = 0,
		
		updateConnectionInfo = function(ping, quality)
			systems.NetworkClient.ping = ping
			systems.NetworkClient.connectionQuality = quality
			clientState.performance.ping = ping
		end
	}
	
	-- Performance Monitor System
	systems.PerformanceMonitor = {
		fps = 60,
		frameTime = 0,
		memoryUsage = 0,
		
		updateMetrics = function()
			local heartbeatTime = RunService.Heartbeat:Wait()
			systems.PerformanceMonitor.frameTime = heartbeatTime
			systems.PerformanceMonitor.fps = 1 / heartbeatTime
			clientState.performance.fps = systems.PerformanceMonitor.fps
			
			-- Auto-adjust graphics quality based on performance
			ClientManager.AutoAdjustGraphics()
		end
	}
	
	-- Settings Manager System
	systems.SettingsManager = {
		saveSettings = function()
			-- Save user settings locally
		end,
		
		loadSettings = function()
			-- Load user settings
		end,
		
		resetToDefaults = function()
			clientState.settings = {
				masterVolume = 1.0,
				mouseSensitivity = 1.0,
				graphics = "auto"
			}
		end
	}
end

function ClientManager.SetupRemoteHandlers()
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- UI Events
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	
	-- Stats Updates
	local updateStatsRemote = UIEvents:WaitForChild("UpdateStats")
	remoteConnections.updateStats = updateStatsRemote.OnClientEvent:Connect(function(stats)
		systems.UIManager.updateStats(stats)
	end)
	
	-- Game State Updates
	local gameStateRemote = UIEvents:FindFirstChild("GameStateUpdate")
	if gameStateRemote then
		remoteConnections.gameState = gameStateRemote.OnClientEvent:Connect(function(data)
			systems.UIManager.updateGameState(data.currentState, data)
		end)
	end
	
	-- Currency Updates
	local updateCurrencyRemote = UIEvents:FindFirstChild("UpdateCurrency")
	if updateCurrencyRemote then
		remoteConnections.currency = updateCurrencyRemote.OnClientEvent:Connect(function(amount)
			clientState.playerStats.currency = amount
			ClientManager.UpdateCurrencyDisplay(amount)
		end)
	end
	
	-- Combat Events
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	
	-- Weapon fired events for effects
	local weaponFiredRemote = CombatEvents:FindFirstChild("WeaponFired")
	if weaponFiredRemote then
		remoteConnections.weaponFired = weaponFiredRemote.OnClientEvent:Connect(function(data)
			systems.EffectsManager.createMuzzleFlash(data.origin, data.direction)
		end)
	end
	
	-- Hit confirmation for effects
	local hitConfirmRemote = CombatEvents:FindFirstChild("HitConfirm")
	if hitConfirmRemote then
		remoteConnections.hitConfirm = hitConfirmRemote.OnClientEvent:Connect(function(data)
			if data.isHeadshot then
				systems.UIManager.showNotification("HEADSHOT!", "success", 2)
			end
			systems.EffectsManager.createHitEffect(data.position, data.surfaceType)
		end)
	end
	
	-- Matchmaking Events
	local MatchmakingEvents = RemoteRoot:WaitForChild("MatchmakingEvents")
	
	-- Match Start
	local matchStartRemote = MatchmakingEvents:WaitForChild("MatchStart")
	remoteConnections.matchStart = matchStartRemote.OnClientEvent:Connect(function(matchData)
		clientState.currentMatch = matchData
		systems.UIManager.showNotification("Match Starting!", "info", 3)
		ClientManager.PrepareForMatch()
	end)
	
	-- Match End
	local matchEndRemote = MatchmakingEvents:WaitForChild("MatchEnd")
	remoteConnections.matchEnd = matchEndRemote.OnClientEvent:Connect(function(results)
		ClientManager.HandleMatchEnd(results)
	end)
end

function ClientManager.StartPerformanceMonitoring()
	-- Use optimized performance monitoring with connection pooling
	local lastUpdate = tick()
	local frameCount = 0
	
	local connection = RunService.Heartbeat:Connect(function()
		frameCount = frameCount + 1
		local now = tick()
		
		-- Update every second instead of every frame
		if now - lastUpdate >= 1.0 then
			systems.PerformanceMonitor.fps = frameCount / (now - lastUpdate)
			systems.PerformanceMonitor.updateMetrics()
			
			-- Auto-adjust graphics every 5 seconds
			if frameCount % 5 == 0 then
				ClientManager.AutoAdjustGraphics()
			end
			
			frameCount = 0
			lastUpdate = now
		end
	end)
	
	-- Store connection for cleanup
	table.insert(connections, connection)
end

function ClientManager.StartNetworkMonitoring()
	-- Optimized network monitoring with less frequent updates
	local lastNetworkCheck = tick()
	
	local connection = RunService.Heartbeat:Connect(function()
		local now = tick()
		
		-- Check network every 5 seconds instead of continuously
		if now - lastNetworkCheck >= 5.0 then
			-- Measure ping to server (placeholder implementation)
			local pingStart = tick()
			
			-- In a real implementation, this would ping the server
			-- For now, we'll simulate network monitoring
			systems.NetworkClient.ping = math.random(10, 100)
			
			-- Update connection quality based on ping
			if systems.NetworkClient.ping < 50 then
				systems.NetworkClient.connectionQuality = "excellent"
			elseif systems.NetworkClient.ping < 100 then
				systems.NetworkClient.connectionQuality = "good"
			elseif systems.NetworkClient.ping < 200 then
				systems.NetworkClient.connectionQuality = "fair"
			else
				systems.NetworkClient.connectionQuality = "poor"
			end
			
			lastNetworkCheck = now
		end
	end)
	
	table.insert(connections, connection)
end

function ClientManager.InitializeUI()
	-- Create main HUD
	ClientManager.CreateMainHUD()
	
	-- Create notification system
	ClientManager.CreateNotificationSystem()
	
	-- Create performance overlay (for debugging)
	if game:GetService("RunService"):IsStudio() then
		ClientManager.CreatePerformanceOverlay()
	end
end

function ClientManager.CreateMainHUD()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Health bar
	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthBar"
	healthFrame.Size = UDim2.new(0, 200, 0, 20)
	healthFrame.Position = UDim2.new(0, 20, 1, -60)
	healthFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	healthFrame.BorderSizePixel = 0
	healthFrame.Parent = screenGui
	
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.Position = UDim2.new(0, 0, 0, 0)
	healthFill.BackgroundColor3 = Color3.new(0, 1, 0)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthFrame
	
	-- Ammo counter
	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoCounter"
	ammoLabel.Size = UDim2.new(0, 100, 0, 30)
	ammoLabel.Position = UDim2.new(1, -120, 1, -60)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = "30 / 90"
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.TextScaled = true
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.Parent = screenGui
	
	-- Score display
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreDisplay"
	scoreLabel.Size = UDim2.new(0, 200, 0, 30)
	scoreLabel.Position = UDim2.new(0.5, -100, 0, 20)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "Score: 0"
	scoreLabel.TextColor3 = Color3.new(1, 1, 1)
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.Parent = screenGui
end

function ClientManager.CreateNotificationSystem()
	local screenGui = player.PlayerGui:FindFirstChild("MainHUD")
	if not screenGui then return end
	
	local notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationContainer"
	notificationFrame.Size = UDim2.new(0, 300, 1, 0)
	notificationFrame.Position = UDim2.new(1, -320, 0, 20)
	notificationFrame.BackgroundTransparency = 1
	notificationFrame.Parent = screenGui
end

function ClientManager.CreateNotification(message, type, duration)
	local container = player.PlayerGui.MainHUD:FindFirstChild("NotificationContainer")
	if not container then return end
	
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(1, 0, 0, 40)
	notification.Position = UDim2.new(0, 0, 0, 0)
	notification.BackgroundColor3 = type == "success" and Color3.new(0, 0.8, 0) or 
	                               type == "error" and Color3.new(0.8, 0, 0) or
	                               Color3.new(0, 0.4, 0.8)
	notification.Parent = container
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.Parent = notification
	
	-- Animate in
	notification.Position = UDim2.new(1, 0, 0, 0)
	local tweenIn = TweenService:Create(notification, TweenInfo.new(0.3), {Position = UDim2.new(0, 0, 0, 0)})
	tweenIn:Play()
	
	-- Auto-remove after duration
	spawn(function()
		wait(duration)
		local tweenOut = TweenService:Create(notification, TweenInfo.new(0.3), {Position = UDim2.new(1, 0, 0, 0)})
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notification:Destroy()
	end)
end

function ClientManager.SetupInputHandling()
	-- Basic input handling
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		local keyBindings = systems.InputManager.keyBindings
		
		if input.KeyCode == keyBindings.reload then
			ClientManager.RequestReload()
		elseif input.KeyCode == keyBindings.weapon1 then
			ClientManager.SwitchWeapon(1)
		elseif input.KeyCode == keyBindings.weapon2 then
			ClientManager.SwitchWeapon(2)
		end
	end)
	
	-- Mouse input for shooting
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ClientManager.FireWeapon()
		end
	end)
end

function ClientManager.LoadUserSettings()
	-- Load saved settings or use defaults
	systems.SettingsManager.loadSettings()
	
	-- Apply settings
	systems.AudioManager.setMasterVolume(clientState.settings.masterVolume)
	systems.InputManager.mouseSettings.sensitivity = clientState.settings.mouseSensitivity
end

function ClientManager.UpdateHUD()
	local mainHUD = player.PlayerGui:FindFirstChild("MainHUD")
	if not mainHUD then return end
	
	local stats = clientState.playerStats
	
	-- Update health bar
	local healthBar = mainHUD:FindFirstChild("HealthBar")
	if healthBar and stats.Health then
		local healthFill = healthBar:FindFirstChild("Fill")
		if healthFill then
			local healthPercent = stats.Health / 100
			healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
			
			-- Color based on health
			if healthPercent > 0.6 then
				healthFill.BackgroundColor3 = Color3.new(0, 1, 0) -- Green
			elseif healthPercent > 0.3 then
				healthFill.BackgroundColor3 = Color3.new(1, 1, 0) -- Yellow
			else
				healthFill.BackgroundColor3 = Color3.new(1, 0, 0) -- Red
			end
		end
	end
	
	-- Update ammo counter
	local ammoCounter = mainHUD:FindFirstChild("AmmoCounter")
	if ammoCounter and stats.Ammo and stats.Reserve then
		ammoCounter.Text = stats.Ammo .. " / " .. stats.Reserve
	end
	
	-- Update score
	local scoreDisplay = mainHUD:FindFirstChild("ScoreDisplay")
	if scoreDisplay and stats.Kills and stats.Deaths then
		scoreDisplay.Text = "K: " .. stats.Kills .. " D: " .. stats.Deaths
	end
end

function ClientManager.AutoAdjustGraphics()
	local fps = systems.PerformanceMonitor.fps
	
	if fps < 30 and clientState.settings.graphics ~= "low" then
		clientState.settings.graphics = "low"
		-- Apply low graphics settings
		print("[ClientManager] Auto-adjusted graphics to LOW due to performance")
	elseif fps > 50 and clientState.settings.graphics == "low" then
		clientState.settings.graphics = "medium"
		-- Apply medium graphics settings
		print("[ClientManager] Auto-adjusted graphics to MEDIUM")
	end
end

function ClientManager.FireWeapon()
	if clientState.gameState ~= "match_active" then return end
	
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	local fireWeaponRemote = CombatEvents:WaitForChild("FireWeapon")
	
	-- Calculate firing direction from camera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	
	fireWeaponRemote:FireServer(origin, direction)
end

function ClientManager.RequestReload()
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	local reloadRemote = CombatEvents:WaitForChild("RequestReload")
	
	reloadRemote:FireServer()
	systems.UIManager.showNotification("Reloading...", "info", 1)
end

function ClientManager.SwitchWeapon(weaponSlot)
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	local switchWeaponRemote = CombatEvents:WaitForChild("SwitchWeapon")
	
	-- This would map weapon slots to weapon IDs
	local weaponIds = {"AssaultRifle", "SMG", "Shotgun", "Sniper"}
	local weaponId = weaponIds[weaponSlot]
	
	if weaponId then
		switchWeaponRemote:FireServer(weaponId)
	end
end

function ClientManager.PrepareForMatch()
	-- Hide lobby UI, show match UI
	ClientManager.ShowMatchHUD()
	
	-- Reset stats
	clientState.playerStats = {
		Health = 100,
		Ammo = 30,
		Reserve = 90,
		Kills = 0,
		Deaths = 0
	}
	
	ClientManager.UpdateHUD()
end

function ClientManager.HandleMatchEnd(results)
	systems.UIManager.updateGameState("match_ending", results)
	
	-- Show match results
	local message = results.won and "VICTORY!" or "DEFEAT"
	local type = results.won and "success" or "error"
	systems.UIManager.showNotification(message, type, 5)
end

function ClientManager.ShowMatchHUD()
	-- Implementation for showing match-specific UI
end

function ClientManager.ShowLobbyUI()
	-- Implementation for showing lobby UI
end

function ClientManager.ShowMatchResults(data)
	-- Implementation for showing detailed match results
end

function ClientManager.UpdateCurrencyDisplay(amount)
	-- Update currency in UI
	print("[ClientManager] Currency updated: " .. amount)
end

function ClientManager.CreatePerformanceOverlay()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PerformanceOverlay"
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 200, 0, 100)
	frame.Position = UDim2.new(0, 10, 0, 10)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.Parent = screenGui
	
	local fpsLabel = Instance.new("TextLabel")
	fpsLabel.Size = UDim2.new(1, 0, 0.5, 0)
	fpsLabel.Position = UDim2.new(0, 0, 0, 0)
	fpsLabel.BackgroundTransparency = 1
	fpsLabel.Text = "FPS: 60"
	fpsLabel.TextColor3 = Color3.new(1, 1, 1)
	fpsLabel.TextScaled = true
	fpsLabel.Parent = frame
	
	local pingLabel = Instance.new("TextLabel")
	pingLabel.Size = UDim2.new(1, 0, 0.5, 0)
	pingLabel.Position = UDim2.new(0, 0, 0.5, 0)
	pingLabel.BackgroundTransparency = 1
	pingLabel.Text = "Ping: 0ms"
	pingLabel.TextColor3 = Color3.new(1, 1, 1)
	pingLabel.TextScaled = true
	pingLabel.Parent = frame
	
	-- Update performance display
	spawn(function()
		while frame.Parent do
			fpsLabel.Text = "FPS: " .. math.floor(systems.PerformanceMonitor.fps)
			pingLabel.Text = "Ping: " .. systems.NetworkClient.ping .. "ms"
			wait(1)
		end
	end)
end

-- Cleanup function
function ClientManager.Cleanup()
	-- Disconnect all RemoteEvent connections
	for name, connection in pairs(remoteConnections) do
		connection:Disconnect()
	end
	remoteConnections = {}
	
	-- Disconnect all RunService connections
	for i, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
	
	print("[ClientManager] ✓ All connections cleaned up")
end

-- Initialize when script loads
ClientManager.Initialize()

-- Initialize quality of life enhancements
spawn(function()
	local OptimizedInputSystem = require(script.Parent:WaitForChild("OptimizedInputSystem"))
	local QualityOfLifeEnhancements = require(script.Parent:WaitForChild("QualityOfLifeEnhancements"))
	
	OptimizedInputSystem.Initialize()
	QualityOfLifeEnhancements.Initialize()
	
	print("[ClientManager] ✓ All optimization systems initialized")
end)

-- Handle player leaving with cleanup
game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		ClientManager.Cleanup()
	end
end)

return ClientManager
