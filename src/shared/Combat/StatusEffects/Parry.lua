-- Parry: penanda jendela parry (perfect-timing) yang aktif sebentar saat block
-- baru dimulai. Kalau kena serang selama efek ini aktif -> serangan dinegasikan
-- dan penyerang kena stun (lihat HitResolver). Murni penanda, tanpa humanoid data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Parry = WCS.RegisterStatusEffect("Parry")

return Parry
