-- Logging.lua
-- Central logging & telemetry facade

local Logging = {}

local function ts()
	return os.clock()
end

function Logging.Event(name, data)
	-- Lightweight structured log
	local payload = { t = ts(), e = name, d = data }
	print("[LOG]", game:GetService("HttpService"):JSONEncode(payload))
end

function Logging.Error(context, message)
	print("[ERROR]", context, message)
end

return Logging
