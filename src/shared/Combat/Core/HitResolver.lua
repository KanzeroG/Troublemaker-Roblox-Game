-- HitResolver: satu pintu untuk semua pukulan mengenai target (server-side).
-- Meniru pola HitHandler dari reference, tapi diadaptasi ke WCS.
-- Menangani: parry (perfect timing), block + chip damage, back-attack bypass,
-- guardbreak (mematahkan block), damage penuh, stun, knockback, hit reaction, VFX.
--
-- Pemakaian dari dalam sebuah WCS Skill:
--   local HitResolver = require(.../Combat/HitResolver)
--   HitResolver.resolve(self, victimHumanoid, {
--       Damage = 5, StunDuration = 0.5, Knockback = 10, GuardBreak = false,
--       HitReaction = "light",  -- "light" | "heavy" | "special" | nil
--   })
-- `self` = skill yang memanggil (dipakai untuk damage container + karakter penyerang).

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WCS = require(ReplicatedStorage.Packages.WCS)

local StatusEffects = script.Parent.Parent.StatusEffects
local Blocking = require(StatusEffects.Blocking)
local Parry = require(StatusEffects.Parry)
local Stun = require(StatusEffects.Stun)
local Ragdoll = require(StatusEffects.Ragdoll)

local Remotes = require(script.Parent.Remotes)

--==================================================--
-- KONFIGURASI
--==================================================--

local BLOCK_CHIP_DIVISOR = 5 -- damage tembus block = Damage / ini (min 1)
local BLOCK_MIN_HEALTH_RATIO = 1 / 3 -- di bawah rasio ini, chip damage tidak lagi mengurangi HP
local BLOCK_STUN = 0.3 -- blockstun: blocker diam sebentar tiap kena serang
local GUARDBREAK_STUN = 2 -- stun saat block dipatahkan skill Guardbreak
local GUARD_CRUSH_STUN = 1.5 -- stun saat guard pecah karena terkikis combo (guard HP habis)
local PARRY_ATTACKER_STUN = 1.2 -- stun untuk penyerang yang ke-parry

-- Animasi reaksi kena pukul (opsional). Ganti dengan ID milikmu.
local HIT_REACTION_ANIMS = {
	light = "rbxassetid://0",
	heavy = "rbxassetid://0",
	special = "rbxassetid://0",
}

--==================================================--

local HitResolver = {}

-- true kalau penyerang berada di belakang korban (bypass block)
local function isBehind(attackerRoot: BasePart, victimRoot: BasePart): boolean
	local front = victimRoot.CFrame * CFrame.new(0, 0, -1)
	local behind = victimRoot.CFrame * CFrame.new(0, 0, 1.5)
	return (attackerRoot.Position - front.Position).Magnitude
		> (attackerRoot.Position - behind.Position).Magnitude
end

local function playHitReaction(humanoid: Humanoid, reaction: string?)
	if not reaction then
		return
	end
	local animId = HIT_REACTION_ANIMS[reaction]
	if not animId or animId == "rbxassetid://0" then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
end

local function applyKnockback(victimModel: Model, attackerRoot: BasePart?, knockback)
	if not knockback then
		return
	end

	local direction: Vector3
	if typeof(knockback) == "Vector3" then
		direction = knockback
	elseif typeof(knockback) == "number" and knockback ~= 0 and attackerRoot then
		direction = attackerRoot.CFrame.LookVector * knockback + Vector3.new(0, knockback / 3, 0)
	else
		return
	end

	local player = Players:GetPlayerFromCharacter(victimModel)
	if player then
		-- pemain: kirim ke client biar mulus (movement authoritative di client)
		Remotes.Get("Knockback"):FireClient(player, direction)
	else
		-- NPC: dorong langsung di server
		local root = victimModel:FindFirstChild("HumanoidRootPart")
		if root then
			local attachment = Instance.new("Attachment")
			attachment.Parent = root
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = attachment
			lv.MaxForce = math.huge
			lv.VectorVelocity = direction
			lv.Parent = attachment
			Debris:AddItem(attachment, 0.15)
		end
	end
end

-- Mengembalikan: "parried" | "blocked" | "hit" | nil (kalau tak valid)
function HitResolver.resolve(sourceSkill, victimHumanoid: Humanoid, params)
	if not victimHumanoid or not victimHumanoid.Parent or victimHumanoid.Health <= 0 then
		return nil
	end

	local attackerChar = sourceSkill.Character
	local attackerModel = attackerChar and attackerChar.Instance
	local attackerRoot = attackerModel and attackerModel:FindFirstChild("HumanoidRootPart")

	-- penyerang yang sedang di-stun tidak menghasilkan hit
	if attackerChar and #attackerChar:GetAllActiveStatusEffectsOfType(Stun) > 0 then
		return nil
	end

	local victimModel = victimHumanoid.Parent
	local victimRoot = victimModel:FindFirstChild("HumanoidRootPart")
	local victimChar = WCS.Character.GetCharacterFromInstance(victimModel)

	local guardBreak = params.GuardBreak == true
	local back = (attackerRoot and victimRoot) and isBehind(attackerRoot, victimRoot) or false

	local isParrying = victimChar and #victimChar:GetAllActiveStatusEffectsOfType(Parry) > 0
	local isBlocking = victimChar and #victimChar:GetAllActiveStatusEffectsOfType(Blocking) > 0

	local VFX = Remotes.Get("VFX")

	-- ===== PARRY: negasi total + counter (stun penyerang) =====
	if isParrying and not guardBreak and not back then
		VFX:FireAllClients("Parry", victimModel)
		if attackerChar then
			Stun.new(attackerChar):Start(PARRY_ATTACKER_STUN)
			if attackerModel then
				VFX:FireAllClients("Stun", attackerModel, PARRY_ATTACKER_STUN)
			end
		end
		return "parried"
	end

	-- ===== BLOCK: kikis guard HP; kalau habis -> guard crush =====
	local guardCrushed = false
	if isBlocking and not guardBreak and not back then
		local blockingEffect = victimChar:GetAllActiveStatusEffectsOfType(Blocking)[1]
		blockingEffect.GuardHealth = (blockingEffect.GuardHealth or blockingEffect.MaxGuardHealth or 0)
			- params.Damage

		if blockingEffect.GuardHealth > 0 then
			-- guard masih kuat: chip damage + blockstun
			local chip = math.max(1, math.round(params.Damage / BLOCK_CHIP_DIVISOR))
			if victimHumanoid.Health > victimHumanoid.MaxHealth * BLOCK_MIN_HEALTH_RATIO then
				victimHumanoid:TakeDamage(chip)
			end
			Stun.new(victimChar):Start(BLOCK_STUN)
			VFX:FireAllClients("Block", victimModel)
			VFX:FireAllClients("GuardBar", victimModel, blockingEffect.GuardHealth / blockingEffect.MaxGuardHealth)
			return "blocked"
		end

		-- guard HP habis: pecah! lepaskan block + hit ini masuk penuh
		guardCrushed = true
	end

	-- ===== GUARD PECAH (skill Guardbreak ATAU terkikis combo): lepaskan block =====
	if (guardBreak or guardCrushed) and isBlocking then
		for _, effect in victimChar:GetAllActiveStatusEffectsOfType(Blocking) do
			effect:Destroy()
		end
		-- hentikan juga skill Block-nya (biar tidak "menahan" tanpa efek)
		local blockSkill = victimChar:GetSkillFromString("Block")
		if blockSkill then
			blockSkill:End()
		end
		VFX:FireAllClients("GuardBreak", victimModel)
	end

	-- ===== HIT PENUH =====
	if victimChar then
		-- lewat WCS supaya status effect lain (buff/debuff) tetap terhitung;
		-- pengurangan HP dilakukan di CombatService (listener DamageTaken).
		victimChar:TakeDamage(sourceSkill:CreateDamageContainer(params.Damage))
	else
		-- target tanpa WCS (NPC dummy): damage langsung
		victimHumanoid:TakeDamage(params.Damage)
	end

	VFX:FireAllClients("Hit", victimModel)

	if params.RagdollDuration and params.RagdollDuration > 0 and victimChar then
		-- ragdoll menggantikan stun (ragdoll sudah bikin tak bisa gerak).
		-- jangan tumpuk kalau sudah ragdoll.
		if #victimChar:GetAllActiveStatusEffectsOfType(Ragdoll) == 0 then
			Ragdoll.new(victimChar):Start(params.RagdollDuration)
		end
		VFX:FireAllClients("Stun", victimModel, params.RagdollDuration)
	else
		local stunDuration = params.StunDuration
		if guardBreak then
			stunDuration = GUARDBREAK_STUN
		elseif guardCrushed then
			stunDuration = GUARD_CRUSH_STUN
		end
		if stunDuration and stunDuration > 0 and victimChar then
			Stun.new(victimChar):Start(stunDuration)
			VFX:FireAllClients("Stun", victimModel, stunDuration)
		end
	end

	applyKnockback(victimModel, attackerRoot, params.Knockback)
	playHitReaction(victimHumanoid, params.HitReaction)

	return "hit"
end

return HitResolver
