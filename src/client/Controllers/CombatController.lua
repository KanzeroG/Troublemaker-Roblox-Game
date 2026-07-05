-- CombatController: bootstrap WCS di client + input combat.
--   Klik kiri  -> M1 (combo)
--   Tahan F    -> Block (lepas F untuk berhenti; ketuk pas sebelum kena = parry)
--   R          -> Guardbreak
-- Juga menerima knockback (di-apply ke karakter sendiri) + VFX dari server.

-- Services
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
do
	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
	VFX_FOLDER = assets and assets:FindFirstChild("vfx")
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

-- Bar guard HP di atas kepala blocker: makin terkikis makin pendek & memerah.
-- Muncul saat guard kena hit, hilang sendiri kalau tidak kena hit lagi.
local guardBars: { [Model]: { gui: BillboardGui, frame: GuiObject?, lastUpdate: number } } = {}

local function removeGuardBar(model: Model)
	local entry = guardBars[model]
	if entry then
		entry.gui:Destroy()
		guardBars[model] = nil
	end
end

local function showGuardBar(model: Model, ratio: number)
	local head = model and (model:FindFirstChild("Head") or getTorso(model))
	local template = getAsset("misc", "stunbar")
	if not head or not template then
		return
	end

	local entry = guardBars[model]
	if not entry or not entry.gui.Parent then
		local gui = template:Clone()
		gui.Adornee = head
		gui.StudsOffset += Vector3.new(0, 0.6, 0) -- sedikit di atas posisi stunbar
		gui.Parent = head
		entry = { gui = gui, frame = gui:FindFirstChild("Frame") :: GuiObject?, lastUpdate = 0 }
		guardBars[model] = entry
	end

	entry.lastUpdate = os.clock()
	local frame = entry.frame
	if frame then
		ratio = math.clamp(ratio, 0, 1)
		frame.Size = UDim2.new(ratio, 0, 1, 0)
		frame.Position = UDim2.new((1 - ratio) / 2, 0, 0, 0)
		-- biru (penuh) -> merah (hampir pecah)
		frame.BackgroundColor3 = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 140, 255), ratio)
	end

	-- hilang sendiri kalau 1.5 detik tidak kena hit lagi
	task.delay(1.6, function()
		local current = guardBars[model]
		if current == entry and os.clock() - entry.lastUpdate >= 1.5 then
			removeGuardBar(model)
		end
	end)
end

local function onVFX(kind: string, model: Model, arg)
	if kind == "Hit" then
		emit(getAsset("hit", "punch"), getTorso(model))
	elseif kind == "Block" then
		emit(getAsset("hit", "punch", "circle"), getTorso(model))
		flashHighlight(model, Color3.fromRGB(80, 140, 255), 0.15)
	elseif kind == "GuardBar" then
		showGuardBar(model, arg)
	elseif kind == "Parry" then
		emit(getAsset("misc", "blast"), getTorso(model))
		flashHighlight(model, Color3.fromRGB(255, 255, 255), 0.3)
	elseif kind == "GuardBreak" then
		removeGuardBar(model)
		emit(getAsset("hit", "punch", "shards"), getTorso(model))
		flashHighlight(model, Color3.fromRGB(255, 60, 60), 0.5)
	elseif kind == "GuardBreakWindup" then
		showGuardbreakMark(model, arg)
	elseif kind == "Stun" then
		showStunBar(model, arg)
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
	ContextActionService:BindAction("Combat_M1", onM1Action, true, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction("Combat_Block", onBlockAction, true, Enum.KeyCode.F)
	ContextActionService:BindAction("Combat_Guardbreak", onGuardbreakAction, true, Enum.KeyCode.R)

	Remotes.Get("Knockback").OnClientEvent:Connect(onKnockback)
	Remotes.Get("VFX").OnClientEvent:Connect(onVFX)
	Remotes.Get("Ragdoll").OnClientEvent:Connect(onRagdoll)
end

return CombatController
