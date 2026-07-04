-- M1: melee combo 4 hit.
-- Hit 1-3  : damage kecil + Stun singkat (combo nyambung)
-- Hit 4    : finisher -- damage besar + knockback + Ragdoll
-- Combo reset kalau tidak menyerang selama COMBO_RESET_TIME.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Stun = require(script.Parent.Parent.StatusEffects.Stun)
local Ragdoll = require(script.Parent.Parent.StatusEffects.Ragdoll)

--==================================================--
-- KONFIGURASI (silakan tweak)
--==================================================--

-- GANTI dengan animation ID milikmu. Selama masih 0, skill tetap jalan tanpa animasi.
local ANIMATIONS = {
	"rbxassetid://0", -- M1_1 : jab kiri
	"rbxassetid://0", -- M1_2 : cross kanan
	"rbxassetid://0", -- M1_3 : hook / tendangan
	"rbxassetid://0", -- M1_4 : finisher (heavy)
}

local DAMAGE = { 2, 2, 3, 6 } -- damage per hit combo
local COMBO_RESET_TIME = 1.2 -- detik idle sebelum combo balik ke 1
local HIT_DELAY = 0.25 -- windup: jeda sebelum hitbox aktif (sinkronkan dengan animasi)
local M1_COOLDOWN = 0.35 -- jeda antar M1 biasa
local FINISHER_COOLDOWN = 1.0 -- jeda setelah finisher
local STUN_DURATION = 0.4 -- durasi stun hit 1-3
local RAGDOLL_DURATION = 1.5 -- durasi ragdoll finisher
local KNOCKBACK_FORCE = 55 -- dorongan horizontal finisher
local KNOCKBACK_UP = 20 -- dorongan vertikal finisher
local HITBOX_SIZE = Vector3.new(4.5, 5, 5)
local HITBOX_OFFSET = -3 -- stud di depan HumanoidRootPart

--==================================================--

local M1 = WCS.RegisterSkill("M1")

-- Jangan bisa menyerang saat sedang kena Stun / Ragdoll
function M1:ShouldStart()
	local character = self.Character
	return #character:GetAllActiveStatusEffectsOfType(Stun) == 0
		and #character:GetAllActiveStatusEffectsOfType(Ragdoll) == 0
end

function M1:OnStartServer()
	local characterModel = self.Character.Instance
	local humanoid = characterModel and characterModel:FindFirstChildOfClass("Humanoid")
	local rootPart = characterModel and characterModel:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		self:End()
		return
	end

	-- hitung index combo (1..4), reset kalau kelamaan idle
	local now = os.clock()
	if now - (self._lastUse or 0) > COMBO_RESET_TIME then
		self._combo = 0
	end
	self._combo = (self._combo or 0) % #ANIMATIONS + 1
	self._lastUse = now
	local comboIndex = self._combo

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
	task.wait(HIT_DELAY)

	-- hitbox kotak di depan pemain
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { characterModel }

	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, HITBOX_OFFSET)
	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, overlapParams)

	-- kumpulkan target unik (model ber-Humanoid)
	local hitTargets = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		if model and targetHumanoid and targetHumanoid.Health > 0 and not hitTargets[model] then
			hitTargets[model] = targetHumanoid
		end
	end

	local lookDirection = rootPart.CFrame.LookVector

	for targetModel, targetHumanoid in hitTargets do
		local targetWcs = WCS.Character.GetCharacterFromInstance(targetModel)
		if targetWcs then
			targetWcs:TakeDamage(self:CreateDamageContainer(DAMAGE[comboIndex]))

			if comboIndex < #ANIMATIONS then
				Stun.new(targetWcs):Start(STUN_DURATION)
			else
				Ragdoll.new(targetWcs):Start(RAGDOLL_DURATION)
			end
		else
			-- target tanpa WCS (misal NPC dummy biasa): damage langsung
			targetHumanoid:TakeDamage(DAMAGE[comboIndex])
		end

		-- knockback saat finisher (berlaku juga untuk NPC)
		if comboIndex == #ANIMATIONS then
			local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				targetRoot.AssemblyLinearVelocity = lookDirection * KNOCKBACK_FORCE
					+ Vector3.new(0, KNOCKBACK_UP, 0)
			end
		end
	end

	self:ApplyCooldown(comboIndex == #ANIMATIONS and FINISHER_COOLDOWN or M1_COOLDOWN)
	self:End()
end

return M1
