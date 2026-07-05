-- SoundController: mengontrol reproduksi efek suara (SFX) di client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local SoundController = Knit.CreateController({
	Name = "SoundController",
})

-- Memutar suara 3D di part tertentu (attachment/torso) dan otomatis menghapusnya setelah selesai.
function SoundController:PlaySound3D(soundName: string, part: BasePart?)
	if not part then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = assets and (assets:FindFirstChild("Sounds") or assets:FindFirstChild("sounds"))
	local sfxSrc = sounds and sounds:FindFirstChild(soundName)
	if sfxSrc then
		local sfx = sfxSrc:Clone()
		sfx.Parent = part
		sfx:Play()
		Debris:AddItem(sfx, sfx.TimeLength > 0 and sfx.TimeLength or 2)
		return sfx
	end
	return nil
end

return SoundController
