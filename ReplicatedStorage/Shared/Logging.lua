-- Logging.lua
-- Central logging & telemetry facade

local HttpService = game:GetService("HttpService")
local Logging = {}
local Metrics = nil

local function ts()
	return os.clock()
end

function Logging.SetMetrics(m)
	Metrics = m
end

function Logging.Event(name, data)
	local payload = { t = ts(), e = name, d = data }
	print("[LOG]", HttpService:JSONEncode(payload))
	if Metrics then Metrics.Inc("Log_" .. name) end
end

function Logging.Error(context, message)
	print("[ERROR]", context, message)
	if Metrics then Metrics.Inc("Errors") end
end

function Logging.Warn(context, message)
	print("[WARN]", context, message)
	if Metrics then Metrics.Inc("Warnings") end
end

return Logging
