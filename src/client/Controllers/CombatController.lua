-- CombatController: bootstrap WCS di client + input combat.
--   Klik kiri  -> M1 (combo)
--   Tahan F    -> Block (lepas F untuk berhenti; ketuk pas sebelum kena = parry)
--   R          -> Guardbreak
-- Juga menerima knockback (di-apply ke karakter sendiri) + VFX dari server.

-- Services
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local WCS = require(Packages.WCS)

local CombatFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat")
local Remotes = require(CombatFolder.Core.Remotes)

-- Folder aset VFX (di-copy dari reference ke ReplicatedStorage.Assets.vfx).
-- Kalau tidak ada (mis. build fresh tanpa Assets), VFX di-skip tanpa error.
local VFX_FOLDER: Folder? = nil
local COMBAT_FX: Folder? = nil
do
	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
	VFX_FOLDER = assets and assets:FindFirstChild("vfx")
	COMBAT_FX = VFX_FOLDER and (VFX_FOLDER:FindFirstChild("FX") or VFX_FOLDER:FindFirstChild("fx"))
end

local player = Players.LocalPlayer

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

--|| Input ||--

local function onM1Action(_actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = WCS.Character.GetLocalCharacter()
	if not character then
		return Enum.ContextActionResult.Pass
	end
	local m1 = character:GetSkillFromString("M1")
	if m1 then
		m1:Start()
	end
	return Enum.ContextActionResult.Pass
end

local function onBlockAction(_actionName: string, inputState: Enum.UserInputState)
	local character = WCS.Character.GetLocalCharacter()
	if not character then
		return Enum.ContextActionResult.Pass
	end
	local block = character:GetSkillFromString("Block")
	if not block then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		block:Start()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		block:End()
	end
	return Enum.ContextActionResult.Pass
end

local function onGuardbreakAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = WCS.Character.GetLocalCharacter()
	if not character then
		return Enum.ContextActionResult.Pass
	end
	local guardbreak = character:GetSkillFromString("Guardbreak")
	if guardbreak then
		guardbreak:Start()
	end
	return Enum.ContextActionResult.Pass
end

local function onPushAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = WCS.Character.GetLocalCharacter()
	if not character then
		return Enum.ContextActionResult.Pass
	end
	local push = character:GetSkillFromString("Push")
	if push then
		push:Start()
	end
	return Enum.ContextActionResult.Pass
end

--|| Knockback (di-apply pada karakter milik client ini) ||--

local function onKnockback(direction: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.VectorVelocity = direction
	lv.Parent = attachment
	Debris:AddItem(attachment, 0.15)
end

--|| Debug: gambar hitbox (hanya diterima kalau toggle "Show Hitbox" ON) ||--

local function onHitboxDebug(cframeOrInstance, size: Vector3, offset: CFrame, duration: number)
	local part = Instance.new("Part")
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 0.55
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Material = Enum.Material.ForceField
	part.Parent = workspace

	local function currentCFrame(): CFrame?
		if typeof(cframeOrInstance) == "Instance" then
			local base = cframeOrInstance :: BasePart
			return base.Parent and base.CFrame * offset or nil
		end
		return cframeOrInstance * offset
	end

	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local cf = currentCFrame()
		if not cf or os.clock() - startTime >= duration then
			connection:Disconnect()
			part:Destroy()
			return
		end
		part.CFrame = cf
	end)
end

--|| Ragdoll (client ini network owner karakternya sendiri, jadi state harus diubah di sini) ||--

local function onRagdoll(active: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if active then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

--|| VFX (pakai aset partikel asli dari reference: ReplicatedStorage.Assets.vfx) ||--

-- Ambil aset bersarang dengan aman, mis. getAsset("hit", "punch")
local function getAsset(...): Instance?
	local node: Instance? = VFX_FOLDER
	for _, name in { ... } do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

local function getTorso(model: Model): BasePart?
	return model
		and (
			model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("UpperTorso")
			or model:FindFirstChild("Torso")
		)
		or nil
end

-- Emit satu ParticleEmitter atau semua emitter di dalam sebuah folder, di posisi `part`.
local function emit(source: Instance?, part: BasePart?)
	if not source or not part then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local function emitOne(emitter: ParticleEmitter)
		local clone = emitter:Clone()
		clone.Parent = attachment
		clone:Emit(clone:GetAttribute("EmitCount") or 15)
	end

	if source:IsA("ParticleEmitter") then
		emitOne(source)
	else
		for _, child in source:GetChildren() do
			if child:IsA("ParticleEmitter") then
				emitOne(child)
			end
		end
	end

	Debris:AddItem(attachment, 1)
end

local function flashHighlight(model: Model, color: Color3, duration: number)
	if not model then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	Debris:AddItem(highlight, duration)
end

-- "!" telegraph guardbreak (BillboardGui asli, warna kuning -> merah)
local function showGuardbreakMark(model: Model, duration: number)
	duration = duration or 0.45
	local head = model and (model:FindFirstChild("Head") or getTorso(model))
	local template = getAsset("misc", "guardbreak")
	if not head or not template then
		return
	end
	local mark = template:Clone()
	mark.Adornee = head
	mark.Parent = head
	local image = mark:FindFirstChild("ImageLabel")
	if image and image:IsA("ImageLabel") then
		image.ImageColor3 = Color3.fromRGB(210, 210, 0)
		TweenService:Create(image, TweenInfo.new(duration), { ImageColor3 = Color3.fromRGB(210, 0, 0) }):Play()
	end
	Debris:AddItem(mark, duration)
end

-- Bar durasi stun di atas kepala (BillboardGui asli, mengecil selama `duration`)
local function showStunBar(model: Model, duration: number)
	local head = model and (model:FindFirstChild("Head") or getTorso(model))
	local template = getAsset("misc", "stunbar")
	if not head or not template or not duration or duration <= 0 then
		return
	end
	local bar = template:Clone()
	bar.Adornee = head
	bar.Parent = head
	local frame = bar:FindFirstChild("Frame")
	if frame and frame:IsA("GuiObject") then
		frame:TweenSize(UDim2.new(0, 0, 1, 0), Enum.EasingDirection.In, Enum.EasingStyle.Linear, duration, true)
		frame:TweenPosition(UDim2.new(0.5, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Linear, duration, true)
	end
	Debris:AddItem(bar, duration)
end

local function onVFX(kind: string, model: Model, arg)
	local torso = getTorso(model)
	local VfxController = Knit.GetController("VfxController")
	local SoundController = Knit.GetController("SoundController")

	if kind == "Hit" then
		VfxController:PlayVFX("Basic Hit", torso)
		SoundController:PlaySound3D("BasicHit", torso)
		VfxController:PlayCameraShake(torso and torso.Position or Vector3.zero, 2.5, 45)
		if arg then
			VfxController:ShowDamageIndicator(arg, model)
		end
	elseif kind == "Block" then
		VfxController:PlayVFX("Block Hit", torso)
		SoundController:PlaySound3D("BlockHit", torso)
		VfxController:PlayCameraShake(torso and torso.Position or Vector3.zero, 1.5, 30)
		if arg then
			VfxController:ShowDamageIndicator(arg, model)
		end
	elseif kind == "GuardBar" then
		VfxController:ShowGuardShield(model, arg)
	elseif kind == "Parry" then
		VfxController:PlayVFX("Perfect Block", torso)
		SoundController:PlaySound3D("PerfectBlock1", torso)
		SoundController:PlaySound3D("PerfectBlock2", torso)
		VfxController:PlayCameraShake(torso and torso.Position or Vector3.zero, 4, 60)
	elseif kind == "GuardBreak" then
		VfxController:RemoveGuardShield(model)
		VfxController:PlayVFX("Block Break", torso)
		SoundController:PlaySound3D("BlockBreak", torso)
		VfxController:PlayCameraShake(torso and torso.Position or Vector3.zero, 5, 80)
	elseif kind == "GuardBreakWindup" then
		showGuardbreakMark(model, arg)
	elseif kind == "Stun" then
		showStunBar(model, arg)
	end
end

local function bindMeleeActions()
	ContextActionService:BindAction("Combat_M1", onM1Action, true, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction("Combat_Block", onBlockAction, true, Enum.KeyCode.F)
	ContextActionService:BindAction("Combat_Guardbreak", onGuardbreakAction, true, Enum.KeyCode.R)
end

local function unbindMeleeActions()
	ContextActionService:UnbindAction("Combat_M1")
	ContextActionService:UnbindAction("Combat_Block")
	ContextActionService:UnbindAction("Combat_Guardbreak")
end

local function setupMeleeToolListeners(character)
	if not character then
		return
	end

	-- Listen for child added (equipped)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Melee" then
			bindMeleeActions()
		end
	end)

	-- Listen for child removed (unequipped)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Melee" then
			unbindMeleeActions()
		end
	end)

	-- Check initial state
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool.Name == "Melee" then
		bindMeleeActions()
	else
		unbindMeleeActions()
	end
end

--|| Knit Lifecycle ||--

function CombatController:KnitInit()
	-- client wajib register directory yang sama dengan server sebelum Start
	local client = WCS.CreateClient()
	client:RegisterDirectory(CombatFolder.Skills)
	client:RegisterDirectory(CombatFolder.StatusEffects)
	client:Start()

	-- definisikan moveset di client juga (WCS butuh nama moveset dikenal dua sisi)
	require(CombatFolder.Movesets)
end

function CombatController:KnitStart()

	-- true = otomatis bikin tombol touch di mobile
	ContextActionService:BindAction("Combat_Push", onPushAction, true, Enum.KeyCode.G)

	player.CharacterAdded:Connect(setupMeleeToolListeners)
	if player.Character then
		setupMeleeToolListeners(player.Character)
	end

	Remotes.Get("Knockback").OnClientEvent:Connect(onKnockback)
	Remotes.Get("VFX").OnClientEvent:Connect(onVFX)
	Remotes.Get("Ragdoll").OnClientEvent:Connect(onRagdoll)
	Remotes.Get("HitboxDebug").OnClientEvent:Connect(onHitboxDebug)
end

return CombatController
