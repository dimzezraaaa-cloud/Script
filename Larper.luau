-- Larper (local, single script, Lua 5.1 style, no remotes / require)
-- Categories never mix: each tab only searches its own asset type.
-- Everything is client-side, only you can see it.

local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- CATEGORIES --------------------------------------------------------------
local CATEGORIES = {
	{
		Name = "Accessories",
		Kind = "accessory",
		Types = { "Hat", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" },
	},
	{ Name = "Animations", Kind = "animation", Bundle = true },
	{ Name = "T-Shirts", Kind = "tshirt", Types = { "TShirt", "ClassicTShirt" } },
	{ Name = "Shirts", Kind = "shirt", Types = { "Shirt", "ClassicShirt" } },
	{ Name = "Pants", Kind = "pants", Types = { "Pants", "ClassicPants" } },
	{ Name = "Emotes", Kind = "emote", Types = { "EmoteAnimation" } },
	{ Name = "Faces", Kind = "face", Types = { "Face" } },
}

local ROLE_BY_TYPE = {
	[48] = "climb",
	[50] = "fall",
	[51] = "idle",
	[52] = "jump",
	[53] = "run",
	[54] = "swim",
	[55] = "walk",
}

local ANIM_PATHS = {
	idle = { "idle", { "Animation1", "Animation2" } },
	walk = { "walk", { "WalkAnim" } },
	run = { "run", { "RunAnim" } },
	jump = { "jump", { "JumpAnim" } },
	fall = { "fall", { "FallAnim" } },
	climb = { "climb", { "ClimbAnim" } },
	swim = { "swim", { "Swim" } },
}

-- THEME (dark, flat, no gradients) ----------------------------------------
local C_BG = Color3.fromRGB(16, 16, 19)
local C_SURFACE = Color3.fromRGB(24, 24, 28)
local C_CARD = Color3.fromRGB(33, 33, 39)
local C_CARD_HOVER = Color3.fromRGB(44, 44, 52)
local C_STROKE = Color3.fromRGB(50, 50, 58)
local C_TEXT = Color3.fromRGB(235, 235, 240)
local C_SUB = Color3.fromRGB(145, 145, 156)
local C_ACCENT = Color3.fromRGB(56, 132, 255)
local C_ACCENT_HOVER = Color3.fromRGB(86, 154, 255)
local C_DANGER = Color3.fromRGB(196, 70, 70)
local C_OK = Color3.fromRGB(80, 200, 120)
local C_WARN = Color3.fromRGB(255, 200, 90)

-- PARENT ------------------------------------------------------------------
local parent = nil
local okH, hui = pcall(function()
	return gethui and gethui()
end)
if okH and hui then
	parent = hui
else
	local okC, core = pcall(function()
		local c = game:GetService("CoreGui")
		local test = Instance.new("Folder")
		test.Parent = c
		test:Destroy()
		return c
	end)
	if okC and core then
		parent = core
	else
		parent = player:WaitForChild("PlayerGui")
	end
end

local old = parent:FindFirstChild("Larper")
if old then old:Destroy() end

-- HELPERS -----------------------------------------------------------------
local function create(className, props, par)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = par
	return inst
end

local function corner(par, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) }, par)
end

local function stroke(par, color, thickness)
	return create("UIStroke", {
		Color = color or C_STROKE,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, par)
end

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SMOOTH_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local function pressable(btn, base, hover)
	btn.AutoButtonColor = false
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tween(btn, FAST, { BackgroundColor3 = hover })
		end
	end)
	btn.InputEnded:Connect(function()
		tween(btn, FAST, { BackgroundColor3 = base })
	end)
end

local function makeButton(props, par, base, hover, radius)
	props.BackgroundColor3 = base
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or C_TEXT
	props.BorderSizePixel = 0
	local b = create("TextButton", props, par)
	corner(b, radius or 8)
	pressable(b, base, hover)
	return b
end

local function makeBox(props, par)
	props.BackgroundColor3 = C_SURFACE
	props.TextColor3 = C_TEXT
	props.PlaceholderColor3 = C_SUB
	props.Font = Enum.Font.Gotham
	props.ClearTextOnFocus = false
	props.BorderSizePixel = 0
	props.TextXAlignment = Enum.TextXAlignment.Left
	local b = create("TextBox", props, par)
	corner(b, 8)
	stroke(b, C_STROKE, 1)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
	return b
end

local function enumItem(enumType, name)
	local ok, v = pcall(function()
		return enumType[name]
	end)
	if ok then return v end
	return nil
end

-- SIZE ----------------------------------------------------------------------
local camera = workspace.CurrentCamera
local vp = camera and camera.ViewportSize or Vector2.new(800, 400)
local PANEL_W = math.min(340, vp.X - 20)
local PANEL_H = math.max(260, math.min(390, vp.Y - 52))

-- GUI -------------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "Larper",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parent)

-- Dex-style tab flush with the top edge
local openBtn = create("TextButton", {
	Text = "Larper",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = C_TEXT,
	BackgroundColor3 = C_BG,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -10),
	Size = UDim2.fromOffset(104, 38),
	TextYAlignment = Enum.TextYAlignment.Bottom,
	ZIndex = 20,
}, gui)
corner(openBtn, 10)
stroke(openBtn, C_STROKE, 1)
create("UIPadding", { PaddingBottom = UDim.new(0, 6) }, openBtn)
pressable(openBtn, C_BG, C_CARD_HOVER)

local panel = create("CanvasGroup", {
	Visible = false,
	GroupTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	BackgroundColor3 = C_BG,
	BorderSizePixel = 0,
	ZIndex = 10,
}, gui)
corner(panel, 12)
stroke(panel, C_STROKE, 1)
local panelScale = create("UIScale", { Scale = 0.92 }, panel)

local panelX = vp.X / 2
local panelY = 46 + PANEL_H / 2
panel.Position = UDim2.fromOffset(panelX, panelY)

-- title bar (drag handle)
local titleBar = create("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 40),
}, panel)

create("TextLabel", {
	Text = "Larper",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = C_TEXT,
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.fromOffset(160, 40),
	Position = UDim2.fromOffset(12, 0),
}, titleBar)

local resetBtn = makeButton({
	Text = "Reset",
	TextSize = 12,
	Size = UDim2.fromOffset(54, 24),
	Position = UDim2.new(1, -96, 0, 8),
}, titleBar, C_CARD, C_CARD_HOVER, 6)

local closeBtn = makeButton({
	Text = "X",
	TextSize = 13,
	Size = UDim2.fromOffset(28, 24),
	Position = UDim2.new(1, -38, 0, 8),
}, titleBar, C_DANGER, Color3.fromRGB(220, 90, 90), 6)

-- Regular / Limited segmented control
local regularBtn = create("TextButton", {
	Text = "Regular",
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = C_TEXT,
	BackgroundColor3 = C_ACCENT,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Size = UDim2.new(0.5, -14, 0, 28),
	Position = UDim2.new(0, 10, 0, 40),
}, panel)
corner(regularBtn, 8)

local limitedBtn = create("TextButton", {
	Text = "Limited",
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = C_TEXT,
	BackgroundColor3 = C_CARD,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Size = UDim2.new(0.5, -14, 0, 28),
	Position = UDim2.new(0.5, 4, 0, 40),
}, panel)
corner(limitedBtn, 8)

-- category strip
local strip = create("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	Size = UDim2.new(1, -20, 0, 28),
	Position = UDim2.fromOffset(10, 72),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, strip)

-- search row
local searchBox = makeBox({
	PlaceholderText = "Search...",
	Text = "",
	TextSize = 13,
	Size = UDim2.new(1, -92, 0, 28),
	Position = UDim2.fromOffset(10, 104),
}, panel)

local searchBtn = makeButton({
	Text = "Search",
	TextSize = 12,
	Size = UDim2.fromOffset(70, 28),
	Position = UDim2.new(1, -80, 0, 104),
}, panel, C_ACCENT, C_ACCENT_HOVER, 8)

-- grid
local scroll = create("ScrollingFrame", {
	BackgroundColor3 = C_SURFACE,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C_STROKE,
	Size = UDim2.new(1, -20, 1, -182),
	Position = UDim2.fromOffset(10, 138),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
corner(scroll, 10)
create("UIGridLayout", {
	CellSize = UDim2.fromOffset(96, 112),
	CellPadding = UDim2.fromOffset(6, 6),
}, scroll)
create("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
}, scroll)

local status = create("TextLabel", {
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = C_SUB,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -122, 0, 32),
	Position = UDim2.new(0, 10, 1, -38),
}, panel)

local moreBtn = makeButton({
	Text = "Load More",
	TextSize = 12,
	Size = UDim2.fromOffset(98, 28),
	Position = UDim2.new(1, -108, 1, -36),
}, panel, C_CARD, C_CARD_HOVER, 8)

local function setStatus(text, kind)
	status.Text = text
	if kind == "ok" then
		status.TextColor3 = C_OK
	elseif kind == "warn" then
		status.TextColor3 = C_WARN
	else
		status.TextColor3 = C_SUB
	end
end

-- OPEN / CLOSE ANIMATION --------------------------------------------------
local isOpen = false
local token = 0

local function setOpen(open)
	isOpen = open
	token = token + 1
	local my = token

	if open then
		panel.Visible = true
		panel.GroupTransparency = 1
		panelScale.Scale = 0.92
		panel.Position = UDim2.fromOffset(panelX, panelY - 14)
		tween(panel, SMOOTH, {
			GroupTransparency = 0,
			Position = UDim2.fromOffset(panelX, panelY),
		})
		tween(panelScale, SMOOTH, { Scale = 1 })
	else
		tween(panel, SMOOTH_IN, {
			GroupTransparency = 1,
			Position = UDim2.fromOffset(panelX, panelY - 14),
		})
		local t = tween(panelScale, SMOOTH_IN, { Scale = 0.92 })
		t.Completed:Connect(function()
			if my == token then
				panel.Visible = false
			end
		end)
	end
end

openBtn.Activated:Connect(function()
	setOpen(not isOpen)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)

-- DRAGGING (title bar) ------------------------------------------------------
local dragging = false
local dragStart = nil
local startX, startY = 0, 0

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startX, startY = panelX, panelY
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(800, 400)
		local nx = math.clamp(startX + delta.X, PANEL_W / 2, v.X - PANEL_W / 2)
		local ny = math.clamp(startY + delta.Y, PANEL_H / 2, v.Y - PANEL_H / 2)
		panelX, panelY = nx, ny
		panel.Position = UDim2.fromOffset(nx, ny)
	end
end)

-- CHARACTER HELPERS ----------------------------------------------------------
local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isR6()
	local hum = getHumanoid()
	return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
end

local origs = {}
local uid = 0
local emoteTrack = nil
local emoteId = nil

local function remember(key, restoreFn)
	if not origs[key] then
		origs[key] = restoreFn
	end
end

local function uniqueKey(prefix)
	uid = uid + 1
	return prefix .. ":" .. uid
end

local function stopEmote()
	if emoteTrack then
		pcall(function() emoteTrack:Stop() end)
	end
	emoteTrack = nil
	emoteId = nil
end

player.CharacterAdded:Connect(function()
	origs = {}
	emoteTrack = nil
	emoteId = nil
end)

local function loadAsset(id)
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. tostring(id))
	end)
	if ok and type(objs) == "table" and objs[1] then
		return objs[1]
	end
	local ok2, model = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok2 and model then
		return model
	end
	return nil
end

local function findOfClass(root, className)
	if root:IsA(className) then return root end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA(className) then
			return d
		end
	end
	return nil
end

-- APPLY: accessories ----------------------------------------------------------
local function applyAccessory(assetId)
	local hum = getHumanoid()
	if not hum then return false, "Character not found" end
	local loaded = loadAsset(assetId)
	if not loaded then return false, "Failed to load asset" end

	local found = {}
	if loaded:IsA("Accessory") then
		table.insert(found, loaded)
	end
	for _, d in ipairs(loaded:GetDescendants()) do
		if d:IsA("Accessory") then
			table.insert(found, d)
		end
	end

	local added = 0
	for _, acc in ipairs(found) do
		local copy = acc:Clone()
		local ok = pcall(function()
			hum:AddAccessory(copy)
		end)
		if ok then
			added = added + 1
			remember(uniqueKey("acc"), function()
				copy:Destroy()
			end)
		end
	end
	loaded:Destroy()

	if added == 0 then return false, "No accessory found in this item" end
	return true, "Accessory equipped"
end

-- APPLY: classic clothing -------------------------------------------------------
local function applyClothing(className, assetId, label)
	local char = player.Character
	if not char then return false, "Character not found" end
	local loaded = loadAsset(assetId)
	if not loaded then return false, "Failed to load asset" end

	local src = findOfClass(loaded, className)
	if not src then
		loaded:Destroy()
		return false, "No " .. label .. " found in this item"
	end

	local oldCopies = {}
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA(className) then
			table.insert(oldCopies, child:Clone())
		end
	end

	remember("cloth:" .. className, function()
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA(className) then
				child:Destroy()
			end
		end
		for _, c in ipairs(oldCopies) do
			c:Clone().Parent = char
		end
	end)

	for _, child in ipairs(char:GetChildren()) do
		if child:IsA(className) then
			child:Destroy()
		end
	end
	src:Clone().Parent = char
	loaded:Destroy()
	return true, label .. " equipped"
end

-- APPLY: face -----------------------------------------------------------------------
local function applyFace(assetId)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return false, "Head not found" end
	local loaded = loadAsset(assetId)
	if not loaded then return false, "Failed to load asset" end

	local srcDecal = findOfClass(loaded, "Decal")
	if not srcDecal then
		loaded:Destroy()
		return false, "No face found in this item"
	end

	local face = head:FindFirstChildOfClass("Decal")
	if not face then
		face = create("Decal", { Name = "face", Face = Enum.NormalId.Front }, head)
		remember(uniqueKey("faceNew"), function()
			face:Destroy()
		end)
	else
		local oldTex = face.Texture
		remember("face:old", function()
			face.Texture = oldTex
		end)
	end
	face.Texture = srcDecal.Texture
	loaded:Destroy()
	return true, "Face equipped"
end

-- APPLY: animation packs (bundles) -----------------------------------------------------
local animCache = {}

local function resolveAnimPack(bundleId)
	if animCache[bundleId] then
		return animCache[bundleId]
	end
	local ok, details = pcall(function()
		return AssetService:GetBundleDetailsAsync(bundleId)
	end)
	if not ok or not details then return nil end

	local roles = {}
	for _, item in ipairs(details.Items) do
		if item.Type == "Asset" then
			local okI, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.Id, Enum.InfoType.Asset)
			end)
			if okI and info then
				local role = ROLE_BY_TYPE[info.AssetTypeId]
				if role then
					roles[role] = item.Id
				end
			end
		end
	end
	animCache[bundleId] = roles
	return roles
end

local function applyAnimationPack(bundleId)
	local char = player.Character
	local hum = getHumanoid()
	if not char or not hum then return false, "Character not found" end
	if isR6() then return false, "Animation packs only work on R15" end

	local animate = char:FindFirstChild("Animate")
	if not animate then return false, "No Animate script on this character" end

	local roles = resolveAnimPack(bundleId)
	if not roles then return false, "Pack not found" end

	local changed = 0
	for role, assetId in pairs(roles) do
		local path = ANIM_PATHS[role]
		local folder = path and animate:FindFirstChild(path[1])
		if folder then
			for _, childName in ipairs(path[2]) do
				local anim = folder:FindFirstChild(childName)
				if anim and anim:IsA("Animation") then
					local oldId = anim.AnimationId
					remember(uniqueKey("anim"), function()
						anim.AnimationId = oldId
					end)
					anim.AnimationId = "rbxassetid://" .. tostring(assetId)
					changed = changed + 1
				end
			end
		end
	end

	if changed == 0 then return false, "Nothing to change in this pack" end

	task.spawn(function()
		pcall(function()
			local animator = hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
			end
			animate.Disabled = true
			task.wait(0.1)
			animate.Disabled = false
		end)
	end)
	return true, "Animation pack equipped"
end

-- APPLY: emotes (play on your character) ---------------------------------------------------
local function applyEmote(assetId)
	local hum = getHumanoid()
	if not hum then return false, "Character not found" end

	if emoteTrack and emoteId == assetId then
		stopEmote()
		return true, "Emote stopped"
	end
	stopEmote()

	local animId = "rbxassetid://" .. tostring(assetId)
	local loaded = loadAsset(assetId)
	if loaded then
		local a = findOfClass(loaded, "Animation")
		if a and a.AnimationId ~= "" then
			animId = a.AnimationId
		end
		loaded:Destroy()
	end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = create("Animator", {}, hum)
	end

	local anim = create("Animation", { AnimationId = animId }, nil)
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not track then return false, "Could not load emote" end

	track.Priority = Enum.AnimationPriority.Action
	track:Play()
	emoteTrack = track
	emoteId = assetId
	if isR6() then
		return true, "Playing (R15 emotes may not move an R6 body)"
	end
	return true, "Playing emote (tap again to stop)"
end

local function resetAll()
	stopEmote()
	local n = 0
	for _, fn in pairs(origs) do
		pcall(fn)
		n = n + 1
	end
	origs = {}
	if n > 0 then
		setStatus("Everything restored", "ok")
	else
		setStatus("Nothing to restore")
	end
end

resetBtn.Activated:Connect(resetAll)

local function applyItem(cat, item)
	local kind = cat.Kind
	if kind == "accessory" then
		return applyAccessory(item.Id)
	elseif kind == "tshirt" then
		return applyClothing("ShirtGraphic", item.Id, "T-Shirt")
	elseif kind == "shirt" then
		return applyClothing("Shirt", item.Id, "Shirt")
	elseif kind == "pants" then
		return applyClothing("Pants", item.Id, "Pants")
	elseif kind == "face" then
		return applyFace(item.Id)
	elseif kind == "emote" then
		return applyEmote(item.Id)
	elseif kind == "animation" then
		return applyAnimationPack(item.Id)
	end
	return false, "Unsupported category"
end

-- SEARCH + GRID ------------------------------------------------------------------------------
local catIndex = 1
local limitedMode = false
local pages = nil
local seen = {}
local count = 0
local loading = false

local function clearGrid()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addCard(item, cat)
	if seen[item.Id] then return end
	seen[item.Id] = true
	count = count + 1

	local card = create("TextButton", {
		Text = "",
		BackgroundColor3 = C_CARD,
		BorderSizePixel = 0,
	}, scroll)
	corner(card, 8)
	pressable(card, C_CARD, C_CARD_HOVER)

	local thumbType = cat.Bundle and "BundleThumbnail" or "Asset"
	create("ImageLabel", {
		Image = ("rbxthumb://type=%s&id=%d&w=150&h=150"):format(thumbType, item.Id),
		BackgroundColor3 = C_SURFACE,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 76),
		Position = UDim2.fromOffset(4, 4),
	}, card)

	create("TextLabel", {
		Text = tostring(item.Name or item.Id),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = C_TEXT,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 28),
		Position = UDim2.new(0, 2, 1, -30),
	}, card)

	card.Activated:Connect(function()
		setStatus("Applying...")
		local ok, msg = applyItem(cat, item)
		setStatus(msg, ok and "ok" or "warn")
	end)
end

local function matchesCategory(item, cat)
	if cat.Bundle then
		return item.ItemType == Enum.AvatarItemType.Bundle or item.ItemType == "Bundle"
	end
	return item.ItemType == Enum.AvatarItemType.Asset or item.ItemType == "Asset"
end

local function addCurrentPage(cat)
	local okP, current = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okP or type(current) ~= "table" then return 0 end

	local before = count
	for _, item in ipairs(current) do
		if matchesCategory(item, cat) then
			addCard(item, cat)
		end
	end
	return count - before
end

local function updateStatus()
	local finished = pages and pages.IsFinished
	setStatus("Loaded: " .. count .. (finished and " (all pages loaded)" or " (more available)"))
	moreBtn.Text = finished and "All Loaded" or "Load More"
end

local function loadMore()
	if loading or not pages or pages.IsFinished then return end
	loading = true
	setStatus("Loading next page...")
	local ok = pcall(function()
		pages:AdvanceToNextPageAsync()
	end)
	if ok then
		addCurrentPage(CATEGORIES[catIndex])
	end
	loading = false
	updateStatus()
end

local function buildParams(cat)
	local params = CatalogSearchParams.new()
	params.SearchKeyword = searchBox.Text

	if cat.Bundle then
		local t = enumItem(Enum.BundleType, "Animations")
		if not t then return nil, "Animations are not supported by this client" end
		params.BundleTypes = { t }
	else
		local list = {}
		for _, name in ipairs(cat.Types) do
			local t = enumItem(Enum.AvatarAssetType, name)
			if t then
				table.insert(list, t)
			end
		end
		if #list == 0 then
			return nil, cat.Name .. " is not supported by this client"
		end
		params.AssetTypes = list
	end

	if limitedMode then
		local sales = enumItem(Enum.SalesTypeFilter, "Collectibles")
		if sales then
			pcall(function() params.SalesTypeFilter = sales end)
		end
		local filt = enumItem(Enum.CatalogCategoryFilter, "Collectibles")
		if filt then
			pcall(function() params.CategoryFilter = filt end)
		end
		pcall(function() params.IncludeOffSale = true end)
	else
		local sales = enumItem(Enum.SalesTypeFilter, "All")
		if sales then
			pcall(function() params.SalesTypeFilter = sales end)
		end
	end
	return params
end

local function startSearch()
	if loading then return end
	loading = true
	setStatus("Searching...")
	clearGrid()
	seen = {}
	count = 0
	pages = nil

	local cat = CATEGORIES[catIndex]
	local params, err = buildParams(cat)
	if not params then
		setStatus(err, "warn")
		loading = false
		return
	end

	local ok, result = pcall(function()
		return AvatarEditorService:SearchCatalog(params)
	end)
	if not ok or not result then
		setStatus("Search failed: " .. tostring(result), "warn")
		loading = false
		return
	end

	pages = result
	addCurrentPage(cat)

	local guard = 0
	while count < 12 and not pages.IsFinished and guard < 6 do
		guard = guard + 1
		local okN = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not okN then break end
		addCurrentPage(cat)
	end

	loading = false
	updateStatus()
end

-- category tabs ------------------------------------------------------------------------------
local tabButtons = {}

local function selectCategory(index)
	catIndex = index
	for i, b in ipairs(tabButtons) do
		if i == index then
			tween(b, FAST, { BackgroundColor3 = C_ACCENT })
		else
			tween(b, FAST, { BackgroundColor3 = C_CARD })
		end
	end
	stopEmote()
	startSearch()
end

for i, cat in ipairs(CATEGORIES) do
	local b = create("TextButton", {
		Text = cat.Name,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = C_TEXT,
		BackgroundColor3 = (i == 1) and C_ACCENT or C_CARD,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = i,
	}, strip)
	corner(b, 8)
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
	tabButtons[i] = b
	b.Activated:Connect(function()
		selectCategory(i)
	end)
end

-- Regular / Limited ---------------------------------------------------------------------------
local function setLimited(value)
	limitedMode = value
	tween(regularBtn, FAST, { BackgroundColor3 = value and C_CARD or C_ACCENT })
	tween(limitedBtn, FAST, { BackgroundColor3 = value and C_ACCENT or C_CARD })
	startSearch()
end

regularBtn.Activated:Connect(function()
	if limitedMode then setLimited(false) end
end)
limitedBtn.Activated:Connect(function()
	if not limitedMode then setLimited(true) end
end)

searchBtn.Activated:Connect(startSearch)
searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then startSearch() end
end)

moreBtn.Activated:Connect(loadMore)

scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	local bottom = scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y
	if scroll.AbsoluteCanvasSize.Y > 0 and bottom >= scroll.AbsoluteCanvasSize.Y - 40 then
		loadMore()
	end
end)

startSearch()
