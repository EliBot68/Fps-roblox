-- RateLimiter.server.lua
-- Token bucket rate limiting for RemoteEvents

local RateLimiter = {}
local buckets = {}

local DEFAULT_BUCKET_SIZE = 20
local DEFAULT_REFILL_RATE = 5 -- tokens per second

local function getBucket(player, eventName)
	if not buckets[player] then buckets[player] = {} end
	if not buckets[player][eventName] then
		buckets[player][eventName] = {
			tokens = DEFAULT_BUCKET_SIZE,
			lastRefill = os.clock(),
			size = DEFAULT_BUCKET_SIZE,
			rate = DEFAULT_REFILL_RATE
		}
	end
	return buckets[player][eventName]
end

function RateLimiter.Consume(player, eventName, cost)
	cost = cost or 1
	local bucket = getBucket(player, eventName)
	local now = os.clock()
	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(bucket.size, bucket.tokens + elapsed * bucket.rate)
	bucket.lastRefill = now
	
	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end
	return false
end

function RateLimiter.SetLimits(player, eventName, bucketSize, refillRate)
	local bucket = getBucket(player, eventName)
	bucket.size = bucketSize
	bucket.rate = refillRate
end

return RateLimiter
