-- RemoteEventValidationExample.lua
-- Example implementation showing how to use the SecurityValidator with RemoteEvents
-- This demonstrates enterprise-grade security validation for all remote calls

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get dependencies from Service Locator
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- This example shows how to protect a combat RemoteEvent
local function SetupCombatEventSecurity()
	-- Get required services
	local AntiExploit = ServiceLocator.GetService("AntiExploit")
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	
	-- Define validation schema for weapon fire events
	local WeaponFireSchema = {
		weaponId = {
			type = "string",
			required = true,
			pattern = "^[A-Z_]+$", -- Only uppercase letters and underscores
			whitelist = {"ASSAULT_RIFLE", "PISTOL", "SNIPER_RIFLE", "SHOTGUN"}
		},
		targetPosition = {
			type = "Vector3",
			required = true,
			customValidator = function(pos)
				-- Validate position is within reasonable bounds
				if typeof(pos) ~= "Vector3" then
					return false, "Invalid Vector3"
				end
				if pos.Magnitude > 10000 then
					return false, "Position too far from origin"
				end
				return true
			end
		},
		damage = {
			type = "number",
			required = true,
			min = 1,
			max = 100
		},
		timestamp = {
			type = "number",
			required = true,
			customValidator = function(ts)
				local currentTime = tick()
				local timeDiff = math.abs(currentTime - ts)
				if timeDiff > 5 then -- More than 5 seconds old
					return false, "Timestamp too old or from future"
				end
				return true
			end
		}
	}
	
	-- Get the RemoteEvent
	local combatEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatEvents")
	local weaponFireEvent = combatEvents:WaitForChild("WeaponFire")
	
	-- Secure the RemoteEvent with validation
	weaponFireEvent.OnServerEvent:Connect(function(player, weaponId, targetPosition, damage, timestamp)
		-- Validate the remote call using AntiExploit system
		local isValid, sanitizedData = AntiExploit:ValidateRemoteEventCall(
			player, 
			"WeaponFire", 
			WeaponFireSchema,
			weaponId, targetPosition, damage, timestamp
		)
		
		if not isValid then
			-- Security validation failed - already logged and handled by AntiExploit
			return
		end
		
		-- Process the validated weapon fire
		print(string.format(
			"[SECURE] Player %s fired %s at %s for %d damage",
			player.Name,
			sanitizedData.weaponId,
			tostring(sanitizedData.targetPosition),
			sanitizedData.damage
		))
		
		-- Continue with game logic using sanitized data
		-- Example: WeaponServer:ProcessWeaponFire(player, sanitizedData)
	end)
	
	print("[Security] Combat events secured with enterprise validation")
end

-- Example of securing a UI event
local function SetupUIEventSecurity()
	local AntiExploit = ServiceLocator.GetService("AntiExploit")
	
	-- Schema for shop purchase events
	local ShopPurchaseSchema = {
		itemId = {
			type = "string",
			required = true,
			pattern = "^item_[a-z0-9_]+$", -- Must start with "item_" followed by lowercase/numbers/underscores
			customValidator = function(itemId)
				-- Check if item exists in shop catalog
				local validItems = {"item_assault_rifle", "item_body_armor", "item_health_pack"}
				for _, validItem in ipairs(validItems) do
					if itemId == validItem then
						return true
					end
				end
				return false, "Item not found in catalog"
			end
		},
		quantity = {
			type = "number",
			required = true,
			min = 1,
			max = 10 -- Prevent bulk purchasing exploits
		},
		currency = {
			type = "string",
			required = true,
			whitelist = {"coins", "gems", "credits"}
		}
	}
	
	-- Get the RemoteEvent
	local uiEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UIEvents")
	local shopPurchaseEvent = uiEvents:WaitForChild("ShopPurchase")
	
	-- Secure the shop purchase event
	shopPurchaseEvent.OnServerEvent:Connect(function(player, itemId, quantity, currency)
		local isValid, sanitizedData = AntiExploit:ValidateRemoteEventCall(
			player,
			"ShopPurchase",
			ShopPurchaseSchema,
			itemId, quantity, currency
		)
		
		if not isValid then
			return
		end
		
		-- Process the validated purchase
		print(string.format(
			"[SECURE] Player %s purchasing %dx %s with %s",
			player.Name,
			sanitizedData.quantity,
			sanitizedData.itemId,
			sanitizedData.currency
		))
		
		-- Continue with shop logic using sanitized data
	end)
	
	print("[Security] UI events secured with enterprise validation")
end

-- Example of securing admin commands
local function SetupAdminEventSecurity()
	local AntiExploit = ServiceLocator.GetService("AntiExploit")
	local AdminAlert = ServiceLocator.GetService("AdminAlert")
	
	-- Schema for admin commands (very strict)
	local AdminCommandSchema = {
		command = {
			type = "string",
			required = true,
			whitelist = {"kick", "ban", "teleport", "give_item", "set_health"}
		},
		targetUserId = {
			type = "number",
			required = true,
			min = 1,
			customValidator = function(userId)
				local targetPlayer = Players:GetPlayerByUserId(userId)
				if not targetPlayer then
					return false, "Target player not found"
				end
				return true
			end
		},
		reason = {
			type = "string",
			required = false,
			max = 200 -- Limit reason length
		},
		parameters = {
			type = "table",
			required = false
		}
	}
	
	-- Create admin RemoteEvent if it doesn't exist
	local adminEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") and 
		ReplicatedStorage.RemoteEvents:FindFirstChild("AdminEvents")
	
	if adminEvents then
		local adminCommandEvent = adminEvents:FindFirstChild("AdminCommand")
		if adminCommandEvent then
			adminCommandEvent.OnServerEvent:Connect(function(player, command, targetUserId, reason, parameters)
				-- Extra security: Verify player is admin
				local AdminAlert = ServiceLocator.GetService("AdminAlert")
				if not AdminAlert:IsPlayerAdmin(player) then
					-- Non-admin attempting admin command - critical security alert
					AdminAlert:SendAlert("UNAUTHORIZED_ADMIN_ATTEMPT", 
						string.format("Player %s attempted admin command: %s", player.Name, tostring(command)),
						{
							playerId = player.UserId,
							command = command,
							severity = 10
						}
					)
					return
				end
				
				local isValid, sanitizedData = AntiExploit:ValidateRemoteEventCall(
					player,
					"AdminCommand",
					AdminCommandSchema,
					command, targetUserId, reason, parameters
				)
				
				if not isValid then
					-- Admin validation failed - suspicious
					AdminAlert:SendAlert("ADMIN_VALIDATION_FAILED",
						string.format("Admin %s failed validation for command: %s", player.Name, tostring(command)),
						{
							adminId = player.UserId,
							command = command,
							severity = 8
						}
					)
					return
				end
				
				-- Log admin action
				AdminAlert:SendAlert("ADMIN_ACTION_PERFORMED",
					string.format("Admin %s executed: %s on user %d", player.Name, sanitizedData.command, sanitizedData.targetUserId),
					{
						adminId = player.UserId,
						command = sanitizedData.command,
						targetUserId = sanitizedData.targetUserId,
						reason = sanitizedData.reason,
						severity = 3
					}
				)
				
				-- Process the validated admin command
				print(string.format(
					"[ADMIN] %s executed %s on user %d",
					player.Name,
					sanitizedData.command,
					sanitizedData.targetUserId
				))
				
				-- Continue with admin command logic using sanitized data
			end)
		end
	end
	
	print("[Security] Admin events secured with enterprise validation")
end

-- Initialize all security systems
local function InitializeSecurityValidation()
	print("[Security] Initializing enterprise RemoteEvent security...")
	
	-- Wait for services to be available
	task.spawn(function()
		-- Wait for critical services
		local maxWait = 10
		local startTime = tick()
		
		while tick() - startTime < maxWait do
			local AntiExploit = ServiceLocator.GetService("AntiExploit")
			local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
			local AdminAlert = ServiceLocator.GetService("AdminAlert")
			
			if AntiExploit and SecurityValidator and AdminAlert then
				-- All services available, setup security
				SetupCombatEventSecurity()
				SetupUIEventSecurity()
				SetupAdminEventSecurity()
				
				print("[Security] ✅ All RemoteEvents secured with enterprise validation")
				return
			end
			
			task.wait(0.5)
		end
		
		warn("[Security] ❌ Timeout waiting for security services - RemoteEvents may not be fully secured")
	end)
end

-- Auto-initialize when required
InitializeSecurityValidation()

return {
	SetupCombatEventSecurity = SetupCombatEventSecurity,
	SetupUIEventSecurity = SetupUIEventSecurity,
	SetupAdminEventSecurity = SetupAdminEventSecurity
}
