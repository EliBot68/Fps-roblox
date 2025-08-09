-- WeaponConfig.lua
-- Stats per weapon (expanded)

local WeaponConfig = {
	AssaultRifle = {
		Id = "AssaultRifle",
		Damage = 25,
		FireRate = 8, -- rounds per second
		MagazineSize = 30,
		ReloadTime = 2.2,
		Range = 300,
		Spread = 2.5, -- degrees
		Recoil = 1.2,
		Class = "AR",
		Cost = 0,
	},
	SMG = {
		Id = "SMG",
		Damage = 18,
		FireRate = 12,
		MagazineSize = 40,
		ReloadTime = 2.0,
		Range = 200,
		Spread = 4.0,
		Recoil = 0.9,
		Class = "SMG",
		Cost = 500,
	},
	Shotgun = {
		Id = "Shotgun",
		Damage = 12, -- per pellet (simplified single ray for now)
		FireRate = 1.2,
		MagazineSize = 8,
		ReloadTime = 3.0,
		Range = 120,
		Spread = 6.0,
		Recoil = 2.5,
		Class = "Shotgun",
		Cost = 800,
	},
	Sniper = {
		Id = "Sniper",
		Damage = 80,
		FireRate = 0.8,
		MagazineSize = 5,
		ReloadTime = 2.8,
		Range = 800,
		Spread = 0.5,
		Recoil = 3.2,
		Class = "Sniper",
		Cost = 1200,
	},
	Pistol = {
		Id = "Pistol",
		Damage = 22,
		FireRate = 4.5,
		MagazineSize = 12,
		ReloadTime = 1.6,
		Range = 180,
		Spread = 3.0,
		Recoil = 0.6,
		Class = "Pistol",
		Cost = 0,
	},
}

return WeaponConfig
