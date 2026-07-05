-- Ragdoll: mengganti semua Motor6D dengan BallSocketConstraint (physics ragdoll),
-- lalu memulihkannya saat efek berakhir. Dipakai oleh finisher M1 (hit ke-4).
-- Tidak butuh animasi -- murni physics.
--
-- PENTING soal jatuh: karakter pemain disimulasikan oleh CLIENT-nya (network owner),
-- jadi ChangeState dari server tidak mempan -- humanoid tetap menegakkan badan.
-- Solusi: PlatformStand=true (property, tereplikasi) + remote ke client korban
-- supaya dia sendiri masuk state Physics. NPC cukup dari server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WCS = require(ReplicatedStorage.Packages.WCS)

local Remotes = require(script.Parent.Parent.Core.Remotes)

local Ragdoll = WCS.RegisterStatusEffect("Ragdoll")

function Ragdoll:OnConstructServer()
	self:SetHumanoidData({
		WalkSpeed = { 0, "Set" },
		JumpPower = { 0, "Set" },
		JumpHeight = { 0, "Set" },
	})
end

function Ragdoll:OnStartServer()
	local model = self.Character.Instance
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	self._joints = {}

	-- matikan gaya berdiri humanoid (property -> tereplikasi ke client pemilik)
	humanoid.RequiresNeck = false -- neck Motor6D kita disable; jangan sampai dianggap mati
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- efektif untuk NPC (server-owned)

	-- pemain: suruh client-nya sendiri masuk state Physics (dia network owner)
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		Remotes.Get("Ragdoll"):FireClient(player, true)
	end

	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local attachment0 = Instance.new("Attachment")
			attachment0.CFrame = motor.C0
			attachment0.Parent = motor.Part0

			local attachment1 = Instance.new("Attachment")
			attachment1.CFrame = motor.C1
			attachment1.Parent = motor.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = motor.Part1

			motor.Enabled = false

			table.insert(self._joints, {
				Motor = motor,
				Socket = socket,
				Attachment0 = attachment0,
				Attachment1 = attachment1,
			})
		end
	end
end

function Ragdoll:OnEndServer()
	local model = self.Character.Instance
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")

	for _, joint in self._joints or {} do
		if joint.Motor and joint.Motor.Parent then
			joint.Motor.Enabled = true
		end
		joint.Socket:Destroy()
		joint.Attachment0:Destroy()
		joint.Attachment1:Destroy()
	end
	self._joints = nil

	if humanoid then
		humanoid.PlatformStand = false
		humanoid.RequiresNeck = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	-- pemain: pulihkan state di client-nya juga
	if model then
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			Remotes.Get("Ragdoll"):FireClient(player, false)
		end
	end
end

return Ragdoll
