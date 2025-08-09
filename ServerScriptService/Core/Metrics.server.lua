-- Metrics.server.lua
-- In-memory counters & periodic print (replace with external sink later)

local Metrics = {}
local counters = {}
local gauges = {}
local hist = {}

local function inc(tbl, key, amount)
	tbl[key] = (tbl[key] or 0) + (amount or 1)
end

function Metrics.Inc(name, amount)
	inc(counters, name, amount)
end

function Metrics.Gauge(name, value)
	gauges[name] = value
end

function Metrics.Observe(name, value)
	local bucket = hist[name]
	if not bucket then bucket = { count=0, sum=0, min=value, max=value }; hist[name] = bucket end
	bucket.count += 1
	bucket.sum += value
	if value < bucket.min then bucket.min = value end
	if value > bucket.max then bucket.max = value end
end

local function dump()
	print("[Metrics] Counters", counters)
	print("[Metrics] Gauges", gauges)
	for k,v in pairs(hist) do
		v.avg = v.sum / v.count
	end
	print("[Metrics] Hist", hist)
end

function Metrics.Init()
	task.spawn(function()
		while task.wait(30) do
			dump()
		end
	end)
end

return Metrics
