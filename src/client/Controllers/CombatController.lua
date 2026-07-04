-- CombatController: bootstrap WCS di client + input M1.
-- Klik kiri (desktop) / tombol touch (mobile) -> jalankan skill M1.

-- Services
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local WCS = require(Packages.WCS)

local CombatFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat")

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

--|| Local Functions ||--

local function onM1Action(_actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	local wcsCharacter = WCS.Character.GetLocalCharacter()
	if not wcsCharacter then
		return Enum.ContextActionResult.Pass
	end

	local m1 = wcsCharacter:GetSkillFromString("M1")
	if m1 then
		m1:Start()
	end

	return Enum.ContextActionResult.Pass
end

--|| Knit Lifecycle ||--

function CombatController:KnitInit()
	-- client wajib register directory yang sama dengan server sebelum Start
	local client = WCS.CreateClient()
	client:RegisterDirectory(CombatFolder.Skills)
	client:RegisterDirectory(CombatFolder.StatusEffects)
	client:Start()
end

function CombatController:KnitStart()
	-- true = otomatis bikin tombol touch di mobile
	ContextActionService:BindAction("Combat_M1", onM1Action, true, Enum.UserInputType.MouseButton1)
end

return CombatController
