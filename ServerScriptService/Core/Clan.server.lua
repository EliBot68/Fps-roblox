-- Clan.server.lua
-- Simple clan data scaffold (in-memory)

local Clan = {}
local clans = {}

function Clan.Create(name, ownerUserId)
	if clans[name] then return false, "Exists" end
	clans[name] = { Owner = ownerUserId, Members = { [ownerUserId] = true }, CreatedAt = os.time() }
	return true
end

function Clan.Invite(name, userId)
	local c = clans[name]; if not c then return false, "NotFound" end
	c.Members[userId] = true
	return true
end

function Clan.Get(name)
	return clans[name]
end

return Clan
