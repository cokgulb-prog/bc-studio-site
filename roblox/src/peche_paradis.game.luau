--[[
	PÊCHE PARADIS — simulateur de pêche et de collection
	6 étangs, 36 espèces de la plus commune à la mythique (1 chance sur 1000),
	25 cannes à pêche. Compléter la collection permet de prestiger : tout repart
	de zéro mais chaque poisson vaut 3× plus.
]]

---------------------------------------------------------------- réglages
local RARITIES = { -- weight = fréquence, mult = multiplicateur de valeur
	{ name = "Commun", weight = 60, mult = 1 },
	{ name = "Peu commun", weight = 25, mult = 3 },
	{ name = "Rare", weight = 10, mult = 10 },
	{ name = "Épique", weight = 4, mult = 40 },
	{ name = "Légendaire", weight = 0.9, mult = 250 },
	{ name = "Mythique", weight = 0.1, mult = 2500 },
}

local PONDS = { -- un poisson par rareté, dans l'ordre de RARITIES
	{ name = "Étang du village", fish = { "Gardon", "Perche", "Carpe miroir", "Brochet géant", "Koï doré", "Esprit de l'étang" } },
	{ name = "Rivière claire", fish = { "Truite", "Ombre", "Saumon argenté", "Esturgeon royal", "Anguille électrique", "Dragon de rivière" } },
	{ name = "Lac gelé", fish = { "Lotte", "Omble", "Poisson-glace", "Narval nain", "Baleine de cristal", "Léviathan des glaces" } },
	{ name = "Récif tropical", fish = { "Poisson-clown", "Poisson-perroquet", "Raie manta", "Espadon voilier", "Requin d'or", "Kraken du récif" } },
	{ name = "Lagune volcanique", fish = { "Poisson-braise", "Crabe de lave", "Murène ardente", "Tortue magma", "Phénix des mers", "Titan de feu" } },
	{ name = "Abysses étoilés", fish = { "Lanterne des abysses", "Méduse lunaire", "Calmar cosmique", "Requin nébuleuse", "Baleine galactique", "Poisson des origines" } },
}
local SPECIES = #PONDS * #RARITIES
local POND_SIZE = 60
local POND_SPACING = 90
local RODS_PER_POND = 4 -- l'étang k demande la canne n° (k - 1) × 4 + 1

local RODS = {} -- 25 cannes : chance et vitesse en hausse, prix ×2,4
for k = 1, 25 do
	RODS[k] = {
		luck = 1 + 0.3 * (k - 1),
		cast = math.max(1, 4 - 0.12 * (k - 1)),
		price = k == 1 and 0 or math.floor(120 * 2.4 ^ (k - 2)),
	}
end

local function pondBase(pond)
	return 8 * 7 ^ (pond - 1)
end

---------------------------------------------------------------- contenu payant (ID à remplir)
PASS_IDS.luck = 0 -- passe « Chance ×2 »
PASS_IDS.auto = 0 -- passe « Pêche automatique »
PRODUCT_IDS.coins = 0 -- produit « Trésor englouti » (50 % du prix de la prochaine canne)

Game.storeName = "PecheParadis_v1"
openStore()

---------------------------------------------------------------- profil
local function refresh(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	setInfo(player, string.format(
		"🪙 Pièces : %s\n🧺 Pêche à vendre : %s\n🎣 Canne n°%d (chance ×%.1f)\n📖 Collection : %d / %d (vente +%d %%)\n🏆 Prestiges : %d",
		fmt(profile.coins.Value),
		fmt(profile.basket),
		profile.rod,
		RODS[profile.rod].luck,
		profile.found.Value,
		SPECIES,
		profile.found.Value * 2,
		profile.prestige.Value
	))
end

Game.serialize = function(profile)
	local index = {}
	for key in pairs(profile.index) do
		table.insert(index, key)
	end
	return {
		coins = profile.coins.Value,
		prestige = profile.prestige.Value,
		basket = profile.basket,
		rod = profile.rod,
		index = index,
	}
end

Game.grantProduct = function(player, key)
	local profile = profiles[player]
	if key ~= "coins" or not profile then
		return false
	end
	local nextRod = RODS[profile.rod + 1] or RODS[#RODS]
	local amount = math.max(500, math.floor(nextRod.price * 0.5))
	profile.coins.Value += amount
	notify(player, "💎 +" .. fmt(amount) .. " 🪙")
	return true
end

Game.cleanup = function(player)
	local profile = profiles[player]
	if profile and profile.bobber then
		profile.bobber:Destroy()
	end
end

---------------------------------------------------------------- monde
local LENGTH = #PONDS * POND_SPACING + 120
block({
	Name = "Sol",
	Size = Vector3.new(180, 2, LENGTH),
	Position = Vector3.new(0, -1, LENGTH / 2 - 60),
	Color = Color3.fromRGB(110, 190, 100),
	Material = Enum.Material.Grass,
})
make("SpawnLocation", {
	Anchored = true,
	Size = Vector3.new(10, 1, 10),
	Position = Vector3.new(0, 0.5, -30),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon,
	Neutral = true,
}, world)

local function sell(player, profile)
	if profile.basket <= 0 then
		notify(player, "Ton panier est vide : va pêcher !")
		return
	end
	local amount = profile.basket
	profile.basket = 0
	profile.coins.Value += amount
	notify(player, "+" .. fmt(amount) .. " 🪙")
	refresh(player)
end

local function pondCenter(pond)
	return Vector3.new(0, 0, 60 + (pond - 1) * POND_SPACING)
end

for pond, def in ipairs(PONDS) do
	local center = pondCenter(pond)
	local water = block({
		Name = def.name,
		Size = Vector3.new(POND_SIZE, 0.4, POND_SIZE),
		Position = center + Vector3.new(0, 0.2, 0),
		Color = Color3.fromHSV(0.5 + pond * 0.05, 0.7, 1),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	label(water, "🎣 " .. def.name .. "\ncanne n°" .. ((pond - 1) * RODS_PER_POND + 1) .. " minimum", 12)
	stand("💰 Poissonnier", center + Vector3.new(POND_SIZE / 2 + 14, 0, 0), Color3.fromRGB(255, 215, 0), "Vendre la pêche", sell)
	-- panneau des espèces et de leurs chances
	local board = block({
		Size = Vector3.new(16, 9, 1),
		Position = center + Vector3.new(-POND_SIZE / 2 - 12, 4.5, 0),
		Color = Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.Wood,
	})
	local lines = {}
	for r, rarity in ipairs(RARITIES) do
		table.insert(lines, string.format("%s — %s (%s %%)", def.fish[r], rarity.name, tostring(rarity.weight)))
	end
	local text = label(board, table.concat(lines, "\n"), 9)
	text.Parent.Size = UDim2.new(0, 380, 0, 170)
end

---------------------------------------------------------------- pêche
local rng = Random.new()

local function pondAt(position)
	for pond = 1, #PONDS do
		local delta = position - pondCenter(pond)
		local reach = POND_SIZE / 2 + 8
		if math.abs(delta.X) <= reach and math.abs(delta.Z) <= reach then
			return pond
		end
	end
	return nil
end

local function rollRarity(luck)
	local total = 0
	local weights = {}
	for r, rarity in ipairs(RARITIES) do
		weights[r] = rarity.weight * (r >= 3 and luck or 1)
		total += weights[r]
	end
	local roll = rng:NextNumber(0, total)
	for r = #RARITIES, 1, -1 do
		roll -= weights[r]
		if roll <= 0 then
			return r
		end
	end
	return 1
end

local function cast(player)
	local profile = profiles[player]
	local root = rootOf(player)
	if not profile or not root or profile.fishing then
		return
	end
	local pond = pondAt(root.Position)
	if not pond then
		if os.clock() - profile.lastWarn > 4 then
			profile.lastWarn = os.clock()
			notify(player, "Approche-toi d'un étang pour pêcher")
		end
		return
	end
	local neededRod = (pond - 1) * RODS_PER_POND + 1
	if profile.rod < neededRod then
		notify(player, "🔒 " .. PONDS[pond].name .. " : canne n°" .. neededRod .. " requise")
		return
	end

	profile.fishing = true
	local start = root.Position
	local center = pondCenter(pond)
	local spot = center + (Vector3.new(start.X, 0, start.Z) - center) * 0.5
	profile.bobber = block({
		Name = "Bouchon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		Position = spot + Vector3.new(0, 0.9, 0),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	task.wait(RODS[profile.rod].cast * rng:NextNumber(0.7, 1.3))
	if profile.bobber then
		profile.bobber:Destroy()
		profile.bobber = nil
	end
	profile.fishing = false

	root = rootOf(player)
	if profiles[player] ~= profile or not root or (root.Position - start).Magnitude > 12 then
		return -- le joueur est parti : le poisson s'échappe
	end

	local luck = RODS[profile.rod].luck * (hasPass(player, "luck") and 2 or 1)
	local r = rollRarity(luck)
	local rarity = RARITIES[r]
	local name = PONDS[pond].fish[r]
	local value = pondBase(pond) * rarity.mult * rng:NextNumber(0.6, 1.8)
	value = math.floor(value * (1 + 0.02 * profile.found.Value) * 3 ^ profile.prestige.Value)
	profile.basket += value

	local key = pond .. "_" .. r
	local isNew = not profile.index[key]
	if isNew then
		profile.index[key] = true
		profile.found.Value += 1
	end
	notify(player, string.format("%s %s (%s) — %s 🪙%s", r >= 5 and "🌟" or "🐟", name, rarity.name, fmt(value), isNew and " — NOUVELLE ESPÈCE !" or ""))
	refresh(player)
end

task.spawn(function() -- pêche automatique pour les détenteurs du passe
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = profiles[player]
			local root = rootOf(player)
			if profile and root and not profile.fishing and hasPass(player, "auto") and pondAt(root.Position) then
				task.spawn(cast, player)
			end
		end
	end
end)

---------------------------------------------------------------- village
stand("🎣 Magasin de cannes", Vector3.new(-20, 0, -10), Color3.fromRGB(70, 140, 255), "Améliorer la canne", function(player, profile)
	local nextRod = RODS[profile.rod + 1]
	if not nextRod then
		notify(player, "Tu as déjà la meilleure canne !")
	elseif profile.coins.Value < nextRod.price then
		notify(player, "Canne n°" .. (profile.rod + 1) .. " : " .. fmt(nextRod.price) .. " 🪙")
	else
		profile.coins.Value -= nextRod.price
		profile.rod += 1
		notify(player, string.format("🎣 Canne n°%d — chance ×%.1f", profile.rod, nextRod.luck))
	end
	refresh(player)
end)

stand("🏆 Prestige", Vector3.new(20, 0, -10), Color3.fromRGB(200, 120, 255), "Prestiger", function(player, profile)
	if profile.found.Value < SPECIES then
		notify(player, "Prestige : complète la collection (" .. profile.found.Value .. "/" .. SPECIES .. ") — poissons ×3")
		return
	end
	profile.coins.Value = 0
	profile.basket = 0
	profile.rod = 1
	profile.index = {}
	profile.found.Value = 0
	profile.prestige.Value += 1
	notify(player, "🏆 Prestige n°" .. profile.prestige.Value .. " ! Tous les poissons valent 3× plus")
	refresh(player)
end)

robuxStand("🍀 Passe Chance ×2", Vector3.new(-12, 0, -45), "pass", "luck")
robuxStand("🤖 Passe Pêche automatique", Vector3.new(0, 0, -45), "pass", "auto")
robuxStand("💰 Trésor englouti", Vector3.new(12, 0, -45), "product", "coins")

---------------------------------------------------------------- joueurs
local function giveTools(player)
	local backpack = player:WaitForChild("Backpack", 10)
	local char = player.Character
	if not backpack or not char then
		return
	end
	local rod = make("Tool", { Name = "🎣 Canne à pêche", RequiresHandle = false, CanBeDropped = false, ToolTip = "Clique près d'un étang" }, backpack)
	rod.Activated:Connect(function()
		cast(player)
	end)
	local home = make("Tool", { Name = "🏠 Village", RequiresHandle = false, CanBeDropped = false }, backpack)
	home.Activated:Connect(function()
		if player.Character then
			player.Character:PivotTo(CFrame.new(0, 4, -30))
		end
	end)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		task.wait(0.5)
		if rod.Parent == backpack then
			hum:EquipTool(rod)
		end
	end
end

local function onPlayer(player)
	local ls = make("Folder", { Name = "leaderstats" }, player)
	local profile = {
		coins = bigStat(player, ls, "Pièces"),
		found = make("IntValue", { Name = "Espèces" }, ls),
		prestige = make("IntValue", { Name = "Prestiges" }, ls),
		basket = 0,
		rod = 1,
		index = {},
		fishing = false,
		lastWarn = 0,
		loaded = false,
	}
	local data, loaded = loadData(player)
	profile.loaded = loaded
	if data then
		profile.coins.Value = tonumber(data.coins) or 0
		profile.prestige.Value = tonumber(data.prestige) or 0
		profile.basket = tonumber(data.basket) or 0
		profile.rod = math.clamp(tonumber(data.rod) or 1, 1, #RODS)
		profile.daily = tonumber(data.daily) or 0
		profile.streak = tonumber(data.streak) or 0
		if type(data.index) == "table" then
			local count = 0
			for _, key in ipairs(data.index) do
				if type(key) == "string" and not profile.index[key] then
					profile.index[key] = true
					count += 1
				end
			end
			profile.found.Value = math.min(count, SPECIES)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile
	task.spawn(loadPasses, player)
	createHud(player)
	profile.coins.Changed:Connect(function()
		refresh(player)
	end)
	refresh(player)

	player.CharacterAdded:Connect(function()
		giveTools(player)
	end)
	if player.Character then
		task.spawn(giveTools, player)
	end

	task.wait(4)
	local streak = profiles[player] == profile and dailyStreak(profile)
	if streak then
		local nextRod = RODS[profile.rod + 1] or RODS[#RODS]
		local amount = math.floor(math.max(100, nextRod.price * 0.1)) * streak
		profile.coins.Value += amount
		notify(player, "🎁 Récompense du jour " .. streak .. "/7 : +" .. fmt(amount) .. " 🪙 — reviens demain !")
	else
		notify(player, "🎣 Va au bord d'un étang et clique pour lancer ta ligne")
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
