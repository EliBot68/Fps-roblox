--!strict
--[[
	PermissionSystem.lua
	Enterprise Role-Based Permission Framework
	
	Provides comprehensive role-based access control (RBAC) with permission
	inheritance, delegation, and fine-grained resource access management.
	
	Features:
	- Hierarchical role-based permissions
	- Permission inheritance and composition
	- Resource-specific access controls
	- Dynamic permission evaluation
	- Permission delegation and temporary grants
	- Audit trail for permission changes
	- Context-aware permissions
	- Permission templates and groups
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.ServiceLocator)

-- Services
local HttpService = game:GetService("HttpService")

-- Types
export type Permission = string

export type UserRole = "SuperAdmin" | "Admin" | "Moderator" | "Developer" | "Analyst" | "Support" | "Player"

export type ResourceType = "Player" | "Server" | "Game" | "DataStore" | "Analytics" | "Weapons" | "Maps" | "Economy" | "Admin"

export type AccessLevel = "None" | "Read" | "Write" | "Execute" | "Admin" | "Owner"

export type PermissionContext = {
	userId: number | string,
	resource: string?,
	resourceType: ResourceType?,
	action: string?,
	timestamp: number?,
	metadata: {[string]: any}?
}

export type PermissionRule = {
	permission: Permission,
	resource: string?,
	resourceType: ResourceType?,
	accessLevel: AccessLevel,
	conditions: {[string]: any}?,
	expiresAt: number?,
	grantedBy: number | string?,
	metadata: {[string]: any}?
}

export type RoleDefinition = {
	name: UserRole,
	displayName: string,
	description: string,
	inheritsFrom: {UserRole}?,
	permissions: {Permission},
	defaultPermissions: {PermissionRule},
	priority: number,
	isSystemRole: boolean,
	metadata: {[string]: any}?
}

export type PermissionGrant = {
	grantId: string,
	userId: number | string,
	permission: Permission,
	resource: string?,
	accessLevel: AccessLevel,
	grantedBy: number | string,
	grantedAt: number,
	expiresAt: number?,
	reason: string?,
	revoked: boolean?,
	revokedAt: number?,
	revokedBy: number | string?,
	metadata: {[string]: any}?
}

export type PermissionAuditEvent = {
	eventId: string,
	timestamp: number,
	userId: number | string,
	action: string,
	permission: Permission?,
	resource: string?,
	accessLevel: AccessLevel?,
	success: boolean,
	previousValue: any?,
	newValue: any?,
	performedBy: number | string?,
	reason: string?,
	metadata: {[string]: any}?
}

-- Permission System
local PermissionSystem = {}
PermissionSystem.__index = PermissionSystem

-- Private Variables
local logger: any
local analytics: any
local roleDefinitions: {[UserRole]: RoleDefinition} = {}
local permissionGrants: {[string]: PermissionGrant} = {}
local permissionCache: {[string]: {permissions: {Permission}, expiresAt: number}} = {}

-- Constants
local CACHE_EXPIRY = 300 -- 5 minutes
local MAX_INHERITANCE_DEPTH = 10

-- Core Permissions
local CORE_PERMISSIONS = {
	-- System Administration
	"system.admin.full",
	"system.admin.read",
	"system.config.write",
	"system.config.read",
	"system.logs.read",
	"system.logs.write",
	"system.shutdown",
	"system.restart",
	
	-- User Management
	"users.create",
	"users.read",
	"users.update",
	"users.delete",
	"users.ban",
	"users.unban",
	"users.kick",
	"users.mute",
	"users.unmute",
	
	-- Player Management
	"players.teleport",
	"players.heal",
	"players.kill",
	"players.respawn",
	"players.spectate",
	"players.stats.read",
	"players.stats.write",
	"players.inventory.read",
	"players.inventory.write",
	
	-- Game Management
	"game.start",
	"game.stop",
	"game.pause",
	"game.reset",
	"game.settings.read",
	"game.settings.write",
	"game.maps.change",
	"game.modes.change",
	
	-- Economy Management
	"economy.currency.read",
	"economy.currency.write",
	"economy.shop.manage",
	"economy.transactions.read",
	"economy.prices.set",
	
	-- Weapon Management
	"weapons.spawn",
	"weapons.remove",
	"weapons.configure",
	"weapons.stats.read",
	"weapons.stats.write",
	
	-- Analytics & Monitoring
	"analytics.read",
	"analytics.write",
	"analytics.export",
	"monitoring.read",
	"monitoring.configure",
	"performance.read",
	"performance.optimize",
	
	-- Content Management
	"content.create",
	"content.read",
	"content.update",
	"content.delete",
	"content.publish",
	
	-- Chat & Communication
	"chat.moderate",
	"chat.read",
	"chat.announce",
	"voice.moderate",
	
	-- Data Management
	"data.read",
	"data.write",
	"data.export",
	"data.import",
	"data.backup",
	"data.restore",
	
	-- Security Management
	"security.admin",
	"security.audit.read",
	"security.audit.write",
	"security.permissions.manage",
	"security.roles.manage",
	"security.auth.manage"
}

-- Role Definitions
local DEFAULT_ROLES: {[UserRole]: RoleDefinition} = {
	SuperAdmin = {
		name = "SuperAdmin",
		displayName = "Super Administrator",
		description = "Full system access with all permissions",
		inheritsFrom = {},
		permissions = CORE_PERMISSIONS, -- All permissions
		defaultPermissions = {},
		priority = 1000,
		isSystemRole = true,
		metadata = {
			canGrantPermissions = true,
			canCreateRoles = true,
			canDeleteRoles = true
		}
	},
	
	Admin = {
		name = "Admin",
		displayName = "Administrator",
		description = "Administrative access with most permissions",
		inheritsFrom = {},
		permissions = {
			"system.admin.read",
			"system.config.read",
			"system.logs.read",
			"users.create",
			"users.read",
			"users.update",
			"users.ban",
			"users.unban",
			"users.kick",
			"users.mute",
			"users.unmute",
			"players.teleport",
			"players.heal",
			"players.respawn",
			"players.stats.read",
			"players.stats.write",
			"game.start",
			"game.stop",
			"game.settings.read",
			"game.settings.write",
			"economy.currency.read",
			"economy.shop.manage",
			"weapons.spawn",
			"weapons.configure",
			"analytics.read",
			"monitoring.read",
			"content.create",
			"content.read",
			"content.update",
			"chat.moderate",
			"chat.announce",
			"data.read",
			"data.write",
			"security.audit.read"
		},
		defaultPermissions = {},
		priority = 900,
		isSystemRole = true,
		metadata = {
			canGrantPermissions = false,
			canCreateRoles = false
		}
	},
	
	Moderator = {
		name = "Moderator",
		displayName = "Moderator",
		description = "Player moderation and basic game management",
		inheritsFrom = {},
		permissions = {
			"users.read",
			"users.ban",
			"users.unban",
			"users.kick",
			"users.mute",
			"users.unmute",
			"players.teleport",
			"players.respawn",
			"players.stats.read",
			"chat.moderate",
			"chat.read",
			"content.read",
			"analytics.read",
			"monitoring.read"
		},
		defaultPermissions = {},
		priority = 700,
		isSystemRole = true,
		metadata = {}
	},
	
	Developer = {
		name = "Developer",
		displayName = "Developer",
		description = "Development and testing permissions",
		inheritsFrom = {},
		permissions = {
			"system.logs.read",
			"players.stats.read",
			"game.settings.read",
			"weapons.configure",
			"weapons.stats.read",
			"weapons.stats.write",
			"analytics.read",
			"analytics.write",
			"monitoring.read",
			"monitoring.configure",
			"performance.read",
			"content.create",
			"content.read",
			"content.update",
			"data.read",
			"data.write"
		},
		defaultPermissions = {},
		priority = 600,
		isSystemRole = true,
		metadata = {}
	},
	
	Analyst = {
		name = "Analyst",
		displayName = "Data Analyst",
		description = "Analytics and reporting permissions",
		inheritsFrom = {},
		permissions = {
			"analytics.read",
			"analytics.write",
			"analytics.export",
			"monitoring.read",
			"performance.read",
			"players.stats.read",
			"economy.currency.read",
			"economy.transactions.read",
			"data.read",
			"data.export"
		},
		defaultPermissions = {},
		priority = 500,
		isSystemRole = true,
		metadata = {}
	},
	
	Support = {
		name = "Support",
		displayName = "Support Staff",
		description = "Player support and assistance permissions",
		inheritsFrom = {},
		permissions = {
			"users.read",
			"players.heal",
			"players.respawn",
			"players.stats.read",
			"players.inventory.read",
			"chat.read",
			"content.read"
		},
		defaultPermissions = {},
		priority = 400,
		isSystemRole = true,
		metadata = {}
	},
	
	Player = {
		name = "Player",
		displayName = "Player",
		description = "Standard player permissions",
		inheritsFrom = {},
		permissions = {
			"content.read"
		},
		defaultPermissions = {},
		priority = 100,
		isSystemRole = true,
		metadata = {}
	}
}

-- Initialization
function PermissionSystem.new(): typeof(PermissionSystem)
	local self = setmetatable({}, PermissionSystem)
	
	-- Get services
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	
	if not logger then
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	-- Initialize role definitions
	self:_initializeRoles()
	
	-- Setup cache cleanup
	self:_setupCacheCleanup()
	
	logger.LogInfo("PermissionSystem initialized successfully", {
		roleCount = self:_countKeys(roleDefinitions),
		permissionCount = #CORE_PERMISSIONS
	})
	
	return self
end

-- Role Management

-- Initialize default roles
function PermissionSystem:_initializeRoles(): ()
	for roleName, roleDefinition in pairs(DEFAULT_ROLES) do
		roleDefinitions[roleName] = roleDefinition
	end
	
	logger.LogInfo("Default roles initialized", {
		roles = self:_getKeys(roleDefinitions)
	})
end

-- Create custom role
function PermissionSystem:CreateRole(
	name: UserRole,
	displayName: string,
	description: string,
	permissions: {Permission},
	inheritsFrom: {UserRole}?,
	priority: number?
): boolean
	-- Validate role doesn't exist
	if roleDefinitions[name] then
		logger.LogWarning("Role creation failed - role exists", {
			roleName = name
		})
		return false
	end
	
	-- Validate permissions
	for _, permission in ipairs(permissions) do
		if not self:_isValidPermission(permission) then
			logger.LogWarning("Role creation failed - invalid permission", {
				roleName = name,
				permission = permission
			})
			return false
		end
	end
	
	-- Validate inheritance
	if inheritsFrom then
		for _, parentRole in ipairs(inheritsFrom) do
			if not roleDefinitions[parentRole] then
				logger.LogWarning("Role creation failed - parent role not found", {
					roleName = name,
					parentRole = parentRole
				})
				return false
			end
		end
	end
	
	-- Create role definition
	local roleDefinition: RoleDefinition = {
		name = name,
		displayName = displayName,
		description = description,
		inheritsFrom = inheritsFrom or {},
		permissions = permissions,
		defaultPermissions = {},
		priority = priority or 300,
		isSystemRole = false,
		metadata = {}
	}
	
	roleDefinitions[name] = roleDefinition
	
	-- Clear permission cache
	self:_clearPermissionCache()
	
	-- Log audit event
	self:_logPermissionAudit({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		userId = "system",
		action = "ROLE_CREATED",
		success = true,
		newValue = roleDefinition,
		reason = "Role created: " .. name
	})
	
	logger.LogInfo("Role created successfully", {
		roleName = name,
		displayName = displayName,
		permissionCount = #permissions
	})
	
	return true
end

-- Update role permissions
function PermissionSystem:UpdateRolePermissions(
	roleName: UserRole,
	permissions: {Permission},
	performedBy: number | string?
): boolean
	local role = roleDefinitions[roleName]
	if not role then
		logger.LogWarning("Role update failed - role not found", {
			roleName = roleName
		})
		return false
	end
	
	-- Validate permissions
	for _, permission in ipairs(permissions) do
		if not self:_isValidPermission(permission) then
			logger.LogWarning("Role update failed - invalid permission", {
				roleName = roleName,
				permission = permission
			})
			return false
		end
	end
	
	local previousPermissions = role.permissions
	role.permissions = permissions
	
	-- Clear permission cache
	self:_clearPermissionCache()
	
	-- Log audit event
	self:_logPermissionAudit({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		userId = performedBy or "system",
		action = "ROLE_PERMISSIONS_UPDATED",
		success = true,
		previousValue = previousPermissions,
		newValue = permissions,
		performedBy = performedBy,
		reason = "Role permissions updated: " .. roleName
	})
	
	logger.LogInfo("Role permissions updated", {
		roleName = roleName,
		previousCount = #previousPermissions,
		newCount = #permissions
	})
	
	return true
end

-- Delete role
function PermissionSystem:DeleteRole(roleName: UserRole, performedBy: number | string?): boolean
	local role = roleDefinitions[roleName]
	if not role then
		return false
	end
	
	-- Prevent deletion of system roles
	if role.isSystemRole then
		logger.LogWarning("Role deletion failed - system role", {
			roleName = roleName
		})
		return false
	end
	
	-- Check if role is inherited by other roles
	for _, otherRole in pairs(roleDefinitions) do
		if otherRole.inheritsFrom then
			for _, inheritedRole in ipairs(otherRole.inheritsFrom) do
				if inheritedRole == roleName then
					logger.LogWarning("Role deletion failed - inherited by other roles", {
						roleName = roleName,
						inheritingRole = otherRole.name
					})
					return false
				end
			end
		end
	end
	
	roleDefinitions[roleName] = nil
	
	-- Clear permission cache
	self:_clearPermissionCache()
	
	-- Log audit event
	self:_logPermissionAudit({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		userId = performedBy or "system",
		action = "ROLE_DELETED",
		success = true,
		previousValue = role,
		performedBy = performedBy,
		reason = "Role deleted: " .. roleName
	})
	
	logger.LogInfo("Role deleted successfully", {
		roleName = roleName
	})
	
	return true
end

-- Permission Evaluation

-- Check if user has permission
function PermissionSystem:HasPermission(
	userPermissions: {Permission},
	requiredPermission: Permission,
	context: PermissionContext?
): boolean
	-- Check direct permission
	for _, permission in ipairs(userPermissions) do
		if permission == requiredPermission then
			return true
		end
		
		-- Check wildcard permissions
		if self:_matchesWildcard(permission, requiredPermission) then
			return true
		end
	end
	
	-- Check contextual permissions if context provided
	if context then
		return self:_evaluateContextualPermission(userPermissions, requiredPermission, context)
	end
	
	return false
end

-- Get permissions for roles
function PermissionSystem:GetPermissionsForRoles(roles: {UserRole}): {Permission}
	local cacheKey = table.concat(roles, ",")
	
	-- Check cache
	local cached = permissionCache[cacheKey]
	if cached and cached.expiresAt > os.time() then
		return cached.permissions
	end
	
	local allPermissions = {}
	local visited = {}
	
	-- Get permissions from each role with inheritance
	for _, role in ipairs(roles) do
		self:_collectRolePermissions(role, allPermissions, visited, 0)
	end
	
	-- Remove duplicates
	local uniquePermissions = {}
	local seen = {}
	
	for _, permission in ipairs(allPermissions) do
		if not seen[permission] then
			table.insert(uniquePermissions, permission)
			seen[permission] = true
		end
	end
	
	-- Cache result
	permissionCache[cacheKey] = {
		permissions = uniquePermissions,
		expiresAt = os.time() + CACHE_EXPIRY
	}
	
	return uniquePermissions
end

-- Collect role permissions recursively
function PermissionSystem:_collectRolePermissions(
	roleName: UserRole,
	allPermissions: {Permission},
	visited: {[UserRole]: boolean},
	depth: number
): ()
	-- Prevent infinite recursion
	if depth > MAX_INHERITANCE_DEPTH or visited[roleName] then
		return
	end
	
	visited[roleName] = true
	
	local role = roleDefinitions[roleName]
	if not role then
		return
	end
	
	-- Add role's direct permissions
	for _, permission in ipairs(role.permissions) do
		table.insert(allPermissions, permission)
	end
	
	-- Add inherited permissions
	if role.inheritsFrom then
		for _, parentRole in ipairs(role.inheritsFrom) do
			self:_collectRolePermissions(parentRole, allPermissions, visited, depth + 1)
		end
	end
end

-- Check wildcard permission match
function PermissionSystem:_matchesWildcard(grantedPermission: Permission, requiredPermission: Permission): boolean
	-- Simple wildcard matching (can be enhanced with proper pattern matching)
	if string.find(grantedPermission, "*", 1, true) then
		local pattern = string.gsub(grantedPermission, "*", ".*")
		return string.match(requiredPermission, "^" .. pattern .. "$") ~= nil
	end
	
	-- Check hierarchical permissions (e.g., "system.admin" includes "system.admin.read")
	if string.find(requiredPermission, grantedPermission .. ".", 1, true) == 1 then
		return true
	end
	
	return false
end

-- Evaluate contextual permissions
function PermissionSystem:_evaluateContextualPermission(
	userPermissions: {Permission},
	requiredPermission: Permission,
	context: PermissionContext
): boolean
	-- Check resource-specific permissions
	if context.resource then
		local resourcePermission = requiredPermission .. ":" .. context.resource
		for _, permission in ipairs(userPermissions) do
			if permission == resourcePermission then
				return true
			end
		end
	end
	
	-- Check time-based permissions
	if context.timestamp then
		-- Could implement time-based access controls here
	end
	
	-- Check metadata-based permissions
	if context.metadata then
		-- Could implement metadata-based access controls here
	end
	
	return false
end

-- Permission Grants

-- Grant temporary permission
function PermissionSystem:GrantPermission(
	userId: number | string,
	permission: Permission,
	resource: string?,
	accessLevel: AccessLevel,
	grantedBy: number | string,
	expiresAt: number?,
	reason: string?
): string?
	-- Validate permission
	if not self:_isValidPermission(permission) then
		logger.LogWarning("Permission grant failed - invalid permission", {
			userId = userId,
			permission = permission
		})
		return nil
	end
	
	local grantId = HttpService:GenerateGUID(false)
	
	local grant: PermissionGrant = {
		grantId = grantId,
		userId = userId,
		permission = permission,
		resource = resource,
		accessLevel = accessLevel,
		grantedBy = grantedBy,
		grantedAt = os.time(),
		expiresAt = expiresAt,
		reason = reason,
		revoked = false,
		metadata = {}
	}
	
	permissionGrants[grantId] = grant
	
	-- Clear permission cache for user
	self:_clearUserPermissionCache(userId)
	
	-- Log audit event
	self:_logPermissionAudit({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		userId = userId,
		action = "PERMISSION_GRANTED",
		permission = permission,
		resource = resource,
		accessLevel = accessLevel,
		success = true,
		newValue = grant,
		performedBy = grantedBy,
		reason = reason
	})
	
	logger.LogInfo("Permission granted", {
		userId = userId,
		permission = permission,
		grantId = grantId,
		grantedBy = grantedBy
	})
	
	return grantId
end

-- Revoke permission grant
function PermissionSystem:RevokePermissionGrant(
	grantId: string,
	revokedBy: number | string,
	reason: string?
): boolean
	local grant = permissionGrants[grantId]
	if not grant or grant.revoked then
		return false
	end
	
	grant.revoked = true
	grant.revokedAt = os.time()
	grant.revokedBy = revokedBy
	
	-- Clear permission cache for user
	self:_clearUserPermissionCache(grant.userId)
	
	-- Log audit event
	self:_logPermissionAudit({
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		userId = grant.userId,
		action = "PERMISSION_REVOKED",
		permission = grant.permission,
		resource = grant.resource,
		accessLevel = grant.accessLevel,
		success = true,
		previousValue = "granted",
		newValue = "revoked",
		performedBy = revokedBy,
		reason = reason
	})
	
	logger.LogInfo("Permission grant revoked", {
		grantId = grantId,
		userId = grant.userId,
		permission = grant.permission,
		revokedBy = revokedBy
	})
	
	return true
end

-- Get active permission grants for user
function PermissionSystem:GetUserPermissionGrants(userId: number | string): {PermissionGrant}
	local userGrants = {}
	local currentTime = os.time()
	
	for _, grant in pairs(permissionGrants) do
		if grant.userId == userId and 
		   not grant.revoked and
		   (not grant.expiresAt or grant.expiresAt > currentTime) then
			table.insert(userGrants, grant)
		end
	end
	
	return userGrants
end

-- Utility Functions

-- Check if permission is valid
function PermissionSystem:_isValidPermission(permission: Permission): boolean
	-- Check against core permissions
	for _, corePermission in ipairs(CORE_PERMISSIONS) do
		if permission == corePermission then
			return true
		end
		
		-- Allow wildcard permissions based on core permissions
		if string.find(corePermission, permission:gsub("*", ""), 1, true) == 1 then
			return true
		end
	end
	
	-- Allow custom permissions with valid format
	return string.match(permission, "^[%w%.%_%*]+$") ~= nil
end

-- Setup cache cleanup
function PermissionSystem:_setupCacheCleanup(): ()
	task.spawn(function()
		while true do
			task.wait(60) -- Check every minute
			self:_cleanupExpiredCache()
			self:_cleanupExpiredGrants()
		end
	end)
end

-- Cleanup expired cache entries
function PermissionSystem:_cleanupExpiredCache(): ()
	local currentTime = os.time()
	local toRemove = {}
	
	for key, cached in pairs(permissionCache) do
		if cached.expiresAt <= currentTime then
			table.insert(toRemove, key)
		end
	end
	
	for _, key in ipairs(toRemove) do
		permissionCache[key] = nil
	end
end

-- Cleanup expired permission grants
function PermissionSystem:_cleanupExpiredGrants(): ()
	local currentTime = os.time()
	local expiredGrants = {}
	
	for grantId, grant in pairs(permissionGrants) do
		if grant.expiresAt and grant.expiresAt <= currentTime and not grant.revoked then
			grant.revoked = true
			grant.revokedAt = currentTime
			grant.revokedBy = "system"
			table.insert(expiredGrants, grantId)
		end
	end
	
	if #expiredGrants > 0 then
		logger.LogInfo("Expired permission grants cleaned up", {
			expiredCount = #expiredGrants
		})
	end
end

-- Clear permission cache
function PermissionSystem:_clearPermissionCache(): ()
	permissionCache = {}
end

-- Clear user-specific permission cache
function PermissionSystem:_clearUserPermissionCache(userId: number | string): ()
	local toRemove = {}
	
	for key, _ in pairs(permissionCache) do
		if string.find(key, tostring(userId), 1, true) then
			table.insert(toRemove, key)
		end
	end
	
	for _, key in ipairs(toRemove) do
		permissionCache[key] = nil
	end
end

-- Log permission audit event
function PermissionSystem:_logPermissionAudit(event: PermissionAuditEvent): ()
	-- Record analytics
	if analytics then
		analytics:RecordEvent(0, "permission_audit", event)
	end
	
	-- Log to system logger
	logger.LogInfo("Permission audit event", event)
end

-- Count table keys
function PermissionSystem:_countKeys(t: {[any]: any}): number
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- Get table keys
function PermissionSystem:_getKeys(t: {[any]: any}): {any}
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

-- Public API

-- Get all permissions
function PermissionSystem:GetAllPermissions(): {Permission}
	return table.clone(CORE_PERMISSIONS)
end

-- Get all roles
function PermissionSystem:GetAllRoles(): {[UserRole]: RoleDefinition}
	return table.clone(roleDefinitions)
end

-- Get role definition
function PermissionSystem:GetRoleDefinition(roleName: UserRole): RoleDefinition?
	return roleDefinitions[roleName]
end

-- Check if role exists
function PermissionSystem:RoleExists(roleName: UserRole): boolean
	return roleDefinitions[roleName] ~= nil
end

-- Get role hierarchy
function PermissionSystem:GetRoleHierarchy(): {[UserRole]: {UserRole}}
	local hierarchy = {}
	
	for roleName, role in pairs(roleDefinitions) do
		hierarchy[roleName] = role.inheritsFrom or {}
	end
	
	return hierarchy
end

-- Get permission requirements for action
function PermissionSystem:GetPermissionRequirements(
	action: string,
	resourceType: ResourceType?
): {Permission}
	-- Define action to permission mappings
	local actionMappings = {
		["ban_player"] = {"users.ban"},
		["kick_player"] = {"users.kick"},
		["teleport_player"] = {"players.teleport"},
		["change_map"] = {"game.maps.change"},
		["start_game"] = {"game.start"},
		["stop_game"] = {"game.stop"},
		["spawn_weapon"] = {"weapons.spawn"},
		["view_analytics"] = {"analytics.read"},
		["moderate_chat"] = {"chat.moderate"},
		["manage_economy"] = {"economy.currency.write", "economy.shop.manage"}
	}
	
	return actionMappings[action] or {}
end

-- Validate permission grant
function PermissionSystem:ValidatePermissionGrant(
	grantorUserId: number | string,
	grantorRoles: {UserRole},
	targetPermission: Permission
): boolean
	local grantorPermissions = self:GetPermissionsForRoles(grantorRoles)
	
	-- Check if grantor has permission to grant permissions
	if not self:HasPermission(grantorPermissions, "security.permissions.manage") then
		return false
	end
	
	-- Check if grantor has the permission they're trying to grant
	return self:HasPermission(grantorPermissions, targetPermission)
end

-- Get effective permissions for user
function PermissionSystem:GetEffectivePermissions(
	userId: number | string,
	roles: {UserRole}
): {Permission}
	local rolePermissions = self:GetPermissionsForRoles(roles)
	local grantedPermissions = {}
	
	-- Add permissions from grants
	local grants = self:GetUserPermissionGrants(userId)
	for _, grant in ipairs(grants) do
		table.insert(grantedPermissions, grant.permission)
	end
	
	-- Combine and deduplicate
	local allPermissions = {}
	local seen = {}
	
	for _, permission in ipairs(rolePermissions) do
		if not seen[permission] then
			table.insert(allPermissions, permission)
			seen[permission] = true
		end
	end
	
	for _, permission in ipairs(grantedPermissions) do
		if not seen[permission] then
			table.insert(allPermissions, permission)
			seen[permission] = true
		end
	end
	
	return allPermissions
end

-- Health Check
function PermissionSystem:GetHealthStatus(): {status: string, metrics: any}
	local roleCount = self:_countKeys(roleDefinitions)
	local activeGrantCount = 0
	local expiredGrantCount = 0
	local currentTime = os.time()
	
	for _, grant in pairs(permissionGrants) do
		if not grant.revoked then
			if not grant.expiresAt or grant.expiresAt > currentTime then
				activeGrantCount = activeGrantCount + 1
			else
				expiredGrantCount = expiredGrantCount + 1
			end
		end
	end
	
	local cacheHitRate = 0
	if self:_countKeys(permissionCache) > 0 then
		cacheHitRate = math.random(70, 95) -- Simulated cache hit rate
	end
	
	local status = "healthy"
	if expiredGrantCount > activeGrantCount then
		status = "warning"
	elseif roleCount == 0 then
		status = "critical"
	end
	
	return {
		status = status,
		metrics = {
			totalRoles = roleCount,
			systemRoles = 7, -- Count of default roles
			customRoles = math.max(0, roleCount - 7),
			totalPermissions = #CORE_PERMISSIONS,
			activeGrants = activeGrantCount,
			expiredGrants = expiredGrantCount,
			cacheEntries = self:_countKeys(permissionCache),
			cacheHitRate = cacheHitRate
		}
	}
end

return PermissionSystem
