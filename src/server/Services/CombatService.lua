-- CombatService: bootstrap WCS di server.
-- - Register skill & status effect dari ReplicatedStorage.Shared.Combat
-- - Bikin WCS.Character untuk tiap karakter pemain + kasih skill M1
-- - Terapkan damage WCS ke Humanoid.Health (WCS tidak melakukannya otomatis)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)
local WCS = require(ReplicatedStorage.Packages.WCS)

local CombatFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat")
local M1 = require(CombatFolder.Skills.M1)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {},
})

--|| Local Functions ||--

local function characterAdded(character: Model)
	-- tunggu bagian penting siap
	character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	local wcsCharacter = WCS.Character.new(character)

	-- WCS hanya memberi sinyal damage -- pengurangan health kita yang urus
	wcsCharacter.DamageTaken:Connect(function(container)
		if humanoid.Health > 0 then
			humanoid:TakeDamage(container.Damage)
		end
	end)

	-- kasih skill combat
	M1.new(wcsCharacter)

	-- bersihkan saat karakter dihapus (mati/respawn)
	character.Destroying:Connect(function()
		if not wcsCharacter:IsDestroyed() then
			wcsCharacter:Destroy()
		end
	end)
end

local function playerAdded(player: Player)
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		characterAdded(player.Character)
	end

	player.CharacterRemoving:Connect(function(character)
		local wcsCharacter = WCS.Character.GetCharacterFromInstance(character)
		if wcsCharacter and not wcsCharacter:IsDestroyed() then
			wcsCharacter:Destroy()
		end
	end)
end

-- KNIT INIT
function CombatService:KnitInit()
	local server = WCS.CreateServer()
	server:RegisterDirectory(CombatFolder.Skills)
	server:RegisterDirectory(CombatFolder.StatusEffects)
	server:Start()
end

-- KNIT START
function CombatService:KnitStart()
	Players.PlayerAdded:Connect(playerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
end

return CombatService
