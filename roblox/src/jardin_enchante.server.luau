--[[
	JARDIN ENCHANTÉ — jeu de jardinage (planter, attendre, récolter, vendre)
	À placer dans ServerScriptService (un seul Script, rien d'autre à construire).
	Chaque joueur reçoit un jardin. Les plantes poussent même hors ligne, peuvent
	muter (Dorée ×5, Arc-en-ciel ×20) et la pluie double la vitesse de pousse.
	Conseil : règle le nombre maximum de joueurs du serveur sur 8.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

---------------------------------------------------------------- réglages
local SEEDS = { -- grow = secondes de pousse, value = prix de vente
	{ name = "Carotte", price = 10, grow = 8, value = 18, color = Color3.fromRGB(255, 140, 40) },
	{ name = "Tomate", price = 40, grow = 20, value = 85, color = Color3.fromRGB(230, 50, 50) },
	{ name = "Citrouille", price = 150, grow = 45, value = 380, color = Color3.fromRGB(255, 110, 0) },
	{ name = "Fleur de lune", price = 600, grow = 120, value = 1800, color = Color3.fromRGB(170, 190, 255) },
	{ name = "Fruit du dragon", price = 2500, grow = 300, value = 9000, color = Color3.fromRGB(255, 60, 160) },
	{ name = "Étoile filante", price = 12000, grow = 900, value = 55000, color = Color3.fromRGB(255, 240, 120) },
}
local MUTATIONS = {
	{ name = "Dorée", mult = 5, chance = 0.08, color = Color3.fromRGB(255, 205, 0) },
	{ name = "Arc-en-ciel", mult = 20, chance = 0.015 },
}
local PLOT_COUNT = 8
local PLOT_RADIUS = 75
local TILE_COUNT = 20 -- 5 colonnes × 4 rangées
local START_TILES = 6
local START_COINS = 20
local EXPAND_BASE_PRICE = 200
local RAIN_EVERY = 240
local RAIN_DURATION = 60

---------------------------------------------------------------- outils
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local world = make("Folder", { Name = "Monde" }, workspace)

local function block(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent or world
	return p
end

local function label(part, text, height)
	local bb = make("BillboardGui", {
		Size = UDim2.new(0, 280, 0, 80),
		StudsOffset = Vector3.new(0, height or 4, 0),
		MaxDistance = 90,
	}, part)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
	}, bb)
end

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }
local function fmt(n)
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n = n / 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.2f%s", n, SUFFIX[i])
end

local function createHud(player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	local info = make("TextLabel", {
		Name = "Info",
		Size = UDim2.new(0, 290, 0, 120),
		Position = UDim2.new(0, 12, 0.5, -60),
		BackgroundColor3 = Color3.fromRGB(20, 30, 20),
		BackgroundTransparency = 0.25,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, info)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, info)
	make("TextLabel", {
		Name = "Notif",
		Size = UDim2.new(0.7, 0, 0, 48),
		Position = UDim2.new(0.15, 0, 0.14, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 230, 90),
		TextStrokeTransparency = 0,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		Text = "",
	}, gui)
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if playerGui then
		gui.Parent = playerGui
	end
end

local function getHud(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	return playerGui and playerGui:FindFirstChild("HUD")
end

local function notify(player, text)
	local gui = getHud(player)
	if not gui then
		return
	end
	local stamp = os.clock()
	gui.Notif.Text = text
	gui.Notif:SetAttribute("Stamp", stamp)
	task.delay(3.5, function()
		if gui.Parent and gui.Notif:GetAttribute("Stamp") == stamp then
			gui.Notif.Text = ""
		end
	end)
end

---------------------------------------------------------------- données
local store
pcall(function()
	store = DataStoreService:GetDataStore("JardinEnchante_v1")
end)

local profiles = {} -- [player] = { coins (IntValue), basket, inv, tiles, plot, loaded }
local plots = {}
local rng = Random.new()

local function refreshHud(player)
	local profile = profiles[player]
	local gui = getHud(player)
	if not profile or not gui then
		return
	end
	local seeds = {}
	for i, seed in ipairs(SEEDS) do
		if profile.inv[i] > 0 then
			table.insert(seeds, seed.name .. " ×" .. profile.inv[i])
		end
	end
	gui.Info.Text = string.format(
		"🪙 Pièces : %s\n🧺 Récolte à vendre : %s\n🌱 Graines : %s",
		fmt(profile.coins.Value),
		fmt(profile.basket),
		#seeds > 0 and table.concat(seeds, ", ") or "aucune"
	)
end

local function expandPrice(profile)
	return math.floor(EXPAND_BASE_PRICE * 1.6 ^ (profile.tiles - START_TILES))
end

---------------------------------------------------------------- jardins
local SOIL = Color3.fromRGB(110, 75, 45)
local LOCKED = Color3.fromRGB(90, 90, 90)

local function removeCrop(tile)
	if tile.crop then
		tile.crop.part:Destroy()
		tile.crop = nil
	end
end

local function addCrop(tile, seedIndex, plantedAt, mutation)
	removeCrop(tile)
	local seed = SEEDS[seedIndex]
	local part = block({
		Name = seed.name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.6, 0.6, 0.6),
		Color = seed.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, tile.part)
	tile.crop = { seed = seedIndex, plantedAt = plantedAt, mut = mutation, part = part, ripe = false }
end

local function cropValue(crop)
	local value = SEEDS[crop.seed].value
	if crop.mut > 0 then
		value *= MUTATIONS[crop.mut].mult
	end
	return value
end

local function refreshTiles(plot)
	local profile = plot.owner and profiles[plot.owner]
	for i, tile in ipairs(plot.tiles) do
		local unlocked = profile ~= nil and i <= profile.tiles
		tile.part.Color = unlocked and SOIL or LOCKED
		tile.prompt.Enabled = unlocked
	end
	if profile then
		plot.signLabel.Text = "🌻 Jardin de " .. plot.owner.DisplayName
		plot.signPrompt.Enabled = profile.tiles < TILE_COUNT
		plot.signPrompt.ActionText = "Agrandir (" .. fmt(expandPrice(profile)) .. " 🪙)"
	else
		plot.signLabel.Text = "Jardin libre"
		plot.signPrompt.Enabled = false
	end
end

local function onTile(plot, index, player)
	local profile = profiles[player]
	local tile = plot.tiles[index]
	if not profile then
		return
	end
	if plot.owner ~= player then
		notify(player, "Ce n'est pas ton jardin !")
		return
	end
	if index > profile.tiles then
		return
	end

	local crop = tile.crop
	if not crop then
		-- plante la meilleure graine possédée
		for i = #SEEDS, 1, -1 do
			if profile.inv[i] > 0 then
				profile.inv[i] -= 1
				local mutation = 0
				local roll = rng:NextNumber()
				if roll < MUTATIONS[2].chance then
					mutation = 2
				elseif roll < MUTATIONS[2].chance + MUTATIONS[1].chance then
					mutation = 1
				end
				addCrop(tile, i, os.time(), mutation)
				tile.prompt.ActionText = "Regarder"
				refreshHud(player)
				return
			end
		end
		notify(player, "Tu n'as pas de graines : va à la boutique au centre !")
	elseif crop.ripe then
		local value = cropValue(crop)
		profile.basket += value
		local mutationName = crop.mut > 0 and (" " .. MUTATIONS[crop.mut].name) or ""
		notify(player, "🧺 " .. SEEDS[crop.seed].name .. mutationName .. " récoltée (+" .. fmt(value) .. ")")
		removeCrop(tile)
		tile.prompt.ActionText = "Planter"
		refreshHud(player)
	else
		local left = math.max(1, SEEDS[crop.seed].grow - (os.time() - crop.plantedAt))
		notify(player, SEEDS[crop.seed].name .. " : prête dans " .. left .. " s")
	end
end

local function buildPlot(index)
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local pos = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	local folder = make("Folder", { Name = "Jardin" .. index }, world)
	local plot = { cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)), owner = nil, tiles = {} }
	plots[index] = plot

	local base = block({
		Name = "Terrain",
		Size = Vector3.new(30, 0.4, 26),
		Color = Color3.fromRGB(70, 140, 70),
		Material = Enum.Material.Grass,
	}, folder)
	base.CFrame = plot.cf * CFrame.new(0, 0.2, 0)

	for i = 1, TILE_COUNT do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		local part = block({
			Name = "Parcelle" .. i,
			Size = Vector3.new(4, 0.4, 4),
			Material = Enum.Material.Ground,
		}, folder)
		part.CFrame = plot.cf * CFrame.new((col - 2) * 5, 0.6, (row - 1.5) * 5)
		local prompt = make("ProximityPrompt", {
			ObjectText = "Parcelle",
			ActionText = "Planter",
			HoldDuration = 0,
			MaxActivationDistance = 7,
			RequiresLineOfSight = false,
		}, part)
		plot.tiles[i] = { part = part, prompt = prompt, crop = nil }
		prompt.Triggered:Connect(function(player)
			onTile(plot, i, player)
		end)
	end

	local sign = block({
		Name = "Panneau",
		Size = Vector3.new(6, 4, 0.6),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.Wood,
	}, folder)
	sign.CFrame = plot.cf * CFrame.new(0, 2, -14.5)
	plot.signLabel = label(sign, "", 4)
	plot.signPrompt = make("ProximityPrompt", {
		ObjectText = "Jardin",
		ActionText = "Agrandir",
		HoldDuration = 0.3,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
	}, sign)
	plot.signPrompt.Triggered:Connect(function(player)
		local profile = profiles[player]
		if not profile or plot.owner ~= player or profile.tiles >= TILE_COUNT then
			return
		end
		local price = expandPrice(profile)
		if profile.coins.Value < price then
			notify(player, "Agrandir coûte " .. fmt(price) .. " 🪙")
			return
		end
		profile.coins.Value -= price
		profile.tiles += 1
		refreshTiles(plot)
		notify(player, "🌱 Nouvelle parcelle débloquée (" .. profile.tiles .. "/" .. TILE_COUNT .. ")")
	end)

	refreshTiles(plot)
end

---------------------------------------------------------------- monde
for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") or obj.Name == "Baseplate" then
		obj:Destroy()
	end
end

block({
	Name = "Sol",
	Size = Vector3.new(320, 2, 320),
	Position = Vector3.new(0, -1, 0),
	Color = Color3.fromRGB(100, 185, 95),
	Material = Enum.Material.Grass,
})
make("SpawnLocation", {
	Anchored = true,
	Size = Vector3.new(10, 1, 10),
	Position = Vector3.new(0, 0.5, 22),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon,
	Neutral = true,
}, world)

for index = 1, PLOT_COUNT do
	buildPlot(index)
end

local function isBroke(profile)
	if profile.coins.Value >= SEEDS[1].price or profile.basket > 0 then
		return false
	end
	for i = 1, #SEEDS do
		if profile.inv[i] > 0 then
			return false
		end
	end
	if profile.plot then
		for _, tile in ipairs(profile.plot.tiles) do
			if tile.crop then
				return false
			end
		end
	end
	return true
end

-- boutique de graines : un étal par graine, en ligne au centre
for i, seed in ipairs(SEEDS) do
	local stand = block({
		Name = "Étal " .. seed.name,
		Size = Vector3.new(4, 3, 4),
		Position = Vector3.new((i - (#SEEDS + 1) / 2) * 7, 1.5, 0),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.Wood,
	})
	block({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = stand.Position + Vector3.new(0, 2.7, 0),
		Color = seed.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	label(stand, string.format("%s — %s 🪙\npousse : %d s · vaut %s", seed.name, fmt(seed.price), seed.grow, fmt(seed.value)), 6.5)
	local prompt = make("ProximityPrompt", {
		ObjectText = "Graine de " .. seed.name,
		ActionText = "Acheter (" .. fmt(seed.price) .. " 🪙)",
		HoldDuration = 0,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
	}, stand)
	prompt.Triggered:Connect(function(player)
		local profile = profiles[player]
		if not profile then
			return
		end
		if i == 1 and isBroke(profile) then
			profile.inv[1] += 1
			notify(player, "🎁 Une graine de carotte offerte pour te relancer !")
		elseif profile.coins.Value < seed.price then
			notify(player, "Pas assez de pièces pour " .. seed.name)
		else
			profile.coins.Value -= seed.price
			profile.inv[i] += 1
		end
		refreshHud(player)
	end)
end

-- stand de vente
local sellStand = block({
	Name = "Marché",
	Size = Vector3.new(8, 5, 8),
	Position = Vector3.new(0, 2.5, -22),
	Color = Color3.fromRGB(255, 215, 0),
	Material = Enum.Material.Neon,
})
label(sellStand, "💰 MARCHÉ\nvends ta récolte ici", 6)
local sellPrompt = make("ProximityPrompt", {
	ObjectText = "Marché",
	ActionText = "Vendre la récolte",
	HoldDuration = 0,
	MaxActivationDistance = 12,
	RequiresLineOfSight = false,
}, sellStand)
sellPrompt.Triggered:Connect(function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.basket <= 0 then
		notify(player, "Ton panier est vide : récolte d'abord tes plantes !")
		return
	end
	local amount = profile.basket
	profile.basket = 0
	profile.coins.Value += amount
	notify(player, "+" .. fmt(amount) .. " 🪙")
	refreshHud(player)
end)

---------------------------------------------------------------- pousse et météo
local raining = false

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, plot in ipairs(plots) do
			for _, tile in ipairs(plot.tiles) do
				local crop = tile.crop
				if crop then
					if raining then
						crop.plantedAt -= 1 -- la pluie double la vitesse
					end
					local seed = SEEDS[crop.seed]
					local progress = math.clamp((now - crop.plantedAt) / seed.grow, 0, 1)
					local size = 0.6 + 2.6 * progress
					crop.part.Size = Vector3.new(size, size, size)
					crop.part.CFrame = tile.part.CFrame * CFrame.new(0, 0.2 + size / 2, 0)
					if progress >= 1 then
						if not crop.ripe then
							crop.ripe = true
							tile.prompt.ActionText = "Récolter"
							if crop.mut > 0 then
								crop.part.Material = Enum.Material.Neon
								label(crop.part, "✨ " .. MUTATIONS[crop.mut].name .. " ×" .. MUTATIONS[crop.mut].mult, 2.5)
							end
							if crop.mut == 1 then
								crop.part.Color = MUTATIONS[1].color
							end
						end
						if crop.mut == 2 then
							crop.part.Color = Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1)
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(RAIN_EVERY)
		raining = true
		for _, player in ipairs(Players:GetPlayers()) do
			notify(player, "🌧️ Il pleut ! Les plantes poussent 2× plus vite")
		end
		task.wait(RAIN_DURATION)
		raining = false
		for _, player in ipairs(Players:GetPlayers()) do
			notify(player, "☀️ La pluie s'arrête")
		end
	end
end)

---------------------------------------------------------------- joueurs
local function save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.loaded then
		return
	end
	local crops = {}
	if profile.plot then
		for i, tile in ipairs(profile.plot.tiles) do
			if tile.crop then
				table.insert(crops, { i = i, seed = tile.crop.seed, at = tile.crop.plantedAt, mut = tile.crop.mut })
			end
		end
	end
	pcall(function()
		store:SetAsync("u_" .. player.UserId, {
			coins = profile.coins.Value,
			basket = profile.basket,
			tiles = profile.tiles,
			inv = profile.inv,
			crops = crops,
		})
	end)
end

local function onPlayer(player)
	local ls = make("Folder", { Name = "leaderstats" }, player)
	local profile = {
		coins = make("IntValue", { Name = "Pièces", Value = START_COINS }, ls),
		basket = 0,
		inv = {},
		tiles = START_TILES,
		plot = nil,
		loaded = false,
	}
	for i = 1, #SEEDS do
		profile.inv[i] = 0
	end

	local savedCrops = {}
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			profile.loaded = true
			if type(data) == "table" then
				profile.coins.Value = tonumber(data.coins) or START_COINS
				profile.basket = tonumber(data.basket) or 0
				profile.tiles = math.clamp(tonumber(data.tiles) or START_TILES, START_TILES, TILE_COUNT)
				if type(data.inv) == "table" then
					for i = 1, #SEEDS do
						profile.inv[i] = tonumber(data.inv[i]) or 0
					end
				end
				if type(data.crops) == "table" then
					savedCrops = data.crops
				end
			end
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile
	createHud(player)
	profile.coins.Changed:Connect(function()
		refreshHud(player)
	end)

	-- attribution d'un jardin libre
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			profile.plot = plot
			for _, saved in ipairs(savedCrops) do
				local tile = type(saved) == "table" and plot.tiles[tonumber(saved.i) or 0]
				local seedIndex = type(saved) == "table" and tonumber(saved.seed)
				if tile and seedIndex and SEEDS[seedIndex] then
					addCrop(tile, seedIndex, tonumber(saved.at) or os.time(), math.clamp(tonumber(saved.mut) or 0, 0, #MUTATIONS))
					tile.prompt.ActionText = "Regarder"
				end
			end
			refreshTiles(plot)
			break
		end
	end

	refreshHud(player)
	if profile.plot then
		notify(player, "🌻 Achète des graines au centre puis plante-les dans ton jardin !")
	else
		notify(player, "Tous les jardins sont pris sur ce serveur…")
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	local profile = profiles[player]
	if profile and profile.plot then
		local plot = profile.plot
		for _, tile in ipairs(plot.tiles) do
			removeCrop(tile)
			tile.prompt.ActionText = "Planter"
		end
		plot.owner = nil
		profiles[player] = nil
		refreshTiles(plot)
	end
	profiles[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)
