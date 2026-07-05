-- Hitbox: thin wrapper around MuchachoHitbox (ported from the reference game).
-- Create(size, cframeOrInstance, offset) returns a hitbox that follows `cframeOrInstance`
-- (pass the HumanoidRootPart so the box tracks the attacker), fires
-- .Touched:Connect(function(hitPart, victimHumanoid) ... end), with :Start()/:Stop().
--
-- Debug "Show Hitbox": server hanya broadcast bentuk hitbox ke client yang OPT-IN
-- (lewat Settings toggle -> HitboxDebug:FireServer(true)). Client lain tidak dapat apa-apa.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Muchacho = require(script.Parent.MuchachoHitbox)
local Remotes = require(script.Parent.Remotes)

local Hitbox = {}

local DEBUG_DURATION = 0.5 -- lama box debug tampil (cukup untuk window hitbox biasa)

-- Server-only: siapa yang mau lihat hitbox
local debugViewers: { [Player]: true } = {}

if RunService:IsServer() then
	Remotes.Get("HitboxDebug").OnServerEvent:Connect(function(player, enabled)
		debugViewers[player] = (enabled == true) or nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		debugViewers[player] = nil
	end)
end

local function broadcastDebug(cframeOrInstance, size: Vector3, offset: CFrame)
	if next(debugViewers) == nil then
		return
	end
	local event = Remotes.Get("HitboxDebug")
	for player in debugViewers do
		event:FireClient(player, cframeOrInstance, size, offset, DEBUG_DURATION)
	end
end

function Hitbox.Create(size: Vector3, cframeOrInstance, offset: CFrame?)
	local box = Muchacho.CreateHitbox()
	box.Size = size
	box.CFrame = cframeOrInstance
	if offset then
		box.Offset = offset
	end
	box.Visualizer = false
	box.AutoDestroy = true

	-- Sisipkan broadcast debug saat hitbox dinyalakan (tanpa mengubah skill mana pun)
	if RunService:IsServer() then
		local rawStart = box.Start
		box.Start = function(self, ...)
			broadcastDebug(cframeOrInstance, size, offset or CFrame.new())
			return rawStart(self, ...)
		end
	end

	return box
end

return Hitbox
