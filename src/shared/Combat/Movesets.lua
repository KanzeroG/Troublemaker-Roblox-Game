-- Movesets: definisi fighting style (WCS Moveset = nama + daftar skill).
-- Satu style = satu moveset. Server memberi style ke pemain lewat
-- wcsCharacter:ApplyMoveset(Movesets.NamaStyle) -- ganti style tinggal Apply lagi
-- (WCS otomatis membersihkan skill style lama).
--
-- CARA MENAMBAH FIGHTING STYLE BARU:
--   1. Buat folder baru di Skills/<NamaStyle>/ berisi skill khas style itu
--   2. Skill umum (Block, nanti Dash, dll) ada di Skills/Shared -- ikutkan di daftar
--   3. Daftarkan moveset baru di bawah
--   4. Selesai -- CombatService.RegisterDirectory sudah scan semua subfolder Skills

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Skills = script.Parent.Skills

-- Shared (semua style punya)
local Block = require(Skills.Shared.Block)
local Push = require(Skills.Shared.Push)

-- Brawler (tangan kosong)
local M1 = require(Skills.Brawler.M1)
local Guardbreak = require(Skills.Brawler.Guardbreak)

local Movesets = {
	Brawler = WCS.CreateMoveset("Brawler", {
		M1,
		Guardbreak,
		Block,
		Push,
	}),

	-- Contoh style berikutnya:
	-- Swordsman = WCS.CreateMoveset("Swordsman", { SwordM1, SwordParry, Block }),
}

return Movesets
