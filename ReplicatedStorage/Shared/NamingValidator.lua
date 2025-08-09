--[[
	NamingValidator.lua
	Enterprise naming convention validator and enforcement
	
	Ensures consistent naming patterns across the codebase:
	- Functions: verbs (camelCase) - calculateDamage, fireWeapon
	- Variables: nouns (camelCase) - playerHealth, weaponData
	- Constants: UPPER_SNAKE_CASE - MAX_HEALTH, FIRE_RATE
	- Classes/Modules: PascalCase - WeaponManager, PlayerData
]]

local NamingValidator = {}

-- Naming pattern definitions
local PATTERNS = {
	-- Function patterns (verbs)
	FUNCTION_VERBS = {
		"get", "set", "calculate", "update", "create", "destroy", "fire", "reload", "spawn", "teleport",
		"validate", "check", "process", "handle", "manage", "initialize", "cleanup", "register",
		"unregister", "connect", "disconnect", "start", "stop", "pause", "resume", "award", "spend"
	},
	
	-- Variable patterns (nouns)
	VARIABLE_NOUNS = {
		"data", "config", "manager", "system", "player", "weapon", "health", "ammo", "position",
		"rotation", "velocity", "damage", "range", "accuracy", "rate", "cooldown", "timestamp",
		"counter", "limit", "threshold", "score", "rank", "currency", "inventory", "stats"
	},
	
	-- Constants pattern
	CONSTANT_PATTERN = "^[A-Z][A-Z0-9_]*$",
	
	-- Class/Module pattern
	CLASS_PATTERN = "^[A-Z][a-zA-Z0-9]*$",
	
	-- Function pattern (camelCase starting with verb)
	FUNCTION_PATTERN = "^[a-z][a-zA-Z0-9]*$",
	
	-- Variable pattern (camelCase starting with noun)
	VARIABLE_PATTERN = "^[a-z][a-zA-Z0-9]*$"
}

-- Check if a name follows camelCase convention
local function isCamelCase(name: string): boolean
	return string.match(name, "^[a-z][a-zA-Z0-9]*$") ~= nil
end

-- Check if a name follows PascalCase convention
local function isPascalCase(name: string): boolean
	return string.match(name, "^[A-Z][a-zA-Z0-9]*$") ~= nil
end

-- Check if a name follows UPPER_SNAKE_CASE convention
local function isUpperSnakeCase(name: string): boolean
	return string.match(name, "^[A-Z][A-Z0-9_]*$") ~= nil
end

-- Check if a function name starts with a verb
local function startsWithVerb(name: string): boolean
	local lowerName = string.lower(name)
	for _, verb in ipairs(PATTERNS.FUNCTION_VERBS) do
		if string.sub(lowerName, 1, #verb) == verb then
			return true
		end
	end
	return false
end

-- Check if a variable name contains a noun
local function containsNoun(name: string): boolean
	local lowerName = string.lower(name)
	for _, noun in ipairs(PATTERNS.VARIABLE_NOUNS) do
		if string.find(lowerName, noun) then
			return true
		end
	end
	return false
end

-- Validate function name
function NamingValidator.ValidateFunction(name: string): {valid: boolean, issues: {string}}
	local issues = {}
	
	if not isCamelCase(name) then
		table.insert(issues, "Should use camelCase (e.g., calculateDamage)")
	end
	
	if not startsWithVerb(name) then
		table.insert(issues, "Should start with action verb (e.g., get, set, calculate, fire)")
	end
	
	if #name < 3 then
		table.insert(issues, "Should be descriptive (minimum 3 characters)")
	end
	
	return {
		valid = #issues == 0,
		issues = issues
	}
end

-- Validate variable name
function NamingValidator.ValidateVariable(name: string): {valid: boolean, issues: {string}}
	local issues = {}
	
	if not isCamelCase(name) then
		table.insert(issues, "Should use camelCase (e.g., playerHealth)")
	end
	
	if not containsNoun(name) then
		table.insert(issues, "Should contain descriptive noun (e.g., data, config, manager)")
	end
	
	if #name < 3 then
		table.insert(issues, "Should be descriptive (minimum 3 characters)")
	end
	
	return {
		valid = #issues == 0,
		issues = issues
	}
end

-- Validate constant name
function NamingValidator.ValidateConstant(name: string): {valid: boolean, issues: {string}}
	local issues = {}
	
	if not isUpperSnakeCase(name) then
		table.insert(issues, "Should use UPPER_SNAKE_CASE (e.g., MAX_HEALTH)")
	end
	
	if #name < 3 then
		table.insert(issues, "Should be descriptive (minimum 3 characters)")
	end
	
	return {
		valid = #issues == 0,
		issues = issues
	}
end

-- Validate class/module name
function NamingValidator.ValidateClass(name: string): {valid: boolean, issues: {string}}
	local issues = {}
	
	if not isPascalCase(name) then
		table.insert(issues, "Should use PascalCase (e.g., WeaponManager)")
	end
	
	if #name < 3 then
		table.insert(issues, "Should be descriptive (minimum 3 characters)")
	end
	
	return {
		valid = #issues == 0,
		issues = issues
	}
end

-- Suggest better name based on type and current name
function NamingValidator.SuggestName(currentName: string, nameType: string): string?
	local suggestions = {
		["function"] = {
			["damage"] = "calculateDamage",
			["health"] = "getHealth",
			["weapon"] = "fireWeapon",
			["player"] = "updatePlayer",
			["spawn"] = "spawnPlayer",
			["tp"] = "teleportPlayer"
		},
		["variable"] = {
			["hp"] = "playerHealth",
			["dmg"] = "weaponDamage",
			["pos"] = "playerPosition",
			["cfg"] = "gameConfig",
			["mgr"] = "weaponManager"
		},
		["constant"] = {
			["maxhp"] = "MAX_HEALTH",
			["firerate"] = "FIRE_RATE",
			["maxammo"] = "MAX_AMMO"
		}
	}
	
	local typeSuggestions = suggestions[nameType]
	if typeSuggestions then
		local lowerName = string.lower(currentName)
		return typeSuggestions[lowerName]
	end
	
	return nil
end

-- Validate a batch of names
function NamingValidator.ValidateBatch(names: {{name: string, type: string}}): {totalNames: number, validNames: number, violations: {{name: string, type: string, issues: {string}}}}
	local violations = {}
	local validCount = 0
	
	for _, nameData in ipairs(names) do
		local result
		
		if nameData.type == "function" then
			result = NamingValidator.ValidateFunction(nameData.name)
		elseif nameData.type == "variable" then
			result = NamingValidator.ValidateVariable(nameData.name)
		elseif nameData.type == "constant" then
			result = NamingValidator.ValidateConstant(nameData.name)
		elseif nameData.type == "class" then
			result = NamingValidator.ValidateClass(nameData.name)
		else
			result = {valid = false, issues = {"Unknown name type"}}
		end
		
		if result.valid then
			validCount = validCount + 1
		else
			table.insert(violations, {
				name = nameData.name,
				type = nameData.type,
				issues = result.issues
			})
		end
	end
	
	return {
		totalNames = #names,
		validNames = validCount,
		violations = violations
	}
end

-- Get naming convention guidelines
function NamingValidator.GetGuidelines(): {[string]: string}
	return {
		functions = "Use camelCase starting with action verbs (calculateDamage, fireWeapon, updatePlayer)",
		variables = "Use camelCase with descriptive nouns (playerHealth, weaponData, gameConfig)",
		constants = "Use UPPER_SNAKE_CASE (MAX_HEALTH, FIRE_RATE, DEFAULT_AMMO)",
		classes = "Use PascalCase (WeaponManager, PlayerData, GameState)",
		general = "Be descriptive, avoid abbreviations, use consistent terminology"
	}
end

return NamingValidator
