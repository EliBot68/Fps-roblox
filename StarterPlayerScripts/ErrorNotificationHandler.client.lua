--!strict
--[[
	ErrorNotificationHandler.client.lua
	Client-side Error and Recovery Notification Handler
	
	Handles error, circuit breaker, and recovery notifications from the server
	to provide transparent communication to players about system status.
	
	Features:
	- Circuit breaker state notifications
	- Recovery progress notifications
	- Error impact notifications
	- Non-intrusive UI integration
	- Performance-aware display
	- Player preference respect
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

-- Get services
local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local uiEvents = remoteEvents:WaitForChild("UIEvents")
local circuitBreakerNotification = uiEvents:WaitForChild("CircuitBreakerNotification")
local recoveryNotification = uiEvents:WaitForChild("RecoveryNotification")

-- Configuration
local NOTIFICATION_DURATION = 5 -- seconds
local MAX_CONCURRENT_NOTIFICATIONS = 3
local NOTIFICATION_FADEOUT_TIME = 1 -- seconds

-- State
local activeNotifications: {[string]: any} = {}
local notificationQueue: {any} = {}
local notificationContainer: ScreenGui?
local notificationFrame: Frame?

-- Initialize notification UI
local function initializeNotificationUI(): ()
	-- Create ScreenGui for notifications
	notificationContainer = Instance.new("ScreenGui")
	notificationContainer.Name = "ErrorNotifications"
	notificationContainer.ResetOnSpawn = false
	notificationContainer.IgnoreGuiInset = true
	notificationContainer.Parent = player:WaitForChild("PlayerGui")
	
	-- Create container frame
	notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationContainer"
	notificationFrame.Size = UDim2.new(0, 400, 0, 200)
	notificationFrame.Position = UDim2.new(1, -420, 0, 20)
	notificationFrame.BackgroundTransparency = 1
	notificationFrame.Parent = notificationContainer
	
	-- Create UIListLayout for stacking notifications
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Parent = notificationFrame
end

-- Create notification UI element
local function createNotificationElement(data: any): Frame
	local notification = Instance.new("Frame")
	notification.Name = "Notification_" .. (data.id or "unknown")
	notification.Size = UDim2.new(1, 0, 0, 80)
	notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	notification.BorderSizePixel = 0
	notification.ClipsDescendants = true
	
	-- Create corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification
	
	-- Create severity indicator
	local severityBar = Instance.new("Frame")
	severityBar.Name = "SeverityBar"
	severityBar.Size = UDim2.new(0, 4, 1, 0)
	severityBar.Position = UDim2.new(0, 0, 0, 0)
	severityBar.BorderSizePixel = 0
	severityBar.Parent = notification
	
	-- Set severity color
	local severityColor = Color3.fromRGB(100, 100, 100) -- Default
	if data.severity == "error" or data.severity == "critical" then
		severityColor = Color3.fromRGB(220, 53, 69) -- Red
	elseif data.severity == "warning" then
		severityColor = Color3.fromRGB(255, 193, 7) -- Yellow
	elseif data.severity == "success" then
		severityColor = Color3.fromRGB(40, 167, 69) -- Green
	elseif data.severity == "info" then
		severityColor = Color3.fromRGB(23, 162, 184) -- Blue
	end
	severityBar.BackgroundColor3 = severityColor
	
	-- Create service name label
	local serviceLabel = Instance.new("TextLabel")
	serviceLabel.Name = "ServiceLabel"
	serviceLabel.Size = UDim2.new(1, -15, 0, 20)
	serviceLabel.Position = UDim2.new(0, 10, 0, 5)
	serviceLabel.BackgroundTransparency = 1
	serviceLabel.Text = data.serviceName or "System"
	serviceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	serviceLabel.TextScaled = true
	serviceLabel.Font = Enum.Font.GothamBold
	serviceLabel.TextXAlignment = Enum.TextXAlignment.Left
	serviceLabel.Parent = notification
	
	-- Create message label
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageLabel"
	messageLabel.Size = UDim2.new(1, -15, 0, 35)
	messageLabel.Position = UDim2.new(0, 10, 0, 25)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = data.message or "System notification"
	messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	messageLabel.TextScaled = true
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextWrapped = true
	messageLabel.Parent = notification
	
	-- Create timestamp label
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(1, -15, 0, 15)
	timeLabel.Position = UDim2.new(0, 10, 1, -20)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = os.date("%H:%M:%S", data.timestamp or os.time())
	timeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	timeLabel.TextScaled = true
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Parent = notification
	
	-- Create close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 20, 0, 20)
	closeButton.Position = UDim2.new(1, -25, 0, 5)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = notification
	
	-- Close button functionality
	closeButton.MouseButton1Click:Connect(function()
		removeNotification(notification.Name)
	end)
	
	-- Hover effects
	closeButton.MouseEnter:Connect(function()
		closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
	
	closeButton.MouseLeave:Connect(function()
		closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	end)
	
	return notification
end

-- Show notification
local function showNotification(data: any): ()
	if not notificationFrame then
		return
	end
	
	-- Create unique ID if not provided
	local notificationId = data.id or tostring(tick())
	data.id = notificationId
	
	-- Check if we already have this notification
	if activeNotifications[notificationId] then
		return
	end
	
	-- Limit concurrent notifications
	if #activeNotifications >= MAX_CONCURRENT_NOTIFICATIONS then
		table.insert(notificationQueue, data)
		return
	end
	
	-- Create notification element
	local notificationElement = createNotificationElement(data)
	notificationElement.Parent = notificationFrame
	
	-- Store active notification
	activeNotifications[notificationId] = {
		element = notificationElement,
		data = data,
		startTime = tick()
	}
	
	-- Animate in
	notificationElement.Position = UDim2.new(1, 50, 0, 0)
	local tweenIn = TweenService:Create(
		notificationElement,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0, 0, 0, 0)}
	)
	tweenIn:Play()
	
	-- Schedule automatic removal
	task.delay(NOTIFICATION_DURATION, function()
		removeNotification(notificationId)
	end)
end

-- Remove notification
function removeNotification(notificationId: string): ()
	local notification = activeNotifications[notificationId]
	if not notification then
		return
	end
	
	local element = notification.element
	
	-- Animate out
	local tweenOut = TweenService:Create(
		element,
		TweenInfo.new(NOTIFICATION_FADEOUT_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, 50, element.Position.Y.Scale, element.Position.Y.Offset)}
	)
	
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		element:Destroy()
		activeNotifications[notificationId] = nil
		
		-- Show queued notification if any
		if #notificationQueue > 0 then
			local queuedData = table.remove(notificationQueue, 1)
			showNotification(queuedData)
		end
	end)
end

-- Process circuit breaker notifications
local function handleCircuitBreakerNotification(data: any): ()
	local message = data.message
	local severity = data.severity or "info"
	
	-- Enhance message based on state
	if data.state == "Open" then
		message = "🔴 " .. message
		severity = "warning"
	elseif data.state == "Closed" then
		message = "🟢 " .. message
		severity = "success"
	elseif data.state == "HalfOpen" then
		message = "🟡 " .. message
		severity = "info"
	end
	
	showNotification({
		id = "cb_" .. data.serviceName .. "_" .. (data.timestamp or tick()),
		serviceName = data.serviceName,
		message = message,
		severity = severity,
		timestamp = data.timestamp,
		type = "circuit_breaker"
	})
end

-- Process recovery notifications
local function handleRecoveryNotification(data: any): ()
	local message = data.message
	local severity = data.severity or "info"
	
	-- Enhance message based on phase
	if data.phase == "started" then
		message = "🔧 " .. message
		severity = "info"
	elseif data.phase == "completed" then
		message = "✅ " .. message
		severity = "success"
	elseif data.phase == "failed" then
		message = "❌ " .. message
		severity = "error"
	end
	
	showNotification({
		id = "recovery_" .. data.serviceName .. "_" .. (data.timestamp or tick()),
		serviceName = data.serviceName,
		message = message,
		severity = severity,
		timestamp = data.timestamp,
		type = "recovery"
	})
end

-- Clean up expired notifications
local function cleanupNotifications(): ()
	local currentTime = tick()
	
	for notificationId, notification in pairs(activeNotifications) do
		if currentTime - notification.startTime > NOTIFICATION_DURATION + 5 then
			removeNotification(notificationId)
		end
	end
end

-- Initialize system
local function initialize(): ()
	-- Wait for player to load
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	
	-- Initialize UI
	initializeNotificationUI()
	
	-- Connect remote events
	circuitBreakerNotification.OnClientEvent:Connect(handleCircuitBreakerNotification)
	recoveryNotification.OnClientEvent:Connect(handleRecoveryNotification)
	
	-- Setup cleanup task
	task.spawn(function()
		while true do
			task.wait(30) -- Clean up every 30 seconds
			cleanupNotifications()
		end
	end)
	
	print("Error notification handler initialized")
end

-- Start initialization
task.spawn(initialize)

-- Return module for potential external access
return {
	showNotification = showNotification,
	removeNotification = removeNotification,
	getActiveNotifications = function()
		return activeNotifications
	end
}
