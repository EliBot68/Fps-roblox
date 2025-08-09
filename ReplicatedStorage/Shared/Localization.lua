-- Localization.lua
-- Key map for translatable strings (example)

local Localization = {
	EN = {
		HUD_HEALTH = "Health",
		HUD_AMMO = "Ammo",
		MSG_MATCH_START = "Match Started",
		MSG_ELIMINATION = "Eliminated",
	},
}

function Localization.Get(locale, key)
	local loc = Localization[locale] or Localization.EN
	return loc[key] or key
end

return Localization
