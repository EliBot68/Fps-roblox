-- DailyChallenges.server.lua
-- Simple rotating daily challenge scaffold

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStore = require(script.Parent.Parent.Core.DataStore)
local FeatureFlags = require(script.Parent.Parent.Core.FeatureFlags)

local DailyChallenges = {}

local CHALLENGES = {
	{ id = "elims_10", desc = "Get 10 eliminations", goal = 10, reward = 100 },
	{ id = "wins_1", desc = "Win 1 match", goal = 1, reward = 150 },
}

local function ensureDaily(profile)
	if not profile.Daily then
		profile.Daily = { Challenges = {}, ResetAt = 0 }
	end
	if os.time() >= (profile.Daily.ResetAt or 0) then
		profile.Daily.Challenges = {}
		for _,c in ipairs(CHALLENGES) do
			profile.Daily.Challenges[c.id] = { progress = 0, goal = c.goal, reward = c.reward, desc = c.desc, claimed = false }
		end
		profile.Daily.ResetAt = os.time() + 24 * 3600
	end
end

function DailyChallenges.Inc(plr, challengeId, amount)
	if not FeatureFlags.IsEnabled("EnableDailyChallenges") then return end
	local profile = DataStore.Get(plr)
	if not profile then return end
	ensureDaily(profile)
	local ch = profile.Daily.Challenges[challengeId]; if not ch or ch.claimed then return end
	ch.progress = math.min(ch.goal, ch.progress + (amount or 1))
	DataStore.MarkDirty(plr)
end

function DailyChallenges.Claim(plr, challengeId)
	local profile = DataStore.Get(plr); if not profile then return false, "NoProfile" end
	ensureDaily(profile)
	local ch = profile.Daily.Challenges[challengeId]; if not ch then return false, "Invalid" end
	if ch.progress < ch.goal then return false, "Incomplete" end
	if ch.claimed then return false, "Claimed" end
	ch.claimed = true
	profile.Currency += ch.reward
	DataStore.MarkDirty(plr)
	return true, ch.reward
end

Players.PlayerAdded:Connect(function(plr)
	local profile = DataStore.Get(plr)
	if profile then ensureDaily(profile) end
end)

return DailyChallenges
