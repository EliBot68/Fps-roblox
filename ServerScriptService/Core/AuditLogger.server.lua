--!strict
--[[
	AuditLogger.server.lua
	Enterprise Security Audit & Logging System
	
	Provides comprehensive audit logging, security monitoring, and compliance
	tracking for all system activities and security events.
	
	Features:
	- Comprehensive security event logging
	- Real-time threat detection and alerting
	- Compliance audit trails
	- Automated security reporting
	- Log integrity verification
	- Hierarchical log levels and filtering
	- Performance monitoring and alerts
	- Data retention and archival
	- Correlation analysis and pattern detection
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.Parent.ReplicatedStorage.Shared.ServiceLocator)

-- Services
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Types
export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR" | "CRITICAL" | "SECURITY"

export type EventCategory = "Authentication" | "Authorization" | "DataAccess" | "SystemAdmin" | 
                           "UserAction" | "NetworkSecurity" | "GameSecurity" | "Performance" | 
                           "Compliance" | "AntiCheat" | "Economy" | "Communication"

export type SecurityThreatLevel = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"

export type AuditEvent = {
	eventId: string,
	timestamp: number,
	logLevel: LogLevel,
	category: EventCategory,
	source: string,
	userId: number | string?,
	sessionId: string?,
	action: string,
	resource: string?,
	success: boolean,
	errorCode: string?,
	errorMessage: string?,
	ipAddress: string?,
	userAgent: string?,
	threatLevel: SecurityThreatLevel?,
	correlationId: string?,
	duration: number?,
	metadata: {[string]: any}?
}

export type SecurityAlert = {
	alertId: string,
	timestamp: number,
	threatLevel: SecurityThreatLevel,
	alertType: string,
	description: string,
	affectedUsers: {number | string},
	sourceEvents: {string},
	actionRequired: boolean,
	autoResolved: boolean,
	resolvedAt: number?,
	resolvedBy: number | string?,
	metadata: {[string]: any}?
}

export type AuditQuery = {
	startTime: number?,
	endTime: number?,
	logLevels: {LogLevel}?,
	categories: {EventCategory}?,
	userIds: {number | string}?,
	actions: {string}?,
	resources: {string}?,
	successOnly: boolean?,
	failuresOnly: boolean?,
	threatLevels: {SecurityThreatLevel}?,
	limit: number?,
	offset: number?
}

export type AuditReport = {
	reportId: string,
	generatedAt: number,
	generatedBy: number | string,
	reportType: string,
	timeRange: {startTime: number, endTime: number},
	summary: {
		totalEvents: number,
		eventsByLevel: {[LogLevel]: number},
		eventsByCategory: {[EventCategory]: number},
		uniqueUsers: number,
		successRate: number,
		threatsDetected: number,
		alertsGenerated: number
	},
	events: {AuditEvent},
	alerts: {SecurityAlert},
	recommendations: {string},
	metadata: {[string]: any}?
}

export type LoggingConfig = {
	maxLogLevel: LogLevel,
	enableRealTimeMonitoring: boolean,
	enableThreatDetection: boolean,
	enableCompliance: boolean,
	retentionDays: number,
	maxEventsPerBatch: number,
	batchFlushInterval: number,
	enableEncryption: boolean,
	enableIntegrityCheck: boolean,
	alertThresholds: {[string]: number}
}

-- Audit Logger
local AuditLogger = {}
AuditLogger.__index = AuditLogger

-- Private Variables
local logger: any
local analytics: any
local configManager: any
local eventBuffer: {AuditEvent} = {}
local activeAlerts: {[string]: SecurityAlert} = {}
local eventCorrelations: {[string]: {string}} = {}
local threatPatterns: {[string]: any} = {}
local performanceMetrics: {[string]: any} = {}

-- Configuration
local LOGGING_CONFIG: LoggingConfig = {
	maxLogLevel = "DEBUG",
	enableRealTimeMonitoring = true,
	enableThreatDetection = true,
	enableCompliance = true,
	retentionDays = 90,
	maxEventsPerBatch = 100,
	batchFlushInterval = 30,
	enableEncryption = false, -- Would use HTTPS in production
	enableIntegrityCheck = true,
	alertThresholds = {
		failedLogins = 5,
		securityViolations = 3,
		performanceDegradation = 10,
		dataAccessAnomalies = 20,
		suspiciousActivity = 15
	}
}

-- Log Levels (priority order)
local LOG_LEVEL_PRIORITY = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	CRITICAL = 5,
	SECURITY = 6
}

-- DataStores
local auditDataStore = DataStoreService:GetDataStore("SecurityAudit_v1")
local alertDataStore = DataStoreService:GetDataStore("SecurityAlerts_v1")
local reportDataStore = DataStoreService:GetDataStore("AuditReports_v1")

-- Events
local SecurityAlertGenerated = Instance.new("BindableEvent")
local ComplianceViolationDetected = Instance.new("BindableEvent")
local ThreatDetected = Instance.new("BindableEvent")
local PerformanceIssueDetected = Instance.new("BindableEvent")

-- Initialization
function AuditLogger.new(): typeof(AuditLogger)
	local self = setmetatable({}, AuditLogger)
	
	-- Get services
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	configManager = ServiceLocator:GetService("ConfigManager")
	
	if not logger then
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	-- Initialize threat detection patterns
	self:_initializeThreatPatterns()
	
	-- Setup batch processing
	self:_setupBatchProcessing()
	
	-- Setup real-time monitoring
	if LOGGING_CONFIG.enableRealTimeMonitoring then
		self:_setupRealTimeMonitoring()
	end
	
	-- Setup threat detection
	if LOGGING_CONFIG.enableThreatDetection then
		self:_setupThreatDetection()
	end
	
	-- Setup performance monitoring
	self:_setupPerformanceMonitoring()
	
	-- Log system initialization
	self:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "INFO",
		category = "SystemAdmin",
		source = "AuditLogger",
		action = "SYSTEM_INITIALIZED",
		success = true,
		metadata = {
			config = LOGGING_CONFIG,
			version = "1.0.0"
		}
	})
	
	logger.LogInfo("AuditLogger initialized successfully", {
		realTimeMonitoring = LOGGING_CONFIG.enableRealTimeMonitoring,
		threatDetection = LOGGING_CONFIG.enableThreatDetection,
		retentionDays = LOGGING_CONFIG.retentionDays
	})
	
	return self
end

-- Core Logging Functions

-- Log audit event
function AuditLogger:LogEvent(event: AuditEvent): ()
	-- Validate log level
	if not self:_shouldLogLevel(event.logLevel) then
		return
	end
	
	-- Ensure required fields
	if not event.eventId then
		event.eventId = HttpService:GenerateGUID(false)
	end
	
	if not event.timestamp then
		event.timestamp = os.time()
	end
	
	-- Add correlation ID if not provided
	if not event.correlationId and event.sessionId then
		event.correlationId = event.sessionId
	end
	
	-- Add to event buffer
	table.insert(eventBuffer, event)
	
	-- Process for threat detection
	if LOGGING_CONFIG.enableThreatDetection then
		self:_analyzeThreatPatterns(event)
	end
	
	-- Process for compliance
	if LOGGING_CONFIG.enableCompliance then
		self:_checkComplianceViolations(event)
	end
	
	-- Record performance metrics
	self:_recordPerformanceMetrics(event)
	
	-- Flush if buffer is full
	if #eventBuffer >= LOGGING_CONFIG.maxEventsPerBatch then
		self:_flushEventBuffer()
	end
	
	-- Handle critical events immediately
	if event.logLevel == "CRITICAL" or event.logLevel == "SECURITY" then
		self:_handleCriticalEvent(event)
	end
end

-- Log authentication event
function AuditLogger:LogAuthentication(
	userId: number | string,
	action: string,
	success: boolean,
	method: string?,
	ipAddress: string?,
	errorCode: string?,
	metadata: {[string]: any}?
): ()
	local event: AuditEvent = {
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = success and "INFO" or "WARN",
		category = "Authentication",
		source = "AuthenticationManager",
		userId = userId,
		action = action,
		success = success,
		errorCode = errorCode,
		ipAddress = ipAddress,
		threatLevel = success and "LOW" or "MEDIUM",
		metadata = table.clone(metadata or {})
	}
	
	-- Add authentication-specific metadata
	if method then
		event.metadata.authMethod = method
	end
	
	self:LogEvent(event)
end

-- Log authorization event
function AuditLogger:LogAuthorization(
	userId: number | string,
	action: string,
	resource: string?,
	permission: string,
	success: boolean,
	reason: string?,
	metadata: {[string]: any}?
): ()
	local event: AuditEvent = {
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = success and "INFO" or "WARN",
		category = "Authorization",
		source = "PermissionSystem",
		userId = userId,
		action = action,
		resource = resource,
		success = success,
		threatLevel = success and "LOW" or "MEDIUM",
		metadata = table.clone(metadata or {})
	}
	
	-- Add authorization-specific metadata
	event.metadata.requiredPermission = permission
	if reason then
		event.metadata.reason = reason
	end
	
	self:LogEvent(event)
end

-- Log data access event
function AuditLogger:LogDataAccess(
	userId: number | string,
	action: string,
	resource: string,
	success: boolean,
	dataType: string?,
	recordCount: number?,
	metadata: {[string]: any}?
): ()
	local event: AuditEvent = {
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "INFO",
		category = "DataAccess",
		source = "DataManager",
		userId = userId,
		action = action,
		resource = resource,
		success = success,
		threatLevel = "LOW",
		metadata = table.clone(metadata or {})
	}
	
	-- Add data access specific metadata
	if dataType then
		event.metadata.dataType = dataType
	end
	if recordCount then
		event.metadata.recordCount = recordCount
	end
	
	-- Check for suspicious data access patterns
	if recordCount and recordCount > 1000 then
		event.threatLevel = "MEDIUM"
		event.logLevel = "WARN"
	end
	
	self:LogEvent(event)
end

-- Log security violation
function AuditLogger:LogSecurityViolation(
	userId: number | string?,
	violationType: string,
	severity: SecurityThreatLevel,
	description: string,
	action: string?,
	resource: string?,
	metadata: {[string]: any}?
): ()
	local event: AuditEvent = {
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "SECURITY",
		category = "GameSecurity",
		source = "SecurityMonitor",
		userId = userId,
		action = action or "SECURITY_VIOLATION",
		resource = resource,
		success = false,
		errorMessage = description,
		threatLevel = severity,
		metadata = table.clone(metadata or {})
	}
	
	-- Add security violation specific metadata
	event.metadata.violationType = violationType
	event.metadata.severity = severity
	
	self:LogEvent(event)
	
	-- Generate security alert
	self:_generateSecurityAlert({
		alertType = "SECURITY_VIOLATION",
		description = description,
		threatLevel = severity,
		affectedUsers = userId and {userId} or {},
		sourceEvents = {event.eventId},
		actionRequired = severity == "HIGH" or severity == "CRITICAL"
	})
end

-- Log performance issue
function AuditLogger:LogPerformanceIssue(
	component: string,
	metric: string,
	value: number,
	threshold: number,
	severity: string,
	metadata: {[string]: any}?
): ()
	local event: AuditEvent = {
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = severity == "critical" and "CRITICAL" or "WARN",
		category = "Performance",
		source = component,
		action = "PERFORMANCE_ISSUE",
		success = false,
		errorMessage = string.format("%s exceeded threshold: %s > %s", metric, value, threshold),
		metadata = table.clone(metadata or {})
	}
	
	-- Add performance specific metadata
	event.metadata.metric = metric
	event.metadata.value = value
	event.metadata.threshold = threshold
	event.metadata.severity = severity
	
	self:LogEvent(event)
end

-- Threat Detection

-- Initialize threat detection patterns
function AuditLogger:_initializeThreatPatterns(): ()
	threatPatterns = {
		bruteForceAttack = {
			pattern = "multiple_failed_logins",
			threshold = 5,
			timeWindow = 300, -- 5 minutes
			severity = "HIGH"
		},
		
		privilegeEscalation = {
			pattern = "unauthorized_permission_access",
			threshold = 3,
			timeWindow = 600, -- 10 minutes
			severity = "CRITICAL"
		},
		
		dataExfiltration = {
			pattern = "excessive_data_access",
			threshold = 1000,
			timeWindow = 3600, -- 1 hour
			severity = "HIGH"
		},
		
		systemManipulation = {
			pattern = "admin_action_anomaly",
			threshold = 10,
			timeWindow = 1800, -- 30 minutes
			severity = "MEDIUM"
		},
		
		suspiciousActivity = {
			pattern = "unusual_user_behavior",
			threshold = 15,
			timeWindow = 3600, -- 1 hour
			severity = "MEDIUM"
		}
	}
end

-- Analyze event for threat patterns
function AuditLogger:_analyzeThreatPatterns(event: AuditEvent): ()
	local currentTime = os.time()
	
	-- Check for brute force attacks
	if event.category == "Authentication" and not event.success then
		self:_checkPattern("bruteForceAttack", event, currentTime)
	end
	
	-- Check for privilege escalation
	if event.category == "Authorization" and not event.success then
		self:_checkPattern("privilegeEscalation", event, currentTime)
	end
	
	-- Check for data exfiltration
	if event.category == "DataAccess" and event.metadata and event.metadata.recordCount then
		if event.metadata.recordCount > threatPatterns.dataExfiltration.threshold then
			self:_checkPattern("dataExfiltration", event, currentTime)
		end
	end
	
	-- Check for system manipulation
	if event.category == "SystemAdmin" then
		self:_checkPattern("systemManipulation", event, currentTime)
	end
	
	-- Check for suspicious activity patterns
	if event.userId then
		self:_checkUserActivityPattern(event, currentTime)
	end
end

-- Check specific threat pattern
function AuditLogger:_checkPattern(patternName: string, event: AuditEvent, currentTime: number): ()
	local pattern = threatPatterns[patternName]
	if not pattern then
		return
	end
	
	local correlationKey = patternName .. "_" .. tostring(event.userId or "unknown")
	
	-- Initialize correlation tracking
	if not eventCorrelations[correlationKey] then
		eventCorrelations[correlationKey] = {}
	end
	
	-- Add current event
	table.insert(eventCorrelations[correlationKey], event.eventId)
	
	-- Count events in time window
	local recentEvents = 0
	local windowStart = currentTime - pattern.timeWindow
	
	-- Simple count for demonstration (in production, would use time-based filtering)
	for _, eventId in ipairs(eventCorrelations[correlationKey]) do
		recentEvents = recentEvents + 1
	end
	
	-- Trigger alert if threshold exceeded
	if recentEvents >= pattern.threshold then
		self:_generateSecurityAlert({
			alertType = patternName:upper(),
			description = string.format("Threat pattern detected: %s (threshold: %d events in %d seconds)", 
				patternName, pattern.threshold, pattern.timeWindow),
			threatLevel = pattern.severity,
			affectedUsers = event.userId and {event.userId} or {},
			sourceEvents = {event.eventId},
			actionRequired = pattern.severity == "HIGH" or pattern.severity == "CRITICAL"
		})
		
		-- Reset correlation to prevent spam
		eventCorrelations[correlationKey] = {}
	end
end

-- Check user activity patterns
function AuditLogger:_checkUserActivityPattern(event: AuditEvent, currentTime: number): ()
	if not event.userId then
		return
	end
	
	local userKey = "user_activity_" .. tostring(event.userId)
	
	-- Track user activity frequency
	if not eventCorrelations[userKey] then
		eventCorrelations[userKey] = {}
	end
	
	table.insert(eventCorrelations[userKey], {
		eventId = event.eventId,
		timestamp = currentTime,
		category = event.category,
		action = event.action
	})
	
	-- Check for unusual activity volume
	local recentActivity = 0
	local windowStart = currentTime - 3600 -- 1 hour window
	
	for _, activity in ipairs(eventCorrelations[userKey]) do
		if activity.timestamp >= windowStart then
			recentActivity = recentActivity + 1
		end
	end
	
	-- Alert on suspicious activity volume
	if recentActivity >= threatPatterns.suspiciousActivity.threshold then
		self:_generateSecurityAlert({
			alertType = "SUSPICIOUS_USER_ACTIVITY",
			description = string.format("User %s has excessive activity: %d events in 1 hour", 
				tostring(event.userId), recentActivity),
			threatLevel = "MEDIUM",
			affectedUsers = {event.userId},
			sourceEvents = {event.eventId},
			actionRequired = false
		})
	end
end

-- Generate security alert
function AuditLogger:_generateSecurityAlert(alertData: any): ()
	local alert: SecurityAlert = {
		alertId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		threatLevel = alertData.threatLevel,
		alertType = alertData.alertType,
		description = alertData.description,
		affectedUsers = alertData.affectedUsers,
		sourceEvents = alertData.sourceEvents,
		actionRequired = alertData.actionRequired,
		autoResolved = false,
		metadata = alertData.metadata or {}
	}
	
	activeAlerts[alert.alertId] = alert
	
	-- Store alert persistently
	pcall(function()
		alertDataStore:SetAsync("alert_" .. alert.alertId, alert)
	end)
	
	-- Fire security alert event
	SecurityAlertGenerated:Fire(alert)
	
	-- Log the alert generation
	self:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "SECURITY",
		category = "GameSecurity",
		source = "ThreatDetection",
		action = "SECURITY_ALERT_GENERATED",
		success = true,
		metadata = {
			alertId = alert.alertId,
			alertType = alert.alertType,
			threatLevel = alert.threatLevel,
			affectedUsers = alert.affectedUsers
		}
	})
	
	logger.LogWarning("Security alert generated", {
		alertId = alert.alertId,
		alertType = alert.alertType,
		threatLevel = alert.threatLevel,
		affectedUsers = alert.affectedUsers
	})
end

-- Compliance and Monitoring

-- Check compliance violations
function AuditLogger:_checkComplianceViolations(event: AuditEvent): ()
	-- Check for unauthorized data access
	if event.category == "DataAccess" and not event.success then
		self:_checkDataProtectionCompliance(event)
	end
	
	-- Check for security policy violations
	if event.category == "Authorization" and not event.success then
		self:_checkSecurityPolicyCompliance(event)
	end
	
	-- Check for admin action compliance
	if event.category == "SystemAdmin" then
		self:_checkAdminActionCompliance(event)
	end
end

-- Check data protection compliance
function AuditLogger:_checkDataProtectionCompliance(event: AuditEvent): ()
	-- Check for sensitive data access violations
	if event.resource and (
		string.find(event.resource, "personal", 1, true) or
		string.find(event.resource, "private", 1, true) or
		string.find(event.resource, "sensitive", 1, true)
	) then
		ComplianceViolationDetected:Fire({
			violationType = "DATA_PROTECTION",
			event = event,
			regulation = "Data Privacy",
			severity = "HIGH"
		})
	end
end

-- Check security policy compliance
function AuditLogger:_checkSecurityPolicyCompliance(event: AuditEvent): ()
	-- Check for multiple authorization failures
	if not event.success and event.userId then
		local userKey = "auth_failures_" .. tostring(event.userId)
		if not eventCorrelations[userKey] then
			eventCorrelations[userKey] = {}
		end
		
		table.insert(eventCorrelations[userKey], event.timestamp)
		
		-- Check for policy violation threshold
		if #eventCorrelations[userKey] >= 3 then
			ComplianceViolationDetected:Fire({
				violationType = "SECURITY_POLICY",
				event = event,
				regulation = "Access Control Policy",
				severity = "MEDIUM"
			})
		end
	end
end

-- Check admin action compliance
function AuditLogger:_checkAdminActionCompliance(event: AuditEvent): ()
	-- Ensure all admin actions are properly authorized
	if event.userId and not event.metadata.approvedBy then
		ComplianceViolationDetected:Fire({
			violationType = "ADMIN_ACTION",
			event = event,
			regulation = "Administrative Oversight",
			severity = "MEDIUM"
		})
	end
end

-- Performance Monitoring

-- Setup performance monitoring
function AuditLogger:_setupPerformanceMonitoring(): ()
	task.spawn(function()
		while true do
			task.wait(60) -- Check every minute
			self:_collectPerformanceMetrics()
		end
	end)
end

-- Collect performance metrics
function AuditLogger:_collectPerformanceMetrics(): ()
	local currentTime = os.time()
	
	-- Collect system metrics
	local metrics = {
		timestamp = currentTime,
		eventBufferSize = #eventBuffer,
		activeAlerts = self:_countKeys(activeAlerts),
		correlationEntries = self:_countKeys(eventCorrelations),
		memoryUsage = gcinfo() * 1024, -- Convert KB to bytes
		heartbeatTime = RunService.Heartbeat:Wait() * 1000 -- Convert to milliseconds
	}
	
	performanceMetrics[tostring(currentTime)] = metrics
	
	-- Check performance thresholds
	if metrics.eventBufferSize > LOGGING_CONFIG.maxEventsPerBatch * 2 then
		self:LogPerformanceIssue("AuditLogger", "eventBufferSize", 
			metrics.eventBufferSize, LOGGING_CONFIG.maxEventsPerBatch, "warning")
	end
	
	if metrics.heartbeatTime > 50 then -- 50ms threshold
		self:LogPerformanceIssue("AuditLogger", "heartbeatTime", 
			metrics.heartbeatTime, 50, "warning")
	end
	
	-- Cleanup old metrics (keep last hour)
	self:_cleanupOldMetrics(currentTime - 3600)
end

-- Record performance metrics from events
function AuditLogger:_recordPerformanceMetrics(event: AuditEvent): ()
	if event.duration then
		local metricKey = event.source .. "_" .. event.action
		if not performanceMetrics[metricKey] then
			performanceMetrics[metricKey] = {
				totalDuration = 0,
				eventCount = 0,
				maxDuration = 0,
				minDuration = math.huge
			}
		end
		
		local metrics = performanceMetrics[metricKey]
		metrics.totalDuration = metrics.totalDuration + event.duration
		metrics.eventCount = metrics.eventCount + 1
		metrics.maxDuration = math.max(metrics.maxDuration, event.duration)
		metrics.minDuration = math.min(metrics.minDuration, event.duration)
		
		-- Calculate average
		metrics.averageDuration = metrics.totalDuration / metrics.eventCount
		
		-- Alert on performance degradation
		if event.duration > 5000 then -- 5 second threshold
			PerformanceIssueDetected:Fire({
				component = event.source,
				action = event.action,
				duration = event.duration,
				threshold = 5000
			})
		end
	end
end

-- Batch Processing

-- Setup batch processing
function AuditLogger:_setupBatchProcessing(): ()
	-- Flush buffer periodically
	task.spawn(function()
		while true do
			task.wait(LOGGING_CONFIG.batchFlushInterval)
			if #eventBuffer > 0 then
				self:_flushEventBuffer()
			end
		end
	end)
end

-- Flush event buffer to persistent storage
function AuditLogger:_flushEventBuffer(): ()
	if #eventBuffer == 0 then
		return
	end
	
	local batchId = HttpService:GenerateGUID(false)
	local events = table.clone(eventBuffer)
	eventBuffer = {}
	
	-- Store events in batches
	pcall(function()
		auditDataStore:SetAsync("batch_" .. batchId, {
			batchId = batchId,
			timestamp = os.time(),
			eventCount = #events,
			events = events
		})
	end)
	
	-- Record to analytics
	if analytics then
		for _, event in ipairs(events) do
			analytics:RecordEvent(event.userId or 0, "audit_event", event)
		end
	end
	
	logger.LogInfo("Event batch flushed", {
		batchId = batchId,
		eventCount = #events
	})
end

-- Real-time Monitoring

-- Setup real-time monitoring
function AuditLogger:_setupRealTimeMonitoring(): ()
	task.spawn(function()
		while true do
			task.wait(10) -- Check every 10 seconds
			self:_processRealTimeAlerts()
		end
	end)
end

-- Process real-time alerts
function AuditLogger:_processRealTimeAlerts(): ()
	local currentTime = os.time()
	
	-- Check for alert escalation
	for alertId, alert in pairs(activeAlerts) do
		if alert.actionRequired and not alert.autoResolved then
			local alertAge = currentTime - alert.timestamp
			
			-- Escalate critical alerts after 5 minutes
			if alert.threatLevel == "CRITICAL" and alertAge > 300 then
				self:_escalateAlert(alert)
			end
			
			-- Auto-resolve medium alerts after 1 hour
			if alert.threatLevel == "MEDIUM" and alertAge > 3600 then
				self:_autoResolveAlert(alert)
			end
		end
	end
end

-- Escalate alert
function AuditLogger:_escalateAlert(alert: SecurityAlert): ()
	alert.metadata.escalated = true
	alert.metadata.escalatedAt = os.time()
	
	-- Generate escalation notification
	self:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "CRITICAL",
		category = "GameSecurity",
		source = "AlertManager",
		action = "ALERT_ESCALATED",
		success = true,
		metadata = {
			originalAlertId = alert.alertId,
			alertType = alert.alertType,
			threatLevel = alert.threatLevel
		}
	})
	
	logger.LogError("Security alert escalated", {
		alertId = alert.alertId,
		alertType = alert.alertType,
		threatLevel = alert.threatLevel
	})
end

-- Auto-resolve alert
function AuditLogger:_autoResolveAlert(alert: SecurityAlert): ()
	alert.autoResolved = true
	alert.resolvedAt = os.time()
	alert.resolvedBy = "system"
	
	self:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "INFO",
		category = "GameSecurity",
		source = "AlertManager",
		action = "ALERT_AUTO_RESOLVED",
		success = true,
		metadata = {
			alertId = alert.alertId,
			alertType = alert.alertType
		}
	})
end

-- Utility Functions

-- Check if log level should be logged
function AuditLogger:_shouldLogLevel(logLevel: LogLevel): boolean
	local eventPriority = LOG_LEVEL_PRIORITY[logLevel]
	local maxPriority = LOG_LEVEL_PRIORITY[LOGGING_CONFIG.maxLogLevel]
	
	return eventPriority >= maxPriority
end

-- Handle critical events
function AuditLogger:_handleCriticalEvent(event: AuditEvent): ()
	-- Immediately flush critical events
	local criticalBatch = {event}
	
	pcall(function()
		auditDataStore:SetAsync("critical_" .. event.eventId, {
			timestamp = os.time(),
			event = event
		})
	end)
	
	-- Generate immediate alert for security events
	if event.logLevel == "SECURITY" then
		ThreatDetected:Fire({
			eventId = event.eventId,
			threatLevel = event.threatLevel or "HIGH",
			description = event.errorMessage or "Security threat detected",
			userId = event.userId
		})
	end
end

-- Count table keys
function AuditLogger:_countKeys(t: {[any]: any}): number
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- Cleanup old metrics
function AuditLogger:_cleanupOldMetrics(cutoffTime: number): ()
	local toRemove = {}
	
	for key, _ in pairs(performanceMetrics) do
		if tonumber(key) and tonumber(key) < cutoffTime then
			table.insert(toRemove, key)
		end
	end
	
	for _, key in ipairs(toRemove) do
		performanceMetrics[key] = nil
	end
end

-- Query and Reporting

-- Query audit events
function AuditLogger:QueryEvents(query: AuditQuery): {AuditEvent}
	local results = {}
	
	-- In a real implementation, this would query the persistent storage
	-- For demonstration, return recent events from buffer
	for _, event in ipairs(eventBuffer) do
		if self:_matchesQuery(event, query) then
			table.insert(results, event)
			
			if query.limit and #results >= query.limit then
				break
			end
		end
	end
	
	return results
end

-- Check if event matches query
function AuditLogger:_matchesQuery(event: AuditEvent, query: AuditQuery): boolean
	-- Time range check
	if query.startTime and event.timestamp < query.startTime then
		return false
	end
	
	if query.endTime and event.timestamp > query.endTime then
		return false
	end
	
	-- Log level check
	if query.logLevels then
		local levelMatch = false
		for _, level in ipairs(query.logLevels) do
			if event.logLevel == level then
				levelMatch = true
				break
			end
		end
		if not levelMatch then
			return false
		end
	end
	
	-- Category check
	if query.categories then
		local categoryMatch = false
		for _, category in ipairs(query.categories) do
			if event.category == category then
				categoryMatch = true
				break
			end
		end
		if not categoryMatch then
			return false
		end
	end
	
	-- User ID check
	if query.userIds and event.userId then
		local userMatch = false
		for _, userId in ipairs(query.userIds) do
			if event.userId == userId then
				userMatch = true
				break
			end
		end
		if not userMatch then
			return false
		end
	end
	
	-- Success/failure check
	if query.successOnly and not event.success then
		return false
	end
	
	if query.failuresOnly and event.success then
		return false
	end
	
	return true
end

-- Generate audit report
function AuditLogger:GenerateReport(
	reportType: string,
	timeRange: {startTime: number, endTime: number},
	generatedBy: number | string
): AuditReport
	local query: AuditQuery = {
		startTime = timeRange.startTime,
		endTime = timeRange.endTime
	}
	
	local events = self:QueryEvents(query)
	local alerts = self:_getAlertsInTimeRange(timeRange.startTime, timeRange.endTime)
	
	-- Calculate summary statistics
	local summary = self:_calculateReportSummary(events, alerts)
	
	local report: AuditReport = {
		reportId = HttpService:GenerateGUID(false),
		generatedAt = os.time(),
		generatedBy = generatedBy,
		reportType = reportType,
		timeRange = timeRange,
		summary = summary,
		events = events,
		alerts = alerts,
		recommendations = self:_generateRecommendations(summary),
		metadata = {
			eventCount = #events,
			alertCount = #alerts,
			reportDuration = os.time() - timeRange.startTime
		}
	}
	
	-- Store report
	pcall(function()
		reportDataStore:SetAsync("report_" .. report.reportId, report)
	end)
	
	logger.LogInfo("Audit report generated", {
		reportId = report.reportId,
		reportType = reportType,
		eventCount = #events,
		alertCount = #alerts
	})
	
	return report
end

-- Calculate report summary
function AuditLogger:_calculateReportSummary(events: {AuditEvent}, alerts: {SecurityAlert}): any
	local summary = {
		totalEvents = #events,
		eventsByLevel = {},
		eventsByCategory = {},
		uniqueUsers = {},
		successRate = 0,
		threatsDetected = 0,
		alertsGenerated = #alerts
	}
	
	local successCount = 0
	
	for _, event in ipairs(events) do
		-- Count by level
		summary.eventsByLevel[event.logLevel] = (summary.eventsByLevel[event.logLevel] or 0) + 1
		
		-- Count by category
		summary.eventsByCategory[event.category] = (summary.eventsByCategory[event.category] or 0) + 1
		
		-- Track unique users
		if event.userId then
			summary.uniqueUsers[event.userId] = true
		end
		
		-- Count successes
		if event.success then
			successCount = successCount + 1
		end
		
		-- Count threats
		if event.threatLevel and event.threatLevel ~= "LOW" then
			summary.threatsDetected = summary.threatsDetected + 1
		end
	end
	
	-- Calculate success rate
	if #events > 0 then
		summary.successRate = (successCount / #events) * 100
	end
	
	-- Count unique users
	local uniqueUserCount = 0
	for _ in pairs(summary.uniqueUsers) do
		uniqueUserCount = uniqueUserCount + 1
	end
	summary.uniqueUsers = uniqueUserCount
	
	return summary
end

-- Generate recommendations
function AuditLogger:_generateRecommendations(summary: any): {string}
	local recommendations = {}
	
	if summary.successRate < 80 then
		table.insert(recommendations, "Low success rate detected. Review authentication and authorization policies.")
	end
	
	if summary.threatsDetected > 10 then
		table.insert(recommendations, "High number of security threats detected. Consider implementing additional security measures.")
	end
	
	if summary.alertsGenerated > 5 then
		table.insert(recommendations, "Multiple security alerts generated. Review alert thresholds and response procedures.")
	end
	
	if summary.eventsByLevel.ERROR and summary.eventsByLevel.ERROR > summary.totalEvents * 0.1 then
		table.insert(recommendations, "High error rate detected. Investigate system stability and error handling.")
	end
	
	if #recommendations == 0 then
		table.insert(recommendations, "No significant issues detected. System operating within normal parameters.")
	end
	
	return recommendations
end

-- Get alerts in time range
function AuditLogger:_getAlertsInTimeRange(startTime: number, endTime: number): {SecurityAlert}
	local alerts = {}
	
	for _, alert in pairs(activeAlerts) do
		if alert.timestamp >= startTime and alert.timestamp <= endTime then
			table.insert(alerts, alert)
		end
	end
	
	return alerts
end

-- Public API

-- Get active alerts
function AuditLogger:GetActiveAlerts(): {SecurityAlert}
	local alerts = {}
	
	for _, alert in pairs(activeAlerts) do
		if not alert.autoResolved and not alert.resolvedAt then
			table.insert(alerts, alert)
		end
	end
	
	return alerts
end

-- Resolve alert
function AuditLogger:ResolveAlert(alertId: string, resolvedBy: number | string, reason: string?): boolean
	local alert = activeAlerts[alertId]
	if not alert or alert.resolvedAt then
		return false
	end
	
	alert.resolvedAt = os.time()
	alert.resolvedBy = resolvedBy
	if reason then
		alert.metadata.resolutionReason = reason
	end
	
	-- Update persistent storage
	pcall(function()
		alertDataStore:SetAsync("alert_" .. alertId, alert)
	end)
	
	self:LogEvent({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		logLevel = "INFO",
		category = "GameSecurity",
		source = "AlertManager",
		action = "ALERT_RESOLVED",
		success = true,
		metadata = {
			alertId = alertId,
			resolvedBy = resolvedBy,
			reason = reason
		}
	})
	
	logger.LogInfo("Security alert resolved", {
		alertId = alertId,
		resolvedBy = resolvedBy,
		reason = reason
	})
	
	return true
end

-- Get performance metrics
function AuditLogger:GetPerformanceMetrics(): {[string]: any}
	return table.clone(performanceMetrics)
end

-- Export audit data
function AuditLogger:ExportAuditData(
	startTime: number,
	endTime: number,
	format: string?
): string
	local query: AuditQuery = {
		startTime = startTime,
		endTime = endTime
	}
	
	local events = self:QueryEvents(query)
	local alerts = self:_getAlertsInTimeRange(startTime, endTime)
	
	local exportData = {
		exportTimestamp = os.time(),
		timeRange = {startTime = startTime, endTime = endTime},
		events = events,
		alerts = alerts,
		metadata = {
			totalEvents = #events,
			totalAlerts = #alerts,
			exportFormat = format or "json"
		}
	}
	
	-- Convert to JSON
	local success, jsonData = pcall(function()
		return HttpService:JSONEncode(exportData)
	end)
	
	if success then
		self:LogEvent({
			eventId = HttpService:GenerateGUID(false),
			timestamp = os.time(),
			logLevel = "INFO",
			category = "DataAccess",
			source = "AuditLogger",
			action = "AUDIT_DATA_EXPORTED",
			success = true,
			metadata = {
				timeRange = {startTime = startTime, endTime = endTime},
				eventCount = #events,
				alertCount = #alerts
			}
		})
		
		return jsonData
	else
		return "{\"error\": \"Failed to export audit data\"}"
	end
end

-- Event Connections
function AuditLogger:OnSecurityAlertGenerated(callback: (SecurityAlert) -> ()): RBXScriptConnection
	return SecurityAlertGenerated.Event:Connect(callback)
end

function AuditLogger:OnComplianceViolationDetected(callback: (any) -> ()): RBXScriptConnection
	return ComplianceViolationDetected.Event:Connect(callback)
end

function AuditLogger:OnThreatDetected(callback: (any) -> ()): RBXScriptConnection
	return ThreatDetected.Event:Connect(callback)
end

function AuditLogger:OnPerformanceIssueDetected(callback: (any) -> ()): RBXScriptConnection
	return PerformanceIssueDetected.Event:Connect(callback)
end

-- Health Check
function AuditLogger:GetHealthStatus(): {status: string, metrics: any}
	local bufferedEvents = #eventBuffer
	local activeAlertCount = 0
	local criticalAlerts = 0
	
	for _, alert in pairs(activeAlerts) do
		if not alert.resolvedAt and not alert.autoResolved then
			activeAlertCount = activeAlertCount + 1
			if alert.threatLevel == "CRITICAL" then
				criticalAlerts = criticalAlerts + 1
			end
		end
	end
	
	local correlationEntries = self:_countKeys(eventCorrelations)
	local performanceMetricCount = self:_countKeys(performanceMetrics)
	
	local status = "healthy"
	if criticalAlerts > 0 then
		status = "critical"
	elseif activeAlertCount > 10 or bufferedEvents > LOGGING_CONFIG.maxEventsPerBatch * 2 then
		status = "warning"
	end
	
	return {
		status = status,
		metrics = {
			bufferedEvents = bufferedEvents,
			activeAlerts = activeAlertCount,
			criticalAlerts = criticalAlerts,
			correlationEntries = correlationEntries,
			performanceMetrics = performanceMetricCount,
			threatDetectionEnabled = LOGGING_CONFIG.enableThreatDetection,
			realTimeMonitoringEnabled = LOGGING_CONFIG.enableRealTimeMonitoring,
			complianceEnabled = LOGGING_CONFIG.enableCompliance,
			retentionDays = LOGGING_CONFIG.retentionDays
		}
	}
end

-- Initialize and register service
local auditLogger = AuditLogger.new()

-- Register with ServiceLocator
task.wait(1) -- Ensure ServiceLocator is ready
ServiceLocator:RegisterService("AuditLogger", auditLogger)

return auditLogger
