--[[
	CATASTROPHES EN FOLIE — survie par manches
	À placer dans ServerScriptService (un seul Script, rien d'autre à construire).
	Les joueurs attendent dans le lobby, sont téléportés sur l'île, puis une
	catastrophe au hasard se déclenche. Les survivants gagnent une victoire et des
	pièces, à dépenser dans le lobby (vitesse et saut).
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

---------------------------------------------------------------- réglages
local INTERMISSION = 15
local ROUND_TIME = 40
local ISLAND = 140 -- taille de l'île
local LOBBY_POS = Vector3.new(320, 20, 0)
local WIN_COINS = 25
local PLAY_COINS = 5
local MAX_LEVEL = 20
local RANKS = { -- victoires nécessaires, titre affiché dans le classement
	{ 0, "Débutant" }, { 10, "Survivant" }, { 40, "Vétéran" }, { 120, "Expert" },
	{ 300, "Maître" }, { 700, "Légende" }, { 1500, "Immortel" },
}

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
local map = make("Folder", { Name = "Carte" }, workspace)
local effects = make("Folder", { Name = "Effets" }, workspace)

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
		Size = UDim2.new(0, 260, 0, 70),
		StudsOffset = Vector3.new(0, height or 4, 0),
		MaxDistance = 120,
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

local status = "Chargement…"

local function createHud(player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	local bar = make("TextLabel", {
		Name = "Status",
		Size = UDim2.new(0.6, 0, 0, 44),
		Position = UDim2.new(0.2, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 0.25,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Text = status,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, bar)
	make("TextLabel", {
		Name = "Notif",
		Size = UDim2.new(0.7, 0, 0, 48),
		Position = UDim2.new(0.15, 0, 0.16, 0),
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

local function setStatus(text)
	status = text
	for _, player in ipairs(Players:GetPlayers()) do
		local gui = getHud(player)
		if gui then
			gui.Status.Text = text
		end
	end
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

---------------------------------------------------------------- contenu payant (Robux)
-- 1. Publie le jeu, puis crée les passes et les produits sur create.roblox.com
--    (ton expérience -> Monétisation -> Passes / Produits développeur).
-- 2. Colle leurs ID ci-dessous. Tant qu'un ID vaut 0, l'achat est désactivé.
local PASS_IDS = {
	vip = 0, -- passe « VIP » (pièces de victoire ×2)
}
local PRODUCT_IDS = {
	coins = 0, -- produit « 100 pièces »
}
local passes = {} -- [player] = { clé = true }

local function hasPass(player, key)
	return passes[player] ~= nil and passes[player][key] == true
end

local function loadPasses(player)
	local owned = {}
	passes[player] = owned
	for key, id in pairs(PASS_IDS) do
		if id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				owned[key] = true
			end
		end
	end
end

local function offer(player, kind, key)
	local id = (kind == "pass" and PASS_IDS or PRODUCT_IDS)[key]
	if not id or id == 0 then
		notify(player, "🛒 Bientôt disponible !")
	elseif kind == "pass" then
		if hasPass(player, key) then
			notify(player, "Tu possèdes déjà ce passe")
		else
			MarketplaceService:PromptGamePassPurchase(player, id)
		end
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

local function robuxStand(name, pos, kind, key)
	local stand = block({
		Name = name,
		Size = Vector3.new(4, 4, 4),
		Position = pos + Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(0, 200, 120),
		Material = Enum.Material.Neon,
	})
	label(stand, name, 5)
	local prompt = make("ProximityPrompt", {
		ObjectText = name,
		ActionText = "Acheter (Robux)",
		HoldDuration = 0.3,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
	}, stand)
	prompt.Triggered:Connect(function(player)
		offer(player, kind, key)
	end)
	return stand
end

---------------------------------------------------------------- données
local store
pcall(function()
	store = DataStoreService:GetDataStore("CatastrophesEnFolie_v1")
end)

local profiles = {} -- [player] = { coins, wins (IntValues), speed, jump, loaded }

local function save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.loaded then
		return
	end
	pcall(function()
		store:SetAsync("u_" .. player.UserId, {
			coins = profile.coins.Value,
			wins = profile.wins.Value,
			speed = profile.speed,
			jump = profile.jump,
			daily = profile.daily,
			streak = profile.streak,
		})
	end)
end

-- achats Robux : passes (permanents) et produits (rachetables)
local function grantProduct(player, key)
	local profile = profiles[player]
	if key ~= "coins" or not profile then
		return false
	end
	profile.coins.Value += 100
	notify(player, "💎 +100 🪙")
	return true
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or not passes[player] then
		return
	end
	for key, id in pairs(PASS_IDS) do
		if id == passId then
			passes[player][key] = true
			notify(player, "✅ Passe activé, merci !")
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player then
		for key, id in pairs(PRODUCT_IDS) do
			if id > 0 and id == receipt.ProductId and grantProduct(player, key) then
				save(player)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function applyPerks(player)
	local profile = profiles[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and hum then
		hum.WalkSpeed = 16 + profile.speed
		hum.UseJumpPower = true
		hum.JumpPower = 50 + 3 * profile.jump
	end
end

---------------------------------------------------------------- monde fixe
for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") or obj.Name == "Baseplate" then
		obj:Destroy()
	end
end

block({
	Name = "Île",
	Size = Vector3.new(ISLAND, 6, ISLAND),
	Position = Vector3.new(0, -3, 0),
	Color = Color3.fromRGB(90, 170, 90),
	Material = Enum.Material.Grass,
})
local water = block({
	Name = "Eau",
	Size = Vector3.new(1200, 1, 1200),
	Position = Vector3.new(0, -5, 0),
	Color = Color3.fromRGB(40, 120, 220),
	Material = Enum.Material.Glass,
	Transparency = 0.3,
	CanCollide = false,
})
water.Touched:Connect(function(hit)
	local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end)

-- lobby
block({
	Name = "Lobby",
	Size = Vector3.new(60, 2, 60),
	Position = LOBBY_POS - Vector3.new(0, 1, 0),
	Color = Color3.fromRGB(60, 60, 80),
	Material = Enum.Material.SmoothPlastic,
})
for _, side in ipairs({ { 0, 30, 60, 1 }, { 0, -30, 60, 1 }, { 30, 0, 1, 60 }, { -30, 0, 1, 60 } }) do
	block({
		Size = Vector3.new(side[3], 8, side[4]),
		Position = LOBBY_POS + Vector3.new(side[1], 4, side[2]),
		Color = Color3.fromRGB(180, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
	})
end
make("SpawnLocation", {
	Anchored = true,
	Size = Vector3.new(12, 1, 12),
	Position = LOBBY_POS + Vector3.new(0, 0.5, 0),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon,
	Neutral = true,
}, world)

local function shop(name, key, offsetZ, color, describe)
	local stand = block({
		Name = name,
		Size = Vector3.new(6, 5, 6),
		Position = LOBBY_POS + Vector3.new(-20, 2.5, offsetZ),
		Color = color,
		Material = Enum.Material.Neon,
	})
	label(stand, name .. "\n" .. MAX_LEVEL .. " niveaux", 6)
	local prompt = make("ProximityPrompt", {
		ObjectText = name,
		ActionText = "Améliorer",
		HoldDuration = 0.25,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
	}, stand)
	prompt.Triggered:Connect(function(player)
		local profile = profiles[player]
		if not profile then
			return
		end
		local level = profile[key]
		local price = math.floor(50 * 1.35 ^ level)
		if level >= MAX_LEVEL then
			notify(player, name .. " : niveau maximum atteint")
		elseif profile.coins.Value < price then
			notify(player, "Niveau " .. (level + 1) .. " : " .. price .. " 🪙 nécessaires")
		else
			profile.coins.Value -= price
			profile[key] = level + 1
			applyPerks(player)
			notify(player, name .. " niveau " .. (level + 1) .. " ! " .. describe)
		end
	end)
end
shop("⚡ Vitesse", "speed", -10, Color3.fromRGB(80, 200, 255), "Tu cours plus vite.")
shop("🦘 Saut", "jump", 10, Color3.fromRGB(140, 255, 120), "Tu sautes plus haut.")

-- boutique Robux
robuxStand("👑 Passe VIP (pièces ×2)", LOBBY_POS + Vector3.new(20, 0, -10), "pass", "vip")
robuxStand("💰 100 pièces", LOBBY_POS + Vector3.new(20, 0, 10), "product", "coins")

---------------------------------------------------------------- carte (reconstruite à chaque manche)
local rng = Random.new()
local HEIGHTS = { 40, 34, 26, 20, 14, 10, 8, 8 }
local SPOTS = {
	Vector3.new(-45, 0, -45), Vector3.new(0, 0, -48), Vector3.new(45, 0, -45),
	Vector3.new(-48, 0, 0), Vector3.new(48, 0, 0),
	Vector3.new(-45, 0, 45), Vector3.new(0, 0, 48), Vector3.new(45, 0, 45),
}

local function buildMap()
	map:ClearAllChildren()
	-- mélange des emplacements
	local order = {}
	for i = 1, #SPOTS do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- tours à escalader (échelle sur le côté)
	for i, height in ipairs(HEIGHTS) do
		local spot = SPOTS[order[i]]
		block({
			Name = "Tour",
			Size = Vector3.new(16, height, 16),
			Position = spot + Vector3.new(0, height / 2, 0),
			Color = Color3.fromHSV(rng:NextNumber(), 0.35, 0.9),
			Material = Enum.Material.Concrete,
		}, map)
		make("TrussPart", {
			Anchored = true,
			Size = Vector3.new(2, height + 2, 2),
			Position = spot + Vector3.new(9, (height + 2) / 2, 0),
			Color = Color3.fromRGB(240, 200, 60),
		}, map)
	end
	-- abris (protègent de ce qui tombe du ciel)
	for _, pos in ipairs({ Vector3.new(-20, 0, 18), Vector3.new(20, 0, -18), Vector3.new(0, 0, 0) }) do
		block({
			Name = "Abri",
			Size = Vector3.new(14, 1, 14),
			Position = pos + Vector3.new(0, 11.5, 0),
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.Wood,
		}, map)
		for _, corner in ipairs({ { -6, -6 }, { -6, 6 }, { 6, -6 }, { 6, 6 } }) do
			block({
				Size = Vector3.new(1, 11, 1),
				Position = pos + Vector3.new(corner[1], 5.5, corner[2]),
				Color = Color3.fromRGB(100, 70, 45),
				Material = Enum.Material.Wood,
			}, map)
		end
	end
end

---------------------------------------------------------------- manche
local alive = {} -- [player] = true

local function aliveCount()
	local n = 0
	for _ in pairs(alive) do
		n += 1
	end
	return n
end

local function rootOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return root, hum
	end
	return nil
end

local function running(endTime)
	return os.clock() < endTime and next(alive) ~= nil
end

local function randomIslandPos(margin)
	local half = ISLAND / 2 - (margin or 6)
	return Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
end

local function randomAlive()
	local list = {}
	for player in pairs(alive) do
		table.insert(list, player)
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- catastrophes
local DISASTERS = {}

table.insert(DISASTERS, {
	name = "🌋 Montée de lave",
	tip = "Grimpe le plus haut possible !",
	run = function(endTime)
		local lava = block({
			Name = "Lave",
			Size = Vector3.new(ISLAND + 80, 2, ISLAND + 80),
			Position = Vector3.new(0, -6, 0),
			Color = Color3.fromRGB(255, 90, 20),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, effects)
		local start = os.clock()
		local duration = endTime - start - 4
		while running(endTime) do
			local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
			local top = -5 + 37 * alpha -- monte jusqu'à y = 32
			lava.Position = Vector3.new(0, top - 1, 0)
			for player in pairs(alive) do
				local root, hum = rootOf(player)
				if root and root.Position.Y - 2.5 < top then
					hum.Health = 0
				end
			end
			task.wait(0.1)
		end
	end,
})

table.insert(DISASTERS, {
	name = "☄️ Pluie de météores",
	tip = "Ne reste pas à découvert !",
	run = function(endTime)
		while running(endTime) do
			local target = randomIslandPos()
			local victim = randomAlive()
			local root = victim and rootOf(victim)
			if root and rng:NextNumber() < 0.4 then
				target = root.Position + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
			end
			local meteor = Instance.new("Part")
			meteor.Name = "Météore"
			meteor.Shape = Enum.PartType.Ball
			meteor.Size = Vector3.new(5, 5, 5)
			meteor.Color = Color3.fromRGB(255, 120, 30)
			meteor.Material = Enum.Material.Neon
			meteor.Position = Vector3.new(target.X, 150, target.Z)
			meteor.Parent = effects
			meteor.AssemblyLinearVelocity = Vector3.new(0, -90, 0)
			make("Fire", { Size = 12, Heat = 0 }, meteor)
			local exploded = false
			meteor.Touched:Connect(function(hit)
				if exploded or hit.Name == "Météore" or hit.Name == "Eau" then
					return
				end
				exploded = true
				make("Explosion", {
					Position = meteor.Position,
					BlastRadius = 7,
					BlastPressure = 200000,
					ExplosionType = Enum.ExplosionType.NoCraters,
				}, effects)
				meteor:Destroy()
			end)
			Debris:AddItem(meteor, 8)
			task.wait(0.35)
		end
	end,
})

table.insert(DISASTERS, {
	name = "☣️ Pluie acide",
	tip = "Abrite-toi sous un toit !",
	run = function(endTime)
		local tint = make("ColorCorrectionEffect", { TintColor = Color3.fromRGB(170, 255, 170) }, Lighting)
		local cloud = block({
			Name = "Nuage",
			Size = Vector3.new(ISLAND, 1, ISLAND),
			Position = Vector3.new(0, 90, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, effects)
		make("ParticleEmitter", {
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 500,
			Speed = NumberRange.new(90),
			Lifetime = NumberRange.new(1.1),
			Color = ColorSequence.new(Color3.fromRGB(120, 255, 80)),
			Size = NumberSequence.new(0.6),
			LightEmission = 0.6,
		}, cloud)
		while running(endTime) do
			for player in pairs(alive) do
				local root, hum = rootOf(player)
				if root then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { player.Character, effects }
					local hit = workspace:Raycast(root.Position, Vector3.new(0, 300, 0), params)
					if not hit then
						hum:TakeDamage(7)
					end
				end
			end
			task.wait(0.5)
		end
		tint:Destroy()
	end,
})

table.insert(DISASTERS, {
	name = "🌪️ Tornade",
	tip = "Cours, elle te poursuit !",
	run = function(endTime)
		local pos = randomIslandPos(20)
		local tornado = block({
			Name = "Tornade",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(70, 18, 18),
			Color = Color3.fromRGB(150, 150, 160),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.45,
			CanCollide = false,
			CanQuery = false,
		}, effects)
		local victim = randomAlive()
		local nextSwitch = os.clock() + 6
		local step = 0.1
		while running(endTime) do
			if os.clock() > nextSwitch or not (victim and alive[victim]) then
				victim = randomAlive()
				nextSwitch = os.clock() + 6
			end
			local targetRoot = victim and rootOf(victim)
			if targetRoot then
				local delta = Vector3.new(targetRoot.Position.X - pos.X, 0, targetRoot.Position.Z - pos.Z)
				if delta.Magnitude > 1 then
					pos += delta.Unit * 13 * step
				end
			end
			tornado.CFrame = CFrame.new(pos.X, 35, pos.Z) * CFrame.Angles(0, os.clock() * 6, math.pi / 2)
			for player in pairs(alive) do
				local root, hum = rootOf(player)
				if root then
					local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
					if flat.Magnitude < 10 then
						hum:TakeDamage(6)
						root.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-40, 40), 70, rng:NextNumber(-40, 40))
					end
				end
			end
			task.wait(step)
		end
	end,
})

table.insert(DISASTERS, {
	name = "⚡ Sol électrique",
	tip = "Quitte le sol quand il devient jaune !",
	run = function(endTime)
		local floor = block({
			Name = "Électricité",
			Size = Vector3.new(ISLAND, 0.4, ISLAND),
			Position = Vector3.new(0, 0.2, 0),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, effects)
		local half = ISLAND / 2
		while running(endTime) do
			-- avertissement
			floor.Color = Color3.fromRGB(255, 230, 60)
			floor.Transparency = 0.6
			task.wait(3)
			-- décharge
			floor.Color = Color3.fromRGB(120, 200, 255)
			floor.Transparency = 0
			local shockEnd = os.clock() + 2.5
			while os.clock() < shockEnd do
				for player in pairs(alive) do
					local root, hum = rootOf(player)
					if root and root.Position.Y < 5 and math.abs(root.Position.X) < half and math.abs(root.Position.Z) < half then
						hum.Health = 0
					end
				end
				task.wait(0.2)
			end
			floor.Transparency = 1
			task.wait(3.5)
		end
	end,
})

table.insert(DISASTERS, {
	name = "💣 Champ de bombes",
	tip = "Éloigne-toi des bombes avant qu'elles n'explosent !",
	run = function(endTime)
		while running(endTime) do
			local pos = randomIslandPos() + Vector3.new(0, 2, 0)
			local victim = randomAlive()
			local root = victim and rootOf(victim)
			if root and rng:NextNumber() < 0.5 then
				pos = root.Position
			end
			local bomb = block({
				Name = "Bombe",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(4, 4, 4),
				Position = pos,
				Color = Color3.fromRGB(30, 30, 30),
				Material = Enum.Material.Metal,
				CanCollide = false,
			}, effects)
			task.delay(1.2, function()
				if bomb.Parent then
					bomb.Color = Color3.fromRGB(255, 40, 40)
					bomb.Material = Enum.Material.Neon
				end
			end)
			task.delay(2.4, function()
				if bomb.Parent then
					make("Explosion", {
						Position = bomb.Position,
						BlastRadius = 13,
						BlastPressure = 300000,
						ExplosionType = Enum.ExplosionType.NoCraters,
					}, effects)
					bomb:Destroy()
				end
			end)
			task.wait(0.45)
		end
	end,
})

table.insert(DISASTERS, {
	name = "🪨 Avalanche de rochers",
	tip = "Esquive, ou cache-toi derrière une tour !",
	run = function(endTime)
		local edge = ISLAND / 2 + 2
		while running(endTime) do
			local offset = rng:NextNumber(-ISLAND / 2 + 8, ISLAND / 2 - 8)
			local side = rng:NextInteger(1, 4)
			local start, dir
			if side == 1 then
				start, dir = Vector3.new(-edge, 9, offset), Vector3.new(1, 0, 0)
			elseif side == 2 then
				start, dir = Vector3.new(edge, 9, offset), Vector3.new(-1, 0, 0)
			elseif side == 3 then
				start, dir = Vector3.new(offset, 9, -edge), Vector3.new(0, 0, 1)
			else
				start, dir = Vector3.new(offset, 9, edge), Vector3.new(0, 0, -1)
			end
			local rock = Instance.new("Part")
			rock.Name = "Rocher"
			rock.Shape = Enum.PartType.Ball
			rock.Size = Vector3.new(10, 10, 10)
			rock.Color = Color3.fromRGB(110, 105, 100)
			rock.Material = Enum.Material.Slate
			rock.Position = start
			rock.Parent = effects
			rock.AssemblyLinearVelocity = dir * 70
			rock.Touched:Connect(function(hit)
				local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = 0
				end
			end)
			Debris:AddItem(rock, 6)
			task.wait(0.7)
		end
	end,
})

---------------------------------------------------------------- boucle principale
local function startRound()
	alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root, hum = rootOf(player)
		if root and profiles[player] then
			alive[player] = true
			profiles[player].coins.Value += PLAY_COINS -- récompense de participation
			applyPerks(player)
			player.Character:PivotTo(CFrame.new(randomIslandPos(30) + Vector3.new(0, 5, 0)))
			hum.Died:Once(function()
				alive[player] = nil
			end)
		end
	end
end

task.spawn(function()
	while true do
		buildMap()
		for t = INTERMISSION, 1, -1 do
			setStatus("Prochaine manche dans " .. t .. " s")
			task.wait(1)
		end

		startRound()
		if aliveCount() == 0 then
			setStatus("En attente de joueurs…")
			task.wait(3)
			continue
		end

		local disaster = DISASTERS[rng:NextInteger(1, #DISASTERS)]
		for t = 5, 1, -1 do
			setStatus("⚠ " .. disaster.name .. " dans " .. t .. " s — " .. disaster.tip)
			task.wait(1)
		end

		local endTime = os.clock() + ROUND_TIME
		local active = true
		task.spawn(function()
			while active do
				local left = math.max(0, math.ceil(endTime - os.clock()))
				setStatus(disaster.name .. " — " .. left .. " s — survivants : " .. aliveCount())
				task.wait(0.5)
			end
		end)
		local ok, err = pcall(disaster.run, endTime)
		if not ok then
			warn("Catastrophe en erreur :", err)
		end
		active = false
		effects:ClearAllChildren()

		local names = {}
		for player in pairs(alive) do
			local profile = profiles[player]
			local root = rootOf(player)
			if profile and root then
				profile.wins.Value += 1
				profile.coins.Value += WIN_COINS * (hasPass(player, "vip") and 2 or 1)
				table.insert(names, player.DisplayName)
				player.Character:PivotTo(CFrame.new(LOBBY_POS + Vector3.new(0, 5, 0)))
				notify(player, "🏆 Tu as survécu ! +" .. WIN_COINS .. " 🪙")
			end
		end
		alive = {}
		if #names > 0 then
			setStatus("Survivants : " .. table.concat(names, ", "))
		else
			setStatus("Personne n'a survécu…")
		end
		task.wait(5)
	end
end)

---------------------------------------------------------------- joueurs
-- récompense quotidienne : série de 7 jours, à réclamer toutes les 20 h
local function giveDaily(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local now = os.time()
	local last = profile.daily or 0
	if now - last < 20 * 3600 then
		return
	end
	profile.streak = now - last < 48 * 3600 and math.min((profile.streak or 0) + 1, 7) or 1
	profile.daily = now
	local amount = math.floor(20) * profile.streak
	profile.coins.Value += amount
	notify(player, "🎁 Récompense du jour " .. profile.streak .. "/7 : +" .. tostring(amount) .. " — reviens demain !")
end

local function onPlayer(player)
	local ls = make("Folder", { Name = "leaderstats" }, player)
	local profile = {
		wins = make("IntValue", { Name = "Victoires" }, ls),
		coins = make("IntValue", { Name = "Pièces" }, ls),
		speed = 0,
		jump = 0,
		loaded = false,
	}

	if store then
		local ok, data = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			profile.loaded = true
			if type(data) == "table" then
				profile.coins.Value = tonumber(data.coins) or 0
				profile.wins.Value = tonumber(data.wins) or 0
				profile.speed = math.clamp(tonumber(data.speed) or 0, 0, MAX_LEVEL)
				profile.jump = math.clamp(tonumber(data.jump) or 0, 0, MAX_LEVEL)
				profile.daily = tonumber(data.daily) or 0
				profile.streak = tonumber(data.streak) or 0
			end
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile
	task.spawn(loadPasses, player)
	task.delay(4, giveDaily, player)
	local rank = make("StringValue", { Name = "Rang" }, ls)
	local function updateRank()
		for _, entry in ipairs(RANKS) do
			if profile.wins.Value >= entry[1] then
				rank.Value = entry[2]
			end
		end
	end
	profile.wins.Changed:Connect(updateRank)
	updateRank()
	createHud(player)

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		applyPerks(player)
	end)
	applyPerks(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	passes[player] = nil
	alive[player] = nil
	save(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)
