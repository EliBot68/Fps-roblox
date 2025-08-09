-- KillStreakManager.server.lua
-- Tracks player kill streaks and grants bonuses

local KillStreakManager = {}
local streaks = {}

local BONUS_THRESHOLDS = {
	{ k = 3, reward = 25, tag = "Triple" },
	{ k = 5, reward = 50, tag = "Rampage" },
	{ k = 8, reward = 100, tag = "Unstoppable" },
}

local CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager)
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)

function KillStreakManager.OnKill(killer, victim)
	if not killer then return end
	streaks[killer] = (streaks[killer] or 0) + 1
	for i=#BONUS_THRESHOLDS,1,-1 do
		local t = BONUS_THRESHOLDS[i]
		if streaks[killer] == t.k then
			CurrencyManager.Award(killer, t.reward, "Streak_" .. t.tag)
			Logging.Event("KillStreak", { u = killer.UserId, streak = streaks[killer], tag = t.tag })
			break
		end
	end
end

function KillStreakManager.Reset(player)
	streaks[player] = 0
end

return KillStreakManager
