-- Blocking: aktif selama pemain menahan tombol block (dipicu skill Block).
-- Cuma memperlambat gerak + jadi penanda "sedang block" yang di-query HitResolver.
-- Semua logika damage/chip/guardbreak diurus di HitResolver, bukan di sini,
-- supaya tidak double-handle dengan WCS PredictDamage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local BLOCK_WALKSPEED = 6 -- kecepatan jalan saat block (jauh lebih lambat)

local Blocking = WCS.RegisterStatusEffect("Blocking")

function Blocking:OnConstructServer()
	self:SetHumanoidData({
		WalkSpeed = { BLOCK_WALKSPEED, "Set" },
		JumpPower = { 0, "Set" },
		JumpHeight = { 0, "Set" },
	})
end

return Blocking
