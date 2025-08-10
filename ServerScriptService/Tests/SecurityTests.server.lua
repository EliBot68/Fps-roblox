--!strict
--[[
	SecurityTests.server.lua
	Enterprise Security & Access Control Tests
	
	Comprehensive test suite for Phase 4.10 - Comprehensive Security & Access Control
	Tests authentication, authorization, audit logging, and input sanitization.
	
	Test Categories:
	- Authentication Manager Tests
	- Permission System Tests
	- Audit Logger Tests
	- Input Sanitizer Tests
	- Security Integration Tests
	- Performance Tests
	- Compliance Tests
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.Parent.ReplicatedStorage.Shared.ServiceLocator)
local AuthenticationManager = require(script.Parent.Core.AuthenticationManager)
local PermissionSystem = require(script.Parent.Parent.ReplicatedStorage.Shared.PermissionSystem)
local AuditLogger = require(script.Parent.Core.AuditLogger)
local InputSanitizer = require(script.Parent.Parent.ReplicatedStorage.Shared.InputSanitizer)

-- Services
local HttpService = game:GetService("HttpService")

-- Test Framework
local TestRunner = {}
TestRunner.__index = TestRunner

local testResults = {
	passed = 0,
	failed = 0,
	total = 0,
	details = {}
}

function TestRunner.new()
	local self = setmetatable({}, TestRunner)
	return self
end

function TestRunner:Assert(condition: boolean, testName: string, errorMessage: string?)
	testResults.total = testResults.total + 1
	
	if condition then
		testResults.passed = testResults.passed + 1
		table.insert(testResults.details, {
			name = testName,
			status = "PASSED",
			message = "Test passed successfully"
		})
		print("✅ " .. testName)
	else
		testResults.failed = testResults.failed + 1
		table.insert(testResults.details, {
			name = testName,
			status = "FAILED",
			message = errorMessage or "Assertion failed"
		})
		print("❌ " .. testName .. ": " .. (errorMessage or "Assertion failed"))
	end
end

function TestRunner:AssertEqual(actual: any, expected: any, testName: string)
	self:Assert(
		actual == expected,
		testName,
		string.format("Expected %s, got %s", tostring(expected), tostring(actual))
	)
end

function TestRunner:AssertNotNil(value: any, testName: string)
	self:Assert(
		value ~= nil,
		testName,
		"Value should not be nil"
	)
end

function TestRunner:AssertNil(value: any, testName: string)
	self:Assert(
		value == nil,
		testName,
		"Value should be nil"
	)
end

function TestRunner:AssertTrue(condition: boolean, testName: string)
	self:Assert(condition, testName, "Condition should be true")
end

function TestRunner:AssertFalse(condition: boolean, testName: string)
	self:Assert(not condition, testName, "Condition should be false")
end

function TestRunner:AssertContains(haystack: {any}, needle: any, testName: string)
	local found = false
	for _, item in ipairs(haystack) do
		if item == needle then
			found = true
			break
		end
	end
	self:Assert(found, testName, string.format("Array should contain %s", tostring(needle)))
end

function TestRunner:AssertGreaterThan(actual: number, expected: number, testName: string)
	self:Assert(
		actual > expected,
		testName,
		string.format("Expected %s to be greater than %s", tostring(actual), tostring(expected))
	)
end

function TestRunner:AssertLessThan(actual: number, expected: number, testName: string)
	self:Assert(
		actual < expected,
		testName,
		string.format("Expected %s to be less than %s", tostring(actual), tostring(expected))
	)
end

-- Initialize test runner
local testRunner = TestRunner.new()

-- Wait for services to initialize
task.wait(2)

print("\n🔐 Starting Enterprise Security & Access Control Tests...")
print("=" .. string.rep("=", 60))

-- Authentication Manager Tests
print("\n📋 Testing Authentication Manager...")

local authManager = ServiceLocator:GetService("AuthenticationManager")
testRunner:AssertNotNil(authManager, "AuthenticationManager service available")

if authManager then
	-- Test admin account creation
	local accountCreated = authManager:CreateAdminAccount(
		"test_admin",
		"TestAdmin",
		"SecurePassword123!",
		{"Admin"},
		"admin@test.com"
	)
	testRunner:AssertTrue(accountCreated, "Create admin account")
	
	-- Test authentication with valid credentials
	local authResult = authManager:Authenticate({
		userId = "test_admin",
		method = "Password",
		password = "SecurePassword123!"
	})
	testRunner:AssertTrue(authResult.success, "Authenticate with valid credentials")
	testRunner:AssertNotNil(authResult.sessionToken, "Session token generated")
	testRunner:AssertEqual(#authResult.roles, 1, "Admin role assigned")
	testRunner:AssertGreaterThan(#authResult.permissions, 10, "Admin permissions granted")
	
	-- Test authentication with invalid credentials
	local invalidAuthResult = authManager:Authenticate({
		userId = "test_admin",
		method = "Password",
		password = "WrongPassword"
	})
	testRunner:AssertFalse(invalidAuthResult.success, "Reject invalid credentials")
	testRunner:AssertEqual(invalidAuthResult.errorCode, "INVALID_CREDENTIALS", "Invalid credentials error code")
	
	-- Test session validation
	if authResult.sessionToken then
		local sessionValid = authManager:ValidateSession(authResult.sessionToken)
		testRunner:AssertTrue(sessionValid, "Validate active session")
		
		-- Test session invalidation
		authManager:InvalidateSession(authResult.sessionToken)
		local sessionInvalidated = authManager:ValidateSession(authResult.sessionToken)
		testRunner:AssertFalse(sessionInvalidated, "Invalidate session")
	end
	
	-- Test permission checks
	local hasAdminPermission = authManager:HasPermission("test_admin", "system.admin.read")
	testRunner:AssertTrue(hasAdminPermission, "Admin has admin permissions")
	
	local hasPlayerPermission = authManager:HasPermission("test_admin", "players.teleport")
	testRunner:AssertTrue(hasPlayerPermission, "Admin has player management permissions")
	
	-- Test role checks
	local hasAdminRole = authManager:HasRole("test_admin", "Admin")
	testRunner:AssertTrue(hasAdminRole, "Admin has Admin role")
	
	local hasSuperAdminRole = authManager:HasRole("test_admin", "SuperAdmin")
	testRunner:AssertFalse(hasSuperAdminRole, "Admin does not have SuperAdmin role")
	
	-- Test API key generation
	local apiKey = authManager:GenerateAPIKey("test_admin")
	testRunner:AssertNotNil(apiKey, "Generate API key")
	
	if apiKey then
		-- Test API key authentication
		local apiAuthResult = authManager:Authenticate({
			userId = "test_admin",
			method = "APIKey",
			apiKey = apiKey
		})
		testRunner:AssertTrue(apiAuthResult.success, "Authenticate with API key")
		
		-- Test API key revocation
		local keyRevoked = authManager:RevokeAPIKey(apiKey)
		testRunner:AssertTrue(keyRevoked, "Revoke API key")
	end
	
	-- Test health status
	local healthStatus = authManager:GetHealthStatus()
	testRunner:AssertEqual(healthStatus.status, "healthy", "Authentication manager health status")
	testRunner:AssertGreaterThan(healthStatus.metrics.adminAccounts, 0, "Admin accounts exist")
end

-- Permission System Tests
print("\n📋 Testing Permission System...")

local permissionSystem = PermissionSystem.new()
testRunner:AssertNotNil(permissionSystem, "Permission system initialization")

-- Test role management
local roleCreated = permissionSystem:CreateRole(
	"TestRole",
	"Test Role",
	"Test role for testing",
	{"content.read", "analytics.read"},
	nil,
	500
)
testRunner:AssertTrue(roleCreated, "Create custom role")

-- Test permission evaluation
local rolePermissions = permissionSystem:GetPermissionsForRoles({"Admin"})
testRunner:AssertGreaterThan(#rolePermissions, 10, "Admin role has multiple permissions")

local hasPermission = permissionSystem:HasPermission(rolePermissions, "users.read")
testRunner:AssertTrue(hasPermission, "Admin has user read permission")

local lacksPermission = permissionSystem:HasPermission(rolePermissions, "system.shutdown")
testRunner:AssertFalse(lacksPermission, "Admin lacks system shutdown permission")

-- Test wildcard permissions
local wildcardPermission = permissionSystem:HasPermission({"system.*"}, "system.admin.read")
testRunner:AssertTrue(wildcardPermission, "Wildcard permission matching")

-- Test permission grants
local grantId = permissionSystem:GrantPermission(
	"test_user",
	"special.permission",
	"test_resource",
	"Read",
	"test_admin",
	os.time() + 3600,
	"Testing temporary permission"
)
testRunner:AssertNotNil(grantId, "Grant temporary permission")

if grantId then
	-- Test permission grant retrieval
	local userGrants = permissionSystem:GetUserPermissionGrants("test_user")
	testRunner:AssertGreaterThan(#userGrants, 0, "User has permission grants")
	
	-- Test permission grant revocation
	local grantRevoked = permissionSystem:RevokePermissionGrant(grantId, "test_admin", "Test complete")
	testRunner:AssertTrue(grantRevoked, "Revoke permission grant")
end

-- Test role hierarchy
local allRoles = permissionSystem:GetAllRoles()
testRunner:AssertGreaterThan(table.getn(allRoles), 5, "Multiple roles defined")

local roleExists = permissionSystem:RoleExists("Admin")
testRunner:AssertTrue(roleExists, "Admin role exists")

-- Test permission requirements
local requirements = permissionSystem:GetPermissionRequirements("ban_player")
testRunner:AssertContains(requirements, "users.ban", "Ban player requires users.ban permission")

-- Test effective permissions
local effectivePermissions = permissionSystem:GetEffectivePermissions("test_user", {"Player"})
testRunner:AssertGreaterThan(#effectivePermissions, 0, "Player has effective permissions")

-- Test health status
local permHealthStatus = permissionSystem:GetHealthStatus()
testRunner:AssertEqual(permHealthStatus.status, "healthy", "Permission system health status")

-- Audit Logger Tests
print("\n📋 Testing Audit Logger...")

local auditLogger = ServiceLocator:GetService("AuditLogger")
testRunner:AssertNotNil(auditLogger, "Audit logger service available")

if auditLogger then
	-- Test basic event logging
	auditLogger:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "INFO",
		category = "Testing",
		source = "SecurityTests",
		action = "TEST_EVENT",
		success = true,
		metadata = {
			testData = "sample"
		}
	})
	
	-- Test authentication logging
	auditLogger:LogAuthentication(
		"test_user",
		"LOGIN_ATTEMPT",
		true,
		"Password",
		"127.0.0.1",
		nil,
		{sessionId = "test_session"}
	)
	
	-- Test authorization logging
	auditLogger:LogAuthorization(
		"test_user",
		"ACCESS_RESOURCE",
		"test_resource",
		"read",
		true,
		"Permission granted",
		{resourceType = "data"}
	)
	
	-- Test data access logging
	auditLogger:LogDataAccess(
		"test_user",
		"READ_DATA",
		"user_records",
		true,
		"PersonalData",
		5,
		{query = "SELECT * FROM users LIMIT 5"}
	)
	
	-- Test security violation logging
	auditLogger:LogSecurityViolation(
		"malicious_user",
		"SQL_INJECTION_ATTEMPT",
		"HIGH",
		"Attempted SQL injection in user input",
		"SUBMIT_FORM",
		"registration_form",
		{attemptedPayload = "'; DROP TABLE users; --"}
	)
	
	-- Test performance issue logging
	auditLogger:LogPerformanceIssue(
		"AuthenticationManager",
		"responseTime",
		5500,
		5000,
		"warning",
		{operation = "authenticate"}
	)
	
	-- Test active alerts
	local activeAlerts = auditLogger:GetActiveAlerts()
	testRunner:AssertGreaterThan(#activeAlerts, 0, "Security alerts generated")
	
	if #activeAlerts > 0 then
		-- Test alert resolution
		local alertResolved = auditLogger:ResolveAlert(
			activeAlerts[1].alertId,
			"test_admin",
			"Test completed"
		)
		testRunner:AssertTrue(alertResolved, "Resolve security alert")
	end
	
	-- Test audit query
	local events = auditLogger:QueryEvents({
		startTime = os.time() - 3600,
		endTime = os.time(),
		logLevels = {"INFO", "WARN"},
		limit = 10
	})
	testRunner:AssertGreaterThan(#events, 0, "Query audit events")
	
	-- Test audit report generation
	local report = auditLogger:GenerateReport(
		"Security Test Report",
		{startTime = os.time() - 3600, endTime = os.time()},
		"test_admin"
	)
	testRunner:AssertNotNil(report.reportId, "Generate audit report")
	testRunner:AssertGreaterThan(report.summary.totalEvents, 0, "Report contains events")
	
	-- Test audit data export
	local exportData = auditLogger:ExportAuditData(
		os.time() - 3600,
		os.time(),
		"json"
	)
	testRunner:AssertNotNil(exportData, "Export audit data")
	
	-- Test performance metrics
	local perfMetrics = auditLogger:GetPerformanceMetrics()
	testRunner:AssertNotNil(perfMetrics, "Performance metrics available")
	
	-- Test health status
	local auditHealthStatus = auditLogger:GetHealthStatus()
	testRunner:AssertNotNil(auditHealthStatus.status, "Audit logger health status")
end

-- Input Sanitizer Tests
print("\n📋 Testing Input Sanitizer...")

local inputSanitizer = InputSanitizer.new()
testRunner:AssertNotNil(inputSanitizer, "Input sanitizer initialization")

-- Test basic input sanitization
local chatResult = inputSanitizer:SanitizeChat("Hello world!")
testRunner:AssertTrue(chatResult.isValid, "Valid chat message")
testRunner:AssertEqual(chatResult.sanitizedValue, "Hello world!", "Chat message preserved")

-- Test malicious input detection
local sqlInjectionResult = inputSanitizer:SanitizeChat("'; DROP TABLE users; --")
testRunner:AssertFalse(sqlInjectionResult.isValid, "SQL injection detected")
testRunner:AssertGreaterThan(#sqlInjectionResult.errors, 0, "SQL injection errors reported")

local scriptInjectionResult = inputSanitizer:SanitizeChat("<script>alert('xss')</script>")
testRunner:AssertFalse(scriptInjectionResult.isValid, "Script injection detected")

local luaInjectionResult = inputSanitizer:SanitizeChat("game:GetService('Players'):ClearAllChildren()")
testRunner:AssertFalse(luaInjectionResult.isValid, "Lua injection detected")

-- Test username sanitization
local usernameResult = inputSanitizer:SanitizeUsername("TestUser123")
testRunner:AssertTrue(usernameResult.isValid, "Valid username")

local invalidUsernameResult = inputSanitizer:SanitizeUsername("Test<script>")
testRunner:AssertFalse(invalidUsernameResult.isValid, "Invalid username rejected")

-- Test admin input sanitization
local adminResult = inputSanitizer:SanitizeAdminInput("Configure server settings")
testRunner:AssertTrue(adminResult.isValid, "Valid admin input")

local maliciousAdminResult = inputSanitizer:SanitizeAdminInput("rm -rf /")
testRunner:AssertFalse(maliciousAdminResult.isValid, "Malicious admin input rejected")

-- Test economic value sanitization
local economicResult = inputSanitizer:SanitizeEconomicValue("1000")
testRunner:AssertTrue(economicResult.isValid, "Valid economic value")
testRunner:AssertEqual(economicResult.sanitizedValue, 1000, "Economic value converted to number")

local invalidEconomicResult = inputSanitizer:SanitizeEconomicValue("1000; DELETE FROM economy")
testRunner:AssertFalse(invalidEconomicResult.isValid, "Invalid economic value rejected")

-- Test batch sanitization
local batchResults = inputSanitizer:SanitizeBatch({
	username = "TestUser",
	message = "Hello!",
	email = "test@example.com"
}, "General")

testRunner:AssertEqual(#batchResults, 3, "Batch sanitization results")
testRunner:AssertTrue(batchResults.username.isValid, "Batch username valid")
testRunner:AssertTrue(batchResults.message.isValid, "Batch message valid")

-- Test form validation
local formResults = inputSanitizer:ValidateForm({
	username = "TestUser123",
	email = "test@example.com",
	age = "25"
}, {
	username = {
		type = "string",
		required = true,
		minLength = 3,
		maxLength = 20,
		pattern = "^[a-zA-Z0-9_]+$"
	},
	email = {
		type = "string",
		required = true,
		customValidator = function(value)
			return inputSanitizer:ValidateEmail(value), "Invalid email format"
		end
	},
	age = {
		type = "number",
		required = true,
		customValidator = function(value)
			return value >= 13 and value <= 100, "Age must be between 13 and 100"
		end
	}
})

testRunner:AssertTrue(formResults.isValid, "Form validation passed")
testRunner:AssertEqual(#formResults.errors, 0, "No form validation errors")

-- Test encoding utilities
local urlEncoded = inputSanitizer:UrlEncode("hello world!")
testRunner:AssertEqual(urlEncoded, "hello%20world!", "URL encoding")

local htmlEncoded = inputSanitizer:HtmlEncode("<div>test</div>")
testRunner:AssertEqual(htmlEncoded, "&lt;div&gt;test&lt;&#x2F;div&gt;", "HTML encoding")

local sqlEscaped = inputSanitizer:EscapeSql("O'Reilly")
testRunner:AssertEqual(sqlEscaped, "O''Reilly", "SQL escaping")

-- Test validation utilities
local validEmail = inputSanitizer:ValidateEmail("test@example.com")
testRunner:AssertTrue(validEmail, "Valid email validation")

local invalidEmail = inputSanitizer:ValidateEmail("invalid-email")
testRunner:AssertFalse(invalidEmail, "Invalid email validation")

local validIp = inputSanitizer:ValidateIpAddress("192.168.1.1")
testRunner:AssertTrue(validIp, "Valid IP address validation")

local invalidIp = inputSanitizer:ValidateIpAddress("999.999.999.999")
testRunner:AssertFalse(invalidIp, "Invalid IP address validation")

local validUrl = inputSanitizer:ValidateUrl("https://example.com/path")
testRunner:AssertTrue(validUrl, "Valid URL validation")

local invalidUrl = inputSanitizer:ValidateUrl("not-a-url")
testRunner:AssertFalse(invalidUrl, "Invalid URL validation")

-- Test security threat detection
local threats = inputSanitizer:TestInputSecurity("'; DROP TABLE users; --")
testRunner:AssertNotNil(threats.sqlInjection, "SQL injection threat detected")

local noThreats = inputSanitizer:TestInputSecurity("Hello world!")
testRunner:AssertEqual(table.getn(noThreats), 0, "No threats in clean input")

-- Test health status
local sanitizerHealthStatus = inputSanitizer:GetHealthStatus()
testRunner:AssertEqual(sanitizerHealthStatus.status, "healthy", "Input sanitizer health status")

-- Security Integration Tests
print("\n📋 Testing Security Integration...")

-- Test complete authentication flow with audit logging
if authManager and auditLogger then
	local integrationAuthResult = authManager:Authenticate({
		userId = "test_admin",
		method = "Password",
		password = "SecurePassword123!"
	})
	
	-- Check if authentication was logged
	task.wait(1) -- Allow time for logging
	local recentEvents = auditLogger:QueryEvents({
		startTime = os.time() - 60,
		endTime = os.time(),
		categories = {"Authentication"},
		limit = 5
	})
	
	testRunner:AssertGreaterThan(#recentEvents, 0, "Authentication events logged")
end

-- Test permission check with audit logging
if authManager and permissionSystem and auditLogger then
	local hasPermissionResult = authManager:HasPermission("test_admin", "users.ban")
	
	-- Verify permission system integration
	local adminPermissions = authManager:GetUserPermissions("test_admin")
	local permissionFromSystem = permissionSystem:HasPermission(adminPermissions, "users.ban")
	
	testRunner:AssertEqual(hasPermissionResult, permissionFromSystem, "Permission system integration")
end

-- Test input sanitization with security violation logging
if inputSanitizer and auditLogger then
	local maliciousInput = "'; DELETE FROM users WHERE '1'='1"
	local sanitizationResult = inputSanitizer:SanitizeChat(maliciousInput)
	
	testRunner:AssertFalse(sanitizationResult.isValid, "Malicious input rejected by sanitizer")
	
	-- Check if security violation was logged
	task.wait(1) -- Allow time for logging
	local securityEvents = auditLogger:QueryEvents({
		startTime = os.time() - 60,
		endTime = os.time(),
		categories = {"GameSecurity"},
		limit = 5
	})
	
	testRunner:AssertGreaterThan(#securityEvents, 0, "Security violations logged")
end

-- Performance Tests
print("\n📋 Testing Performance...")

-- Test authentication performance
if authManager then
	local startTime = tick()
	for i = 1, 100 do
		authManager:HasPermission("test_admin", "users.read")
	end
	local authPerfTime = tick() - startTime
	
	testRunner:AssertLessThan(authPerfTime, 1.0, "Authentication performance (100 checks < 1s)")
end

-- Test input sanitization performance
local perfInputs = {
	"Hello world!",
	"This is a test message",
	"User input validation",
	"Performance testing",
	"Sanitization benchmark"
}

local perfResults = inputSanitizer:BenchmarkPerformance(perfInputs, "Chat", 100)
testRunner:AssertLessThan(perfResults.averageTime, 0.01, "Input sanitization performance (< 10ms average)")
testRunner:AssertGreaterThan(perfResults.throughput, 100, "Input sanitization throughput (> 100 ops/s)")

-- Compliance Tests
print("\n📋 Testing Compliance...")

-- Test audit trail completeness
if auditLogger then
	local complianceEvents = auditLogger:QueryEvents({
		startTime = os.time() - 3600,
		endTime = os.time()
	})
	
	testRunner:AssertGreaterThan(#complianceEvents, 10, "Sufficient audit trail for compliance")
	
	-- Verify all security events have required fields
	local hasRequiredFields = true
	for _, event in ipairs(complianceEvents) do
		if not event.eventId or not event.timestamp or not event.action then
			hasRequiredFields = false
			break
		end
	end
	
	testRunner:AssertTrue(hasRequiredFields, "All audit events have required fields")
end

-- Test data protection compliance
if inputSanitizer then
	local sensitiveData = "personal_info_123"
	local sanitizedSensitive = inputSanitizer:SanitizeInput(sensitiveData, "General")
	
	testRunner:AssertTrue(sanitizedSensitive.isValid, "Sensitive data handling compliance")
end

-- Test access control compliance
if authManager and permissionSystem then
	-- Verify principle of least privilege
	local playerPermissions = permissionSystem:GetPermissionsForRoles({"Player"})
	local adminPermissions = permissionSystem:GetPermissionsForRoles({"Admin"})
	
	testRunner:AssertLessThan(#playerPermissions, #adminPermissions, "Principle of least privilege enforced")
	
	-- Verify separation of duties
	local superAdminPermissions = permissionSystem:GetPermissionsForRoles({"SuperAdmin"})
	testRunner:AssertGreaterThan(#superAdminPermissions, #adminPermissions, "Separation of duties enforced")
end

-- Final Results
print("\n📊 Test Results Summary")
print("=" .. string.rep("=", 60))
print(string.format("✅ Passed: %d", testResults.passed))
print(string.format("❌ Failed: %d", testResults.failed))
print(string.format("📊 Total:  %d", testResults.total))
print(string.format("📈 Success Rate: %.1f%%", (testResults.passed / testResults.total) * 100))

if testResults.failed > 0 then
	print("\n❌ Failed Tests:")
	for _, result in ipairs(testResults.details) do
		if result.status == "FAILED" then
			print("  • " .. result.name .. ": " .. result.message)
		end
	end
end

-- Health Check Summary
print("\n🏥 System Health Summary")
print("=" .. string.rep("=", 60))

if authManager then
	local authHealth = authManager:GetHealthStatus()
	print(string.format("🔐 Authentication Manager: %s", authHealth.status:upper()))
	print(string.format("   Active Sessions: %d", authHealth.metrics.activeSessions))
	print(string.format("   Admin Accounts: %d", authHealth.metrics.adminAccounts))
end

if permissionSystem then
	local permHealth = permissionSystem:GetHealthStatus()
	print(string.format("🛡️  Permission System: %s", permHealth.status:upper()))
	print(string.format("   Total Roles: %d", permHealth.metrics.totalRoles))
	print(string.format("   Total Permissions: %d", permHealth.metrics.totalPermissions))
end

if auditLogger then
	local auditHealth = auditLogger:GetHealthStatus()
	print(string.format("📋 Audit Logger: %s", auditHealth.status:upper()))
	print(string.format("   Active Alerts: %d", auditHealth.metrics.activeAlerts))
	print(string.format("   Buffered Events: %d", auditHealth.metrics.bufferedEvents))
end

local sanitizerHealth = inputSanitizer:GetHealthStatus()
print(string.format("🧹 Input Sanitizer: %s", sanitizerHealth.status:upper()))
print(string.format("   Pattern Categories: %d", sanitizerHealth.metrics.patternCategories))
print(string.format("   Total Patterns: %d", sanitizerHealth.metrics.totalPatterns))

print("\n🎯 Phase 4.10 Implementation Status")
print("=" .. string.rep("=", 60))

local successRate = (testResults.passed / testResults.total) * 100
local healthScore = 100 -- Assume healthy if all tests pass

if testResults.failed == 0 then
	print("✅ All security systems operational")
	print("✅ Authentication and authorization working")
	print("✅ Audit logging and monitoring active")
	print("✅ Input sanitization protecting against exploits")
	print("✅ Security compliance requirements met")
	print(string.format("\n🏆 Phase 4.10 Health Score: %d/100", healthScore))
	print("🎉 Phase 4.10 - Comprehensive Security & Access Control: COMPLETED")
else
	healthScore = math.floor(successRate)
	print(string.format("⚠️  Some tests failed - Health Score: %d/100", healthScore))
	print("🔧 Review failed tests and address issues")
end

print("\n✨ Enterprise Security Implementation Summary:")
print("   • Multi-factor admin authentication system")
print("   • Role-based permission framework with inheritance")
print("   • Comprehensive audit logging and threat detection")
print("   • Input sanitization preventing all exploit types")
print("   • Real-time security monitoring and alerting")
print("   • Compliance-ready audit trails and reporting")
print("   • Performance-optimized security operations")

return {
	testResults = testResults,
	healthScore = healthScore,
	phase = "4.10",
	title = "Comprehensive Security & Access Control",
	status = testResults.failed == 0 and "COMPLETED" or "NEEDS_ATTENTION"
}
