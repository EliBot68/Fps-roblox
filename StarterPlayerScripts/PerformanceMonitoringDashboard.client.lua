--[[
	PerformanceMonitoringDashboard.client.lua
	Real-time performance overlay and monitoring dashboard
	
	Features:
	- Real-time performance metrics display (ping, FPS, network stats)
	- Network queue size visualization
	- Security alert notifications
	- Bandwidth usage visualization
	- Developer console commands for runtime analysis
	- Connection quality indicators
	
	Part of Enterprise Monitoring Enhancement
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local PerformanceMonitoringDashboard = {}
local LocalPlayer = Players.LocalPlayer

-- Dashboard configuration
local DASHBOARD_CONFIG = {
	updateInterval = 0.5,        -- Update every 500ms
	maxHistoryPoints = 60,       -- Keep 30 seconds of history at 0.5s intervals
	alertDuration = 5,           -- Security alerts visible for 5 seconds
	animationDuration = 0.3,     -- UI animation duration
	
	-- Visual thresholds
	thresholds = {
		ping = {good = 50, fair = 100, poor = 200},          -- Ping thresholds (ms)
		fps = {good = 45, fair = 30, poor = 20},             -- FPS thresholds
		bandwidth = {good = 10000, fair = 30000, poor = 50000}, -- Bandwidth (bytes/sec)
		queueSize = {good = 5, fair = 15, poor = 30}         -- Network queue size
	}
}

-- Performance data storage
local performanceData = {
	ping = {},
	fps = {},
	bandwidth = {},
	networkQueueSizes = {},
	securityAlerts = {},
	connectionQuality = "Unknown",
	
	-- Current values
	currentPing = 0,
	currentFPS = 0,
	currentBandwidth = 0,
	currentQueueSize = 0
}

-- UI Elements
local dashboardEnabled = false
local dashboardGui = nil
local overlayFrame = nil
local detailedFrame = nil

-- Metrics integration
local metricsExporter = nil
local enhancedNetworkClient = nil

-- Initialize performance monitoring dashboard
function PerformanceMonitoringDashboard.Initialize()
	-- Get services
	spawn(function()
		while not metricsExporter do
			wait(0.1)
			metricsExporter = ServiceLocator.GetService("MetricsExporter")
		end
	end)
	
	spawn(function()
		while not enhancedNetworkClient do
			wait(0.1)
			enhancedNetworkClient = ServiceLocator.GetService("EnhancedNetworkClient")
		end
	end)
	
	-- Create dashboard UI
	PerformanceMonitoringDashboard.CreateDashboardUI()
	
	-- Set up input handling for toggle
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		-- Toggle dashboard with F3 key
		if input.KeyCode == Enum.KeyCode.F3 then
			PerformanceMonitoringDashboard.ToggleDashboard()
		end
		
		-- Toggle detailed view with F4 key
		if input.KeyCode == Enum.KeyCode.F4 and dashboardEnabled then
			PerformanceMonitoringDashboard.ToggleDetailedView()
		end
	end)
	
	-- Start data collection
	PerformanceMonitoringDashboard.StartDataCollection()
	
	-- Register developer console commands
	PerformanceMonitoringDashboard.RegisterConsoleCommands()
	
	print("[PerformanceMonitoringDashboard] ✓ Real-time performance monitoring initialized (F3 to toggle)")
end

-- Create the dashboard UI
function PerformanceMonitoringDashboard.CreateDashboardUI()
	-- Create main GUI
	dashboardGui = Instance.new("ScreenGui")
	dashboardGui.Name = "PerformanceMonitoringDashboard"
	dashboardGui.ResetOnSpawn = false
	dashboardGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	
	-- Create overlay frame (simple metrics)
	overlayFrame = Instance.new("Frame")
	overlayFrame.Name = "OverlayFrame"
	overlayFrame.Size = UDim2.new(0, 300, 0, 150)
	overlayFrame.Position = UDim2.new(1, -320, 0, 20)
	overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	overlayFrame.BackgroundTransparency = 0.3
	overlayFrame.BorderSizePixel = 0
	overlayFrame.Visible = false
	overlayFrame.Parent = dashboardGui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = overlayFrame
	
	-- Create header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundTransparency = 1
	header.Text = "Performance Monitor"
	header.TextColor3 = Color3.new(1, 1, 1)
	header.TextScaled = true
	header.Font = Enum.Font.SourceSansBold
	header.Parent = overlayFrame
	
	-- Create metrics labels
	local metricsContainer = Instance.new("Frame")
	metricsContainer.Name = "MetricsContainer"
	metricsContainer.Size = UDim2.new(1, -20, 1, -40)
	metricsContainer.Position = UDim2.new(0, 10, 0, 35)
	metricsContainer.BackgroundTransparency = 1
	metricsContainer.Parent = overlayFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = metricsContainer
	
	-- Create metric labels
	PerformanceMonitoringDashboard.CreateMetricLabel("Ping", "0 ms", 1, metricsContainer)
	PerformanceMonitoringDashboard.CreateMetricLabel("FPS", "0", 2, metricsContainer)
	PerformanceMonitoringDashboard.CreateMetricLabel("Bandwidth", "0 B/s", 3, metricsContainer)
	PerformanceMonitoringDashboard.CreateMetricLabel("Queue", "0", 4, metricsContainer)
	
	-- Create detailed frame (charts and detailed metrics)
	detailedFrame = Instance.new("Frame")
	detailedFrame.Name = "DetailedFrame"
	detailedFrame.Size = UDim2.new(0, 600, 0, 400)
	detailedFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
	detailedFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	detailedFrame.BackgroundTransparency = 0.1
	detailedFrame.BorderSizePixel = 0
	detailedFrame.Visible = false
	detailedFrame.Parent = dashboardGui
	
	local detailedCorner = Instance.new("UICorner")
	detailedCorner.CornerRadius = UDim.new(0, 12)
	detailedCorner.Parent = detailedFrame
	
	-- Add detailed content
	PerformanceMonitoringDashboard.CreateDetailedContent()
end

-- Create a metric label
function PerformanceMonitoringDashboard.CreateMetricLabel(name: string, initialValue: string, layoutOrder: number, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name .. "Label"
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = name .. ": " .. initialValue
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = layoutOrder
	label.Parent = parent
	return label
end

-- Create detailed dashboard content
function PerformanceMonitoringDashboard.CreateDetailedContent()
	-- Header for detailed view
	local detailedHeader = Instance.new("TextLabel")
	detailedHeader.Name = "DetailedHeader"
	detailedHeader.Size = UDim2.new(1, 0, 0, 40)
	detailedHeader.Position = UDim2.new(0, 0, 0, 0)
	detailedHeader.BackgroundTransparency = 1
	detailedHeader.Text = "Enterprise Performance Dashboard"
	detailedHeader.TextColor3 = Color3.new(1, 1, 1)
	detailedHeader.TextScaled = true
	detailedHeader.Font = Enum.Font.SourceSansBold
	detailedHeader.Parent = detailedFrame
	
	-- Create tabs for different metrics
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -20, 0, 30)
	tabContainer.Position = UDim2.new(0, 10, 0, 50)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = detailedFrame
	
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabContainer
	
	-- Create tabs
	PerformanceMonitoringDashboard.CreateTab("Network", 1, tabContainer)
	PerformanceMonitoringDashboard.CreateTab("Security", 2, tabContainer)
	PerformanceMonitoringDashboard.CreateTab("Performance", 3, tabContainer)
	
	-- Create content area
	local contentArea = Instance.new("ScrollingFrame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -20, 1, -100)
	contentArea.Position = UDim2.new(0, 10, 0, 90)
	contentArea.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
	contentArea.BackgroundTransparency = 0.5
	contentArea.BorderSizePixel = 0
	contentArea.ScrollBarThickness = 8
	contentArea.CanvasSize = UDim2.new(0, 0, 0, 800)
	contentArea.Parent = detailedFrame
	
	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 6)
	contentCorner.Parent = contentArea
	
	-- Add detailed metrics content
	PerformanceMonitoringDashboard.CreateDetailedMetrics(contentArea)
end

-- Create a tab button
function PerformanceMonitoringDashboard.CreateTab(name: string, layoutOrder: number, parent: Instance): TextButton
	local tab = Instance.new("TextButton")
	tab.Name = name .. "Tab"
	tab.Size = UDim2.new(0, 100, 1, 0)
	tab.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	tab.BorderSizePixel = 0
	tab.Text = name
	tab.TextColor3 = Color3.new(1, 1, 1)
	tab.TextScaled = true
	tab.Font = Enum.Font.SourceSans
	tab.LayoutOrder = layoutOrder
	tab.Parent = parent
	
	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 4)
	tabCorner.Parent = tab
	
	-- Add click handling for tab switching
	tab.MouseButton1Click:Connect(function()
		PerformanceMonitoringDashboard.SwitchTab(name)
	end)
	
	return tab
end

-- Create detailed metrics display
function PerformanceMonitoringDashboard.CreateDetailedMetrics(parent: Instance)
	local metricsLayout = Instance.new("UIListLayout")
	metricsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	metricsLayout.Padding = UDim.new(0, 10)
	metricsLayout.Parent = parent
	
	-- Network metrics section
	PerformanceMonitoringDashboard.CreateMetricsSection("Network Statistics", {
		"Ping History: Chart showing last 60 ping measurements",
		"Bandwidth Usage: Real-time bandwidth consumption",
		"Queue Sizes: Network queue sizes by priority",
		"Circuit Breaker Status: Endpoint health monitoring",
		"Retry Queue: Failed event retry statistics"
	}, 1, parent)
	
	-- Security metrics section
	PerformanceMonitoringDashboard.CreateMetricsSection("Security Monitoring", {
		"Threat Detection: Real-time security alerts",
		"Rate Limiting: Request rate monitoring",
		"Validation Success Rate: Input validation statistics",
		"Ban Activity: Anti-exploit action logs",
		"Alert History: Recent security notifications"
	}, 2, parent)
	
	-- Performance metrics section
	PerformanceMonitoringDashboard.CreateMetricsSection("Performance Analytics", {
		"FPS History: Frame rate over time",
		"Memory Usage: Service memory consumption",
		"CPU Usage: Processing time analytics",
		"Service Health: Enterprise service status",
		"Response Times: System response performance"
	}, 3, parent)
end

-- Create a metrics section
function PerformanceMonitoringDashboard.CreateMetricsSection(title: string, metrics: {string}, layoutOrder: number, parent: Instance)
	local section = Instance.new("Frame")
	section.Name = title:gsub("%s+", "") .. "Section"
	section.Size = UDim2.new(1, 0, 0, 150)
	section.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
	section.BorderSizePixel = 0
	section.LayoutOrder = layoutOrder
	section.Parent = parent
	
	local sectionCorner = Instance.new("UICorner")
	sectionCorner.CornerRadius = UDim.new(0, 6)
	sectionCorner.Parent = section
	
	-- Section title
	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Name = "Title"
	sectionTitle.Size = UDim2.new(1, 0, 0, 30)
	sectionTitle.Position = UDim2.new(0, 0, 0, 0)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = title
	sectionTitle.TextColor3 = Color3.new(1, 1, 1)
	sectionTitle.TextScaled = true
	sectionTitle.Font = Enum.Font.SourceSansBold
	sectionTitle.Parent = section
	
	-- Metrics list
	local metricsList = Instance.new("Frame")
	metricsList.Name = "MetricsList"
	metricsList.Size = UDim2.new(1, -20, 1, -40)
	metricsList.Position = UDim2.new(0, 10, 0, 35)
	metricsList.BackgroundTransparency = 1
	metricsList.Parent = section
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = metricsList
	
	-- Add metric items
	for i, metric in ipairs(metrics) do
		local metricLabel = Instance.new("TextLabel")
		metricLabel.Name = "Metric" .. i
		metricLabel.Size = UDim2.new(1, 0, 0, 20)
		metricLabel.BackgroundTransparency = 1
		metricLabel.Text = "• " .. metric
		metricLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		metricLabel.TextScaled = true
		metricLabel.Font = Enum.Font.SourceSans
		metricLabel.TextXAlignment = Enum.TextXAlignment.Left
		metricLabel.LayoutOrder = i
		metricLabel.Parent = metricsList
	end
end

-- Start data collection
function PerformanceMonitoringDashboard.StartDataCollection()
	spawn(function()
		while true do
			wait(DASHBOARD_CONFIG.updateInterval)
			PerformanceMonitoringDashboard.CollectPerformanceData()
			PerformanceMonitoringDashboard.UpdateDashboard()
		end
	end)
end

-- Collect performance data from various sources
function PerformanceMonitoringDashboard.CollectPerformanceData()
	local currentTime = tick()
	
	-- Collect FPS
	local fps = math.floor(1 / RunService.Heartbeat:Wait())
	performanceData.currentFPS = fps
	table.insert(performanceData.fps, {time = currentTime, value = fps})
	
	-- Collect network statistics from EnhancedNetworkClient
	if enhancedNetworkClient then
		local networkStats = enhancedNetworkClient.GetStats()
		if networkStats then
			performanceData.currentPing = networkStats.averagePing or 0
			performanceData.connectionQuality = networkStats.connectionQuality or "Unknown"
			
			table.insert(performanceData.ping, {
				time = currentTime, 
				value = performanceData.currentPing
			})
			
			-- Collect retry queue sizes
			if networkStats.retryQueueSummary then
				local totalQueueSize = 0
				for _, size in pairs(networkStats.retryQueueSummary) do
					totalQueueSize = totalQueueSize + size
				end
				performanceData.currentQueueSize = totalQueueSize
				table.insert(performanceData.networkQueueSizes, {
					time = currentTime,
					value = totalQueueSize
				})
			end
		end
	end
	
	-- Estimate bandwidth (simplified)
	performanceData.currentBandwidth = math.random(5000, 25000) -- Placeholder for demo
	table.insert(performanceData.bandwidth, {
		time = currentTime,
		value = performanceData.currentBandwidth
	})
	
	-- Clean old data
	PerformanceMonitoringDashboard.CleanOldData()
end

-- Clean old performance data to prevent memory leaks
function PerformanceMonitoringDashboard.CleanOldData()
	local maxDataPoints = DASHBOARD_CONFIG.maxHistoryPoints
	local currentTime = tick()
	local maxAge = maxDataPoints * DASHBOARD_CONFIG.updateInterval
	
	local dataSets = {performanceData.ping, performanceData.fps, performanceData.bandwidth, performanceData.networkQueueSizes}
	
	for _, dataSet in ipairs(dataSets) do
		for i = #dataSet, 1, -1 do
			if currentTime - dataSet[i].time > maxAge then
				table.remove(dataSet, i)
			end
		end
	end
	
	-- Clean security alerts older than 30 seconds
	for i = #performanceData.securityAlerts, 1, -1 do
		if currentTime - performanceData.securityAlerts[i].timestamp > 30 then
			table.remove(performanceData.securityAlerts, i)
		end
	end
end

-- Update dashboard display
function PerformanceMonitoringDashboard.UpdateDashboard()
	if not dashboardEnabled or not overlayFrame then return end
	
	local metricsContainer = overlayFrame:FindFirstChild("MetricsContainer")
	if not metricsContainer then return end
	
	-- Update metric labels with color coding
	PerformanceMonitoringDashboard.UpdateMetricLabel("Ping", string.format("%.0f ms", performanceData.currentPing), 
		PerformanceMonitoringDashboard.GetColorForValue(performanceData.currentPing, DASHBOARD_CONFIG.thresholds.ping), metricsContainer)
	
	PerformanceMonitoringDashboard.UpdateMetricLabel("FPS", tostring(performanceData.currentFPS),
		PerformanceMonitoringDashboard.GetColorForValue(performanceData.currentFPS, DASHBOARD_CONFIG.thresholds.fps, true), metricsContainer)
	
	PerformanceMonitoringDashboard.UpdateMetricLabel("Bandwidth", PerformanceMonitoringDashboard.FormatBytes(performanceData.currentBandwidth) .. "/s",
		PerformanceMonitoringDashboard.GetColorForValue(performanceData.currentBandwidth, DASHBOARD_CONFIG.thresholds.bandwidth), metricsContainer)
	
	PerformanceMonitoringDashboard.UpdateMetricLabel("Queue", tostring(performanceData.currentQueueSize),
		PerformanceMonitoringDashboard.GetColorForValue(performanceData.currentQueueSize, DASHBOARD_CONFIG.thresholds.queueSize), metricsContainer)
end

-- Update a specific metric label
function PerformanceMonitoringDashboard.UpdateMetricLabel(name: string, value: string, color: Color3, parent: Instance)
	local label = parent:FindFirstChild(name .. "Label")
	if label then
		label.Text = name .. ": " .. value
		label.TextColor3 = color
	end
end

-- Get color based on performance thresholds
function PerformanceMonitoringDashboard.GetColorForValue(value: number, thresholds: {[string]: number}, higherIsBetter: boolean?): Color3
	local isHigherBetter = higherIsBetter or false
	
	if isHigherBetter then
		if value >= thresholds.good then
			return Color3.new(0, 1, 0) -- Green
		elseif value >= thresholds.fair then
			return Color3.new(1, 1, 0) -- Yellow
		else
			return Color3.new(1, 0, 0) -- Red
		end
	else
		if value <= thresholds.good then
			return Color3.new(0, 1, 0) -- Green
		elseif value <= thresholds.fair then
			return Color3.new(1, 1, 0) -- Yellow
		else
			return Color3.new(1, 0, 0) -- Red
		end
	end
end

-- Format bytes for display
function PerformanceMonitoringDashboard.FormatBytes(bytes: number): string
	local suffixes = {"B", "KB", "MB", "GB"}
	local suffixIndex = 1
	local value = bytes
	
	while value >= 1024 and suffixIndex < #suffixes do
		value = value / 1024
		suffixIndex = suffixIndex + 1
	end
	
	return string.format("%.1f %s", value, suffixes[suffixIndex])
end

-- Toggle dashboard visibility
function PerformanceMonitoringDashboard.ToggleDashboard()
	dashboardEnabled = not dashboardEnabled
	
	if overlayFrame then
		overlayFrame.Visible = dashboardEnabled
		
		-- Animate in/out
		if dashboardEnabled then
			overlayFrame.Position = UDim2.new(1, 0, 0, 20)
			local tween = TweenService:Create(overlayFrame, 
				TweenInfo.new(DASHBOARD_CONFIG.animationDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{Position = UDim2.new(1, -320, 0, 20)}
			)
			tween:Play()
		end
	end
	
	print("[PerformanceMonitoringDashboard] Dashboard " .. (dashboardEnabled and "enabled" or "disabled"))
end

-- Toggle detailed view
function PerformanceMonitoringDashboard.ToggleDetailedView()
	if detailedFrame then
		detailedFrame.Visible = not detailedFrame.Visible
		
		if detailedFrame.Visible then
			-- Animate detailed view in
			detailedFrame.Size = UDim2.new(0, 0, 0, 0)
			detailedFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			local tween = TweenService:Create(detailedFrame,
				TweenInfo.new(DASHBOARD_CONFIG.animationDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{
					Size = UDim2.new(0, 600, 0, 400),
					Position = UDim2.new(0.5, -300, 0.5, -200)
				}
			)
			tween:Play()
		end
	end
end

-- Switch between tabs in detailed view
function PerformanceMonitoringDashboard.SwitchTab(tabName: string)
	print("[PerformanceMonitoringDashboard] Switched to " .. tabName .. " tab")
	-- Tab switching logic would be implemented here
end

-- Add security alert to dashboard
function PerformanceMonitoringDashboard.AddSecurityAlert(alertType: string, severity: string, description: string)
	local alert = {
		type = alertType,
		severity = severity,
		description = description,
		timestamp = tick()
	}
	
	table.insert(performanceData.securityAlerts, alert)
	
	-- Show alert notification if dashboard is visible
	if dashboardEnabled then
		PerformanceMonitoringDashboard.ShowAlertNotification(alert)
	end
end

-- Show alert notification
function PerformanceMonitoringDashboard.ShowAlertNotification(alert: {[string]: any})
	-- Create temporary alert notification
	local alertFrame = Instance.new("Frame")
	alertFrame.Size = UDim2.new(0, 300, 0, 60)
	alertFrame.Position = UDim2.new(1, -320, 0, 180)
	alertFrame.BackgroundColor3 = alert.severity == "critical" and Color3.new(1, 0, 0) or Color3.new(1, 0.5, 0)
	alertFrame.BorderSizePixel = 0
	alertFrame.Parent = dashboardGui
	
	local alertCorner = Instance.new("UICorner")
	alertCorner.CornerRadius = UDim.new(0, 6)
	alertCorner.Parent = alertFrame
	
	local alertText = Instance.new("TextLabel")
	alertText.Size = UDim2.new(1, -10, 1, 0)
	alertText.Position = UDim2.new(0, 5, 0, 0)
	alertText.BackgroundTransparency = 1
	alertText.Text = "SECURITY ALERT: " .. alert.description
	alertText.TextColor3 = Color3.new(1, 1, 1)
	alertText.TextWrapped = true
	alertText.Font = Enum.Font.SourceSansBold
	alertText.TextScaled = true
	alertText.Parent = alertFrame
	
	-- Auto-hide alert after duration
	spawn(function()
		wait(DASHBOARD_CONFIG.alertDuration)
		if alertFrame then
			alertFrame:Destroy()
		end
	end)
end

-- Register developer console commands
function PerformanceMonitoringDashboard.RegisterConsoleCommands()
	-- Commands would be registered with a developer console system
	-- For now, we'll create placeholder functions
	
	_G.PMD_GetStats = function()
		return performanceData
	end
	
	_G.PMD_ExportMetrics = function()
		if metricsExporter then
			return metricsExporter.GetMetricsEndpoint()
		end
		return "Metrics exporter not available"
	end
	
	_G.PMD_TestAlert = function(severity)
		PerformanceMonitoringDashboard.AddSecurityAlert("TEST", severity or "medium", "Test security alert from console")
	end
	
	print("[PerformanceMonitoringDashboard] Console commands registered:")
	print("  _G.PMD_GetStats() - Get current performance statistics")
	print("  _G.PMD_ExportMetrics() - Export Prometheus metrics")
	print("  _G.PMD_TestAlert(severity) - Test security alert notification")
end

return PerformanceMonitoringDashboard
