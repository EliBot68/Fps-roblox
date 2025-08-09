-- TournamentPersistence.server.lua
-- Store tournament bracket snapshots to DataStore

local DataStoreService = game:GetService("DataStoreService")
local tournamentStore = DataStoreService:GetDataStore("TournamentData_v1")

local TournamentPersistence = {}

function TournamentPersistence.Save(tournamentId, bracketData)
	local key = "T_" .. tournamentId
	local success, err = pcall(function()
		return tournamentStore:SetAsync(key, {
			Bracket = bracketData,
			SavedAt = os.time()
		})
	end)
	if not success then
		warn("[TournamentPersistence] Save failed:", err)
	end
	return success
end

function TournamentPersistence.Load(tournamentId)
	local key = "T_" .. tournamentId
	local success, data = pcall(function()
		return tournamentStore:GetAsync(key)
	end)
	if success and data then
		return data.Bracket
	end
	return nil
end

return TournamentPersistence
