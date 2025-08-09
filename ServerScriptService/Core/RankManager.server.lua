-- RankManager.server.lua
-- ELO adjustment placeholder

local RankManager = {}

local DEFAULT_ELO = 1000
local playerElo = {}

function RankManager.Get(plr)
	return playerElo[plr] or DEFAULT_ELO
end

function RankManager.Adjust(plr, delta)
	playerElo[plr] = RankManager.Get(plr) + delta
	return playerElo[plr]
end

function RankManager.OnMatchResult(results)
	-- results: { {player=Player, performance=number} }
	-- Simple delta for scaffold
	for _,entry in ipairs(results) do
		RankManager.Adjust(entry.player, math.floor(entry.performance))
	end
end

return RankManager
