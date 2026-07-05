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
local AnimationProvider = require(Combat.Core.AnimationProvider)

--==================================================--
-- KONFIGURASI (silakan tweak)
--==================================================--

-- Parameter per-hit combo. Size/Offset = bentuk & posisi hitbox (mengikuti HumanoidRootPart).
local COMBO = {
	{ Size = Vector3.new(4, 4.5, 4.5), Offset = CFrame.new(0, 0, -2.5), Damage = 4, Stun = 0.35, Knockback = 6, Reaction = "1" },
	{ Size = Vector3.new(4, 4.5, 4.5), Offset = CFrame.new(0, 0.3, -2.5), Damage = 4, Stun = 0.35, Knockback = 6, Reaction = "2" },
	{ Size = Vector3.new(4.5, 4.5, 5), Offset = CFrame.new(0, 0, -2.7), Damage = 5, Stun = 0.4, Knockback = 8, Reaction = "1" },
	{ Size = Vector3.new(5, 5, 5.5), Offset = CFrame.new(0, 0.2, -3), Damage = 9, Knockback = 45, Ragdoll = 1.5, Reaction = "2" },
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
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local style = characterModel:GetAttribute("Style") or "Melee"
		local animation = AnimationProvider.get(style, "M1_" .. comboIndex)
		if animation then
			local track = animator:LoadAnimation(animation)
			if track then
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
			end
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
