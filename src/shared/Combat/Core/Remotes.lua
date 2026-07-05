-- Remotes: RemoteEvents untuk combat yang di luar jangkauan WCS
-- (knockback client-authoritative + VFX broadcast).
-- Server membuat folder + event; client menunggunya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CombatRemotes"
local EVENT_NAMES = { "Knockback", "VFX" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.Get(name: string): RemoteEvent
	return folder:WaitForChild(name)
end

return Remotes
