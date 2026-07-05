-- Blocking: aktif selama pemain menahan tombol block (dipicu skill Block).
-- Punya GUARD HP: tiap serangan yang diblok mengikis GuardHealth (lihat HitResolver);
-- kalau habis -> guard pecah (guard crush): block lepas + stun, seperti kena Guardbreak.
-- Semua logika damage diurus di HitResolver, bukan di sini.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local BLOCK_WALKSPEED = 6 -- kecepatan jalan saat block (jauh lebih lambat)
local GUARD_MAX_HEALTH = 35 -- total damage yang bisa ditahan sebelum guard pecah
-- (M1 Brawler = 4+4+5+9 per combo -> guard pecah di tengah combo kedua)

local Blocking = WCS.RegisterStatusEffect("Blocking")

function Blocking:OnConstructServer()
	self.GuardHealth = GUARD_MAX_HEALTH
	self.MaxGuardHealth = GUARD_MAX_HEALTH

	self:SetHumanoidData({
		WalkSpeed = { BLOCK_WALKSPEED, "Set" },
		JumpPower = { 0, "Set" },
		JumpHeight = { 0, "Set" },
	})
end

return Blocking
