-- Localization.lua
-- Enterprise internationalization system with comprehensive language support

local Players = game:GetService("Players")

local Localization = {}

-- Language definitions with comprehensive UI strings
local Languages = {
	EN = {
		-- HUD and UI
		HUD_HEALTH = "Health",
		HUD_AMMO = "Ammo",
		HUD_KILLS = "Kills",
		HUD_DEATHS = "Deaths",
		HUD_SCORE = "Score",
		HUD_PING = "Ping",
		HUD_FPS = "FPS",
		HUD_TIME_LEFT = "Time Left",
		
		-- Match states
		MSG_MATCH_START = "Match Started!",
		MSG_MATCH_END = "Match Ended",
		MSG_ELIMINATION = "Eliminated",
		MSG_VICTORY = "Victory!",
		MSG_DEFEAT = "Defeat",
		MSG_WAITING_PLAYERS = "Waiting for players...",
		MSG_COUNTDOWN = "Match starts in {0}",
		MSG_OVERTIME = "Overtime!",
		
		-- Weapons and combat
		WEAPON_ASSAULT_RIFLE = "Assault Rifle",
		WEAPON_SMG = "SMG",
		WEAPON_SHOTGUN = "Shotgun",
		WEAPON_SNIPER = "Sniper Rifle",
		WEAPON_PISTOL = "Pistol",
		WEAPON_BURST_RIFLE = "Burst Rifle",
		
		COMBAT_HEADSHOT = "Headshot!",
		COMBAT_MULTIKILL = "Multikill!",
		COMBAT_KILLSTREAK = "Killstreak!",
		COMBAT_RELOAD = "Reloading...",
		COMBAT_OUT_OF_AMMO = "Out of ammo!",
		
		-- Economy and progression
		CURRENCY_COINS = "Coins",
		CURRENCY_GEMS = "Gems",
		SHOP_PURCHASE = "Purchase",
		SHOP_EQUIP = "Equip",
		SHOP_OWNED = "Owned",
		SHOP_INSUFFICIENT_FUNDS = "Insufficient funds",
		
		RANK_BRONZE = "Bronze",
		RANK_SILVER = "Silver",
		RANK_GOLD = "Gold",
		RANK_PLATINUM = "Platinum",
		RANK_DIAMOND = "Diamond",
		RANK_CHAMPION = "Champion",
		
		-- Social features
		CLAN_CREATE = "Create Clan",
		CLAN_JOIN = "Join Clan",
		CLAN_LEAVE = "Leave Clan",
		CLAN_INVITE = "Invite to Clan",
		CLAN_MEMBER = "Member",
		CLAN_OFFICER = "Officer",
		CLAN_LEADER = "Leader",
		
		-- Notifications
		NOTIF_RANK_UP = "Rank Up! You are now {0}",
		NOTIF_ACHIEVEMENT = "Achievement Unlocked: {0}",
		NOTIF_DAILY_REWARD = "Daily reward claimed: {0} coins",
		NOTIF_FRIEND_ONLINE = "{0} is now online",
		
		-- Errors and warnings
		ERROR_CONNECTION = "Connection error",
		ERROR_SERVER_FULL = "Server is full",
		ERROR_INVALID_INPUT = "Invalid input",
		WARNING_HIGH_PING = "High ping detected",
		WARNING_LOW_FPS = "Low FPS detected",
		
		-- Settings
		SETTINGS_GRAPHICS = "Graphics",
		SETTINGS_AUDIO = "Audio",
		SETTINGS_CONTROLS = "Controls",
		SETTINGS_SENSITIVITY = "Mouse Sensitivity",
		SETTINGS_VOLUME = "Volume",
		SETTINGS_QUALITY = "Quality",
		
		-- Game modes
		MODE_DEATHMATCH = "Deathmatch",
		MODE_TEAM_DEATHMATCH = "Team Deathmatch",
		MODE_COMPETITIVE = "Competitive",
		MODE_CASUAL = "Casual",
		MODE_RANKED = "Ranked",
		
		-- Time formats
		TIME_SECONDS = "{0}s",
		TIME_MINUTES = "{0}m {1}s",
		TIME_HOURS = "{0}h {1}m",
	},
	
	ES = {
		-- Spanish translations
		HUD_HEALTH = "Salud",
		HUD_AMMO = "Munición",
		HUD_KILLS = "Eliminaciones",
		HUD_DEATHS = "Muertes",
		HUD_SCORE = "Puntuación",
		MSG_MATCH_START = "¡Partida iniciada!",
		MSG_MATCH_END = "Partida terminada",
		MSG_ELIMINATION = "Eliminado",
		MSG_VICTORY = "¡Victoria!",
		MSG_DEFEAT = "Derrota",
		WEAPON_ASSAULT_RIFLE = "Rifle de Asalto",
		WEAPON_SMG = "Subfusil",
		WEAPON_SHOTGUN = "Escopeta",
		WEAPON_SNIPER = "Rifle de Francotirador",
		WEAPON_PISTOL = "Pistola",
		COMBAT_HEADSHOT = "¡Disparo a la cabeza!",
		COMBAT_RELOAD = "Recargando...",
		RANK_BRONZE = "Bronce",
		RANK_SILVER = "Plata",
		RANK_GOLD = "Oro",
		RANK_PLATINUM = "Platino",
		RANK_DIAMOND = "Diamante",
		RANK_CHAMPION = "Campeón",
	},
	
	FR = {
		-- French translations
		HUD_HEALTH = "Santé",
		HUD_AMMO = "Munitions",
		HUD_KILLS = "Éliminations",
		HUD_DEATHS = "Morts",
		HUD_SCORE = "Score",
		MSG_MATCH_START = "Match commencé !",
		MSG_MATCH_END = "Match terminé",
		MSG_ELIMINATION = "Éliminé",
		MSG_VICTORY = "Victoire !",
		MSG_DEFEAT = "Défaite",
		WEAPON_ASSAULT_RIFLE = "Fusil d'Assaut",
		WEAPON_SMG = "Mitraillette",
		WEAPON_SHOTGUN = "Fusil à Pompe",
		WEAPON_SNIPER = "Fusil de Précision",
		WEAPON_PISTOL = "Pistolet",
		COMBAT_HEADSHOT = "Tir à la tête !",
		COMBAT_RELOAD = "Rechargement...",
		RANK_BRONZE = "Bronze",
		RANK_SILVER = "Argent",
		RANK_GOLD = "Or",
		RANK_PLATINUM = "Platine",
		RANK_DIAMOND = "Diamant",
		RANK_CHAMPION = "Champion",
	},
	
	DE = {
		-- German translations
		HUD_HEALTH = "Gesundheit",
		HUD_AMMO = "Munition",
		HUD_KILLS = "Eliminierungen",
		HUD_DEATHS = "Tode",
		HUD_SCORE = "Punkte",
		MSG_MATCH_START = "Match gestartet!",
		MSG_MATCH_END = "Match beendet",
		MSG_ELIMINATION = "Eliminiert",
		MSG_VICTORY = "Sieg!",
		MSG_DEFEAT = "Niederlage",
		WEAPON_ASSAULT_RIFLE = "Sturmgewehr",
		WEAPON_SMG = "Maschinenpistole",
		WEAPON_SHOTGUN = "Schrotflinte",
		WEAPON_SNIPER = "Scharfschützengewehr",
		WEAPON_PISTOL = "Pistole",
		COMBAT_HEADSHOT = "Kopfschuss!",
		COMBAT_RELOAD = "Nachladen...",
		RANK_BRONZE = "Bronze",
		RANK_SILVER = "Silber",
		RANK_GOLD = "Gold",
		RANK_PLATINUM = "Platin",
		RANK_DIAMOND = "Diamant",
		RANK_CHAMPION = "Champion",
	}
}

-- Player language preferences
local playerLanguages = {}

-- Default language
local DEFAULT_LANGUAGE = "EN"

function Localization.GetPlayerLanguage(player)
	if playerLanguages[player.UserId] then
		return playerLanguages[player.UserId]
	end
	
	-- Try to detect from locale
	local locale = player.LocaleId
	if locale then
		local langCode = string.upper(string.sub(locale, 1, 2))
		if Languages[langCode] then
			playerLanguages[player.UserId] = langCode
			return langCode
		end
	end
	
	-- Default to English
	playerLanguages[player.UserId] = DEFAULT_LANGUAGE
	return DEFAULT_LANGUAGE
end

function Localization.SetPlayerLanguage(player, language)
	if Languages[language] then
		playerLanguages[player.UserId] = language
		return true
	end
	return false
end

function Localization.Get(key, player, ...)
	local language = DEFAULT_LANGUAGE
	
	if player then
		language = Localization.GetPlayerLanguage(player)
	end
	
	local languageTable = Languages[language] or Languages[DEFAULT_LANGUAGE]
	local text = languageTable[key] or Languages[DEFAULT_LANGUAGE][key] or key
	
	-- Handle string formatting with parameters
	local args = {...}
	if #args > 0 then
		for i, arg in ipairs(args) do
			text = string.gsub(text, "{" .. (i-1) .. "}", tostring(arg))
		end
	end
	
	return text
end

function Localization.GetWithFallback(key, language, ...)
	local languageTable = Languages[language] or Languages[DEFAULT_LANGUAGE]
	local text = languageTable[key] or Languages[DEFAULT_LANGUAGE][key] or key
	
	-- Handle string formatting with parameters
	local args = {...}
	if #args > 0 then
		for i, arg in ipairs(args) do
			text = string.gsub(text, "{" .. (i-1) .. "}", tostring(arg))
		end
	end
	
	return text
end

function Localization.GetAvailableLanguages()
	local langs = {}
	for code, _ in pairs(Languages) do
		table.insert(langs, code)
	end
	return langs
end

function Localization.IsLanguageSupported(language)
	return Languages[language] ~= nil
end

-- Batch translation for UI elements
function Localization.TranslateUI(ui, player)
	local language = Localization.GetPlayerLanguage(player)
	
	-- Recursively find all UI elements with translation keys
	local function translateElement(element)
		-- Check for translation attributes
		if element:GetAttribute("LocalizationKey") then
			local key = element:GetAttribute("LocalizationKey")
			if element:IsA("TextLabel") or element:IsA("TextButton") then
				element.Text = Localization.GetWithFallback(key, language)
			end
		end
		
		-- Recurse through children
		for _, child in pairs(element:GetChildren()) do
			translateElement(child)
		end
	end
	
	translateElement(ui)
end

-- Format numbers according to locale
function Localization.FormatNumber(number, player)
	local language = player and Localization.GetPlayerLanguage(player) or DEFAULT_LANGUAGE
	
	-- Different number formatting rules
	local formatted = tostring(number)
	
	if language == "EN" then
		-- English: 1,234.56
		local parts = string.split(formatted, ".")
		local intPart = parts[1]
		local decPart = parts[2]
		
		-- Add commas
		local result = ""
		for i = 1, #intPart do
			if i > 1 and (i - 1) % 3 == 0 then
				result = "," .. result
			end
			result = string.sub(intPart, #intPart - i + 1, #intPart - i + 1) .. result
		end
		
		if decPart then
			result = result .. "." .. decPart
		end
		
		return result
	elseif language == "DE" or language == "ES" then
		-- German/Spanish: 1.234,56
		local parts = string.split(formatted, ".")
		local intPart = parts[1]
		local decPart = parts[2]
		
		-- Add periods for thousands
		local result = ""
		for i = 1, #intPart do
			if i > 1 and (i - 1) % 3 == 0 then
				result = "." .. result
			end
			result = string.sub(intPart, #intPart - i + 1, #intPart - i + 1) .. result
		end
		
		if decPart then
			result = result .. "," .. decPart
		end
		
		return result
	end
	
	return formatted
end

-- Clean up when player leaves
game.Players.PlayerRemoving:Connect(function(player)
	playerLanguages[player.UserId] = nil
end)

return Localization
