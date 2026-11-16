--[[
	LAMES & LÉGENDES — simulateur de combat
	Frappe les monstres pour gagner des pièces et de l'expérience, achète de
	meilleures épées, monte de niveau pour débloquer les 20 zones, bats les boss,
	puis renais pour doubler tes dégâts et tes gains.
]]

---------------------------------------------------------------- réglages
local ZONE_NAMES = {
	"Prairie", "Forêt", "Marais", "Désert", "Canyon", "Toundra", "Volcan", "Ruines", "Abysses", "Citadelle",
	"Nuages", "Cristal", "Ombre", "Enfer", "Astral", "Néant", "Chaos", "Éden", "Panthéon", "Infini",
}
local ZONE_LEN = 80
local PATH_WIDTH = 70
local LEVELS_PER_ZONE = 8 -- la zone k demande le niveau 1 + (k - 1) × 8
local ATTACK_RANGE = 16
local ATTACK_COOLDOWN = 0.35
local REBIRTH_LEVEL = 40 -- niveau requis pour la 1re renaissance, +20 à chaque fois

local SWORDS = {} -- 50 épées : dégâts ×1,6 et prix ×1,75 à chaque palier
for k = 1, 50 do
	SWORDS[k] = { damage = math.floor(6 * 1.6 ^ (k - 1)), price = k == 1 and 0 or math.floor(60 * 1.75 ^ (k - 2)) }
end

local function mobHp(zone)
	return 30 * 5 ^ (zone - 1)
end

---------------------------------------------------------------- contenu payant (ID à remplir)
PASS_IDS.double = 0 -- passe « Dégâts ×2 »
PASS_IDS.auto = 0 -- passe « Attaque automatique »
PRODUCT_IDS.coins = 0 -- produit « Bourse d'or » (50 % du prix de la prochaine épée)

Game.storeName = "LamesEtLegendes_v1"
openStore()

---------------------------------------------------------------- profil
local function levelOf(profile)
	return math.floor(math.sqrt(profile.xp / 40)) + 1
end

local function zoneLevel(zone)
	return 1 + (zone - 1) * LEVELS_PER_ZONE
end

local function bestZone(profile)
	return math.clamp(math.floor((levelOf(profile) - 1) / LEVELS_PER_ZONE) + 1, 1, #ZONE_NAMES)
end

local function rebirthLevel(profile)
	return REBIRTH_LEVEL + 20 * profile.rebirths.Value
end

local function damageOf(player, profile)
	local damage = SWORDS[profile.sword].damage * (1 + 0.04 * (levelOf(profile) - 1)) * 2 ^ profile.rebirths.Value
	if hasPass(player, "double") then
		damage *= 2
	end
	return damage
end

local function refresh(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local level = levelOf(profile)
	profile.level.Value = level
	setInfo(player, string.format(
		"🪙 Pièces : %s\n⭐ Niveau %d (XP %s / %s)\n⚔️ Épée n°%d — dégâts %s\n🗺 Zone max : %s\n♻ Renaissance au niveau %d",
		fmt(profile.coins.Value),
		level,
		fmt(profile.xp),
		fmt(40 * level * level),
		profile.sword,
		fmt(damageOf(player, profile)),
		ZONE_NAMES[bestZone(profile)],
		rebirthLevel(profile)
	))
end

Game.serialize = function(profile)
	return {
		coins = profile.coins.Value,
		rebirths = profile.rebirths.Value,
		xp = profile.xp,
		sword = profile.sword,
	}
end

Game.grantProduct = function(player, key)
	local profile = profiles[player]
	if key ~= "coins" or not profile then
		return false
	end
	local nextSword = SWORDS[profile.sword + 1] or SWORDS[#SWORDS]
	local amount = math.max(500, math.floor(nextSword.price * 0.5))
	profile.coins.Value += amount
	notify(player, "💎 +" .. fmt(amount) .. " 🪙")
	return true
end

---------------------------------------------------------------- monde
local TOTAL = #ZONE_NAMES * ZONE_LEN
block({
	Name = "Sol",
	Size = Vector3.new(PATH_WIDTH + 40, 2, TOTAL + 160),
	Position = Vector3.new(0, -1, TOTAL / 2 - 40),
	Color = Color3.fromRGB(95, 170, 90),
	Material = Enum.Material.Grass,
})
make("SpawnLocation", {
	Anchored = true,
	Size = Vector3.new(10, 1, 10),
	Position = Vector3.new(0, 0.5, -45),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon,
	Neutral = true,
}, world)

local mobs = {} -- [zone] = liste de monstres

local function spawnMob(zone, pos, boss)
	local hp = mobHp(zone) * (boss and 15 or 1)
	local size = boss and Vector3.new(9, 11, 9) or Vector3.new(4, 5, 4)
	local color = Color3.fromHSV((zone - 1) / #ZONE_NAMES, boss and 0.9 or 0.6, boss and 0.7 or 1)
	local part = block({
		Name = (boss and "Boss de " or "Monstre de ") .. ZONE_NAMES[zone],
		Size = size,
		Position = pos + Vector3.new(0, size.Y / 2, 0),
		Color = color,
		Material = boss and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})
	local mob = {
		zone = zone,
		part = part,
		maxHp = hp,
		hp = hp,
		coins = hp / 3 * (boss and 2 or 1),
		xp = math.floor(4 * zone ^ 2.5) * (boss and 10 or 1),
		respawn = boss and 20 or 3,
		dead = false,
	}
	mob.text = label(part, "", size.Y / 2 + 2)
	mob.title = (boss and "👑 " or "") .. part.Name
	mob.text.Text = mob.title .. "\n❤ " .. fmt(hp)
	table.insert(mobs[zone], mob)
end

for zone, name in ipairs(ZONE_NAMES) do
	local z0 = (zone - 1) * ZONE_LEN
	mobs[zone] = {}
	local floor = block({
		Name = "Zone " .. name,
		Size = Vector3.new(PATH_WIDTH, 0.2, ZONE_LEN - 2),
		Position = Vector3.new(0, 0.1, z0 + ZONE_LEN / 2),
		Color = Color3.fromHSV((zone - 1) / #ZONE_NAMES, 0.35, 0.85),
		Material = Enum.Material.SmoothPlastic,
	})
	local sign = block({
		Size = Vector3.new(12, 6, 1),
		Position = Vector3.new(PATH_WIDTH / 2 + 4, 3, z0 + 4),
		Color = floor.Color,
		Material = Enum.Material.Wood,
	})
	label(sign, "Zone " .. zone .. " — " .. name .. "\nniveau " .. zoneLevel(zone), 5)
	for _, x in ipairs({ -22, 0, 22 }) do
		spawnMob(zone, Vector3.new(x, 0.2, z0 + 22), false)
		spawnMob(zone, Vector3.new(x, 0.2, z0 + 44), false)
	end
	spawnMob(zone, Vector3.new(0, 0.2, z0 + 66), true)
end

---------------------------------------------------------------- combat
local function attack(player)
	local profile = profiles[player]
	local root = rootOf(player)
	if not profile or not root then
		return
	end
	local now = os.clock()
	if now - profile.lastAttack < ATTACK_COOLDOWN then
		return
	end
	profile.lastAttack = now

	local zone = math.floor(root.Position.Z / ZONE_LEN) + 1
	local list = mobs[zone]
	if not list then
		return
	end
	local target, best = nil, ATTACK_RANGE
	for _, mob in ipairs(list) do
		if not mob.dead then
			local distance = (mob.part.Position - root.Position).Magnitude - mob.part.Size.X / 2
			if distance < best then
				target, best = mob, distance
			end
		end
	end
	if not target then
		return
	end
	if levelOf(profile) < zoneLevel(zone) then
		if now - profile.lastWarn > 4 then
			profile.lastWarn = now
			notify(player, "🔒 Zone " .. ZONE_NAMES[zone] .. " : niveau " .. zoneLevel(zone) .. " requis")
		end
		return
	end

	target.hp -= damageOf(player, profile)
	if target.hp > 0 then
		target.text.Text = target.title .. "\n❤ " .. fmt(target.hp)
		return
	end
	-- monstre vaincu
	target.dead = true
	target.part.Transparency = 1
	target.part.CanCollide = false
	target.text.Text = ""
	local coins = math.floor(target.coins * 2 ^ profile.rebirths.Value)
	profile.coins.Value += coins
	profile.xp += target.xp
	refresh(player)
	task.delay(target.respawn, function()
		target.hp = target.maxHp
		target.dead = false
		target.part.Transparency = 0
		target.part.CanCollide = true
		target.text.Text = target.title .. "\n❤ " .. fmt(target.maxHp)
	end)
end

task.spawn(function() -- attaque automatique pour les détenteurs du passe
	while true do
		task.wait(0.4)
		for _, player in ipairs(Players:GetPlayers()) do
			if hasPass(player, "auto") then
				attack(player)
			end
		end
	end
end)

---------------------------------------------------------------- village
stand("⚔️ Forgeron", Vector3.new(-20, 0, -30), Color3.fromRGB(70, 140, 255), "Améliorer l'épée", function(player, profile)
	local nextSword = SWORDS[profile.sword + 1]
	if not nextSword then
		notify(player, "Tu as déjà la meilleure épée !")
	elseif profile.coins.Value < nextSword.price then
		notify(player, "Épée n°" .. (profile.sword + 1) .. " : " .. fmt(nextSword.price) .. " 🪙")
	else
		profile.coins.Value -= nextSword.price
		profile.sword += 1
		notify(player, "⚔️ Épée n°" .. profile.sword .. " — dégâts de base " .. fmt(nextSword.damage))
	end
	refresh(player)
end)

stand("♻ Renaissance", Vector3.new(20, 0, -30), Color3.fromRGB(255, 215, 0), "Renaître", function(player, profile)
	local needed = rebirthLevel(profile)
	if levelOf(profile) < needed then
		notify(player, "Renaissance : niveau " .. needed .. " requis (dégâts et pièces ×2)")
		return
	end
	profile.coins.Value = 0
	profile.xp = 0
	profile.sword = 1
	profile.rebirths.Value += 1
	notify(player, "♻ Renaissance n°" .. profile.rebirths.Value .. " ! Dégâts et pièces ×" .. fmt(2 ^ profile.rebirths.Value))
	refresh(player)
end)

robuxStand("💎 Passe Dégâts ×2", Vector3.new(-12, 0, -60), "pass", "double")
robuxStand("🤖 Passe Attaque automatique", Vector3.new(0, 0, -60), "pass", "auto")
robuxStand("💰 Bourse d'or", Vector3.new(12, 0, -60), "product", "coins")

---------------------------------------------------------------- joueurs
local function giveTools(player)
	local backpack = player:WaitForChild("Backpack", 10)
	local char = player.Character
	if not backpack or not char then
		return
	end
	local sword = make("Tool", { Name = "⚔️ Épée", RequiresHandle = false, CanBeDropped = false, ToolTip = "Clique près d'un monstre" }, backpack)
	sword.Activated:Connect(function()
		attack(player)
	end)
	local warp = make("Tool", { Name = "🌀 Meilleure zone", RequiresHandle = false, CanBeDropped = false }, backpack)
	warp.Activated:Connect(function()
		local profile = profiles[player]
		if profile and player.Character then
			player.Character:PivotTo(CFrame.new(0, 4, (bestZone(profile) - 1) * ZONE_LEN + 8))
		end
	end)
	local home = make("Tool", { Name = "🏠 Village", RequiresHandle = false, CanBeDropped = false }, backpack)
	home.Activated:Connect(function()
		if player.Character then
			player.Character:PivotTo(CFrame.new(0, 4, -45))
		end
	end)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		task.wait(0.5)
		if sword.Parent == backpack then
			hum:EquipTool(sword)
		end
	end
end

local function onPlayer(player)
	local ls = make("Folder", { Name = "leaderstats" }, player)
	local profile = {
		level = make("IntValue", { Name = "Niveau", Value = 1 }, ls),
		coins = bigStat(player, ls, "Pièces"),
		rebirths = make("IntValue", { Name = "Renaissances" }, ls),
		xp = 0,
		sword = 1,
		lastAttack = 0,
		lastWarn = 0,
		loaded = false,
	}
	local data, loaded = loadData(player)
	profile.loaded = loaded
	if data then
		profile.coins.Value = tonumber(data.coins) or 0
		profile.rebirths.Value = tonumber(data.rebirths) or 0
		profile.xp = tonumber(data.xp) or 0
		profile.sword = math.clamp(tonumber(data.sword) or 1, 1, #SWORDS)
		profile.daily = tonumber(data.daily) or 0
		profile.streak = tonumber(data.streak) or 0
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile
	task.spawn(loadPasses, player)
	createHud(player)
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
		local nextSword = SWORDS[profile.sword + 1] or SWORDS[#SWORDS]
		local amount = math.floor(math.max(100, nextSword.price * 0.1)) * streak
		profile.coins.Value += amount
		refresh(player)
		notify(player, "🎁 Récompense du jour " .. streak .. "/7 : +" .. fmt(amount) .. " 🪙 — reviens demain !")
	else
		notify(player, "⚔️ Avance vers les monstres et clique pour frapper")
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
