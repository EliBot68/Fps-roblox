-- CurrencyManager.server.lua
-- Handles awarding and spend validation

local DataStore = require(script.Parent.Parent.Core.DataStore)
local FeatureFlags = require(script.Parent.Parent.Core.FeatureFlags)
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)

local CurrencyManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiRemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UIEvents")
local UpdateCurrencyRemote = uiRemoteRoot:FindFirstChild("UpdateCurrency")

local KILL_AWARD = 15
local WIN_AWARD = 75

local function push(plr)
	if UpdateCurrencyRemote then
		local profile = DataStore.Get(plr); if not profile then return end
		UpdateCurrencyRemote:FireClient(plr, profile.Currency or 0)
	end
end

function CurrencyManager.Award(plr, amount, reason)
	if amount <= 0 then return end
	local profile = DataStore.Get(plr); if not profile then return end
	profile.Currency += amount
	DataStore.MarkDirty(plr)
	Logging.Event("CurrencyAward", { u = plr.UserId, amt = amount, r = reason })
	push(plr)
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
	push(plr)
	return true
end

function CurrencyManager.AwardForKill(plr)
	CurrencyManager.Award(plr, KILL_AWARD, "Kill")
end

function CurrencyManager.AwardForWin(plr)
	CurrencyManager.Award(plr, WIN_AWARD, "Win")
end

return CurrencyManager
