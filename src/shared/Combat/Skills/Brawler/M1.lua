-- M1: melee combo 4 hit (hitbox EZ Hitbox yang mengikuti pemain via wrapper Core/Hitbox,
-- damage/stun/knockback lewat HitResolver sehingga block/parry/guardbreak otomatis berlaku).
-- Hit 1-3 : damage kecil + stun singkat (combo nyambung)
-- Hit 4   : finisher -- damage besar + knockback kuat
-- Combo reset kalau tidak menyerang selama COMBO_RESET_TIME.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Combat = script.Parent.Parent.Parent
local Hitbox = require(Combat.Core.Hitbox)
local HitResolver = require(Combat.Core.HitResolver)
local Stun = require(Combat.StatusEffects.Stun)
local Blocking = require(Combat.StatusEffects.Blocking)

--==================================================--
-- KONFIGURASI (silakan tweak)
--==================================================--

-- GANTI dengan animation ID milikmu. Selama masih 0, skill tetap jalan tanpa animasi.
local ANIMATIONS = {
	"rbxassetid://103345170539869", -- M1_1 : jab kiri
	"rbxassetid://110981237071409", -- M1_2 : cross kanan
	"rbxassetid://84999084297864", -- M1_3 : hook / tendangan
	"rbxassetid://95539017376715", -- M1_4 : finisher (heavy)
}

-- Parameter per-hit combo. Size/Offset = bentuk & posisi hitbox (mengikuti HumanoidRootPart).
local COMBO = {
	{ Size = Vector3.new(4, 4.5, 4.5), Offset = CFrame.new(0, 0, -2.5), Damage = 4, Stun = 0.35, Knockback = 6, Reaction = "light" },
	{ Size = Vector3.new(4, 4.5, 4.5), Offset = CFrame.new(0, 0.3, -2.5), Damage = 4, Stun = 0.35, Knockback = 6, Reaction = "light" },
	{ Size = Vector3.new(4.5, 4.5, 5), Offset = CFrame.new(0, 0, -2.7), Damage = 5, Stun = 0.4, Knockback = 8, Reaction = "light" },
	{ Size = Vector3.new(5, 5, 5.5), Offset = CFrame.new(0, 0.2, -3), Damage = 9, Knockback = 45, Ragdoll = 1.5, Reaction = "heavy" },
}

local MAX_COMBO = #COMBO
local COMBO_RESET_TIME = 1.2 -- detik idle sebelum combo balik ke 1
local WINDUP = 0.15 -- jeda sebelum hitbox aktif (sinkronkan dengan animasi)
local HITBOX_ACTIVE = 0.15 -- lama hitbox menyala
local M1_COOLDOWN = 0.32 -- jeda antar M1 biasa
local FINISHER_COOLDOWN = 0.9 -- jeda setelah finisher

--==================================================--

local M1 = WCS.RegisterSkill("M1")

-- Tidak bisa menyerang saat stun atau saat sedang block
function M1:ShouldStart()
	local character = self.Character
	return #character:GetAllActiveStatusEffectsOfType(Stun) == 0
		and #character:GetAllActiveStatusEffectsOfType(Blocking) == 0
end

function M1:OnStartServer()
	local characterModel = self.Character.Instance
	local humanoid = characterModel and characterModel:FindFirstChildOfClass("Humanoid")
	local rootPart = characterModel and characterModel:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		self:End()
		return
	end

	-- hitung index combo (1..MAX_COMBO), reset kalau kelamaan idle
	local now = os.clock()
	if now - (self._lastUse or 0) > COMBO_RESET_TIME then
		self._combo = 0
	end
	self._combo = (self._combo or 0) % MAX_COMBO + 1
	self._lastUse = now
	local comboIndex = self._combo
	local data = COMBO[comboIndex]

	-- mainkan animasi (di-load server-side, otomatis tereplikasi)
	local animationId = ANIMATIONS[comboIndex]
	if animationId and animationId ~= "rbxassetid://0" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = animationId
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
		end
	end

	-- windup sebelum hitbox aktif
	task.wait(WINDUP)

	-- hitbox statis di depan rootPart (tidak mengikuti pergerakan pemain saat aktif)
	local box = Hitbox.Create(data.Size, rootPart, data.Offset)
	box.Touched:Connect(function(_hitPart, victimHumanoid)
		if victimHumanoid == humanoid then
			return
		end
		HitResolver.resolve(self, victimHumanoid, {
			Damage = data.Damage,
			StunDuration = data.Stun,
			Knockback = data.Knockback,
			RagdollDuration = data.Ragdoll,
			GuardBreak = false,
			HitReaction = data.Reaction,
		})
	end)

	box:Start()
	task.wait(HITBOX_ACTIVE)
	box:Stop()

	self:ApplyCooldown(comboIndex == MAX_COMBO and FINISHER_COOLDOWN or M1_COOLDOWN)
	self:End()
end

return M1
