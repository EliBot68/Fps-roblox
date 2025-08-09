--[[
	WeaponIcons.lua
	Place in: StarterGui/WeaponUI/
	
	Creates and manages weapon icons display showing equipped weapons
	and their visual representations in the UI slots.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for weapon system
local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Modules = WeaponSystem:WaitForChild("Modules")
local WeaponDefinitions = require(Modules:WaitForChild("WeaponDefinitions"))

local WeaponIcons = {}

-- Weapon icon mappings (using text icons for now)
local WEAPON_ICONS = {
	-- Primary weapons
	AssaultRifle = "🔫",
	SMG = "💥",
	Shotgun = "🎯",
	Sniper = "🔭",
	
	-- Secondary weapons
	Pistol = "🔫",
	
	-- Melee weapons
	CombatKnife = "🗡️",
	Axe = "🪓",
	ThrowingKnife = "🥷"
}

-- Weapon category colors
local CATEGORY_COLORS = {
	AssaultRifle = Color3.new(0.8, 0.4, 0.2), -- Orange
	SMG = Color3.new(1, 1, 0), -- Yellow
	Shotgun = Color3.new(1, 0, 0), -- Red
	Sniper = Color3.new(0, 0, 1), -- Blue
	Pistol = Color3.new(0.5, 0.5, 0.5), -- Gray
	Melee = Color3.new(0.6, 0.3, 0.1), -- Brown
	Throwable = Color3.new(0.8, 0, 0.8) -- Purple
}

-- Update weapon icon in slot
function WeaponIcons.UpdateSlotIcon(slot: string, weaponId: string?)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local slotsFrame = weaponUI:FindFirstChild("SlotsFrame")
	if not slotsFrame then return end
	
	local slotFrame = slotsFrame:FindFirstChild(slot .. "Slot")
	if not slotFrame then return end
	
	-- Find icon label (the weapon icon display)
	local iconLabel = slotFrame:FindFirstChild("TextLabel")
	if not iconLabel then return end
	
	if weaponId then
		local weapon = WeaponDefinitions.GetWeapon(weaponId)
		if weapon then
			-- Set weapon icon
			iconLabel.Text = WEAPON_ICONS[weaponId] or "⚔️"
			
			-- Set color based on category
			local categoryColor = CATEGORY_COLORS[weapon.Category] or Color3.new(0.8, 0.8, 0.8)
			iconLabel.TextColor3 = categoryColor
			
			-- Update slot background color slightly
			slotFrame.BackgroundColor3 = Color3.new(
				categoryColor.R * 0.3,
				categoryColor.G * 0.3,
				categoryColor.B * 0.3
			)
		end
	else
		-- Empty slot
		iconLabel.Text = "❌"
		iconLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
		slotFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	end
end

-- Create weapon tooltip
function WeaponIcons.CreateWeaponTooltip(weaponId: string): Frame?
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then return nil end
	
	-- Create tooltip frame
	local tooltip = Instance.new("Frame")
	tooltip.Name = "WeaponTooltip"
	tooltip.Size = UDim2.new(0, 250, 0, 120)
	tooltip.BackgroundColor3 = Color3.new(0, 0, 0)
	tooltip.BackgroundTransparency = 0.2
	tooltip.BorderSizePixel = 1
	tooltip.BorderColor3 = Color3.new(1, 1, 1)
	tooltip.ZIndex = 10
	
	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 6)
	tooltipCorner.Parent = tooltip
	
	-- Weapon name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0, 25)
	nameLabel.Position = UDim2.new(0, 5, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = weapon.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = tooltip
	
	-- Weapon stats
	local statsText = string.format(
		"Damage: %d\nFire Rate: %.1f RPS\nRange: %d\nMagazine: %d",
		weapon.Damage,
		weapon.FireRate,
		weapon.Range,
		weapon.MagazineSize >= 999 and "∞" or weapon.MagazineSize
	)
	
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, -10, 1, -35)
	statsLabel.Position = UDim2.new(0, 5, 0, 30)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = statsText
	statsLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.SourceSans
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Parent = tooltip
	
	return tooltip
end

-- Show weapon tooltip on hover
function WeaponIcons.ShowTooltip(slot: string, weaponId: string)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	-- Remove existing tooltip
	local existingTooltip = weaponUI:FindFirstChild("WeaponTooltip")
	if existingTooltip then
		existingTooltip:Destroy()
	end
	
	-- Create new tooltip
	local tooltip = WeaponIcons.CreateWeaponTooltip(weaponId)
	if not tooltip then return end
	
	-- Position tooltip above slot
	local slotsFrame = weaponUI:FindFirstChild("SlotsFrame")
	if slotsFrame then
		local slotFrame = slotsFrame:FindFirstChild(slot .. "Slot")
		if slotFrame then
			tooltip.Position = UDim2.new(
				slotFrame.Position.X.Scale,
				slotFrame.Position.X.Offset - 80,
				0, -140
			)
		end
	end
	
	tooltip.Parent = weaponUI
end

-- Hide weapon tooltip
function WeaponIcons.HideTooltip()
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local tooltip = weaponUI:FindFirstChild("WeaponTooltip")
	if tooltip then
		tooltip:Destroy()
	end
end

-- Set up tooltip interactions for slots
function WeaponIcons.SetupTooltipInteractions()
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local slotsFrame = weaponUI:FindFirstChild("SlotsFrame")
	if not slotsFrame then return end
	
	for _, slotFrame in ipairs(slotsFrame:GetChildren()) do
		if slotFrame:IsA("Frame") and slotFrame.Name:find("Slot") then
			local slotName = slotFrame.Name:gsub("Slot", "")
			
			-- Mouse enter
			slotFrame.MouseEnter:Connect(function()
				-- Get current weapon for this slot (would need weapon state)
				-- For now, just show placeholder
				print("Show tooltip for", slotName, "slot")
			end)
			
			-- Mouse leave
			slotFrame.MouseLeave:Connect(function()
				WeaponIcons.HideTooltip()
			end)
		end
	end
end

-- Update all weapon icons based on loadout
function WeaponIcons.UpdateAllIcons(weaponLoadout)
	if not weaponLoadout then return end
	
	-- Update each slot
	WeaponIcons.UpdateSlotIcon("Primary", weaponLoadout.Primary)
	WeaponIcons.UpdateSlotIcon("Secondary", weaponLoadout.Secondary)
	WeaponIcons.UpdateSlotIcon("Melee", weaponLoadout.Melee)
end

-- Create damage indicator
function WeaponIcons.ShowDamageIndicator(damage: number, isHeadshot: boolean?)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	-- Create damage indicator
	local damageFrame = Instance.new("Frame")
	damageFrame.Size = UDim2.new(0, 100, 0, 40)
	damageFrame.Position = UDim2.new(0.5, -50, 0.5, -100)
	damageFrame.BackgroundTransparency = 1
	damageFrame.Parent = weaponUI
	
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Size = UDim2.new(1, 0, 1, 0)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = "-" .. damage .. (isHeadshot and " HS!" or "")
	damageLabel.TextColor3 = isHeadshot and Color3.new(1, 0, 0) or Color3.new(1, 1, 0)
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.SourceSansBold
	damageLabel.TextStrokeTransparency = 0
	damageLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	damageLabel.Parent = damageFrame
	
	-- Animate damage indicator
	local TweenService = game:GetService("TweenService")
	
	-- Scale and fade animation
	local scaleTween = TweenService:Create(
		damageLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	
	local fadeTween = TweenService:Create(
		damageLabel,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.5),
		{TextTransparency = 1, Position = UDim2.new(0.5, -50, 0.5, -150)}
	)
	
	scaleTween:Play()
	fadeTween:Play()
	
	-- Clean up after animation
	fadeTween.Completed:Connect(function()
		damageFrame:Destroy()
	end)
end

-- Initialize weapon icons system
task.spawn(function()
	-- Wait for UI to be created
	repeat
		task.wait(0.1)
	until PlayerGui:FindFirstChild("WeaponUI")
	
	-- Set up tooltip interactions
	WeaponIcons.SetupTooltipInteractions()
end)

-- Listen for weapon state changes
local WeaponEvents = ReplicatedStorage:WaitForChild("WeaponEvents")
local WeaponStateRemote = WeaponEvents:WaitForChild("WeaponState")

WeaponStateRemote.OnClientEvent:Connect(function(data)
	if data.Type == "WeaponFired" and data.Hits then
		-- Show damage indicators for hits
		for _, hit in ipairs(data.Hits) do
			if hit.Type == "PlayerHit" and hit.Damage then
				WeaponIcons.ShowDamageIndicator(hit.Damage, hit.Headshot)
			end
		end
	elseif data.Primary or data.Secondary or data.Melee then
		-- Full loadout update
		WeaponIcons.UpdateAllIcons(data)
	end
end)

print("WeaponIcons system initialized")

return WeaponIcons
