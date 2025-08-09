-- RankManager.server.lua
-- ELO adjustment system

local Utilities = require(game:GetService("ReplicatedStorage").Shared.Utilities)

local RankManager = {}

local DEFAULT_ELO = 1000
local K_FACTOR = 32
local TIERS = {
	{ Name = "Bronze", Min = 0 },
	{ Name = "Silver", Min = 1100 },
	{ Name = "Gold", Min = 1300 },
	{ Name = "Platinum", Min = 1500 },
	{ Name = "Diamond", Min = 1700 },
	{ Name = "Champion", Min = 1900 },
}

local playerElo = {}

function RankManager.Get(plr)
	return playerElo[plr] or DEFAULT_ELO
end

local function tierFor(elo)
	local current = TIERS[1].Name
	for _,tier in ipairs(TIERS) do
		if elo >= tier.Min then current = tier.Name else break end
	end
	return current
end

function RankManager.GetTier(plr)
	return tierFor(RankManager.Get(plr))
end

-- score: 1 win, 0 loss, 0.5 draw
function RankManager.ApplyResult(plr, opponentAvg, score)
	local ra = RankManager.Get(plr)
	local expected = Utilities.EloExpected(ra, opponentAvg)
	local newRating = Utilities.EloAdjust(ra, expected, score, K_FACTOR)
	playerElo[plr] = newRating
	return newRating, tierFor(newRating)
end

function RankManager.OnMatchResult(resultTable)
	-- resultTable: { {player=Player, score=0|0.5|1, opponentsRating=number} }
	for _,entry in ipairs(resultTable) do
		RankManager.ApplyResult(entry.player, entry.opponentsRating or DEFAULT_ELO, entry.score)
	end
end

return RankManager
