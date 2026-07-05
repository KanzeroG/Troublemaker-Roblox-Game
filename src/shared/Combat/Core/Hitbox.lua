-- Hitbox: thin wrapper around MuchachoHitbox (ported from the reference game).
-- Create(size, cframeOrInstance, offset) returns a hitbox that follows `cframeOrInstance`
-- (pass the HumanoidRootPart so the box tracks the attacker), fires
-- .Touched:Connect(function(hitPart, victimHumanoid) ... end), with :Start()/:Stop().

local Muchacho = require(script.Parent.MuchachoHitbox)

local Hitbox = {}

function Hitbox.Create(size: Vector3, cframeOrInstance, offset: CFrame?)
	local box = Muchacho.CreateHitbox()
	box.Size = size
	box.CFrame = cframeOrInstance
	if offset then
		box.Offset = offset
	end
	box.Visualizer = false -- set true saat debugging biar hitbox kelihatan
	box.AutoDestroy = true
	return box
end

return Hitbox
