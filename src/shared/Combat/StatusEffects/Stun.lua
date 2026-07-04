-- Stun: korban tidak bisa jalan/lompat selama durasi efek.
-- Dipakai saat kena M1 hit 1-3 supaya combo bisa nyambung.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Stun = WCS.RegisterStatusEffect("Stun")

function Stun:OnConstructServer()
	self:SetHumanoidData({
		WalkSpeed = { 0, "Set" },
		JumpPower = { 0, "Set" },
		JumpHeight = { 0, "Set" },
	})
end

return Stun
