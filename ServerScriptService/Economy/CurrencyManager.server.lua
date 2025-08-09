-- CurrencyManager.server.lua
-- Handles awarding and spend validation with HMAC transaction security

local DataStore = require(script.Parent.Parent.Core.DataStore)
local FeatureFlags = require(script.Parent.Parent.Core.FeatureFlags)
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)
local CryptoSecurity = require(game:GetService("ReplicatedStorage").Shared.CryptoSecurity)

local CurrencyManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiRemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UIEvents")
local UpdateCurrencyRemote = uiRemoteRoot:FindFirstChild("UpdateCurrency")

local KILL_AWARD = 15
local WIN_AWARD = 75

-- Store recent transaction signatures to prevent replay attacks
local recentTransactions = {}
local MAX_TRANSACTION_HISTORY = 1000

local function push(plr)
	if UpdateCurrencyRemote then
		local profile = DataStore.Get(plr); if not profile then return end
		UpdateCurrencyRemote:FireClient(plr, profile.Currency or 0)
	end
end

-- Secure transaction logging with HMAC
local function logSecureTransaction(plr, amount, transactionType, reason)
	local transactionData = {
		userId = plr.UserId,
		amount = amount,
		type = transactionType,
		reason = reason
	}
	
	-- Sign the transaction
	local signedTransaction = CryptoSecurity.SignTransaction(transactionData)
	
	-- Check for replay attacks
	local signatureKey = signedTransaction.signature
	if recentTransactions[signatureKey] then
		warn("[CurrencyManager] Replay attack detected for player:", plr.Name)
		return false
	end
	
	-- Store signature to prevent replays
	recentTransactions[signatureKey] = tick()
	
	-- Clean old signatures periodically
	if #recentTransactions > MAX_TRANSACTION_HISTORY then
		local currentTime = tick()
		for sig, timestamp in pairs(recentTransactions) do
			if currentTime - timestamp > 300 then -- 5 minutes
				recentTransactions[sig] = nil
			end
		end
	end
	
	-- Log the signed transaction
	Logging.Event("SecureTransaction", {
		transaction = signedTransaction,
		verified = CryptoSecurity.VerifyTransaction(signedTransaction)
	})
	
	return true
end

function CurrencyManager.Award(plr, amount, reason)
	if amount <= 0 then return end
	local profile = DataStore.Get(plr); if not profile then return end
	
	-- Secure transaction logging
	if not logSecureTransaction(plr, amount, "award", reason) then
		warn("[CurrencyManager] Failed to log secure transaction for award")
		return
	end
	
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
	
	-- Secure transaction logging
	if not logSecureTransaction(plr, -cost, "spend", reason) then
		warn("[CurrencyManager] Failed to log secure transaction for spend")
		return false
	end
	
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
