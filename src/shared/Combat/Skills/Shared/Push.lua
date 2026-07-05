local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Combat = script.Parent.Parent.Parent
local Hitbox = require(Combat.Core.Hitbox)
local HitResolver = require(Combat.Core.HitResolver)
local AnimationProvider = require(Combat.Core.AnimationProvider)
local Stun = require(Combat.StatusEffects.Stun)
local Blocking = require(Combat.StatusEffects.Blocking)
local PushConfig = require(ReplicatedStorage.Shared.Template.Push)

local Push = WCS.RegisterSkill("Push")

function Push:ShouldStart()
	local character = self.Character
	return #character:GetAllActiveStatusEffectsOfType(Stun) == 0
		and #character:GetAllActiveStatusEffectsOfType(Blocking) == 0
end

function Push:OnStartServer()
	local characterModel = self.Character.Instance
	local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
	local rootPart = characterModel:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		self:End()
		return
	end

	-- Play the Push animation (resolved dynamically from Shared animations folder)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = AnimationProvider.getShared("Push")
		if animation then
			local track = animator:LoadAnimation(animation)
			if track then
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
			end
		end
	end

	-- Windup before hitbox becomes active
	task.wait(0.1)

	-- Create the push hitbox in front of the player
	local box = Hitbox.Create(PushConfig.Size, rootPart, PushConfig.Offset)
	box.Touched:Connect(function(_hitPart, victimHumanoid)
		if victimHumanoid == humanoid then
			return
		end

		-- Resolve the hit (Push doesn't break guard, it just knocks back)
		HitResolver.resolve(self, victimHumanoid, {
			Damage = PushConfig.Damage,
			StunDuration = PushConfig.StunDuration,
			RagdollDuration = PushConfig.RagdollDuration,
			Knockback = PushConfig.Knockback,
			HitReaction = "2", -- plays right/medium reaction
		})
	end)

	box:Start()
	task.wait(0.2)
	box:Stop()

	self:ApplyCooldown(PushConfig.PushCooldown)
	self:End()
end

function Push:GetCooldown()
	return PushConfig.PushCooldown
end

return Push
