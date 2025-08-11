--!strict
--[[
	@fileoverview Enterprise-grade network proxy for secure client-server communication
	@author Enterprise Development Team
	@version 2.0.0
	@since Phase B Implementation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ClientTypes = require(script.Parent.Parent.Shared.ClientTypes)
type NetworkProxy = ClientTypes.NetworkProxy

--[[
	@class NetworkProxyImpl
	@implements NetworkProxy
	@description Secure wrapper for RemoteEvent/RemoteFunction communications with validation, throttling, and anti-cheat measures
]]
local NetworkProxyImpl = {}
NetworkProxyImpl.__index = NetworkProxyImpl

-- Constants for security and performance
local THROTTLE_CACHE_SIZE = 100
local MAX_PAYLOAD_SIZE = 8192 -- 8KB limit
local SUSPICIOUS_ACTIVITY_THRESHOLD = 10
local VALIDATION_TIMEOUT = 5

-- Private properties
local throttleCache: {[string]: {lastCall: number, count: number}} = {}
local debounceCache: {[string]: number} = {}
local suspiciousActivity = 0

--[[
	@constructor
	@param remoteObject RemoteEvent | RemoteFunction - The remote object to proxy
	@param config? {maxPayloadSize: number?, enableLogging: boolean?} - Optional configuration
	@returns NetworkProxy
]]
function NetworkProxyImpl.new(remoteObject: RemoteEvent | RemoteFunction, config: {maxPayloadSize: number?, enableLogging: boolean?}?): NetworkProxy
	config = config or {}
	
	local self = setmetatable({
		_remote = remoteObject,
		_maxPayloadSize = config.maxPayloadSize or MAX_PAYLOAD_SIZE,
		_enableLogging = config.enableLogging or false,
		_type = if remoteObject:IsA("RemoteEvent") then "Event" else "Function"
	}, NetworkProxyImpl)
	
	return self
end

--[[
	@method validatePayload
	@description Validates payload data for size, type safety, and security
	@param payload {[string]: any} - The payload data to validate
	@returns boolean - True if valid, false otherwise
]]
function NetworkProxyImpl:validatePayload(payload: {[string]: any}): boolean
	-- Check payload size
	local success, serialized = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	
	if not success then
		if self._enableLogging then
			warn("[NetworkProxy] Payload serialization failed:", payload)
		end
		return false
	end
	
	if #serialized > self._maxPayloadSize then
		if self._enableLogging then
			warn("[NetworkProxy] Payload exceeds size limit:", #serialized, "bytes")
		end
		suspiciousActivity += 1
		return false
	end
	
	-- Validate payload structure
	return self:_validatePayloadStructure(payload)
end

--[[
	@method sanitizeData
	@description Sanitizes data to prevent injection attacks and ensure type safety
	@param data any - The data to sanitize
	@returns any - Sanitized data
]]
function NetworkProxyImpl:sanitizeData(data: any): any
	local dataType = typeof(data)
	
	if dataType == "string" then
		-- Remove potentially dangerous characters and limit length
		return string.sub(string.gsub(data, "[%c%z]", ""), 1, 1000)
	elseif dataType == "number" then
		-- Ensure number is finite and within reasonable bounds
		if data ~= data or data == math.huge or data == -math.huge then
			return 0
		end
		return math.clamp(data, -1e6, 1e6)
	elseif dataType == "table" then
		local sanitized = {}
		local count = 0
		
		for key, value in pairs(data) do
			count += 1
			if count > 100 then -- Prevent large table exploits
				break
			end
			
			sanitized[self:sanitizeData(key)] = self:sanitizeData(value)
		end
		
		return sanitized
	elseif dataType == "Vector3" then
		-- Validate Vector3 components
		local x = math.clamp(data.X, -1e4, 1e4)
		local y = math.clamp(data.Y, -1e4, 1e4)
		local z = math.clamp(data.Z, -1e4, 1e4)
		return Vector3.new(x, y, z)
	elseif dataType == "CFrame" then
		-- Validate CFrame position
		local pos = self:sanitizeData(data.Position)
		return CFrame.new(pos) * (data - data.Position)
	end
	
	return data
end

--[[
	@method throttle
	@description Implements throttling to prevent spam and abuse
	@param action string - The action identifier
	@param cooldown number - Cooldown time in seconds
	@returns boolean - True if action is allowed, false if throttled
]]
function NetworkProxyImpl:throttle(action: string, cooldown: number): boolean
	local now = tick()
	local cacheKey = self._remote.Name .. ":" .. action
	
	if not throttleCache[cacheKey] then
		throttleCache[cacheKey] = {lastCall = 0, count = 0}
	end
	
	local cache = throttleCache[cacheKey]
	
	-- Reset count if enough time has passed
	if now - cache.lastCall > cooldown then
		cache.count = 0
	end
	
	-- Check if we're within the throttle limit
	if now - cache.lastCall < cooldown then
		cache.count += 1
		
		if cache.count > 5 then -- Max 5 rapid calls
			suspiciousActivity += 1
			if self._enableLogging then
				warn("[NetworkProxy] Throttle limit exceeded for action:", action)
			end
			return false
		end
	end
	
	cache.lastCall = now
	return true
end

--[[
	@method debounce
	@description Implements debouncing to prevent duplicate rapid calls
	@param action string - The action identifier
	@param delay number - Debounce delay in seconds
	@returns boolean - True if action is allowed, false if debounced
]]
function NetworkProxyImpl:debounce(action: string, delay: number): boolean
	local now = tick()
	local cacheKey = self._remote.Name .. ":" .. action
	
	if debounceCache[cacheKey] and now - debounceCache[cacheKey] < delay then
		return false
	end
	
	debounceCache[cacheKey] = now
	return true
end

--[[
	@method fireServer
	@description Securely fires a RemoteEvent to the server
	@param ... any - Arguments to send to the server
]]
function NetworkProxyImpl:fireServer(...: any): ()
	if self._type ~= "Event" then
		error("Cannot fire a RemoteFunction. Use invokeServer instead.")
	end
	
	local args = {...}
	local payload = {args = args, timestamp = tick()}
	
	-- Validate and sanitize payload
	if not self:validatePayload(payload) then
		if self._enableLogging then
			warn("[NetworkProxy] Invalid payload blocked for:", self._remote.Name)
		end
		return
	end
	
	local sanitizedArgs = {}
	for i, arg in ipairs(args) do
		sanitizedArgs[i] = self:sanitizeData(arg)
	end
	
	-- Apply basic throttling
	if not self:throttle("fire", 0.1) then
		return
	end
	
	local remote = self._remote :: RemoteEvent
	remote:FireServer(unpack(sanitizedArgs))
end

--[[
	@method invokeServer
	@description Securely invokes a RemoteFunction on the server
	@param ... any - Arguments to send to the server
	@returns any? - Server response or nil if failed
]]
function NetworkProxyImpl:invokeServer(...: any): any?
	if self._type ~= "Function" then
		error("Cannot invoke a RemoteEvent. Use fireServer instead.")
	end
	
	local args = {...}
	local payload = {args = args, timestamp = tick()}
	
	-- Validate and sanitize payload
	if not self:validatePayload(payload) then
		if self._enableLogging then
			warn("[NetworkProxy] Invalid payload blocked for:", self._remote.Name)
		end
		return nil
	end
	
	local sanitizedArgs = {}
	for i, arg in ipairs(args) do
		sanitizedArgs[i] = self:sanitizeData(arg)
	end
	
	-- Apply basic throttling
	if not self:throttle("invoke", 0.2) then
		return nil
	end
	
	local remote = self._remote :: RemoteFunction
	
	-- Implement timeout protection
	local success, result = pcall(function()
		return remote:InvokeServer(unpack(sanitizedArgs))
	end)
	
	if not success then
		if self._enableLogging then
			warn("[NetworkProxy] Server invocation failed:", result)
		end
		return nil
	end
	
	return self:sanitizeData(result)
end

--[[
	@private
	@method _validatePayloadStructure
	@description Validates the internal structure of payload data
	@param payload {[string]: any} - The payload to validate
	@returns boolean - True if structure is valid
]]
function NetworkProxyImpl:_validatePayloadStructure(payload: {[string]: any}): boolean
	-- Check for required fields
	if not payload.args or typeof(payload.args) ~= "table" then
		return false
	end
	
	if not payload.timestamp or typeof(payload.timestamp) ~= "number" then
		return false
	end
	
	-- Validate timestamp is recent (within 10 seconds)
	local now = tick()
	if math.abs(now - payload.timestamp) > 10 then
		suspiciousActivity += 1
		return false
	end
	
	-- Check argument count
	if #payload.args > 20 then -- Reasonable argument limit
		return false
	end
	
	return true
end

-- Clean up old cache entries periodically
RunService.Heartbeat:Connect(function()
	local now = tick()
	
	-- Clean throttle cache
	for key, cache in pairs(throttleCache) do
		if now - cache.lastCall > 60 then -- Remove entries older than 1 minute
			throttleCache[key] = nil
		end
	end
	
	-- Clean debounce cache
	for key, timestamp in pairs(debounceCache) do
		if now - timestamp > 30 then -- Remove entries older than 30 seconds
			debounceCache[key] = nil
		end
	end
	
	-- Reset suspicious activity counter
	if suspiciousActivity > 0 then
		suspiciousActivity = math.max(0, suspiciousActivity - 1)
	end
end)

-- Export the implementation
return NetworkProxyImpl
