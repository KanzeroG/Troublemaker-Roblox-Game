-- SettingsController: panel Settings di kiri layar + toggle.
-- Sekarang isinya "Show Hitbox" (dev tool). Gampang ditambah: panggil makeToggle(...) lagi.
-- UI dibuat programatik (bukan Roact) supaya terpisah dari HUD utama & mudah di-extend.

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local CombatFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat")
local Remotes = require(CombatFolder.Core.Remotes)

local player = Players.LocalPlayer

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

-- Palet warna
local COLOR = {
	panel = Color3.fromRGB(28, 28, 34),
	header = Color3.fromRGB(38, 38, 46),
	row = Color3.fromRGB(40, 40, 48),
	text = Color3.fromRGB(235, 235, 240),
	subtext = Color3.fromRGB(160, 160, 170),
	toggleOff = Color3.fromRGB(70, 70, 82),
	toggleOn = Color3.fromRGB(90, 200, 130),
	knob = Color3.fromRGB(245, 245, 245),
	accent = Color3.fromRGB(90, 160, 255),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- Satu baris toggle: label + switch. onChanged(state) dipanggil tiap berubah.
local function makeToggle(parent: Instance, label: string, default: boolean, onChanged: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = COLOR.row
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 8)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = row

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -54, 1, 0)
	text.Position = UDim2.fromScale(0, 0)
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 14
	text.TextColor3 = COLOR.text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = label
	text.Parent = row

	-- switch
	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.Size = UDim2.new(0, 44, 0, 22)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.BackgroundColor3 = COLOR.toggleOff
	track.Parent = row
	corner(track, 11)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 2, 0.5, 0)
	knob.BackgroundColor3 = COLOR.knob
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 9)

	local state = default
	local function render(animate: boolean)
		local knobPos = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		local trackColor = state and COLOR.toggleOn or COLOR.toggleOff
		if animate then
			TweenService:Create(knob, TweenInfo.new(0.15), { Position = knobPos }):Play()
			TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = trackColor }):Play()
		else
			knob.Position = knobPos
			track.BackgroundColor3 = trackColor
		end
	end

	track.Activated:Connect(function()
		state = not state
		render(true)
		onChanged(state)
	end)

	render(false)
	return row
end

function SettingsController:KnitStart()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- tombol gear (buka/tutup) di pojok kiri atas
	local openButton = Instance.new("TextButton")
	openButton.Name = "Open"
	openButton.Size = UDim2.new(0, 42, 0, 42)
	openButton.Position = UDim2.new(0, 12, 0, 12)
	openButton.BackgroundColor3 = COLOR.header
	openButton.Text = "⚙"
	openButton.TextSize = 22
	openButton.TextColor3 = COLOR.text
	openButton.Font = Enum.Font.GothamBold
	openButton.AutoButtonColor = true
	openButton.Parent = gui
	corner(openButton, 10)

	-- panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 240, 0, 0) -- tinggi diatur AutomaticSize
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, -260, 0, 64) -- mulai di luar layar (kiri), nanti di-slide masuk
	panel.BackgroundColor3 = COLOR.panel
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 12)
	panelPad.PaddingBottom = UDim.new(0, 12)
	panelPad.PaddingLeft = UDim.new(0, 12)
	panelPad.PaddingRight = UDim.new(0, 12)
	panelPad.Parent = panel

	-- header
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = COLOR.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Settings"
	title.LayoutOrder = 0
	title.Parent = panel

	-- ==== TOGGLES ====
	local hitboxDebug = Remotes.Get("HitboxDebug")
	makeToggle(panel, "Show Hitbox", false, function(state)
		hitboxDebug:FireServer(state)
	end)
	-- tambah toggle baru di sini: makeToggle(panel, "Nama", false, function(state) ... end)

	-- buka/tutup dengan slide
	local isOpen = false
	local shownX, hiddenX = 12, -260
	local function setOpen(open: boolean)
		isOpen = open
		if open then
			panel.Visible = true
		end
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, open and shownX or hiddenX, 0, 64),
		}):Play()
		if not open then
			task.delay(0.2, function()
				if not isOpen then
					panel.Visible = false
				end
			end)
		end
	end

	openButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)
end

return SettingsController
