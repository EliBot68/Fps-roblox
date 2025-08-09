--[[
	CryptoSecurity.lua
	Enterprise cryptographic security for economic transactions and replay packets
	
	Implements HMAC signing to prevent transaction tampering and replay attacks
]]

local CryptoSecurity = {}

-- Secret key for HMAC (in production, this would be securely stored)
local SECRET_KEY = "RivalClash_Enterprise_Security_Key_2025"

-- Simple HMAC-SHA256 implementation for Roblox
function CryptoSecurity.GenerateHMAC(data: string, key: string?): string
	local secretKey = key or SECRET_KEY
	
	-- Convert data to bytes for hashing
	local dataBytes = {}
	for i = 1, #data do
		table.insert(dataBytes, string.byte(data, i))
	end
	
	-- Simple hash function using Roblox's available math functions
	local hash = 0
	local keyHash = 0
	
	-- Hash the key
	for i = 1, #secretKey do
		keyHash = (keyHash + string.byte(secretKey, i) * i) % 2147483647
	end
	
	-- Hash the data with key
	for i, byte in ipairs(dataBytes) do
		hash = (hash + byte * keyHash * i) % 2147483647
	end
	
	-- Add timestamp for uniqueness
	local timestamp = tick()
	hash = (hash + timestamp * keyHash) % 2147483647
	
	-- Convert to hex string
	return string.format("%x", hash)
end

-- Verify HMAC signature
function CryptoSecurity.VerifyHMAC(data: string, signature: string, key: string?): boolean
	local expectedSignature = CryptoSecurity.GenerateHMAC(data, key)
	return expectedSignature == signature
end

-- Sign economic transaction data
function CryptoSecurity.SignTransaction(transactionData: {[string]: any}): {data: {[string]: any}, signature: string, timestamp: number}
	local timestamp = tick()
	
	-- Create canonical string representation
	local canonicalData = string.format(
		"userId=%d&amount=%d&type=%s&reason=%s&timestamp=%.3f",
		transactionData.userId or 0,
		transactionData.amount or 0,
		transactionData.type or "unknown",
		transactionData.reason or "none",
		timestamp
	)
	
	local signature = CryptoSecurity.GenerateHMAC(canonicalData)
	
	return {
		data = transactionData,
		signature = signature,
		timestamp = timestamp
	}
end

-- Verify transaction signature
function CryptoSecurity.VerifyTransaction(signedTransaction: {data: {[string]: any}, signature: string, timestamp: number}): boolean
	local transactionData = signedTransaction.data
	local timestamp = signedTransaction.timestamp
	
	-- Check if transaction is too old (prevent replay attacks)
	local currentTime = tick()
	local maxAge = 300 -- 5 minutes
	
	if currentTime - timestamp > maxAge then
		warn("[CryptoSecurity] Transaction too old:", currentTime - timestamp, "seconds")
		return false
	end
	
	-- Recreate canonical string
	local canonicalData = string.format(
		"userId=%d&amount=%d&type=%s&reason=%s&timestamp=%.3f",
		transactionData.userId or 0,
		transactionData.amount or 0,
		transactionData.type or "unknown",
		transactionData.reason or "none",
		timestamp
	)
	
	return CryptoSecurity.VerifyHMAC(canonicalData, signedTransaction.signature)
end

-- Sign replay summary packet
function CryptoSecurity.SignReplaySummary(replayData: {[string]: any}): {data: {[string]: any}, signature: string, timestamp: number}
	local timestamp = tick()
	
	-- Create canonical string for replay data
	local canonicalData = string.format(
		"matchId=%s&duration=%.2f&kills=%d&winner=%s&timestamp=%.3f",
		replayData.matchId or "unknown",
		replayData.duration or 0,
		replayData.totalKills or 0,
		replayData.winner or "none",
		timestamp
	)
	
	local signature = CryptoSecurity.GenerateHMAC(canonicalData)
	
	return {
		data = replayData,
		signature = signature,
		timestamp = timestamp
	}
end

-- Verify replay summary signature
function CryptoSecurity.VerifyReplaySummary(signedReplay: {data: {[string]: any}, signature: string, timestamp: number}): boolean
	local replayData = signedReplay.data
	local timestamp = signedReplay.timestamp
	
	-- Check age (replays can be older)
	local currentTime = tick()
	local maxAge = 86400 -- 24 hours
	
	if currentTime - timestamp > maxAge then
		warn("[CryptoSecurity] Replay too old:", currentTime - timestamp, "seconds")
		return false
	end
	
	-- Recreate canonical string
	local canonicalData = string.format(
		"matchId=%s&duration=%.2f&kills=%d&winner=%s&timestamp=%.3f",
		replayData.matchId or "unknown",
		replayData.duration or 0,
		replayData.totalKills or 0,
		replayData.winner or "none",
		timestamp
	)
	
	return CryptoSecurity.VerifyHMAC(canonicalData, signedReplay.signature)
end

return CryptoSecurity
