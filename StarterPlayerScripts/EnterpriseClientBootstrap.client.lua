--[[
	EnterpriseClientBootstrap.client.lua
	Client-side initialization for enterprise monitoring and network systems
	
	Initializes:
	- EnhancedNetworkClient with circuit breaker and advanced retry logic
	- PerformanceMonitoringDashboard with real-time metrics
	- Integration with server-side MetricsExporter
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- Import client-side services
local EnhancedNetworkClient = require(script.Parent.EnhancedNetworkClient)
local PerformanceMonitoringDashboard = require(script.Parent.PerformanceMonitoringDashboard)

-- Initialize client-side enterprise systems
spawn(function()
	-- Wait for server services to be ready
	wait(2)
	
	-- Initialize enhanced network client
	EnhancedNetworkClient.Initialize()
	
	-- Initialize performance monitoring dashboard
	PerformanceMonitoringDashboard.Initialize()
	
	print("[EnterpriseClientBootstrap] ✓ All enterprise client systems initialized")
	print("                               Press F3 to toggle performance dashboard")
	print("                               Press F4 for detailed metrics view")
end)
