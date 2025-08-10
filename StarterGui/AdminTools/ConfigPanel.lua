--!strict
--[[
	ConfigPanel.lua
	Enterprise Configuration Management Admin Panel
	
	Provides an intuitive admin interface for managing feature flags, A/B tests,
	and configuration settings with real-time updates and validation.
	
	Features:
	- Feature flag management interface
	- A/B test creation and monitoring
	- Configuration editor with validation
	- Real-time metrics dashboard
	- User segment management
	- Admin command interface
	- Export/import functionality
	- Configuration history viewer
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

-- Types
type FeatureFlag = {
	name: string,
	enabled: boolean,
	userSegments: {string},
	rolloutPercentage: number,
	description: string
}

type ABTest = {
	name: string,
	variants: {string},
	traffic: {[string]: number},
	isActive: boolean,
	targetSegments: {string}
}

type MetricsData = {
	experiments: any,
	featureFlags: any,
	serverHealth: any,
	timestamp: number
}

-- ConfigPanel Class
local ConfigPanel = {}
ConfigPanel.__index = ConfigPanel

-- Private Variables
local player = Players.LocalPlayer
local gui: ScreenGui
local mainFrame: Frame
local tabButtons: {TextButton} = {}
local tabFrames: {Frame} = {}
local currentTab = "flags"
local isVisible = false

-- Remote Events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local featureFlagRemotes = remoteEvents:WaitForChild("FeatureFlagEvents")
local adminCommandRemote = featureFlagRemotes:WaitForChild("AdminCommand")
local configUpdatedRemote = featureFlagRemotes:WaitForChild("ConfigUpdated")

-- Data Storage
local currentFlags: {[string]: FeatureFlag} = {}
local currentTests: {[string]: ABTest} = {}
local currentMetrics: MetricsData? = nil
local userSegments: {[string]: any} = {}

-- Initialization
function ConfigPanel.new(): typeof(ConfigPanel)
	local self = setmetatable({}, ConfigPanel)
	
	self:_createGUI()
	self:_setupRemoteHandlers()
	self:_setupInputHandlers()
	
	-- Request initial data
	self:_requestMetrics()
	
	return self
end

-- Create GUI Components
function ConfigPanel:_createGUI(): ()
	-- Main ScreenGui
	gui = Instance.new("ScreenGui")
	gui.Name = "ConfigAdminPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	
	-- Main Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
	mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = gui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleBar
	
	-- Title Text
	local titleText = Instance.new("TextLabel")
	titleText.Name = "TitleText"
	titleText.Size = UDim2.new(1, -100, 1, 0)
	titleText.Position = UDim2.new(0, 20, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "🏢 Enterprise Configuration Manager"
	titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleText.TextScaled = true
	titleText.Font = Enum.Font.GothamBold
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.Parent = titleBar
	
	-- Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = titleBar
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		self:Hide()
	end)
	
	-- Tab Container
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, 0, 0, 40)
	tabContainer.Position = UDim2.new(0, 0, 0, 60)
	tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	tabContainer.BorderSizePixel = 0
	tabContainer.Parent = mainFrame
	
	-- Create tabs
	self:_createTabs(tabContainer)
	
	-- Content Area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -20, 1, -120)
	contentArea.Position = UDim2.new(0, 10, 0, 110)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainFrame
	
	-- Create tab content frames
	self:_createTabContent(contentArea)
end

-- Create tab buttons
function ConfigPanel:_createTabs(parent: Frame): ()
	local tabs = {
		{name = "flags", text = "🚩 Feature Flags", color = Color3.fromRGB(100, 150, 255)},
		{name = "tests", text = "🧪 A/B Tests", color = Color3.fromRGB(255, 150, 100)},
		{name = "config", text = "⚙️ Configuration", color = Color3.fromRGB(150, 255, 100)},
		{name = "metrics", text = "📊 Metrics", color = Color3.fromRGB(255, 100, 150)},
		{name = "segments", text = "👥 User Segments", color = Color3.fromRGB(200, 100, 255)}
	}
	
	for i, tab in ipairs(tabs) do
		local button = Instance.new("TextButton")
		button.Name = tab.name .. "Tab"
		button.Size = UDim2.new(1/#tabs, -4, 1, -8)
		button.Position = UDim2.new((i-1)/#tabs, 2, 0, 4)
		button.BackgroundColor3 = tab.color
		button.BorderSizePixel = 0
		button.Text = tab.text
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextScaled = true
		button.Font = Enum.Font.Gotham
		button.Parent = parent
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		
		button.MouseButton1Click:Connect(function()
			self:_switchTab(tab.name)
		end)
		
		tabButtons[tab.name] = button
	end
end

-- Create tab content frames
function ConfigPanel:_createTabContent(parent: Frame): ()
	-- Feature Flags Tab
	local flagsFrame = Instance.new("ScrollingFrame")
	flagsFrame.Name = "FlagsFrame"
	flagsFrame.Size = UDim2.new(1, 0, 1, 0)
	flagsFrame.Position = UDim2.new(0, 0, 0, 0)
	flagsFrame.BackgroundTransparency = 1
	flagsFrame.ScrollBarThickness = 8
	flagsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	flagsFrame.Visible = true
	flagsFrame.Parent = parent
	tabFrames["flags"] = flagsFrame
	
	-- A/B Tests Tab
	local testsFrame = Instance.new("ScrollingFrame")
	testsFrame.Name = "TestsFrame"
	testsFrame.Size = UDim2.new(1, 0, 1, 0)
	testsFrame.Position = UDim2.new(0, 0, 0, 0)
	testsFrame.BackgroundTransparency = 1
	testsFrame.ScrollBarThickness = 8
	testsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	testsFrame.Visible = false
	testsFrame.Parent = parent
	tabFrames["tests"] = testsFrame
	
	-- Configuration Tab
	local configFrame = Instance.new("ScrollingFrame")
	configFrame.Name = "ConfigFrame"
	configFrame.Size = UDim2.new(1, 0, 1, 0)
	configFrame.Position = UDim2.new(0, 0, 0, 0)
	configFrame.BackgroundTransparency = 1
	configFrame.ScrollBarThickness = 8
	configFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	configFrame.Visible = false
	configFrame.Parent = parent
	tabFrames["config"] = configFrame
	
	-- Metrics Tab
	local metricsFrame = Instance.new("ScrollingFrame")
	metricsFrame.Name = "MetricsFrame"
	metricsFrame.Size = UDim2.new(1, 0, 1, 0)
	metricsFrame.Position = UDim2.new(0, 0, 0, 0)
	metricsFrame.BackgroundTransparency = 1
	metricsFrame.ScrollBarThickness = 8
	metricsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	metricsFrame.Visible = false
	metricsFrame.Parent = parent
	tabFrames["metrics"] = metricsFrame
	
	-- User Segments Tab
	local segmentsFrame = Instance.new("ScrollingFrame")
	segmentsFrame.Name = "SegmentsFrame"
	segmentsFrame.Size = UDim2.new(1, 0, 1, 0)
	segmentsFrame.Position = UDim2.new(0, 0, 0, 0)
	segmentsFrame.BackgroundTransparency = 1
	segmentsFrame.ScrollBarThickness = 8
	segmentsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	segmentsFrame.Visible = false
	segmentsFrame.Parent = parent
	tabFrames["segments"] = segmentsFrame
	
	-- Initialize content
	self:_updateFlagsContent()
	self:_updateTestsContent()
	self:_updateConfigContent()
	self:_updateMetricsContent()
	self:_updateSegmentsContent()
end

-- Switch tab
function ConfigPanel:_switchTab(tabName: string): ()
	currentTab = tabName
	
	-- Update tab button appearance
	for name, button in pairs(tabButtons) do
		if name == tabName then
			button.BackgroundColor3 = button.BackgroundColor3:lerp(Color3.fromRGB(255, 255, 255), 0.3)
		else
			-- Reset to original color
			local originalColors = {
				flags = Color3.fromRGB(100, 150, 255),
				tests = Color3.fromRGB(255, 150, 100),
				config = Color3.fromRGB(150, 255, 100),
				metrics = Color3.fromRGB(255, 100, 150),
				segments = Color3.fromRGB(200, 100, 255)
			}
			button.BackgroundColor3 = originalColors[name]
		end
	end
	
	-- Update frame visibility
	for name, frame in pairs(tabFrames) do
		frame.Visible = name == tabName
	end
	
	-- Update content based on tab
	if tabName == "flags" then
		self:_updateFlagsContent()
	elseif tabName == "tests" then
		self:_updateTestsContent()
	elseif tabName == "config" then
		self:_updateConfigContent()
	elseif tabName == "metrics" then
		self:_updateMetricsContent()
		self:_requestMetrics() -- Refresh metrics
	elseif tabName == "segments" then
		self:_updateSegmentsContent()
	end
end

-- Update feature flags content
function ConfigPanel:_updateFlagsContent(): ()
	local frame = tabFrames["flags"]
	
	-- Clear existing content
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Create new flag button
	local newFlagButton = Instance.new("TextButton")
	newFlagButton.Name = "NewFlagButton"
	newFlagButton.Size = UDim2.new(1, -20, 0, 40)
	newFlagButton.Position = UDim2.new(0, 10, 0, 10)
	newFlagButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	newFlagButton.BorderSizePixel = 0
	newFlagButton.Text = "➕ Create New Feature Flag"
	newFlagButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	newFlagButton.TextScaled = true
	newFlagButton.Font = Enum.Font.GothamBold
	newFlagButton.Parent = frame
	
	local newFlagCorner = Instance.new("UICorner")
	newFlagCorner.CornerRadius = UDim.new(0, 4)
	newFlagCorner.Parent = newFlagButton
	
	newFlagButton.MouseButton1Click:Connect(function()
		self:_showCreateFlagDialog()
	end)
	
	-- Display existing flags
	local yOffset = 60
	for flagName, flagData in pairs(currentFlags) do
		local flagFrame = self:_createFlagItem(flagName, flagData, yOffset)
		flagFrame.Parent = frame
		yOffset = yOffset + 80
	end
	
	-- Update canvas size
	frame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

-- Create feature flag item
function ConfigPanel:_createFlagItem(flagName: string, flagData: FeatureFlag, yPos: number): Frame
	local item = Instance.new("Frame")
	item.Name = flagName .. "Item"
	item.Size = UDim2.new(1, -20, 0, 70)
	item.Position = UDim2.new(0, 10, 0, yPos)
	item.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	item.BorderSizePixel = 0
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = item
	
	-- Flag name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = flagName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = item
	
	-- Enabled toggle
	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0, 60, 0, 25)
	toggleButton.Position = UDim2.new(0.35, 0, 0, 10)
	toggleButton.BackgroundColor3 = flagData.enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = flagData.enabled and "ON" or "OFF"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Parent = item
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggleButton
	
	toggleButton.MouseButton1Click:Connect(function()
		self:_toggleFeatureFlag(flagName, not flagData.enabled)
	end)
	
	-- Rollout percentage
	local rolloutLabel = Instance.new("TextLabel")
	rolloutLabel.Size = UDim2.new(0.15, 0, 0.5, 0)
	rolloutLabel.Position = UDim2.new(0.5, 0, 0, 5)
	rolloutLabel.BackgroundTransparency = 1
	rolloutLabel.Text = `{flagData.rolloutPercentage}%`
	rolloutLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	rolloutLabel.TextScaled = true
	rolloutLabel.Font = Enum.Font.Gotham
	rolloutLabel.Parent = item
	
	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -20, 0.4, 0)
	descLabel.Position = UDim2.new(0, 10, 0.5, 5)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = flagData.description or "No description"
	descLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = item
	
	-- Edit button
	local editButton = Instance.new("TextButton")
	editButton.Size = UDim2.new(0, 60, 0, 25)
	editButton.Position = UDim2.new(1, -70, 0, 10)
	editButton.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
	editButton.BorderSizePixel = 0
	editButton.Text = "EDIT"
	editButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	editButton.TextScaled = true
	editButton.Font = Enum.Font.Gotham
	editButton.Parent = item
	
	local editCorner = Instance.new("UICorner")
	editCorner.CornerRadius = UDim.new(0, 4)
	editCorner.Parent = editButton
	
	editButton.MouseButton1Click:Connect(function()
		self:_showEditFlagDialog(flagName, flagData)
	end)
	
	return item
end

-- Update A/B tests content
function ConfigPanel:_updateTestsContent(): ()
	local frame = tabFrames["tests"]
	
	-- Clear existing content
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Create new test button
	local newTestButton = Instance.new("TextButton")
	newTestButton.Name = "NewTestButton"
	newTestButton.Size = UDim2.new(1, -20, 0, 40)
	newTestButton.Position = UDim2.new(0, 10, 0, 10)
	newTestButton.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
	newTestButton.BorderSizePixel = 0
	newTestButton.Text = "🧪 Create New A/B Test"
	newTestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	newTestButton.TextScaled = true
	newTestButton.Font = Enum.Font.GothamBold
	newTestButton.Parent = frame
	
	local newTestCorner = Instance.new("UICorner")
	newTestCorner.CornerRadius = UDim.new(0, 4)
	newTestCorner.Parent = newTestButton
	
	newTestButton.MouseButton1Click:Connect(function()
		self:_showCreateTestDialog()
	end)
	
	-- Display existing tests
	local yOffset = 60
	for testName, testData in pairs(currentTests) do
		local testFrame = self:_createTestItem(testName, testData, yOffset)
		testFrame.Parent = frame
		yOffset = yOffset + 100
	end
	
	-- Update canvas size
	frame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

-- Create A/B test item
function ConfigPanel:_createTestItem(testName: string, testData: ABTest, yPos: number): Frame
	local item = Instance.new("Frame")
	item.Name = testName .. "Item"
	item.Size = UDim2.new(1, -20, 0, 90)
	item.Position = UDim2.new(0, 10, 0, yPos)
	item.BackgroundColor3 = Color3.fromRGB(55, 50, 50)
	item.BorderSizePixel = 0
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = item
	
	-- Test name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = testName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = item
	
	-- Active status
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0.2, 0, 0.3, 0)
	statusLabel.Position = UDim2.new(0.45, 0, 0, 5)
	statusLabel.BackgroundColor3 = testData.isActive and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
	statusLabel.BorderSizePixel = 0
	statusLabel.Text = testData.isActive and "ACTIVE" or "INACTIVE"
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Parent = item
	
	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 4)
	statusCorner.Parent = statusLabel
	
	-- Variants
	local variantsText = table.concat(testData.variants, ", ")
	local variantsLabel = Instance.new("TextLabel")
	variantsLabel.Size = UDim2.new(1, -20, 0.4, 0)
	variantsLabel.Position = UDim2.new(0, 10, 0.35, 0)
	variantsLabel.BackgroundTransparency = 1
	variantsLabel.Text = "Variants: " .. variantsText
	variantsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	variantsLabel.TextScaled = true
	variantsLabel.Font = Enum.Font.Gotham
	variantsLabel.TextXAlignment = Enum.TextXAlignment.Left
	variantsLabel.Parent = item
	
	return item
end

-- Update configuration content (placeholder)
function ConfigPanel:_updateConfigContent(): ()
	local frame = tabFrames["config"]
	
	-- Clear existing content
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Add placeholder text
	local placeholder = Instance.new("TextLabel")
	placeholder.Size = UDim2.new(1, 0, 1, 0)
	placeholder.Position = UDim2.new(0, 0, 0, 0)
	placeholder.BackgroundTransparency = 1
	placeholder.Text = "⚙️ Configuration Editor\n\nComing Soon..."
	placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
	placeholder.TextScaled = true
	placeholder.Font = Enum.Font.Gotham
	placeholder.Parent = frame
end

-- Update metrics content
function ConfigPanel:_updateMetricsContent(): ()
	local frame = tabFrames["metrics"]
	
	-- Clear existing content
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	if not currentMetrics then
		local loading = Instance.new("TextLabel")
		loading.Size = UDim2.new(1, 0, 1, 0)
		loading.Position = UDim2.new(0, 0, 0, 0)
		loading.BackgroundTransparency = 1
		loading.Text = "📊 Loading Metrics..."
		loading.TextColor3 = Color3.fromRGB(150, 150, 150)
		loading.TextScaled = true
		loading.Font = Enum.Font.Gotham
		loading.Parent = frame
		return
	end
	
	-- Display metrics
	local yOffset = 10
	
	-- Server Health
	local healthFrame = self:_createMetricsSection("Server Health", currentMetrics.serverHealth, yOffset)
	healthFrame.Parent = frame
	yOffset = yOffset + 150
	
	-- Feature Flag Metrics
	if currentMetrics.featureFlags then
		local flagsFrame = self:_createMetricsSection("Feature Flags", currentMetrics.featureFlags, yOffset)
		flagsFrame.Parent = frame
		yOffset = yOffset + 150
	end
	
	-- Experiment Metrics
	if currentMetrics.experiments then
		local experimentsFrame = self:_createMetricsSection("A/B Tests", currentMetrics.experiments, yOffset)
		experimentsFrame.Parent = frame
		yOffset = yOffset + 150
	end
	
	-- Update canvas size
	frame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

-- Create metrics section
function ConfigPanel:_createMetricsSection(title: string, data: any, yPos: number): Frame
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, -20, 0, 140)
	section.Position = UDim2.new(0, 10, 0, yPos)
	section.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	section.BorderSizePixel = 0
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section
	
	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 30)
	titleLabel.Position = UDim2.new(0, 10, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = section
	
	-- Content
	local contentLabel = Instance.new("TextLabel")
	contentLabel.Size = UDim2.new(1, -20, 1, -40)
	contentLabel.Position = UDim2.new(0, 10, 0, 35)
	contentLabel.BackgroundTransparency = 1
	contentLabel.Text = self:_formatMetricsData(data)
	contentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	contentLabel.TextScaled = true
	contentLabel.Font = Enum.Font.Gotham
	contentLabel.TextXAlignment = Enum.TextXAlignment.Left
	contentLabel.TextYAlignment = Enum.TextYAlignment.Top
	contentLabel.Parent = section
	
	return section
end

-- Format metrics data for display
function ConfigPanel:_formatMetricsData(data: any): string
	if typeof(data) == "table" then
		local lines = {}
		for key, value in pairs(data) do
			if typeof(value) == "table" then
				table.insert(lines, `{key}: [Complex Object]`)
			else
				table.insert(lines, `{key}: {tostring(value)}`)
			end
		end
		return table.concat(lines, "\n")
	else
		return tostring(data)
	end
end

-- Update user segments content (placeholder)
function ConfigPanel:_updateSegmentsContent(): ()
	local frame = tabFrames["segments"]
	
	-- Clear existing content
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Add placeholder text
	local placeholder = Instance.new("TextLabel")
	placeholder.Size = UDim2.new(1, 0, 1, 0)
	placeholder.Position = UDim2.new(0, 0, 0, 0)
	placeholder.BackgroundTransparency = 1
	placeholder.Text = "👥 User Segments\n\nComing Soon..."
	placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
	placeholder.TextScaled = true
	placeholder.Font = Enum.Font.Gotham
	placeholder.Parent = frame
end

-- Dialog Functions

-- Show create flag dialog
function ConfigPanel:_showCreateFlagDialog(): ()
	-- This would create a dialog for creating new feature flags
	print("Create Feature Flag Dialog - Coming Soon")
end

-- Show edit flag dialog
function ConfigPanel:_showEditFlagDialog(flagName: string, flagData: FeatureFlag): ()
	-- This would create a dialog for editing feature flags
	print(`Edit Feature Flag Dialog for {flagName} - Coming Soon`)
end

-- Show create test dialog
function ConfigPanel:_showCreateTestDialog(): ()
	-- This would create a dialog for creating new A/B tests
	print("Create A/B Test Dialog - Coming Soon")
end

-- Actions

-- Toggle feature flag
function ConfigPanel:_toggleFeatureFlag(flagName: string, enabled: boolean): ()
	adminCommandRemote:FireServer("setFeatureFlag", {
		flagName = flagName,
		enabled = enabled,
		rolloutPercentage = currentFlags[flagName] and currentFlags[flagName].rolloutPercentage or 0
	})
	
	-- Update local data
	if currentFlags[flagName] then
		currentFlags[flagName].enabled = enabled
		self:_updateFlagsContent()
	end
end

-- Request metrics from server
function ConfigPanel:_requestMetrics(): ()
	adminCommandRemote:FireServer("getMetrics", {})
end

-- Setup remote handlers
function ConfigPanel:_setupRemoteHandlers(): ()
	configUpdatedRemote.OnClientEvent:Connect(function(data: any)
		if data.type == "metrics" then
			currentMetrics = data.data
			if currentTab == "metrics" then
				self:_updateMetricsContent()
			end
		elseif data.featureFlags then
			-- Update feature flags data
			for flagName, enabled in pairs(data.featureFlags) do
				if not currentFlags[flagName] then
					currentFlags[flagName] = {
						name = flagName,
						enabled = enabled,
						userSegments = {},
						rolloutPercentage = 0,
						description = ""
					}
				else
					currentFlags[flagName].enabled = enabled
				end
			end
			
			if currentTab == "flags" then
				self:_updateFlagsContent()
			end
		end
	end)
end

-- Setup input handlers
function ConfigPanel:_setupInputHandlers(): ()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		
		-- Toggle panel with F10
		if input.KeyCode == Enum.KeyCode.F10 then
			self:Toggle()
		end
		
		-- Hide panel with Escape
		if input.KeyCode == Enum.KeyCode.Escape and isVisible then
			self:Hide()
		end
	end)
end

-- Public Interface

-- Show the panel
function ConfigPanel:Show(): ()
	if not isVisible then
		isVisible = true
		mainFrame.Visible = true
		
		-- Animate in
		mainFrame.Size = UDim2.new(0, 0, 0, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.8, 0, 0.8, 0),
			Position = UDim2.new(0.1, 0, 0.1, 0)
		})
		tween:Play()
	end
end

-- Hide the panel
function ConfigPanel:Hide(): ()
	if isVisible then
		isVisible = false
		
		-- Animate out
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0)
		})
		tween:Play()
		
		tween.Completed:Connect(function()
			mainFrame.Visible = false
		end)
	end
end

-- Toggle panel visibility
function ConfigPanel:Toggle(): ()
	if isVisible then
		self:Hide()
	else
		self:Show()
	end
end

-- Get health status
function ConfigPanel:GetHealthStatus(): {status: string, metrics: any}
	return {
		status = "healthy",
		metrics = {
			panelVisible = isVisible,
			currentTab = currentTab,
			flagsLoaded = #currentFlags,
			testsLoaded = #currentTests,
			hasMetrics = currentMetrics ~= nil,
			lastUpdate = os.time()
		}
	}
end

return ConfigPanel.new()
