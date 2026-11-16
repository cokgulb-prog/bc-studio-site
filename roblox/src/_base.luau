--[[
	SOCLE COMMUN — ajouté automatiquement par build.py au début des jeux qui en ont besoin
	(mine, combat, pêche). Il fournit : outils de construction, interface, sauvegarde,
	récompense quotidienne et boutique Robux. Le jeu remplit ensuite la table `Game`.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

---------------------------------------------------------------- outils
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") or obj.Name == "Baseplate" then
		obj:Destroy()
	end
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

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad" }
local function fmt(n)
	if n >= 1e48 then
		return string.format("%.2e", n)
	end
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
		Size = UDim2.new(0, 300, 0, 160),
		Position = UDim2.new(0, 12, 0.5, -80),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
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

local function setInfo(player, text)
	local gui = getHud(player)
	if gui then
		gui.Info.Text = text
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

-- grande valeur : NumberValue cachée (pas de limite) + affichage abrégé dans le classement
local function bigStat(player, ls, name)
	local stats = player:FindFirstChild("Stats") or make("Folder", { Name = "Stats" }, player)
	local value = make("NumberValue", { Name = name }, stats)
	local shown = make("StringValue", { Name = name, Value = "0" }, ls)
	value.Changed:Connect(function()
		shown.Value = fmt(value.Value)
	end)
	return value
end

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- jeu
-- Le jeu remplit ces champs :
--   Game.storeName             nom du DataStore
--   Game.serialize(profile)    -> table à sauvegarder
--   Game.grantProduct(player, key) -> true si le produit Robux a été donné
--   Game.cleanup(player)       (facultatif) appelé quand le joueur part
local Game = {}
local profiles = {} -- [player] = profil du jeu (doit contenir loaded, daily, streak)

-- un stand avec une action (touche E / appui sur mobile)
local function stand(name, pos, color, actionText, callback)
	local pedestal = block({
		Name = name,
		Size = Vector3.new(7, 5, 7),
		Position = pos + Vector3.new(0, 2.5, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	label(pedestal, name, 6)
	local prompt = make("ProximityPrompt", {
		ObjectText = name,
		ActionText = actionText,
		HoldDuration = 0.2,
		MaxActivationDistance = 13,
		RequiresLineOfSight = false,
	}, pedestal)
	prompt.Triggered:Connect(function(player)
		local profile = profiles[player]
		if profile then
			callback(player, profile)
		end
	end)
	return pedestal
end

---------------------------------------------------------------- sauvegarde
local store

local function openStore()
	pcall(function()
		store = DataStoreService:GetDataStore(Game.storeName)
	end)
end

-- renvoie (données ou nil, chargement réussi)
local function loadData(player)
	if not store then
		return nil, false
	end
	local ok, data = pcall(function()
		return store:GetAsync("u_" .. player.UserId)
	end)
	if not ok then
		return nil, false
	end
	return type(data) == "table" and data or nil, true
end

local function save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.loaded then
		return
	end
	local data = Game.serialize(profile)
	data.daily = profile.daily
	data.streak = profile.streak
	pcall(function()
		store:SetAsync("u_" .. player.UserId, data)
	end)
end

-- récompense quotidienne : renvoie le jour de la série (1 à 7) si elle est due, sinon nil
local function dailyStreak(profile)
	local now = os.time()
	local last = profile.daily or 0
	if now - last < 20 * 3600 then
		return nil
	end
	profile.streak = now - last < 48 * 3600 and math.min((profile.streak or 0) + 1, 7) or 1
	profile.daily = now
	return profile.streak
end

---------------------------------------------------------------- contenu payant (Robux)
-- 1. Publie le jeu, puis crée les passes et les produits sur create.roblox.com
--    (ton expérience -> Monétisation -> Passes / Produits développeur).
-- 2. Colle leurs ID dans la section « contenu payant » du jeu, plus bas.
--    Tant qu'un ID vaut 0, l'achat est désactivé.
local PASS_IDS = {}
local PRODUCT_IDS = {}
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
	local pedestal = block({
		Name = name,
		Size = Vector3.new(4, 4, 4),
		Position = pos + Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(0, 200, 120),
		Material = Enum.Material.Neon,
	})
	label(pedestal, name, 5)
	local prompt = make("ProximityPrompt", {
		ObjectText = name,
		ActionText = "Acheter (Robux)",
		HoldDuration = 0.3,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
	}, pedestal)
	prompt.Triggered:Connect(function(player)
		offer(player, kind, key)
	end)
	return pedestal
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
	if player and Game.grantProduct then
		for key, id in pairs(PRODUCT_IDS) do
			if id > 0 and id == receipt.ProductId and Game.grantProduct(player, key) then
				save(player)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------- départ des joueurs
Players.PlayerRemoving:Connect(function(player)
	save(player)
	if Game.cleanup then
		Game.cleanup(player)
	end
	profiles[player] = nil
	passes[player] = nil
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

