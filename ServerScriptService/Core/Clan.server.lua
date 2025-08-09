-- Clan.server.lua
-- Simple clan data scaffold (in-memory)

local Clan = {}
local clans = {}
local DataStore = require(script.Parent.DataStore)

function Clan.Create(name, ownerUserId)
	if clans[name] then return false, "Exists" end
	clans[name] = { Owner = ownerUserId, Members = { [ownerUserId] = true }, CreatedAt = os.time() }
	local ownerPlayer = nil
	for _,p in ipairs(game:GetService("Players"):GetPlayers()) do if p.UserId == ownerUserId then ownerPlayer = p break end end
	if ownerPlayer then
		local prof = DataStore.Get(ownerPlayer)
		if prof then
			prof.Clans = prof.Clans or {}
			prof.Clans[name] = true
			DataStore.MarkDirty(ownerPlayer)
		end
	end
	return true
end

function Clan.Invite(name, userId)
	local c = clans[name]; if not c then return false, "NotFound" end
	c.Members[userId] = true
	for _,p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.UserId == userId then
			local prof = DataStore.Get(p)
			if prof then
				prof.Clans = prof.Clans or {}
				prof.Clans[name] = true
				DataStore.MarkDirty(p)
			end
			break
		end
	end
	return true
end

function Clan.Get(name)
	return clans[name]
end

function Clan.ListMembers(name)
	local c = clans[name]; if not c then return {} end
	local out = {}
	for uid,_ in pairs(c.Members) do table.insert(out, uid) end
	return out
end

return Clan
