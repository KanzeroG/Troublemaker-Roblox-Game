-- Guardbreak: serangan bertanda "!" yang MEMATAHKAN block lawan (lalu tetap kena hit penuh).
-- Ada telegraph (tanda "!" di atas kepala) selama windup supaya lawan bisa bereaksi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Combat = script.Parent.Parent.Parent
local Hitbox = require(Combat.Core.Hitbox)
local HitResolver = require(Combat.Core.HitResolver)
local Remotes = require(Combat.Core.Remotes)
local Stun = require(Combat.StatusEffects.Stun)
local Blocking = require(Combat.StatusEffects.Blocking)

--==================================================--
local GB_ANIM = "rbxassetid://0" -- GANTI dengan animasi guardbreak-mu
local WINDUP = 0.45 -- telegraph "!" sebelum hitbox aktif
local HITBOX_ACTIVE = 0.2
local COOLDOWN = 8
local SIZE = Vector3.new(5, 5, 5.5)
local OFFSET = CFrame.new(0, 0, -3)
local DAMAGE = 12
local STUN = 0.7
local KNOCKBACK = 40
--==================================================--

local Guardbreak = WCS.RegisterSkill("Guardbreak")

function Guardbreak:ShouldStart()
	local character = self.Character
	return #character:GetAllActiveStatusEffectsOfType(Stun) == 0
		and #character:GetAllActiveStatusEffectsOfType(Blocking) == 0
end

function Guardbreak:OnStartServer()
	local characterModel = self.Character.Instance
	local humanoid = characterModel and characterModel:FindFirstChildOfClass("Humanoid")
	local rootPart = characterModel and characterModel:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		self:End()
		return
	end

	-- animasi + telegraph "!"
	if GB_ANIM ~= "rbxassetid://0" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = GB_ANIM
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
		end
	end
	Remotes.Get("VFX"):FireAllClients("GuardBreakWindup", characterModel, WINDUP)

	task.wait(WINDUP)

	local box = Hitbox.Create(SIZE, rootPart, OFFSET)
	box.Touched:Connect(function(_hitPart, victimHumanoid)
		if victimHumanoid == humanoid then
			return
		end
		HitResolver.resolve(self, victimHumanoid, {
			Damage = DAMAGE,
			StunDuration = STUN,
			Knockback = KNOCKBACK,
			GuardBreak = true,
			HitReaction = "heavy",
		})
	end)

	box:Start()
	task.wait(HITBOX_ACTIVE)
	box:Stop()

	self:ApplyCooldown(COOLDOWN)
	self:End()
end

return Guardbreak
