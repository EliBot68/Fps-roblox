--[[
	RateLimiter.lua
	Enterprise-grade token bucket rate limiting system
	
	Usage:
		local limiter = RateLimiter.new(maxTokens, refillPerSecond)
		if RateLimiter.consume(limiter, cost) then
			-- Allow action
		else
			-- Rate limited, reject
		end
]]

local RateLimiter = {}

-- Type definitions for better code quality
export type TokenBucket = {
	tokens: number,
	maxTokens: number,
	refillRate: number,
	lastRefill: number,
	violations: number,
	firstViolation: number?
}

-- Configuration constants
local VIOLATION_RESET_TIME = 60 -- Reset violation count after 60 seconds
local MAX_VIOLATIONS_BEFORE_MUTE = 5
local MUTE_DURATION = 300 -- 5 minutes

-- Create a new token bucket rate limiter
function RateLimiter.new(maxTokens: number, refillPerSecond: number): TokenBucket
	return {
		tokens = maxTokens,
		maxTokens = maxTokens,
		refillRate = refillPerSecond,
		lastRefill = os.clock(),
		violations = 0,
		firstViolation = nil
	}
end

-- Attempt to consume tokens from the bucket
function RateLimiter.consume(bucket: TokenBucket, cost: number?): boolean
	cost = cost or 1
	local now = os.clock()
	
	-- Refill tokens based on elapsed time
	local elapsed = now - bucket.lastRefill
	bucket.lastRefill = now
	bucket.tokens = math.min(bucket.maxTokens, bucket.tokens + elapsed * bucket.refillRate)
	
	-- Reset violation count if enough time has passed
	if bucket.firstViolation and (now - bucket.firstViolation) > VIOLATION_RESET_TIME then
		bucket.violations = 0
		bucket.firstViolation = nil
	end
	
	-- Check if we have enough tokens
	if bucket.tokens >= cost then
		bucket.tokens = bucket.tokens - cost
		return true
	else
		-- Track violation
		bucket.violations = bucket.violations + 1
		if not bucket.firstViolation then
			bucket.firstViolation = now
		end
		return false
	end
end

-- Check if bucket is currently muted due to excessive violations
function RateLimiter.isMuted(bucket: TokenBucket): boolean
	if bucket.violations >= MAX_VIOLATIONS_BEFORE_MUTE then
		local timeSinceFirstViolation = os.clock() - (bucket.firstViolation or 0)
		return timeSinceFirstViolation < MUTE_DURATION
	end
	return false
end

-- Get current bucket status for monitoring
function RateLimiter.getStatus(bucket: TokenBucket): {tokens: number, violations: number, isMuted: boolean}
	return {
		tokens = math.floor(bucket.tokens * 100) / 100, -- Round to 2 decimals
		violations = bucket.violations,
		isMuted = RateLimiter.isMuted(bucket)
	}
end

-- Reset a bucket (useful for testing or admin commands)
function RateLimiter.reset(bucket: TokenBucket): ()
	bucket.tokens = bucket.maxTokens
	bucket.violations = 0
	bucket.firstViolation = nil
	bucket.lastRefill = os.clock()
end

return RateLimiter
