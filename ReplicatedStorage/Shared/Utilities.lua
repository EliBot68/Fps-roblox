-- Utilities.lua
-- Enterprise utility functions for high-performance FPS game

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Utilities = {}

-- Mathematical utilities
function Utilities.DegreesToVector3(degX, degY)
	local rx = math.rad(degX)
	local ry = math.rad(degY)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	-- Simplified forward vector from Euler
	return Vector3.new(sy * cx, -sx, cy * cx).Unit
end

function Utilities.ApplySpread(direction, spreadDegrees)
	local rand = Random.new()
	local yawOffset = (rand:NextNumber() - 0.5) * spreadDegrees
	local pitchOffset = (rand:NextNumber() - 0.5) * spreadDegrees
	local dir = Utilities.DegreesToVector3(pitchOffset, yawOffset)
	-- Blend with original
	local blended = (direction + dir * 0.15).Unit
	return blended
end

function Utilities.Clamp(num, min, max)
	if num < min then return min end
	if num > max then return max end
	return num
end

function Utilities.Lerp(a, b, t)
	return a + (b - a) * Utilities.Clamp(t, 0, 1)
end

function Utilities.Round(num, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- Data structure utilities
function Utilities.DeepCopy(tbl)
	if type(tbl) ~= 'table' then return tbl end
	local t = {}
	for k,v in pairs(tbl) do
		t[k] = Utilities.DeepCopy(v)
	end
	return t
end

function Utilities.ShallowCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = v
	end
	return copy
end

function Utilities.TableContains(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then return true end
	end
	return false
end

function Utilities.TableLength(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

-- ELO rating system utilities
function Utilities.EloExpected(ra, rb)
	return 1 / (1 + 10 ^ ((rb - ra) / 400))
end

function Utilities.EloAdjust(rating, expected, score, k)
	return math.floor(rating + k * (score - expected))
end

-- Advanced ELO with placement bonus and decay
function Utilities.EloAdjustAdvanced(currentRating, opponentRating, won, isPlacement, matchCount)
	local kFactor = 32
	
	-- Placement matches get higher K-factor
	if isPlacement then
		kFactor = 50
	elseif matchCount < 50 then
		-- Higher volatility for new players
		kFactor = 40
	elseif currentRating > 1800 then
		-- Lower volatility for high-rated players
		kFactor = 24
	end
	
	local expected = Utilities.EloExpected(currentRating, opponentRating)
	local score = won and 1 or 0
	local change = kFactor * (score - expected)
	
	return math.floor(currentRating + change), math.floor(change)
end

-- Network and async utilities
function Utilities.Retry(attempts, delaySeconds, fn)
	local lastErr
	for i=1,attempts do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		if i < attempts then task.wait(delaySeconds) end
	end
	return false, lastErr
end

function Utilities.RetryWithBackoff(attempts, baseDelay, fn)
	local lastErr
	for i=1,attempts do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		if i < attempts then 
			local delay = baseDelay * (2 ^ (i - 1)) -- Exponential backoff
			task.wait(delay)
		end
	end
	return false, lastErr
end

-- Performance monitoring utilities
function Utilities.Benchmark(name, fn)
	local startTime = tick()
	local result = fn()
	local endTime = tick()
	local duration = (endTime - startTime) * 1000 -- Convert to milliseconds
	
	print(string.format("[Benchmark] %s took %.2fms", name, duration))
	return result, duration
end

function Utilities.Throttle(fn, cooldownSeconds)
	local lastCall = 0
	return function(...)
		local now = tick()
		if now - lastCall >= cooldownSeconds then
			lastCall = now
			return fn(...)
		end
	end
end

function Utilities.Debounce(fn, delaySeconds)
	local debounceId = 0
	return function(...)
		debounceId = debounceId + 1
		local currentId = debounceId
		local args = {...}
		
		task.wait(delaySeconds)
		if debounceId == currentId then
			return fn(unpack(args))
		end
	end
end

-- String utilities
function Utilities.FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

function Utilities.FormatNumber(num)
	local formatted = tostring(num)
	local k = string.len(formatted)
	while k > 3 do
		formatted = string.sub(formatted, 1, k-3) .. "," .. string.sub(formatted, k-2)
		k = k - 4
	end
	return formatted
end

-- Validation utilities
function Utilities.ValidateVector3(vector, maxMagnitude)
	if typeof(vector) ~= "Vector3" then return false end
	if maxMagnitude and vector.Magnitude > maxMagnitude then return false end
	return true
end

function Utilities.ValidateRange(value, min, max)
	return type(value) == "number" and value >= min and value <= max
end

function Utilities.SanitizeUserInput(input, maxLength)
	if type(input) ~= "string" then return "" end
	input = string.gsub(input, "[%c%z]", "") -- Remove control characters
	if maxLength and string.len(input) > maxLength then
		input = string.sub(input, 1, maxLength)
	end
	return input
end

-- Random utilities
function Utilities.WeightedRandom(weights)
	local totalWeight = 0
	for _, weight in pairs(weights) do
		totalWeight = totalWeight + weight
	end
	
	local random = math.random() * totalWeight
	local current = 0
	
	for key, weight in pairs(weights) do
		current = current + weight
		if random <= current then
			return key
		end
	end
end

function Utilities.Shuffle(tbl)
	local shuffled = Utilities.ShallowCopy(tbl)
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

-- Hash utilities for consistent randomization
function Utilities.Hash(input)
	local hash = 0
	for i = 1, #input do
		local char = string.byte(input, i)
		hash = ((hash * 31) + char) % 2147483647
	end
	return hash
end

function Utilities.SeededRandom(seed, min, max)
	math.randomseed(seed)
	local result = math.random(min or 0, max or 1)
	math.randomseed(tick()) -- Reset to prevent predictable sequences
	return result
end

-- Color utilities for UI
function Utilities.ColorLerp(color1, color2, t)
	return Color3.new(
		Utilities.Lerp(color1.R, color2.R, t),
		Utilities.Lerp(color1.G, color2.G, t),
		Utilities.Lerp(color1.B, color2.B, t)
	)
end

function Utilities.GetTierColor(tier)
	local colors = {
		[1] = Color3.fromRGB(139, 69, 19),   -- Bronze
		[2] = Color3.fromRGB(192, 192, 192), -- Silver  
		[3] = Color3.fromRGB(255, 215, 0),   -- Gold
		[4] = Color3.fromRGB(229, 228, 226), -- Platinum
		[5] = Color3.fromRGB(185, 242, 255), -- Diamond
		[6] = Color3.fromRGB(255, 105, 180)  -- Champion
	}
	return colors[tier] or Color3.fromRGB(255, 255, 255)
end

return Utilities
