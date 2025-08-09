-- ReplayRecorder.server.lua
-- Lightweight event log scaffold (in-memory)

local ReplayRecorder = {}
local logs = {}
local MAX_EVENTS = 5000

function ReplayRecorder.Log(eventName, data)
	if #logs >= MAX_EVENTS then
		table.remove(logs, 1)
	end
	logs[#logs+1] = { t = os.clock(), e = eventName, d = data }
end

function ReplayRecorder.Export()
	return logs
end

function ReplayRecorder.Clear()
	table.clear(logs)
end

return ReplayRecorder
