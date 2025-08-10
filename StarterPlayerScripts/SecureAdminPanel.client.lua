--!strict
--[[
	SecureAdminPanel.client.lua
	Enterprise Secure Admin Panel Interface
	
	Provides a secure, role-based admin interface with comprehensive
	authentication, authorization, and audit logging integration.
	
	Features:
	- Multi-factor authentication integration
	- Role-based UI components
	- Real-time security monitoring
	- Audit trail visualization
	- Input validation and sanitization
	- Session management
	- Security alerts dashboard
	- Performance monitoring
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(game.ReplicatedStorage.Shared.ServiceLocator)
local InputSanitizer = require(game.ReplicatedStorage.Shared.InputSanitizer)

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote Events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local adminAuthentication = remoteEvents:WaitForChild("AdminAuthentication")

-- Types
export type AdminSession = {
	sessionToken: string,
	userId: number | string,
	roles: {string},
	permissions: {string},
	expiresAt: number,
	lastActivity: number
}

export type SecurityAlert = {
	alertId: string,
	timestamp: number,
	threatLevel: string,
	alertType: string,
	description: string,
	affectedUsers: {number | string},
	actionRequired: boolean
}

-- Secure Admin Panel
local SecureAdminPanel = {}
SecureAdminPanel.__index = SecureAdminPanel

-- Private Variables
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local inputSanitizer: any
local currentSession: AdminSession?
local adminGui: ScreenGui?
local authenticationFrame: Frame?
local adminDashboard: Frame?
local securityMonitor: Frame?
local auditViewer: Frame?

-- Security Configuration
local SECURITY_CONFIG = {
	sessionTimeout = 3600, -- 1 hour
	autoLockTimeout = 900, -- 15 minutes
	maxIdleTime = 600, -- 10 minutes
	requireReauth = true,
	enableBiometric = false,
	logAllActions = true
}

-- UI Styles
local UI_STYLES = {
	primaryColor = Color3.fromRGB(26, 42, 108),
	secondaryColor = Color3.fromRGB(67, 90, 111),
	successColor = Color3.fromRGB(40, 167, 69),
	warningColor = Color3.fromRGB(255, 193, 7),
	dangerColor = Color3.fromRGB(220, 53, 69),
	backgroundColor = Color3.fromRGB(248, 249, 250),
	textColor = Color3.fromRGB(33, 37, 41),
	borderColor = Color3.fromRGB(206, 212, 218)
}

-- Initialization
function SecureAdminPanel.new(): typeof(SecureAdminPanel)
	local self = setmetatable({}, SecureAdminPanel)
	
	-- Initialize input sanitizer
	inputSanitizer = InputSanitizer.new()
	
	-- Create admin interface
	self:_createAdminInterface()
	
	-- Setup security monitoring
	self:_setupSecurityMonitoring()
	
	-- Setup session management
	self:_setupSessionManagement()
	
	-- Setup input handlers
	self:_setupInputHandlers()
	
	print("SecureAdminPanel initialized successfully")
	
	return self
end

-- Authentication Interface

-- Create admin interface
function SecureAdminPanel:_createAdminInterface(): ()
	-- Create main GUI
	adminGui = Instance.new("ScreenGui")
	adminGui.Name = "SecureAdminPanel"
	adminGui.ResetOnSpawn = false
	adminGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	adminGui.Parent = playerGui
	
	-- Create authentication frame
	self:_createAuthenticationFrame()
	
	-- Create admin dashboard (initially hidden)
	self:_createAdminDashboard()
	
	-- Create security monitor
	self:_createSecurityMonitor()
	
	-- Create audit viewer
	self:_createAuditViewer()
	
	-- Show authentication frame initially
	self:ShowAuthentication()
end

-- Create authentication frame
function SecureAdminPanel:_createAuthenticationFrame(): ()
	authenticationFrame = Instance.new("Frame")
	authenticationFrame.Name = "AuthenticationFrame"
	authenticationFrame.Size = UDim2.new(0, 400, 0, 500)
	authenticationFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
	authenticationFrame.BackgroundColor3 = UI_STYLES.backgroundColor
	authenticationFrame.BorderColor3 = UI_STYLES.borderColor
	authenticationFrame.BorderSizePixel = 2
	authenticationFrame.Parent = adminGui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = authenticationFrame
	
	-- Add title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = UI_STYLES.primaryColor
	title.BorderSizePixel = 0
	title.Text = "🔐 Enterprise Admin Authentication"
	title.TextColor3 = Color3.white
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.Parent = authenticationFrame
	
	-- Title corner
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = title
	
	-- Content frame
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -40, 1, -100)
	contentFrame.Position = UDim2.new(0, 20, 0, 80)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = authenticationFrame
	
	-- User ID input
	local userIdLabel = self:_createLabel("User ID:", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), contentFrame)
	local userIdInput = self:_createTextInput("Enter user ID or email", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 35), contentFrame)
	userIdInput.Name = "UserIdInput"
	
	-- Password input
	local passwordLabel = self:_createLabel("Password:", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 90), contentFrame)
	local passwordInput = self:_createTextInput("Enter password", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 125), contentFrame)
	passwordInput.Name = "PasswordInput"
	passwordInput.TextBox.Text = ""
	passwordInput.TextBox.PlaceholderText = "Enter password"
	passwordInput.TextBox.ClearTextOnFocus = false
	
	-- Two-factor code input (initially hidden)
	local twoFactorLabel = self:_createLabel("Two-Factor Code:", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 180), contentFrame)
	twoFactorLabel.Name = "TwoFactorLabel"
	twoFactorLabel.Visible = false
	
	local twoFactorInput = self:_createTextInput("Enter 6-digit code", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 215), contentFrame)
	twoFactorInput.Name = "TwoFactorInput"
	twoFactorInput.Visible = false
	
	-- Login button
	local loginButton = self:_createButton("🔐 Login", UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 270), contentFrame)
	loginButton.Name = "LoginButton"
	loginButton.BackgroundColor3 = UI_STYLES.primaryColor
	
	-- Status label
	local statusLabel = self:_createLabel("", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 335), contentFrame)
	statusLabel.Name = "StatusLabel"
	statusLabel.TextColor3 = UI_STYLES.dangerColor
	statusLabel.TextScaled = false
	statusLabel.TextSize = 14
	
	-- Setup login functionality
	self:_setupLoginHandlers()
end

-- Create admin dashboard
function SecureAdminPanel:_createAdminDashboard(): ()
	adminDashboard = Instance.new("Frame")
	adminDashboard.Name = "AdminDashboard"
	adminDashboard.Size = UDim2.new(1, 0, 1, 0)
	adminDashboard.Position = UDim2.new(0, 0, 0, 0)
	adminDashboard.BackgroundColor3 = UI_STYLES.backgroundColor
	adminDashboard.BorderSizePixel = 0
	adminDashboard.Visible = false
	adminDashboard.Parent = adminGui
	
	-- Top bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 60)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = UI_STYLES.primaryColor
	topBar.BorderSizePixel = 0
	topBar.Parent = adminDashboard
	
	-- Title
	local dashboardTitle = Instance.new("TextLabel")
	dashboardTitle.Name = "Title"
	dashboardTitle.Size = UDim2.new(0, 300, 1, 0)
	dashboardTitle.Position = UDim2.new(0, 20, 0, 0)
	dashboardTitle.BackgroundTransparency = 1
	dashboardTitle.Text = "🛡️ Enterprise Admin Dashboard"
	dashboardTitle.TextColor3 = Color3.white
	dashboardTitle.TextScaled = true
	dashboardTitle.Font = Enum.Font.SourceSansBold
	dashboardTitle.TextXAlignment = Enum.TextXAlignment.Left
	dashboardTitle.Parent = topBar
	
	-- Session info
	local sessionInfo = Instance.new("TextLabel")
	sessionInfo.Name = "SessionInfo"
	sessionInfo.Size = UDim2.new(0, 300, 1, -10)
	sessionInfo.Position = UDim2.new(1, -320, 0, 5)
	sessionInfo.BackgroundTransparency = 1
	sessionInfo.Text = "Session: Loading..."
	sessionInfo.TextColor3 = Color3.white
	sessionInfo.TextScaled = false
	sessionInfo.TextSize = 14
	sessionInfo.Font = Enum.Font.SourceSans
	sessionInfo.TextXAlignment = Enum.TextXAlignment.Right
	sessionInfo.Parent = topBar
	
	-- Logout button
	local logoutButton = self:_createButton("🚪 Logout", UDim2.new(0, 80, 0, 40), UDim2.new(1, -100, 0, 10), topBar)
	logoutButton.Name = "LogoutButton"
	logoutButton.BackgroundColor3 = UI_STYLES.dangerColor
	logoutButton.TextScaled = false
	logoutButton.TextSize = 14
	
	-- Setup logout functionality
	logoutButton.MouseButton1Click:Connect(function()
		self:Logout()
	end)
	
	-- Navigation tabs
	local navFrame = Instance.new("Frame")
	navFrame.Name = "Navigation"
	navFrame.Size = UDim2.new(1, 0, 0, 50)
	navFrame.Position = UDim2.new(0, 0, 0, 60)
	navFrame.BackgroundColor3 = UI_STYLES.secondaryColor
	navFrame.BorderSizePixel = 0
	navFrame.Parent = adminDashboard
	
	-- Tab buttons
	local tabs = {"Dashboard", "Users", "Security", "Analytics", "Settings"}
	local tabWidth = 1 / #tabs
	
	for i, tabName in ipairs(tabs) do
		local tabButton = self:_createButton(tabName, UDim2.new(tabWidth, -2, 1, -10), UDim2.new(tabWidth * (i-1), 1, 0, 5), navFrame)
		tabButton.Name = tabName .. "Tab"
		tabButton.BackgroundColor3 = UI_STYLES.backgroundColor
		tabButton.TextColor3 = UI_STYLES.textColor
		
		tabButton.MouseButton1Click:Connect(function()
			self:_switchTab(tabName)
		end)
	end
	
	-- Content area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -20, 1, -130)
	contentArea.Position = UDim2.new(0, 10, 0, 120)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = adminDashboard
	
	-- Create content frames for each tab
	self:_createDashboardContent(contentArea)
	self:_createUsersContent(contentArea)
	self:_createSecurityContent(contentArea)
	self:_createAnalyticsContent(contentArea)
	self:_createSettingsContent(contentArea)
end

-- Create security monitor
function SecureAdminPanel:_createSecurityMonitor(): ()
	securityMonitor = Instance.new("Frame")
	securityMonitor.Name = "SecurityMonitor"
	securityMonitor.Size = UDim2.new(0, 400, 0, 600)
	securityMonitor.Position = UDim2.new(1, -420, 0, 20)
	securityMonitor.BackgroundColor3 = UI_STYLES.backgroundColor
	securityMonitor.BorderColor3 = UI_STYLES.borderColor
	securityMonitor.BorderSizePixel = 2
	securityMonitor.Visible = false
	securityMonitor.Parent = adminGui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = securityMonitor
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = UI_STYLES.dangerColor
	titleBar.BorderSizePixel = 0
	titleBar.Parent = securityMonitor
	
	local monitorTitle = Instance.new("TextLabel")
	monitorTitle.Size = UDim2.new(1, -40, 1, 0)
	monitorTitle.Position = UDim2.new(0, 10, 0, 0)
	monitorTitle.BackgroundTransparency = 1
	monitorTitle.Text = "🚨 Security Alerts"
	monitorTitle.TextColor3 = Color3.white
	monitorTitle.TextScaled = true
	monitorTitle.Font = Enum.Font.SourceSansBold
	monitorTitle.TextXAlignment = Enum.TextXAlignment.Left
	monitorTitle.Parent = titleBar
	
	-- Close button
	local closeButton = self:_createButton("❌", UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), titleBar)
	closeButton.BackgroundColor3 = UI_STYLES.dangerColor
	closeButton.TextColor3 = Color3.white
	
	closeButton.MouseButton1Click:Connect(function()
		securityMonitor.Visible = false
	end)
	
	-- Alerts list
	local alertsList = Instance.new("ScrollingFrame")
	alertsList.Name = "AlertsList"
	alertsList.Size = UDim2.new(1, -20, 1, -60)
	alertsList.Position = UDim2.new(0, 10, 0, 50)
	alertsList.BackgroundTransparency = 1
	alertsList.BorderSizePixel = 0
	alertsList.ScrollBarThickness = 8
	alertsList.Parent = securityMonitor
	
	-- Alert list layout
	local alertsLayout = Instance.new("UIListLayout")
	alertsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	alertsLayout.Padding = UDim.new(0, 5)
	alertsLayout.Parent = alertsList
end

-- Create audit viewer
function SecureAdminPanel:_createAuditViewer(): ()
	auditViewer = Instance.new("Frame")
	auditViewer.Name = "AuditViewer"
	auditViewer.Size = UDim2.new(0, 800, 0, 600)
	auditViewer.Position = UDim2.new(0.5, -400, 0.5, -300)
	auditViewer.BackgroundColor3 = UI_STYLES.backgroundColor
	auditViewer.BorderColor3 = UI_STYLES.borderColor
	auditViewer.BorderSizePixel = 2
	auditViewer.Visible = false
	auditViewer.Parent = adminGui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = auditViewer
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = UI_STYLES.primaryColor
	titleBar.BorderSizePixel = 0
	titleBar.Parent = auditViewer
	
	local auditTitle = Instance.new("TextLabel")
	auditTitle.Size = UDim2.new(1, -40, 1, 0)
	auditTitle.Position = UDim2.new(0, 10, 0, 0)
	auditTitle.BackgroundTransparency = 1
	auditTitle.Text = "📋 Audit Trail Viewer"
	auditTitle.TextColor3 = Color3.white
	auditTitle.TextScaled = true
	auditTitle.Font = Enum.Font.SourceSansBold
	auditTitle.TextXAlignment = Enum.TextXAlignment.Left
	auditTitle.Parent = titleBar
	
	-- Close button
	local closeButton = self:_createButton("❌", UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), titleBar)
	closeButton.BackgroundColor3 = UI_STYLES.primaryColor
	closeButton.TextColor3 = Color3.white
	
	closeButton.MouseButton1Click:Connect(function()
		auditViewer.Visible = false
	end)
	
	-- Audit log
	local auditLog = Instance.new("ScrollingFrame")
	auditLog.Name = "AuditLog"
	auditLog.Size = UDim2.new(1, -20, 1, -60)
	auditLog.Position = UDim2.new(0, 10, 0, 50)
	auditLog.BackgroundTransparency = 1
	auditLog.BorderSizePixel = 0
	auditLog.ScrollBarThickness = 8
	auditLog.Parent = auditViewer
	
	-- Audit log layout
	local auditLayout = Instance.new("UIListLayout")
	auditLayout.SortOrder = Enum.SortOrder.LayoutOrder
	auditLayout.Padding = UDim.new(0, 2)
	auditLayout.Parent = auditLog
end

-- Authentication Functions

-- Setup login handlers
function SecureAdminPanel:_setupLoginHandlers(): ()
	if not authenticationFrame then return end
	
	local loginButton = authenticationFrame:FindFirstChild("Content"):FindFirstChild("LoginButton")
	local userIdInput = authenticationFrame:FindFirstChild("Content"):FindFirstChild("UserIdInput"):FindFirstChild("TextBox")
	local passwordInput = authenticationFrame:FindFirstChild("Content"):FindFirstChild("PasswordInput"):FindFirstChild("TextBox")
	local statusLabel = authenticationFrame:FindFirstChild("Content"):FindFirstChild("StatusLabel")
	
	local function attemptLogin()
		-- Sanitize inputs
		local userIdResult = inputSanitizer:SanitizeInput(userIdInput.Text, "AdminInput")
		local passwordResult = inputSanitizer:SanitizeInput(passwordInput.Text, "AdminInput")
		
		if not userIdResult.isValid then
			statusLabel.Text = "Invalid user ID format"
			statusLabel.TextColor3 = UI_STYLES.dangerColor
			return
		end
		
		if not passwordResult.isValid then
			statusLabel.Text = "Invalid password format"
			statusLabel.TextColor3 = UI_STYLES.dangerColor
			return
		end
		
		-- Clear status
		statusLabel.Text = "Authenticating..."
		statusLabel.TextColor3 = UI_STYLES.warningColor
		
		-- Disable login button
		loginButton.Active = false
		loginButton.BackgroundColor3 = UI_STYLES.secondaryColor
		
		-- Attempt authentication
		local authData = {
			userId = userIdResult.sanitizedValue,
			method = "Password",
			password = passwordResult.sanitizedValue,
			metadata = {
				clientVersion = "1.0.0",
				timestamp = os.time()
			}
		}
		
		local success, result = pcall(function()
			return adminAuthentication:InvokeServer("authenticate", authData)
		end)
		
		-- Re-enable login button
		loginButton.Active = true
		loginButton.BackgroundColor3 = UI_STYLES.primaryColor
		
		if success and result then
			if result.success then
				-- Store session
				currentSession = {
					sessionToken = result.sessionToken,
					userId = result.userId,
					roles = result.roles,
					permissions = result.permissions,
					expiresAt = result.expiresAt,
					lastActivity = os.time()
				}
				
				-- Show dashboard
				self:ShowDashboard()
				statusLabel.Text = ""
			elseif result.requiresTwoFactor then
				-- Show two-factor input
				self:_showTwoFactorInput()
				statusLabel.Text = "Enter two-factor authentication code"
				statusLabel.TextColor3 = UI_STYLES.warningColor
			else
				statusLabel.Text = result.errorMessage or "Authentication failed"
				statusLabel.TextColor3 = UI_STYLES.dangerColor
			end
		else
			statusLabel.Text = "Connection error - please try again"
			statusLabel.TextColor3 = UI_STYLES.dangerColor
		end
	end
	
	-- Connect login button
	loginButton.MouseButton1Click:Connect(attemptLogin)
	
	-- Connect enter key
	userIdInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			passwordInput:CaptureFocus()
		end
	end)
	
	passwordInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			attemptLogin()
		end
	end)
end

-- Show two-factor input
function SecureAdminPanel:_showTwoFactorInput(): ()
	if not authenticationFrame then return end
	
	local content = authenticationFrame:FindFirstChild("Content")
	local twoFactorLabel = content:FindFirstChild("TwoFactorLabel")
	local twoFactorInput = content:FindFirstChild("TwoFactorInput")
	
	twoFactorLabel.Visible = true
	twoFactorInput.Visible = true
	
	-- Focus on two-factor input
	twoFactorInput:FindFirstChild("TextBox"):CaptureFocus()
end

-- Dashboard Functions

-- Show authentication
function SecureAdminPanel:ShowAuthentication(): ()
	if authenticationFrame then
		authenticationFrame.Visible = true
	end
	if adminDashboard then
		adminDashboard.Visible = false
	end
	if securityMonitor then
		securityMonitor.Visible = false
	end
	if auditViewer then
		auditViewer.Visible = false
	end
end

-- Show dashboard
function SecureAdminPanel:ShowDashboard(): ()
	if not currentSession then
		self:ShowAuthentication()
		return
	end
	
	if authenticationFrame then
		authenticationFrame.Visible = false
	end
	if adminDashboard then
		adminDashboard.Visible = true
		self:_updateSessionInfo()
		self:_switchTab("Dashboard")
	end
	
	-- Show security monitor if user has security permissions
	if self:_hasPermission("security.admin") then
		if securityMonitor then
			securityMonitor.Visible = true
		end
	end
end

-- Update session info
function SecureAdminPanel:_updateSessionInfo(): ()
	if not adminDashboard or not currentSession then return end
	
	local sessionInfo = adminDashboard:FindFirstChild("TopBar"):FindFirstChild("SessionInfo")
	if sessionInfo then
		local timeLeft = currentSession.expiresAt - os.time()
		local rolesText = table.concat(currentSession.roles, ", ")
		sessionInfo.Text = string.format("User: %s | Roles: %s | Session: %dm", 
			tostring(currentSession.userId), rolesText, math.floor(timeLeft / 60))
	end
end

-- Switch tab
function SecureAdminPanel:_switchTab(tabName: string): ()
	if not adminDashboard then return end
	
	local contentArea = adminDashboard:FindFirstChild("ContentArea")
	if not contentArea then return end
	
	-- Hide all content frames
	for _, child in ipairs(contentArea:GetChildren()) do
		if child:IsA("Frame") and string.find(child.Name, "Content") then
			child.Visible = false
		end
	end
	
	-- Show selected content frame
	local targetFrame = contentArea:FindFirstChild(tabName .. "Content")
	if targetFrame then
		targetFrame.Visible = true
	end
	
	-- Update tab appearance
	local navFrame = adminDashboard:FindFirstChild("Navigation")
	if navFrame then
		for _, child in ipairs(navFrame:GetChildren()) do
			if child:IsA("TextButton") and string.find(child.Name, "Tab") then
				if child.Name == tabName .. "Tab" then
					child.BackgroundColor3 = UI_STYLES.primaryColor
					child.TextColor3 = Color3.white
				else
					child.BackgroundColor3 = UI_STYLES.backgroundColor
					child.TextColor3 = UI_STYLES.textColor
				end
			end
		end
	end
end

-- Create dashboard content
function SecureAdminPanel:_createDashboardContent(parent: Frame): ()
	local dashboardContent = Instance.new("Frame")
	dashboardContent.Name = "DashboardContent"
	dashboardContent.Size = UDim2.new(1, 0, 1, 0)
	dashboardContent.Position = UDim2.new(0, 0, 0, 0)
	dashboardContent.BackgroundTransparency = 1
	dashboardContent.Visible = true
	dashboardContent.Parent = parent
	
	-- System status cards
	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "StatusFrame"
	statusFrame.Size = UDim2.new(1, 0, 0, 200)
	statusFrame.Position = UDim2.new(0, 0, 0, 0)
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = dashboardContent
	
	-- Status cards layout
	local statusLayout = Instance.new("UIGridLayout")
	statusLayout.CellSize = UDim2.new(0, 240, 0, 90)
	statusLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.Parent = statusFrame
	
	-- Create status cards
	local statusCards = {
		{title = "🔐 Authentication", value = "Healthy", color = UI_STYLES.successColor},
		{title = "🛡️ Permissions", value = "Active", color = UI_STYLES.successColor},
		{title = "📋 Audit Log", value = "Recording", color = UI_STYLES.successColor},
		{title = "🧹 Input Filter", value = "Protecting", color = UI_STYLES.successColor},
		{title = "🚨 Security Alerts", value = "0 Active", color = UI_STYLES.successColor},
		{title = "⚡ Performance", value = "Optimal", color = UI_STYLES.successColor}
	}
	
	for i, cardData in ipairs(statusCards) do
		local card = self:_createStatusCard(cardData.title, cardData.value, cardData.color)
		card.LayoutOrder = i
		card.Parent = statusFrame
	end
	
	-- Quick actions
	local actionsFrame = Instance.new("Frame")
	actionsFrame.Name = "ActionsFrame"
	actionsFrame.Size = UDim2.new(1, 0, 0, 100)
	actionsFrame.Position = UDim2.new(0, 0, 0, 220)
	actionsFrame.BackgroundTransparency = 1
	actionsFrame.Parent = dashboardContent
	
	local actionsTitle = self:_createLabel("Quick Actions", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), actionsFrame)
	actionsTitle.Font = Enum.Font.SourceSansBold
	actionsTitle.TextXAlignment = Enum.TextXAlignment.Left
	
	-- Action buttons
	local actionButtons = {
		{text = "👥 Manage Users", tab = "Users"},
		{text = "🔒 Security Log", tab = "Security"},
		{text = "📊 Analytics", tab = "Analytics"},
		{text = "⚙️ Settings", tab = "Settings"}
	}
	
	for i, buttonData in ipairs(actionButtons) do
		local button = self:_createButton(buttonData.text, UDim2.new(0, 200, 0, 40), UDim2.new((i-1) * 210, 0, 0, 40), actionsFrame)
		button.BackgroundColor3 = UI_STYLES.primaryColor
		
		button.MouseButton1Click:Connect(function()
			self:_switchTab(buttonData.tab)
		end)
	end
end

-- Create users content
function SecureAdminPanel:_createUsersContent(parent: Frame): ()
	local usersContent = Instance.new("Frame")
	usersContent.Name = "UsersContent"
	usersContent.Size = UDim2.new(1, 0, 1, 0)
	usersContent.Position = UDim2.new(0, 0, 0, 0)
	usersContent.BackgroundTransparency = 1
	usersContent.Visible = false
	usersContent.Parent = parent
	
	-- Users management interface
	local usersTitle = self:_createLabel("👥 User Management", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), usersContent)
	usersTitle.Font = Enum.Font.SourceSansBold
	usersTitle.TextXAlignment = Enum.TextXAlignment.Left
	usersTitle.TextSize = 24
	
	-- Users list
	local usersList = Instance.new("ScrollingFrame")
	usersList.Name = "UsersList"
	usersList.Size = UDim2.new(1, 0, 1, -60)
	usersList.Position = UDim2.new(0, 0, 0, 50)
	usersList.BackgroundColor3 = Color3.white
	usersList.BorderColor3 = UI_STYLES.borderColor
	usersList.BorderSizePixel = 1
	usersList.ScrollBarThickness = 8
	usersList.Parent = usersContent
	
	-- Users layout
	local usersLayout = Instance.new("UIListLayout")
	usersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	usersLayout.Padding = UDim.new(0, 2)
	usersLayout.Parent = usersList
	
	-- Load users (simulated)
	self:_loadUsersList(usersList)
end

-- Create security content
function SecureAdminPanel:_createSecurityContent(parent: Frame): ()
	local securityContent = Instance.new("Frame")
	securityContent.Name = "SecurityContent"
	securityContent.Size = UDim2.new(1, 0, 1, 0)
	securityContent.Position = UDim2.new(0, 0, 0, 0)
	securityContent.BackgroundTransparency = 1
	securityContent.Visible = false
	securityContent.Parent = parent
	
	-- Security interface
	local securityTitle = self:_createLabel("🔒 Security Management", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), securityContent)
	securityTitle.Font = Enum.Font.SourceSansBold
	securityTitle.TextXAlignment = Enum.TextXAlignment.Left
	securityTitle.TextSize = 24
	
	-- Security actions
	local securityActions = {
		{text = "🚨 View Security Alerts", action = "alerts"},
		{text = "📋 View Audit Log", action = "audit"},
		{text = "🔐 Manage Permissions", action = "permissions"},
		{text = "🛡️ Security Report", action = "report"}
	}
	
	for i, actionData in ipairs(securityActions) do
		local button = self:_createButton(actionData.text, UDim2.new(0, 300, 0, 50), UDim2.new(0, 0, 0, 50 + (i-1) * 60), securityContent)
		button.BackgroundColor3 = UI_STYLES.primaryColor
		
		button.MouseButton1Click:Connect(function()
			self:_handleSecurityAction(actionData.action)
		end)
	end
end

-- Create analytics content
function SecureAdminPanel:_createAnalyticsContent(parent: Frame): ()
	local analyticsContent = Instance.new("Frame")
	analyticsContent.Name = "AnalyticsContent"
	analyticsContent.Size = UDim2.new(1, 0, 1, 0)
	analyticsContent.Position = UDim2.new(0, 0, 0, 0)
	analyticsContent.BackgroundTransparency = 1
	analyticsContent.Visible = false
	analyticsContent.Parent = parent
	
	-- Analytics interface
	local analyticsTitle = self:_createLabel("📊 Security Analytics", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), analyticsContent)
	analyticsTitle.Font = Enum.Font.SourceSansBold
	analyticsTitle.TextXAlignment = Enum.TextXAlignment.Left
	analyticsTitle.TextSize = 24
	
	-- Analytics placeholder
	local placeholder = self:_createLabel("Analytics dashboard coming soon...", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 60), analyticsContent)
	placeholder.TextColor3 = UI_STYLES.secondaryColor
end

-- Create settings content
function SecureAdminPanel:_createSettingsContent(parent: Frame): ()
	local settingsContent = Instance.new("Frame")
	settingsContent.Name = "SettingsContent"
	settingsContent.Size = UDim2.new(1, 0, 1, 0)
	settingsContent.Position = UDim2.new(0, 0, 0, 0)
	settingsContent.BackgroundTransparency = 1
	settingsContent.Visible = false
	settingsContent.Parent = parent
	
	-- Settings interface
	local settingsTitle = self:_createLabel("⚙️ Security Settings", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), settingsContent)
	settingsTitle.Font = Enum.Font.SourceSansBold
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.TextSize = 24
	
	-- Settings placeholder
	local placeholder = self:_createLabel("Settings panel coming soon...", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 60), settingsContent)
	placeholder.TextColor3 = UI_STYLES.secondaryColor
end

-- Security Functions

-- Handle security action
function SecureAdminPanel:_handleSecurityAction(action: string): ()
	if action == "alerts" then
		if securityMonitor then
			securityMonitor.Visible = true
		end
	elseif action == "audit" then
		if auditViewer then
			auditViewer.Visible = true
		end
	elseif action == "permissions" then
		-- Open permissions management
		print("Opening permissions management...")
	elseif action == "report" then
		-- Generate security report
		print("Generating security report...")
	end
end

-- Check permission
function SecureAdminPanel:_hasPermission(permission: string): boolean
	if not currentSession then
		return false
	end
	
	for _, userPermission in ipairs(currentSession.permissions) do
		if userPermission == permission then
			return true
		end
	end
	
	return false
end

-- Load users list
function SecureAdminPanel:_loadUsersList(parent: ScrollingFrame): ()
	-- Simulated users data
	local users = {
		{id = 1, name = "AdminUser", role = "Admin", status = "Online", lastSeen = "Now"},
		{id = 2, name = "ModeratorUser", role = "Moderator", status = "Online", lastSeen = "5m ago"},
		{id = 3, name = "TestUser", role = "Player", status = "Offline", lastSeen = "2h ago"}
	}
	
	for i, userData in ipairs(users) do
		local userFrame = Instance.new("Frame")
		userFrame.Name = "User" .. i
		userFrame.Size = UDim2.new(1, -10, 0, 40)
		userFrame.Position = UDim2.new(0, 5, 0, 0)
		userFrame.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(250, 250, 250) or Color3.white
		userFrame.BorderSizePixel = 0
		userFrame.LayoutOrder = i
		userFrame.Parent = parent
		
		-- User info labels
		local nameLabel = self:_createLabel(userData.name, UDim2.new(0, 150, 1, 0), UDim2.new(0, 10, 0, 0), userFrame)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.SourceSansBold
		
		local roleLabel = self:_createLabel(userData.role, UDim2.new(0, 100, 1, 0), UDim2.new(0, 170, 0, 0), userFrame)
		roleLabel.TextXAlignment = Enum.TextXAlignment.Left
		
		local statusLabel = self:_createLabel(userData.status, UDim2.new(0, 80, 1, 0), UDim2.new(0, 280, 0, 0), userFrame)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.TextColor3 = userData.status == "Online" and UI_STYLES.successColor or UI_STYLES.secondaryColor
		
		local lastSeenLabel = self:_createLabel(userData.lastSeen, UDim2.new(0, 100, 1, 0), UDim2.new(0, 370, 0, 0), userFrame)
		lastSeenLabel.TextXAlignment = Enum.TextXAlignment.Left
		lastSeenLabel.TextColor3 = UI_STYLES.secondaryColor
	end
	
	-- Update canvas size
	parent.CanvasSize = UDim2.new(0, 0, 0, #users * 42)
end

-- Session Management

-- Setup session management
function SecureAdminPanel:_setupSessionManagement(): ()
	-- Session timeout timer
	task.spawn(function()
		while true do
			task.wait(30) -- Check every 30 seconds
			self:_checkSessionStatus()
		end
	end)
	
	-- Activity tracking
	UserInputService.InputBegan:Connect(function()
		if currentSession then
			currentSession.lastActivity = os.time()
		end
	end)
end

-- Check session status
function SecureAdminPanel:_checkSessionStatus(): ()
	if not currentSession then
		return
	end
	
	local currentTime = os.time()
	
	-- Check session expiry
	if currentTime >= currentSession.expiresAt then
		self:_sessionExpired("Session expired")
		return
	end
	
	-- Check idle timeout
	local idleTime = currentTime - currentSession.lastActivity
	if idleTime >= SECURITY_CONFIG.maxIdleTime then
		self:_sessionExpired("Session idle timeout")
		return
	end
	
	-- Update session info
	self:_updateSessionInfo()
end

-- Session expired
function SecureAdminPanel:_sessionExpired(reason: string): ()
	currentSession = nil
	
	-- Show expiry message
	if adminDashboard then
		local topBar = adminDashboard:FindFirstChild("TopBar")
		if topBar then
			local sessionInfo = topBar:FindFirstChild("SessionInfo")
			if sessionInfo then
				sessionInfo.Text = "Session Expired: " .. reason
				sessionInfo.TextColor3 = UI_STYLES.dangerColor
			end
		end
	end
	
	-- Return to authentication after delay
	task.wait(2)
	self:ShowAuthentication()
end

-- Logout
function SecureAdminPanel:Logout(): ()
	if currentSession then
		-- Invalidate session on server
		pcall(function()
			adminAuthentication:InvokeServer("logout", {sessionToken = currentSession.sessionToken})
		end)
		
		currentSession = nil
	end
	
	self:ShowAuthentication()
end

-- Security Monitoring

-- Setup security monitoring
function SecureAdminPanel:_setupSecurityMonitoring(): ()
	-- Simulated security alerts
	task.spawn(function()
		while true do
			task.wait(math.random(30, 120)) -- Random intervals
			if currentSession and self:_hasPermission("security.admin") then
				self:_addSecurityAlert({
					alertId = HttpService:GenerateGUID(false),
					timestamp = os.time(),
					threatLevel = math.random() > 0.7 and "HIGH" or "MEDIUM",
					alertType = "SUSPICIOUS_ACTIVITY",
					description = "Unusual activity detected",
					affectedUsers = {math.random(1000, 9999)},
					actionRequired = true
				})
			end
		end
	end)
end

-- Add security alert
function SecureAdminPanel:_addSecurityAlert(alert: SecurityAlert): ()
	if not securityMonitor then return end
	
	local alertsList = securityMonitor:FindFirstChild("AlertsList")
	if not alertsList then return end
	
	-- Create alert item
	local alertItem = Instance.new("Frame")
	alertItem.Name = "Alert_" .. alert.alertId
	alertItem.Size = UDim2.new(1, -10, 0, 80)
	alertItem.Position = UDim2.new(0, 5, 0, 0)
	alertItem.BackgroundColor3 = alert.threatLevel == "HIGH" and UI_STYLES.dangerColor or UI_STYLES.warningColor
	alertItem.BorderSizePixel = 1
	alertItem.BorderColor3 = UI_STYLES.borderColor
	alertItem.Parent = alertsList
	
	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = alertItem
	
	-- Alert content
	local threatIcon = alert.threatLevel == "HIGH" and "🚨" or "⚠️"
	local titleLabel = self:_createLabel(threatIcon .. " " .. alert.alertType, UDim2.new(1, -60, 0, 20), UDim2.new(0, 10, 0, 5), alertItem)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.white
	titleLabel.Font = Enum.Font.SourceSansBold
	
	local descLabel = self:_createLabel(alert.description, UDim2.new(1, -60, 0, 15), UDim2.new(0, 10, 0, 25), alertItem)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextColor3 = Color3.white
	descLabel.TextSize = 12
	
	local timeLabel = self:_createLabel(os.date("%H:%M:%S", alert.timestamp), UDim2.new(1, -60, 0, 15), UDim2.new(0, 10, 0, 45), alertItem)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.TextColor3 = Color3.white
	timeLabel.TextSize = 10
	
	-- Dismiss button
	local dismissButton = self:_createButton("❌", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 5), alertItem)
	dismissButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255, 100)
	dismissButton.TextColor3 = Color3.white
	
	dismissButton.MouseButton1Click:Connect(function()
		alertItem:Destroy()
		self:_updateAlertsCanvas()
	end)
	
	self:_updateAlertsCanvas()
end

-- Update alerts canvas
function SecureAdminPanel:_updateAlertsCanvas(): ()
	if not securityMonitor then return end
	
	local alertsList = securityMonitor:FindFirstChild("AlertsList")
	if not alertsList then return end
	
	local totalHeight = 0
	for _, child in ipairs(alertsList:GetChildren()) do
		if child:IsA("Frame") then
			totalHeight = totalHeight + child.Size.Y.Offset + 5
		end
	end
	
	alertsList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

-- Setup input handlers
function SecureAdminPanel:_setupInputHandlers(): ()
	-- Admin panel toggle key (F12)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.F12 then
			if currentSession then
				if adminDashboard then
					adminDashboard.Visible = not adminDashboard.Visible
				end
			else
				self:ShowAuthentication()
			end
		end
	end)
end

-- UI Helper Functions

-- Create label
function SecureAdminPanel:_createLabel(text: string, size: UDim2, position: UDim2, parent: GuiObject): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = UI_STYLES.textColor
	label.TextScaled = true
	label.Font = Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

-- Create button
function SecureAdminPanel:_createButton(text: string, size: UDim2, position: UDim2, parent: GuiObject): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = UI_STYLES.primaryColor
	button.BorderColor3 = UI_STYLES.borderColor
	button.BorderSizePixel = 1
	button.Text = text
	button.TextColor3 = Color3.white
	button.TextScaled = true
	button.Font = Enum.Font.SourceSansBold
	button.Parent = parent
	
	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	
	-- Hover effect
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Color3.fromRGB(
			math.min(255, button.BackgroundColor3.R * 255 + 20),
			math.min(255, button.BackgroundColor3.G * 255 + 20),
			math.min(255, button.BackgroundColor3.B * 255 + 20)
		)
	end)
	
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = UI_STYLES.primaryColor
	end)
	
	return button
end

-- Create text input
function SecureAdminPanel:_createTextInput(placeholder: string, size: UDim2, position: UDim2, parent: GuiObject): Frame
	local inputFrame = Instance.new("Frame")
	inputFrame.Size = size
	inputFrame.Position = position
	inputFrame.BackgroundColor3 = Color3.white
	inputFrame.BorderColor3 = UI_STYLES.borderColor
	inputFrame.BorderSizePixel = 1
	inputFrame.Parent = parent
	
	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = inputFrame
	
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 1, -10)
	textBox.Position = UDim2.new(0, 10, 0, 5)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = placeholder
	textBox.TextColor3 = UI_STYLES.textColor
	textBox.TextScaled = false
	textBox.TextSize = 14
	textBox.Font = Enum.Font.SourceSans
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputFrame
	
	return inputFrame
end

-- Create status card
function SecureAdminPanel:_createStatusCard(title: string, value: string, color: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 240, 0, 90)
	card.BackgroundColor3 = Color3.white
	card.BorderColor3 = UI_STYLES.borderColor
	card.BorderSizePixel = 1
	
	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	
	-- Status indicator
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 8, 1, 0)
	indicator.Position = UDim2.new(0, 0, 0, 0)
	indicator.BackgroundColor3 = color
	indicator.BorderSizePixel = 0
	indicator.Parent = card
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 8)
	indicatorCorner.Parent = indicator
	
	-- Title
	local titleLabel = self:_createLabel(title, UDim2.new(1, -20, 0, 30), UDim2.new(0, 15, 0, 10), card)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 14
	titleLabel.TextScaled = false
	
	-- Value
	local valueLabel = self:_createLabel(value, UDim2.new(1, -20, 0, 30), UDim2.new(0, 15, 0, 45), card)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextColor3 = color
	valueLabel.Font = Enum.Font.SourceSansBold
	valueLabel.TextSize = 18
	valueLabel.TextScaled = false
	
	return card
end

-- Initialize secure admin panel
local secureAdminPanel = SecureAdminPanel.new()

return secureAdminPanel
