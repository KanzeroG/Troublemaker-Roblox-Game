-- AnimationProvider: Utility untuk memuat objek Animasi dari ReplicatedStorage.Assets.Animations

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationProvider = {}

local function getAnimationsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Animations")
end

-- Mendapatkan objek Animation dari subfolder style tertentu (mis. Melee, Shared, dll.)
function AnimationProvider.get(style: string, name: string): Animation?
	local animFolder = getAnimationsFolder()
	if not animFolder then
		return nil
	end
	
	local styleFolder = animFolder:FindFirstChild(style)
	if not styleFolder then
		return nil
	end
	
	local anim = styleFolder:FindFirstChild(name)
	if anim and anim:IsA("Animation") then
		return anim
	end
	
	return nil
end

-- Mendapatkan objek Animation dari folder Shared (mis. HitReaction)
function AnimationProvider.getShared(name: string): Animation?
	return AnimationProvider.get("Shared", name)
end

return AnimationProvider
