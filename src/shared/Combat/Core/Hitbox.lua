-- Hitbox: wrapper tipis di atas EZ Hitbox (breezy1214/hitbox).
-- API dijaga SAMA seperti sebelumnya supaya skill (M1, Guardbreak) tidak perlu diubah:
--   local box = Hitbox.Create(size, rootPart, offset)
--   box.Touched:Connect(function(hitPart, victimHumanoid) ... end)
--   box:Start() ; box:Stop()
--
-- EZ Hitbox unggul: :WeldTo mengikuti pemain + velocity-prediction (target lari cepat
-- tetap kena), blacklist penyerang, debounce per-target.
--
-- Debug "Show Hitbox": server broadcast bentuk hitbox ke client yang OPT-IN (tak berubah).

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EZHitbox = require(ReplicatedStorage.Packages.EZHitbox)
local Remotes = require(script.Parent.Remotes)

local Hitbox = {}

local DEBUG_DURATION = 0.5 -- lama box debug tampil

-- Server-only: siapa yang mau lihat hitbox (dari Settings toggle)
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

-- Signal minimal untuk meniru API .Touched lama (Muchacho) -> skill tak perlu diubah.
local function createSignal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function()
					local i = table.find(handlers, fn)
					if i then
						table.remove(handlers, i)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				task.spawn(fn, ...)
			end
		end,
	}
end

function Hitbox.Create(size: Vector3, cframeOrInstance, offset: CFrame?)
	offset = offset or CFrame.identity
	local isPart = typeof(cframeOrInstance) == "Instance"
	local initialCFrame = if isPart then cframeOrInstance.CFrame * offset else cframeOrInstance * offset

	local params = {
		Size = size,
		CFrame = initialCFrame,
		LookingFor = "Humanoid",
		DebounceTime = 0, -- tag sekali; box ini pendek & di-destroy tiap swing
		Lifetime = 0, -- lifecycle diatur manual (Start/Stop)
	}
	if isPart then
		params.Blacklist = { cframeOrInstance.Parent } -- jangan kena diri sendiri
	end

	local ez = EZHitbox.new(params)
	if isPart then
		ez:WeldTo(cframeOrInstance, offset) -- ikuti pemain + velocity prediction
	end

	local touched = createSignal()
	ez.OnHit:Connect(function(characters)
		for _, character in characters do
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				touched:Fire(character.PrimaryPart, humanoid)
			end
		end
	end)

	local box = { Touched = touched }

	function box:Start()
		broadcastDebug(cframeOrInstance, size, offset)
		ez:Start()
	end

	function box:Stop()
		ez:Stop()
		ez:Destroy()
	end

	return box
end

return Hitbox
