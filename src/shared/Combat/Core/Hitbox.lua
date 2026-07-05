-- Hitbox: wrapper tipis di atas EZ Hitbox (breezy1214/hitbox).
-- API dijaga SAMA supaya skill (M1, Guardbreak) tidak perlu diubah:
--   local box = Hitbox.Create(size, rootPart, offset)
--   box.Touched:Connect(function(hitPart, victimHumanoid) ... end)
--   box:Start() ; box:Stop()
--
-- Pola MELEE sesuai README EZ Hitbox: hitbox ditaruh di posisi TETAP saat serangan
-- keluar (rootPart.CFrame * offset dihitung sekali) -- TIDAK mengikuti pemain.
-- (`:WeldTo` di README hanya untuk proyektil/serangan bergerak, bukan pukulan.)
--
-- Debug "Show Hitbox": server broadcast bentuk hitbox (statis) ke client yang OPT-IN.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EZHitbox = require(ReplicatedStorage.Packages.EZHitbox)
local Remotes = require(script.Parent.Remotes)

local Hitbox = {}

local DEBUG_DURATION = 0.2 -- kira-kira sepanjang window hitbox aktif (bukan 0.5 lagi)

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

-- worldCFrame = posisi tetap hitbox (bukan instance) supaya box debug juga diam
local function broadcastDebug(worldCFrame: CFrame, size: Vector3)
	if next(debugViewers) == nil then
		return
	end
	local event = Remotes.Get("HitboxDebug")
	for player in debugViewers do
		event:FireClient(player, worldCFrame, size, CFrame.identity, DEBUG_DURATION)
	end
end

-- Signal minimal untuk meniru API .Touched lama -> skill tak perlu diubah.
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
	-- Hitung posisi TETAP sekali di sini (saat serangan keluar). Tidak mengikuti.
	local worldCFrame = if typeof(cframeOrInstance) == "Instance"
		then cframeOrInstance.CFrame * offset
		else cframeOrInstance * offset

	local params = {
		Size = size,
		CFrame = worldCFrame,
		LookingFor = "Humanoid",
		DebounceTime = 0, -- tag sekali; box pendek & di-destroy tiap swing
		Lifetime = 0, -- lifecycle diatur manual (Start/Stop)
	}
	if typeof(cframeOrInstance) == "Instance" then
		params.Blacklist = { cframeOrInstance.Parent } -- jangan kena diri sendiri
	end

	-- TANPA :WeldTo -> hitbox diam di worldCFrame
	local ez = EZHitbox.new(params)

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
		broadcastDebug(worldCFrame, size)
		ez:Start()
	end

	function box:Stop()
		ez:Stop()
		ez:Destroy()
	end

	return box
end

return Hitbox
