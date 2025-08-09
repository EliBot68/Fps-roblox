-- QualityOfLifeEnhancements.lua
-- Comprehensive quality of life improvements for enhanced player experience

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QoLEnhancements = {}

-- Quality of Life Configuration
local QOL_CONFIG = {
	-- Visual Enhancements
	smoothAnimations = true,
	hitMarkers = true,
	damageNumbers = true,
	killFeed = true,
	crosshairCustomization = true,
	
	-- Audio Enhancements
	spatialAudio = true,
	footstepAudio = true,
	reloadSounds = true,
	lowHealthWarning = true,
	
	-- Interface Improvements
	smartReload = true,
	weaponSwapIndicator = true,
	ammoWarning = true,
	minimapEnabled = true,
	scoreboardHotkey = true,
	
	-- Accessibility Features
	colorBlindSupport = false,
	reducedMotion = false,
	highContrast = false,
	largerText = false,
	
	-- Performance Features
	autoGraphicsAdjust = true,
	smartNetworking = true,
	memoryOptimization = true
}

-- Enhancement State
local enhancementState = {
	lastHitTime = 0,
	killFeedEntries = {},
	damageNumbers = {},
	currentCrosshair = "default",
	isLowHealth = false,
	ammoWarningShown = false
}

-- UI Elements
local screenGui = nil
local hitMarker = nil
local killFeedFrame = nil
local minimapFrame = nil
local crosshair = nil

-- Initialize quality of life enhancements
function QoLEnhancements.Initialize()
	QoLEnhancements.CreateUI()
	QoLEnhancements.SetupHitMarkers()
	QoLEnhancements.SetupKillFeed()
	QoLEnhancements.SetupAudioEnhancements()
	QoLEnhancements.SetupSmartFeatures()
	QoLEnhancements.SetupAccessibility()
	QoLEnhancements.StartEnhancementLoop()
	
	print("[QoLEnhancements] Quality of life enhancements initialized")
end

-- Create UI elements
function QoLEnhancements.CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Main screen GUI
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QoLEnhancements"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Hit marker
	if QOL_CONFIG.hitMarkers then
		QoLEnhancements.CreateHitMarker()
	end
	
	-- Kill feed
	if QOL_CONFIG.killFeed then
		QoLEnhancements.CreateKillFeed()
	end
	
	-- Minimap
	if QOL_CONFIG.minimapEnabled then
		QoLEnhancements.CreateMinimap()
	end
	
	-- Custom crosshair
	if QOL_CONFIG.crosshairCustomization then
		QoLEnhancements.CreateCrosshair()
	end
end

-- Create hit marker
function QoLEnhancements.CreateHitMarker()
	hitMarker = Instance.new("ImageLabel")
	hitMarker.Name = "HitMarker"
	hitMarker.Size = UDim2.new(0, 40, 0, 40)
	hitMarker.Position = UDim2.new(0.5, -20, 0.5, -20)
	hitMarker.BackgroundTransparency = 1
	hitMarker.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- Replace with actual hit marker image
	hitMarker.ImageColor3 = Color3.new(1, 1, 1)
	hitMarker.ImageTransparency = 1
	hitMarker.ZIndex = 10
	hitMarker.Parent = screenGui
end

-- Create kill feed
function QoLEnhancements.CreateKillFeed()
	killFeedFrame = Instance.new("Frame")
	killFeedFrame.Name = "KillFeed"
	killFeedFrame.Size = UDim2.new(0, 300, 0, 200)
	killFeedFrame.Position = UDim2.new(1, -320, 0, 20)
	killFeedFrame.BackgroundTransparency = 1
	killFeedFrame.Parent = screenGui
	
	-- Add UIListLayout for automatic positioning
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = killFeedFrame
end

-- Create minimap
function QoLEnhancements.CreateMinimap()
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "Minimap"
	minimapFrame.Size = UDim2.new(0, 200, 0, 200)
	minimapFrame.Position = UDim2.new(1, -220, 0, 20)
	minimapFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	minimapFrame.BackgroundTransparency = 0.3
	minimapFrame.BorderSizePixel = 2
	minimapFrame.BorderColor3 = Color3.new(1, 1, 1)
	minimapFrame.Parent = screenGui
	
	-- Create minimap content
	local minimapViewport = Instance.new("ViewportFrame")
	minimapViewport.Size = UDim2.new(1, -4, 1, -4)
	minimapViewport.Position = UDim2.new(0, 2, 0, 2)
	minimapViewport.BackgroundTransparency = 1
	minimapViewport.Parent = minimapFrame
end

-- Create custom crosshair
function QoLEnhancements.CreateCrosshair()
	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 20, 0, 20)
	crosshair.Position = UDim2.new(0.5, -10, 0.5, -10)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = screenGui
	
	-- Create crosshair lines
	local horizontal = Instance.new("Frame")
	horizontal.Size = UDim2.new(0, 20, 0, 2)
	horizontal.Position = UDim2.new(0, 0, 0.5, -1)
	horizontal.BackgroundColor3 = Color3.new(1, 1, 1)
	horizontal.BorderSizePixel = 0
	horizontal.Parent = crosshair
	
	local vertical = Instance.new("Frame")
	vertical.Size = UDim2.new(0, 2, 0, 20)
	vertical.Position = UDim2.new(0.5, -1, 0, 0)
	vertical.BackgroundColor3 = Color3.new(1, 1, 1)
	vertical.BorderSizePixel = 0
	vertical.Parent = crosshair
end

-- Setup hit markers
function QoLEnhancements.SetupHitMarkers()
	if not QOL_CONFIG.hitMarkers then return end
	
	-- Connect to hit events
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	
	local hitConfirmRemote = CombatEvents:FindFirstChild("HitConfirm")
	if hitConfirmRemote then
		hitConfirmRemote.OnClientEvent:Connect(function(data)
			QoLEnhancements.ShowHitMarker(data.isHeadshot)
			
			if QOL_CONFIG.damageNumbers then
				QoLEnhancements.ShowDamageNumber(data.damage, data.isHeadshot)
			end
		end)
	end
end

-- Show hit marker
function QoLEnhancements.ShowHitMarker(isHeadshot)
	if not hitMarker then return end
	
	-- Set color based on hit type
	if isHeadshot then
		hitMarker.ImageColor3 = Color3.new(1, 0, 0) -- Red for headshot
	else
		hitMarker.ImageColor3 = Color3.new(1, 1, 1) -- White for body shot
	end
	
	-- Animate hit marker
	hitMarker.ImageTransparency = 0
	hitMarker.Size = UDim2.new(0, 50, 0, 50)
	hitMarker.Position = UDim2.new(0.5, -25, 0.5, -25)
	
	local tween = TweenService:Create(hitMarker, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		ImageTransparency = 1,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(0.5, -20, 0.5, -20)
	})
	
	tween:Play()
end

-- Show damage number
function QoLEnhancements.ShowDamageNumber(damage, isHeadshot)
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Size = UDim2.new(0, 100, 0, 50)
	damageLabel.Position = UDim2.new(0.5, math.random(-50, 50), 0.5, math.random(-30, 30))
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = "-" .. damage
	damageLabel.TextColor3 = isHeadshot and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.SourceSansBold
	damageLabel.Parent = screenGui
	
	-- Animate damage number
	local tween = TweenService:Create(damageLabel, TweenInfo.new(1.0, Enum.EasingStyle.Quad), {
		Position = UDim2.new(damageLabel.Position.X.Scale, damageLabel.Position.X.Offset, 0.3, 0),
		TextTransparency = 1
	})
	
	tween:Play()
	tween.Completed:Connect(function()
		damageLabel:Destroy()
	end)
end

-- Setup kill feed
function QoLEnhancements.SetupKillFeed()
	if not QOL_CONFIG.killFeed then return end
	
	-- Connect to kill events
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	
	local killFeedRemote = CombatEvents:FindFirstChild("KillFeed")
	if killFeedRemote then
		killFeedRemote.OnClientEvent:Connect(function(killerName, victimName, weaponName, isHeadshot)
			QoLEnhancements.AddKillFeedEntry(killerName, victimName, weaponName, isHeadshot)
		end)
	end
end

-- Add kill feed entry
function QoLEnhancements.AddKillFeedEntry(killerName, victimName, weaponName, isHeadshot)
	if not killFeedFrame then return end
	
	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, 0, 0, 25)
	entry.BackgroundColor3 = Color3.new(0, 0, 0)
	entry.BackgroundTransparency = 0.5
	entry.Parent = killFeedFrame
	
	-- Killer name
	local killerLabel = Instance.new("TextLabel")
	killerLabel.Size = UDim2.new(0.4, 0, 1, 0)
	killerLabel.Position = UDim2.new(0, 0, 0, 0)
	killerLabel.BackgroundTransparency = 1
	killerLabel.Text = killerName
	killerLabel.TextColor3 = Color3.new(1, 1, 1)
	killerLabel.TextScaled = true
	killerLabel.TextXAlignment = Enum.TextXAlignment.Right
	killerLabel.Font = Enum.Font.SourceSans
	killerLabel.Parent = entry
	
	-- Weapon/method
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Size = UDim2.new(0.2, 0, 1, 0)
	weaponLabel.Position = UDim2.new(0.4, 0, 0, 0)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = isHeadshot and "🎯" or "💥"
	weaponLabel.TextColor3 = isHeadshot and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)
	weaponLabel.TextScaled = true
	weaponLabel.Font = Enum.Font.SourceSans
	weaponLabel.Parent = entry
	
	-- Victim name
	local victimLabel = Instance.new("TextLabel")
	victimLabel.Size = UDim2.new(0.4, 0, 1, 0)
	victimLabel.Position = UDim2.new(0.6, 0, 0, 0)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = victimName
	victimLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	victimLabel.TextScaled = true
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.Font = Enum.Font.SourceSans
	victimLabel.Parent = entry
	
	-- Fade out after 5 seconds
	task.spawn(function()
		task.wait(5)
		local fadeTween = TweenService:Create(entry, TweenInfo.new(1.0), {
			BackgroundTransparency = 1
		})
		fadeTween:Play()
		
		-- Fade text
		TweenService:Create(killerLabel, TweenInfo.new(1.0), {TextTransparency = 1}):Play()
		TweenService:Create(weaponLabel, TweenInfo.new(1.0), {TextTransparency = 1}):Play()
		TweenService:Create(victimLabel, TweenInfo.new(1.0), {TextTransparency = 1}):Play()
		
		fadeTween.Completed:Connect(function()
			entry:Destroy()
		end)
	end)
	
	-- Keep only recent entries
	local children = killFeedFrame:GetChildren()
	if #children > 10 then -- Keep only last 10 entries
		for i = 1, #children - 10 do
			if children[i]:IsA("Frame") then
				children[i]:Destroy()
			end
		end
	end
end

-- Setup audio enhancements
function QoLEnhancements.SetupAudioEnhancements()
	-- Enable spatial audio
	if QOL_CONFIG.spatialAudio then
		SoundService.RespectFilteringEnabled = false
	end
	
	-- Setup low health warning
	if QOL_CONFIG.lowHealthWarning then
		QoLEnhancements.SetupLowHealthWarning()
	end
end

-- Setup low health warning
function QoLEnhancements.SetupLowHealthWarning()
	-- Connect to health updates
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	
	local updateStatsRemote = UIEvents:FindFirstChild("UpdateStats")
	if updateStatsRemote then
		updateStatsRemote.OnClientEvent:Connect(function(stats)
			local healthPercentage = stats.Health / stats.MaxHealth
			
			if healthPercentage <= 0.25 and not enhancementState.isLowHealth then
				enhancementState.isLowHealth = true
				QoLEnhancements.StartLowHealthEffect()
			elseif healthPercentage > 0.25 and enhancementState.isLowHealth then
				enhancementState.isLowHealth = false
				QoLEnhancements.StopLowHealthEffect()
			end
		end)
	end
end

-- Start low health effect
function QoLEnhancements.StartLowHealthEffect()
	-- Create red screen tint
	local redTint = Instance.new("Frame")
	redTint.Name = "LowHealthTint"
	redTint.Size = UDim2.new(1, 0, 1, 0)
	redTint.Position = UDim2.new(0, 0, 0, 0)
	redTint.BackgroundColor3 = Color3.new(1, 0, 0)
	redTint.BackgroundTransparency = 0.8
	redTint.BorderSizePixel = 0
	redTint.ZIndex = 1
	redTint.Parent = screenGui
	
	-- Pulse effect
	local pulseTween = TweenService:Create(redTint, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.6
	})
	pulseTween:Play()
end

-- Stop low health effect
function QoLEnhancements.StopLowHealthEffect()
	local redTint = screenGui:FindFirstChild("LowHealthTint")
	if redTint then
		redTint:Destroy()
	end
end

-- Setup smart features
function QoLEnhancements.SetupSmartFeatures()
	if QOL_CONFIG.smartReload then
		QoLEnhancements.SetupSmartReload()
	end
	
	if QOL_CONFIG.scoreboardHotkey then
		QoLEnhancements.SetupScoreboardHotkey()
	end
end

-- Setup smart reload
function QoLEnhancements.SetupSmartReload()
	-- Auto-reload when ammo is low
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	
	local updateStatsRemote = UIEvents:FindFirstChild("UpdateStats")
	if updateStatsRemote then
		updateStatsRemote.OnClientEvent:Connect(function(stats)
			local ammoPercentage = stats.Ammo / (stats.Ammo + stats.Reserve)
			
			if ammoPercentage <= 0.1 and not enhancementState.ammoWarningShown then
				enhancementState.ammoWarningShown = true
				QoLEnhancements.ShowAmmoWarning()
			elseif ammoPercentage > 0.1 then
				enhancementState.ammoWarningShown = false
			end
		end)
	end
end

-- Show ammo warning
function QoLEnhancements.ShowAmmoWarning()
	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.new(0, 200, 0, 50)
	warningLabel.Position = UDim2.new(0.5, -100, 0.7, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "LOW AMMO!"
	warningLabel.TextColor3 = Color3.new(1, 0.5, 0)
	warningLabel.TextScaled = true
	warningLabel.Font = Enum.Font.SourceSansBold
	warningLabel.Parent = screenGui
	
	-- Pulse animation
	local pulseTween = TweenService:Create(warningLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
		TextTransparency = 0.5
	})
	pulseTween:Play()
	
	-- Remove after animation
	pulseTween.Completed:Connect(function()
		warningLabel:Destroy()
	end)
end

-- Setup scoreboard hotkey
function QoLEnhancements.SetupScoreboardHotkey()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.Tab then
			-- Show scoreboard
			QoLEnhancements.ToggleScoreboard(true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Tab then
			-- Hide scoreboard
			QoLEnhancements.ToggleScoreboard(false)
		end
	end)
end

-- Toggle scoreboard
function QoLEnhancements.ToggleScoreboard(show)
	-- This would show/hide the scoreboard
	-- Implementation depends on your scoreboard system
end

-- Setup accessibility features
function QoLEnhancements.SetupAccessibility()
	if QOL_CONFIG.colorBlindSupport then
		QoLEnhancements.EnableColorBlindSupport()
	end
	
	if QOL_CONFIG.reducedMotion then
		QoLEnhancements.EnableReducedMotion()
	end
	
	if QOL_CONFIG.highContrast then
		QoLEnhancements.EnableHighContrast()
	end
end

-- Enable color blind support
function QoLEnhancements.EnableColorBlindSupport()
	-- Modify UI colors for better visibility
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = 1.2
	colorCorrection.Contrast = 0.1
	colorCorrection.Parent = Lighting
end

-- Enable reduced motion
function QoLEnhancements.EnableReducedMotion()
	-- Reduce animation intensity
	QOL_CONFIG.smoothAnimations = false
end

-- Enable high contrast
function QoLEnhancements.EnableHighContrast()
	-- Increase UI contrast
	local colorCorrection = Lighting:FindFirstChild("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = Lighting
	end
	
	colorCorrection.Contrast = 0.3
end

-- Start enhancement loop
function QoLEnhancements.StartEnhancementLoop()
	RunService.Heartbeat:Connect(function()
		-- Update minimap if enabled
		if QOL_CONFIG.minimapEnabled and minimapFrame then
			QoLEnhancements.UpdateMinimap()
		end
		
		-- Update crosshair
		if QOL_CONFIG.crosshairCustomization and crosshair then
			QoLEnhancements.UpdateCrosshair()
		end
	end)
end

-- Update minimap
function QoLEnhancements.UpdateMinimap()
	-- This would update the minimap with player positions
	-- Implementation depends on your game's needs
end

-- Update crosshair
function QoLEnhancements.UpdateCrosshair()
	-- Dynamic crosshair based on movement/shooting
	local player = Players.LocalPlayer
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		local humanoid = player.Character.Humanoid
		local moveVector = humanoid.MoveDirection
		
		if moveVector.Magnitude > 0 then
			-- Expand crosshair when moving
			crosshair.Size = UDim2.new(0, 30, 0, 30)
			crosshair.Position = UDim2.new(0.5, -15, 0.5, -15)
		else
			-- Contract crosshair when stationary
			crosshair.Size = UDim2.new(0, 20, 0, 20)
			crosshair.Position = UDim2.new(0.5, -10, 0.5, -10)
		end
	end
end

-- Configuration functions
function QoLEnhancements.SetConfig(configName, value)
	if QOL_CONFIG[configName] ~= nil then
		QOL_CONFIG[configName] = value
		print("[QoLEnhancements] Set " .. configName .. " to " .. tostring(value))
		return true
	end
	return false
end

function QoLEnhancements.GetConfig(configName)
	return QOL_CONFIG[configName]
end

return QoLEnhancements
