-- Tournament.server.lua
-- Basic tournament bracket scaffold

local Tournament = {}

local activeBracket = nil

function Tournament.Create(players)
	-- single elimination scaffold
	activeBracket = { Rounds = { { Players = players } }, State = "Setup" }
end

function Tournament.Advance()
	if not activeBracket then return end
	-- Placeholder
end

function Tournament.Get()
	return activeBracket
end

return Tournament
