-- Block: HoldableSkill. Tahan tombol -> mulai block; lepas -> berhenti.
-- Detik-detik pertama block = jendela PARRY (perfect timing) -- lihat HitResolver.
-- Semua efek damage diurus HitResolver; skill ini hanya menyalakan status Blocking + Parry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Combat = script.Parent.Parent.Parent
local Blocking = require(Combat.StatusEffects.Blocking)
local Parry = require(Combat.StatusEffects.Parry)
local Stun = require(Combat.StatusEffects.Stun)

--==================================================--
local PARRY_WINDOW = 0.25 -- detik pertama block yang menghitung sebagai parry
local BLOCK_ANIM = "rbxassetid://0" -- GANTI dengan animasi block-mu
--==================================================--

local Block = WCS.RegisterHoldableSkill("Block")

function Block:ShouldStart()
	return #self.Character:GetAllActiveStatusEffectsOfType(Stun) == 0
end

function Block:OnStartServer()
	local character = self.Character

	-- status block: aktif sampai di-Destroy (tombol dilepas)
	self._blockingEffect = Blocking.new(character)
	self._blockingEffect:Start()

	-- jendela parry singkat di awal
	Parry.new(character):Start(PARRY_WINDOW)

	-- animasi block (opsional)
	if BLOCK_ANIM ~= "rbxassetid://0" then
		local model = character.Instance
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = BLOCK_ANIM
			self._blockTrack = animator:LoadAnimation(animation)
			self._blockTrack.Priority = Enum.AnimationPriority.Action
			self._blockTrack.Looped = true
			self._blockTrack:Play()
		end
	end
end

function Block:OnEndServer()
	if self._blockingEffect and not self._blockingEffect:IsDestroyed() then
		self._blockingEffect:Destroy()
	end
	self._blockingEffect = nil

	if self._blockTrack then
		self._blockTrack:Stop()
		self._blockTrack = nil
	end
end

return Block
