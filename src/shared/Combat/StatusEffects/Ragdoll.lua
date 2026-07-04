-- Ragdoll: mengganti semua Motor6D dengan BallSocketConstraint (physics ragdoll),
-- lalu memulihkannya saat efek berakhir. Dipakai oleh finisher M1 (hit ke-4).
-- Tidak butuh animasi -- murni physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WCS = require(ReplicatedStorage.Packages.WCS)

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

	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

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
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

return Ragdoll
