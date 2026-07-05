-- VfxController: mengontrol efek visual (VFX), guncangan kamera (Camera Shake), 
-- dan angka damage melayang (Damage Indicator) di client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local VfxController = Knit.CreateController({
	Name = "VfxController",
})

local VFX_FOLDER: Folder? = nil
local COMBAT_FX: Folder? = nil
do
	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
	VFX_FOLDER = assets and assets:FindFirstChild("vfx")
	COMBAT_FX = VFX_FOLDER and (VFX_FOLDER:FindFirstChild("FX") or VFX_FOLDER:FindFirstChild("fx"))
end

local player = Players.LocalPlayer
local cameraShaker = nil
local camShake = nil

-- Memutar guncangan kamera (Camera Shake) berbasis jarak (magnitude) dari titik tabrakan
function VfxController:PlayCameraShake(position: Vector3, shakeStrength: number, maxMagnitude: number)
	if not camShake then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local shakeMagnitude = (hrp.Position - position).Magnitude
	if shakeMagnitude < maxMagnitude then
		if shakeMagnitude >= 0 and shakeMagnitude < maxMagnitude / 4 then
			camShake:ShakeOnce(shakeStrength / 1.5, shakeStrength * 2, 0, 0.7)
		elseif shakeMagnitude > maxMagnitude / 4 and shakeMagnitude < maxMagnitude / 3 then
			camShake:ShakeOnce(shakeStrength / 5, shakeStrength * 1.5, 0, 1)
		elseif shakeMagnitude > maxMagnitude / 3 and shakeMagnitude < maxMagnitude / 2 then
			camShake:ShakeOnce(shakeStrength / 7.5, shakeStrength * 1, 0, 1.2)
		elseif shakeMagnitude > maxMagnitude / 3.5 and shakeMagnitude < maxMagnitude then
			camShake:ShakeOnce(shakeStrength / 10, shakeStrength * 0.5, 0, 1.5)
		end
	end
end

-- Memunculkan angka damage melayang (Damage Indicator) di atas kepala model
function VfxController:ShowDamageIndicator(damage: number, character: Model)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local guiSrc = assets and assets:FindFirstChild("DamageIndicator")
	if not guiSrc then
		return
	end

	local rnd = Random.new()
	local gui = guiSrc:Clone()
	local textLabel = gui:FindFirstChild("Damage")
	if not textLabel then
		return
	end

	textLabel.Size = UDim2.fromScale(0, 0)
	textLabel.TextColor3 = Color3.fromRGB(220, 20, 20)
	gui.StudsOffset = Vector3.new(
		rnd:NextNumber(-1.5, 1.5),
		rnd:NextNumber(-1, 1),
		rnd:NextNumber(-0.5, 0.5)
	)
	textLabel.Text = tostring(math.floor(damage + 0.5))
	gui.Adornee = hrp
	gui.Parent = workspace:FindFirstChild("Debris") or workspace

	textLabel:TweenSize(UDim2.fromScale(0.9, 0.9), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1, true)
	task.delay(0.1, function()
		textLabel:TweenSize(UDim2.fromScale(0.75, 0.75), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
		task.delay(0.75, function()
			textLabel:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.2, true)
			Debris:AddItem(gui, 0.2)
		end)
	end)
end

-- Memainkan efek visual kombinasi partikel & highlight dari Assets.vfx.FX
function VfxController:PlayVFX(name: string, target: BasePart?)
	if not target or not COMBAT_FX then
		return
	end
	local src = COMBAT_FX:FindFirstChild(name)
	if not src then
		return
	end

	-- 1. Emit Particle & Light
	local attSrc = src:FindFirstChild("Attachment")
	if attSrc then
		local att = attSrc:Clone()
		att.Parent = target
		for _, child in ipairs(att:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				local count = child:GetAttribute("EmitCount") or 15
				child:Emit(count)
			elseif child:IsA("PointLight") then
				child.Brightness = 0
				child.Range = 0
				TweenService:Create(child, TweenInfo.new(0.1), { Brightness = 1, Range = 10 }):Play()
				task.delay(0.15, function()
					if child and child.Parent then
						TweenService:Create(child, TweenInfo.new(0.1), { Brightness = 0, Range = 0 }):Play()
					end
				end)
			end
		end
		Debris:AddItem(att, 2)
	end

	-- 2. Highlight flash
	local hlSrc = src:FindFirstChild("Highlight")
	if hlSrc and target.Parent then
		local hl = hlSrc:Clone()
		hl.Adornee = target.Parent
		hl.Parent = target.Parent
		TweenService:Create(hl, TweenInfo.new(0.35), { OutlineTransparency = 1, FillTransparency = 1 }):Play()
		Debris:AddItem(hl, 0.35)
	end
end

local guardShields: { [Model]: { gui: BillboardGui, grad: UGradient?, frame: GuiObject?, lastUpdate: number } } = {}

-- Menghapus visual tameng block
function VfxController:RemoveGuardShield(model: Model)
	local entry = guardShields[model]
	if entry then
		entry.gui:Destroy()
		guardShields[model] = nil
	end
end

-- Memunculkan tameng block BillboardGui yang berkurang secara melingkar (menggunakan UIGradient Y-Offset)
function VfxController:ShowGuardShield(model: Model, ratio: number)
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("vfx") and assets.vfx:FindFirstChild("misc") and assets.vfx.misc:FindFirstChild("BlockShield")
	if not template then
		-- Fallback ke stunbar jika BlockShield belum di-copy
		template = assets and assets:FindFirstChild("vfx") and assets.vfx:FindFirstChild("misc") and assets.vfx.misc:FindFirstChild("stunbar")
	end
	if not template then
		return
	end

	local entry = guardShields[model]
	if not entry or not entry.gui.Parent then
		local gui = template:Clone()
		gui.Adornee = hrp
		gui.Enabled = true
		gui.Parent = hrp

		local shield = gui:FindFirstChild("Shield")
		local grad = shield and shield:FindFirstChildOfClass("UIGradient")
		local frame = gui:FindFirstChild("Frame")

		entry = { gui = gui, grad = grad, frame = frame, lastUpdate = 0 }
		guardShields[model] = entry
	end

	entry.lastUpdate = os.clock()
	ratio = math.clamp(ratio, 0, 1)

	if entry.grad then
		-- Shield visual Y-Offset (1 = Penuh, berkurang ke 0)
		entry.grad.Offset = Vector2.new(0, ratio)
	elseif entry.frame then
		-- Fallback standard stunbar frame
		entry.frame.Size = UDim2.new(ratio, 0, 1, 0)
		entry.frame.Position = UDim2.new((1 - ratio) / 2, 0, 0, 0)
		entry.frame.BackgroundColor3 = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 140, 255), ratio)
	end

	-- Hilang otomatis setelah 1.5 detik jika tidak menerima damage lagi
	task.delay(1.6, function()
		local current = guardShields[model]
		if current == entry and os.clock() - entry.lastUpdate >= 1.5 then
			self:RemoveGuardShield(model)
		end
	end)
end


function VfxController:KnitStart()
	-- Initialize CameraShaker if present
	local CameraShakerModule = Packages:FindFirstChild("CameraShaker")
	if CameraShakerModule then
		cameraShaker = require(CameraShakerModule)
		camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			local camera = workspace.CurrentCamera
			if camera then
				camera.CFrame = camera.CFrame * shakeCFrame
			end
		end)
		camShake:Start()
	end
end

return VfxController
