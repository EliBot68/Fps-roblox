-- CurrencyManager.server.lua
-- Handles awarding and spend validation

local DataStore = require(script.Parent.Parent.Core.DataStore)
local FeatureFlags = require(script.Parent.Parent.Core.FeatureFlags)
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)

local CurrencyManager = {}

function CurrencyManager.Award(plr, amount, reason)
	if amount <= 0 then return end
	local profile = DataStore.Get(plr); if not profile then return end
	profile.Currency += amount
	DataStore.MarkDirty(plr)
	Logging.Event("CurrencyAward", { u = plr.UserId, amt = amount, r = reason })
end

function CurrencyManager.CanAfford(plr, cost)
	local profile = DataStore.Get(plr); if not profile then return false end
	return (profile.Currency or 0) >= cost
end

function CurrencyManager.Spend(plr, cost, reason)
	if cost <= 0 then return true end
	local profile = DataStore.Get(plr); if not profile then return false end
	if (profile.Currency or 0) < cost then return false end
	profile.Currency -= cost
	DataStore.MarkDirty(plr)
	Logging.Event("CurrencySpend", { u = plr.UserId, amt = cost, r = reason })
	return true
end

function CurrencyManager.AwardForKill(plr)
	CurrencyManager.Award(plr, 10, "Kill")
end

function CurrencyManager.AwardForWin(plr)
	CurrencyManager.Award(plr, 100, "Win")
end

return CurrencyManager
