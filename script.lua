-- ============================================================================
--  Salamangue Cloner (Ultimate Edition)
--  Visible par tous sur le serveur (FE) via CatalogOnApplyOutfit.
--  Fonctionnalités :
--   - Clic-to-Clone (Raycast in-game interactif)
--   - Mode Miroir Live / Stalker (Synchronisation auto en direct)
--   - Restauration du skin d'origine (Mon Skin Initial)
--   - Équipement par ID Direct (Custom Asset Equipper)
--   - Inspecteur d'Accessoires avec copie rapide d'Asset IDs
--   - Modificateurs rapides (Headless, Korblox Right Leg) avec persistance Favoris
--   - Mode Rainbow Skin RGB (Cycle Chroma FE visible par tous)
--   - Contrôles 3D Avancés (Rotation manuelle Drag, Zoom Molette & Emotes 3D)
--   - Auto-Reapply au Respawn (Anti-Reset)
--   - Outfit Randomizer / Mashup (mélangeur de skins du serveur)
--   - Presets cultes intégrés & Système d'Export/Import de skins
--   - Tri des joueurs (Distance, Amis Roblox, Alphabétique)
--   - Thèmes d'accent personnalisables & Raccourcis clavier (RightControl / F4)
-- ============================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

if _G.SalamangueClonerInstance then
	pcall(function() _G.SalamangueClonerInstance() end)
end

-- ============================================================================
--  1. REMOTES DU JEU
-- ============================================================================
local Bloxbiz = ReplicatedStorage:WaitForChild("BloxbizRemotes", 10)
local ApplyOutfitRemote = Bloxbiz and Bloxbiz:FindFirstChild("CatalogOnApplyOutfit")
local ApplyPropertyRemote = Bloxbiz and Bloxbiz:FindFirstChild("CatalogOnApplyToRealHumanoid")

if not ApplyOutfitRemote and Bloxbiz then
	ApplyOutfitRemote = Bloxbiz:WaitForChild("CatalogOnApplyOutfit", 5)
end
if not ApplyPropertyRemote and Bloxbiz then
	ApplyPropertyRemote = Bloxbiz:WaitForChild("CatalogOnApplyToRealHumanoid", 5)
end

-- ============================================================================
--  2. CONFIGURATION, THÈMES & PROPORTIONS
-- ============================================================================
local ScaleLimits = {
	HeadScale = { 0.1, 1.0, 1.0, "Tête" },
	WidthScale = { 0.1, 1.0, 1.0, "Largeur" },
	HeightScale = { 0.1, 1.2, 1.0, "Hauteur" },
	DepthScale = { 0.1, 1.2, 1.0, "Profondeur" },
	BodyTypeScale = { 0.0, 1.0, 0.0, "Type de corps" },
	ProportionScale = { 0.0, 1.0, 0.0, "Proportions" },
}

local ScaleOptions = {}
for k, lim in pairs(ScaleLimits) do
	ScaleOptions[k] = lim[3]
end

local CopyOptions = {
	body = { head = true, torso = true, leftArm = true, rightArm = true, leftLeg = true, rightLeg = true },
	face = { decal = true },
	clothes = { shirt = true, pants = true, graphicTShirt = true },
	colors = { head = true, torso = true, leftArm = true, rightArm = true, leftLeg = true, rightLeg = true },
	animations = { climb = true, fall = true, idle = true, jump = true, mood = true, run = true, swim = true, walk = true },
	scales = true,
	accessories = { hair = true, hat = true, face = true, neck = true, front = true, back = true, waist = true, shirt = true, pants = true, jacket = true, sweater = true, shorts = true, leftShoe = true, rightShoe = true, dressSkirt = true, eyebrow = true, eyelash = true },
}

local SAVEPATH = "cloned_skins.txt"
local SETTINGS_FILE = "cloner_settings.json"
local SavedSkins = {}

local Themes = {
	["Blanc Minimal"] = { Accent = Color3.fromRGB(245, 245, 250), TextDark = Color3.fromRGB(15, 15, 18) },
	["Cyan Neon"]     = { Accent = Color3.fromRGB(0, 225, 255),   TextDark = Color3.fromRGB(10, 15, 20) },
	["Violet Cyber"]  = { Accent = Color3.fromRGB(180, 100, 255), TextDark = Color3.fromRGB(15, 10, 25) },
	["Rouge Crimson"] = { Accent = Color3.fromRGB(255, 75, 90),   TextDark = Color3.fromRGB(20, 10, 12) },
	["Vert Émeraude"] = { Accent = Color3.fromRGB(80, 240, 140),  TextDark = Color3.fromRGB(10, 20, 15) },
}
local CurrentThemeName = "Blanc Minimal"
local CurrentTheme = Themes[CurrentThemeName]
local AutoReapplyOnRespawn = true

local function persistSettings()
	pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode({
			CopyOptions = CopyOptions,
			Theme = CurrentThemeName,
			AutoReapply = AutoReapplyOnRespawn,
		}))
	end)
end

local function deepMerge(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			deepMerge(target[k], v)
		elseif type(v) ~= "table" then
			target[k] = v
		end
	end
end

local function loadSettings()
	local ok, raw = pcall(function() return readfile(SETTINGS_FILE) end)
	if ok and raw and raw ~= "" then
		local okD, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
		if okD and type(parsed) == "table" then
			if parsed.CopyOptions then
				local saved = parsed.CopyOptions
				for catKey, catVal in pairs(saved) do
					if CopyOptions[catKey] ~= nil then
						if type(catVal) == "boolean" and type(CopyOptions[catKey]) == "table" then
							for subKey, _ in pairs(CopyOptions[catKey]) do
								CopyOptions[catKey][subKey] = catVal
							end
						elseif type(catVal) == "table" and type(CopyOptions[catKey]) == "table" then
							deepMerge(CopyOptions[catKey], catVal)
						elseif type(catVal) == "boolean" and type(CopyOptions[catKey]) == "boolean" then
							CopyOptions[catKey] = catVal
						end
					end
				end
			end
			if parsed.Theme and Themes[parsed.Theme] then
				CurrentThemeName = parsed.Theme
				CurrentTheme = Themes[parsed.Theme]
			end
			if parsed.AutoReapply ~= nil then
				AutoReapplyOnRespawn = parsed.AutoReapply
			end
		end
	end
end
loadSettings()

-- ============================================================================
--  3. COOLDOWN & CLIPBOARD
-- ============================================================================
local LastApplyTick = 0
local COOLDOWN_SEC = 3.5
local setStatus = nil

local function canApplyOutfit()
	local now = tick()
	local elapsed = now - LastApplyTick
	if elapsed < COOLDOWN_SEC then
		return false, math.ceil((COOLDOWN_SEC - elapsed) * 10) / 10
	end
	LastApplyTick = now
	return true, 0
end

local function copyToClipboard(text)
	local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
	if fn then
		pcall(function() fn(tostring(text)) end)
		return true
	end
	return false
end

-- ============================================================================
--  3.1 SERVER SNIPER & PRESENCE (REJOINDRE UN JOUEUR PAR PSEUDO / USERID)
-- ============================================================================
local function universalPost(url, bodyJson)
	local reqFn = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
	if reqFn then
		local ok, rep = pcall(function()
			return reqFn({
				Url = url,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = bodyJson,
			})
		end)
		if ok and rep then
			if type(rep) == "string" then return rep end
			if type(rep) == "table" then return rep.Body or rep.body or rep[1] end
		end
	end
	local okCore, repCore = pcall(function() return game:HttpPost(url, bodyJson, "application/json") end)
	if okCore and repCore then return repCore end
	return nil
end

local function extractImageHash(url)
	if not url or type(url) ~= "string" then return "" end
	local h = url:match("rbxcdn%.com/([%w%-_]+)") or url:match("/([%w%-_]+)/%d+/%d+") or url:match("id=([%w%-_]+)")
	if h then return h:lower() end
	local clean = url:gsub("%?.*$", "")
	return clean:lower()
end

local function isImageMatch(url1, url2)
	if not url1 or not url2 then return false end
	if url1 == url2 then return true end
	local h1 = extractImageHash(url1)
	local h2 = extractImageHash(url2)
	if h1 ~= "" and h2 ~= "" and h1 == h2 then return true end
	return false
end

local function getPlayerPresence(userId)
	local payload = HttpService:JSONEncode({ userIds = { userId } })
	local res = universalPost("https://presence.roblox.com/v1/presence/users", payload)
	if res then
		local okD, data = pcall(function() return HttpService:JSONDecode(res) end)
		if okD and data and data.userPresences and data.userPresences[1] then
			local p = data.userPresences[1]
			local typeNames = {
				[0] = "Hors-Ligne ❌",
				[1] = "En ligne (Site) 🌐",
				[2] = "En Jeu 🎮",
				[3] = "Dans Roblox Studio 🛠️",
			}
			local label = typeNames[p.userPresenceType] or "Inconnu"
			if p.userPresenceType == 2 and p.lastLocation and p.lastLocation ~= "" then
				label = "🎮 En Jeu : " .. p.lastLocation
			end
			return {
				raw = p,
				type = p.userPresenceType or 0,
				gameName = p.lastLocation or "Jeu Roblox",
				placeId = p.placeId or p.rootPlaceId,
				gameId = p.gameId,
				label = label,
			}
		end
	end
	return nil
end

local function sniperJoinPlayer(targetInput, statusCallback)
	local function updateStatus(msg, isHighlight)
		if statusCallback then
			pcall(function() statusCallback(msg, isHighlight) end)
		end
		if setStatus then
			pcall(function() setStatus(msg, isHighlight) end)
		end
	end

	targetInput = (targetInput or ""):gsub("%s+", "")
	if targetInput == "" then
		updateStatus("Veuillez entrer un Pseudo ou UserID", false)
		return
	end

	task.spawn(function()
		updateStatus("Résolution du joueur...", true)
		local userId = tonumber(targetInput)
		local userName = targetInput

		if not userId or userId <= 0 then
			local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(targetInput) end)
			if ok and uid and uid > 0 then
				userId = uid
			else
				updateStatus("Pseudo Roblox introuvable", false)
				return
			end
		else
			local okN, nm = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
			if okN and nm then userName = nm end
		end

		updateStatus("Vérification statut @" .. userName .. "...", true)

		-- 1. Présence & JobId direct
		local presence = getPlayerPresence(userId)
		local targetPlaceId = game.PlaceId
		local gameTitle = (game.PlaceId == 4924922222 and "Brookhaven RP" or "ce jeu")

		if presence then
			if presence.type == 0 then
				updateStatus("❌ @" .. userName .. " apparaît Hors-Ligne (Recherche en cours...)", true)
				task.wait(0.5)
			elseif presence.type == 1 then
				updateStatus("🌐 @" .. userName .. " est sur le site Roblox", true)
				task.wait(0.5)
			elseif presence.type == 2 then
				gameTitle = presence.gameName or "Jeu détecté"
				if presence.placeId and presence.placeId > 0 then
					targetPlaceId = presence.placeId
				end
				updateStatus("🎮 @" .. userName .. " est dans : " .. gameTitle, true)
				task.wait(0.5)

				if presence.gameId and type(presence.gameId) == "string" and #presence.gameId > 10 then
					updateStatus("🚀 JobID direct trouvé (" .. string.sub(presence.gameId, 1, 8) .. "...) ! Téléportation...", true)
					task.wait(0.5)
					local okTp = pcall(function()
						TeleportService:TeleportToPlaceInstance(targetPlaceId, presence.gameId, LocalPlayer)
					end)
					if okTp then return end
				end
			elseif presence.type == 3 then
				updateStatus("🛠️ @" .. userName .. " est dans Roblox Studio", false)
				task.wait(0.5)
			end
		end

		updateStatus("Chargement avatar @" .. userName .. "...", true)

		local headshotUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(userId) .. "&size=150x150&format=Png&isCircular=false"
		local targetImgUrl = nil
		local okHead, headRes = pcall(function() return game:HttpGet(headshotUrl) end)
		if okHead and headRes then
			local okHD, hData = pcall(function() return HttpService:JSONDecode(headRes) end)
			if okHD and hData and hData.data and hData.data[1] and hData.data[1].imageUrl then
				targetImgUrl = hData.data[1].imageUrl
			end
		end

		if not targetImgUrl or targetImgUrl == "" then
			updateStatus("Impossible d'obtenir l'avatar du joueur", false)
			return
		end

		local cursor = ""
		local page = 0
		local foundServerId = nil
		local totalServersScanned = 0

		updateStatus("Scan des serveurs de " .. gameTitle .. "...", true)

		while true do
			page = page + 1
			local serverUrl = "https://games.roblox.com/v1/games/" .. tostring(targetPlaceId) .. "/servers/Public?limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
			local okS, sRes = pcall(function() return game:HttpGet(serverUrl) end)
			if not okS or not sRes then break end

			local okD, sData = pcall(function() return HttpService:JSONDecode(sRes) end)
			if not okD or not sData or not sData.data then break end

			local batchPayload = {}
			local tokenToServer = {}

			for _, sv in ipairs(sData.data) do
				totalServersScanned = totalServersScanned + 1
				if sv.playerIds and type(sv.playerIds) == "table" then
					for _, pid in ipairs(sv.playerIds) do
						if pid == userId then
							foundServerId = sv.id
							break
						end
					end
				end
				if foundServerId then break end

				if sv.playerTokens and type(sv.playerTokens) == "table" then
					for _, tok in ipairs(sv.playerTokens) do
						table.insert(batchPayload, {
							requestId = tok,
							type = "AvatarHeadshot",
							targetId = 0,
							token = tok,
							format = "png",
							size = "150x150",
						})
						tokenToServer[tok] = sv.id
					end
				end
			end

			if foundServerId then break end

			if #batchPayload > 0 then
				for i = 1, #batchPayload, 100 do
					local chunk = {}
					for j = i, math.min(i + 99, #batchPayload) do
						table.insert(chunk, batchPayload[j])
					end
					local jsonBody = HttpService:JSONEncode(chunk)
					local bRes = universalPost("https://thumbnails.roblox.com/v1/batch", jsonBody)

					if bRes then
						local okBD, bData = pcall(function() return HttpService:JSONDecode(bRes) end)
						if okBD and bData and bData.data then
							for _, item in ipairs(bData.data) do
								if item.imageUrl and isImageMatch(item.imageUrl, targetImgUrl) then
									foundServerId = tokenToServer[item.requestId]
									break
								end
							end
						end
					end
					if foundServerId then break end
				end
			end

			if foundServerId then break end

			updateStatus("Scan: " .. tostring(totalServersScanned) .. " serveurs vérifiés...", true)

			cursor = sData.nextPageCursor
			if not cursor or cursor == "" or cursor == "null" or page >= 25 then
				break
			end
			task.wait(0.08)
		end

		if foundServerId then
			updateStatus("Serveur trouvé (" .. string.sub(foundServerId, 1, 8) .. "...) ! Téléportation vers " .. gameTitle .. "...", true)
			task.wait(0.6)
			local okTp = pcall(function()
				TeleportService:TeleportToPlaceInstance(targetPlaceId, foundServerId, LocalPlayer)
			end)
			if not okTp then
				updateStatus("Échec de téléportation", false)
			end
		else
			updateStatus("Serveur non trouvé (" .. tostring(totalServersScanned) .. " serveurs vérifiés)", false)
		end
	end)
end

-- ============================================================================
--  4. SÉRIALISATION & FAVORIS
-- ============================================================================
local function serializeValue(v)
	local t = type(v)
	if t == "number" or t == "boolean" or t == "string" then
		return v
	elseif typeof(v) == "Color3" then
		return { __type = "Color3", r = v.R, g = v.G, b = v.B }
	elseif typeof(v) == "EnumItem" then
		local enumName = tostring(v.EnumType):gsub("^Enum%.", "")
		return { __type = "EnumItem", enum = enumName, val = v.Value, name = v.Name }
	elseif t == "table" then
		local out = {}
		for k, item in pairs(v) do
			out[tostring(k)] = serializeValue(item)
		end
		return out
	end
	return nil
end

local function deserializeValue(v)
	if type(v) ~= "table" then return v end
	if v.__type == "Color3" then
		return Color3.new(v.r or 1, v.g or 1, v.b or 1)
	elseif v.__type == "EnumItem" then
		if v.enum and v.name then
			local cleanEnum = v.enum:gsub("^Enum%.", "")
			if Enum[cleanEnum] and Enum[cleanEnum][v.name] then
				return Enum[cleanEnum][v.name]
			end
		end
		return v.val or 0
	end
	local out = {}
	for k, item in pairs(v) do
		local numKey = tonumber(k)
		out[numKey or k] = deserializeValue(item)
	end
	return out
end

local function persistSkinsToFile()
	local serializable = {}
	for _, sk in ipairs(SavedSkins) do
		table.insert(serializable, {
			name = sk.name or "Skin",
			date = sk.date or os.date("%d/%m %H:%M"),
			outfit = serializeValue(sk.outfit),
			userId = sk.userId or nil,
		})
	end
	local ok, json = pcall(function() return HttpService:JSONEncode(serializable) end)
	if ok and json then
		pcall(function() writefile(SAVEPATH, json) end)
	end
end

local function loadSkinsFromFile()
	local okR, content = pcall(function() return readfile(SAVEPATH) end)
	if okR and content and content ~= "" then
		local okD, data = pcall(function() return HttpService:JSONDecode(content) end)
		if okD and type(data) == "table" then
			SavedSkins = {}
			for _, item in ipairs(data) do
				if type(item) == "table" and item.outfit then
					table.insert(SavedSkins, {
						name = item.name or "Skin",
						date = item.date or "",
						outfit = deserializeValue(item.outfit),
						userId = tonumber(item.userId) or nil,
					})
				end
			end
		end
	end
end
loadSkinsFromFile()

-- ============================================================================
--  5. CATALOGUE DE PRESETS INTÉGRÉS
-- ============================================================================
local BuiltInPresets = {
	{
		name = "Headless Slender",
		desc = "Look noir & blanc moderne sans tête",
		outfit = {
			Head = 134082579, Shirt = 6982944322, Pants = 6982945209, Face = 0,
			HeadScale = 1, WidthScale = 0.9, HeightScale = 1.05, DepthScale = 1,
			IdleAnimation = 656117400, WalkAnimation = 656121769, RunAnimation = 656118852,
			Accessories = {
				{ AssetId = 376527350, AccessoryType = Enum.AccessoryType.Hair, Order = 1 },
				{ AssetId = 6958763567, AccessoryType = Enum.AccessoryType.Face, Order = 2 },
			}
		}
	},
	{
		name = "Korblox Deathspeaker",
		desc = "Jambe droite squelette Korblox",
		outfit = {
			RightLeg = 139607718, Head = 0, Shirt = 4784738291, Pants = 4784739182, Face = 209712379,
			HeadScale = 1, WidthScale = 1, HeightScale = 1, DepthScale = 1,
			IdleAnimation = 616006778, WalkAnimation = 616013216, RunAnimation = 616010382,
			Accessories = { { AssetId = 139607068, AccessoryType = Enum.AccessoryType.Hat, Order = 1 } }
		}
	},
	{
		name = "Noob God Classic",
		desc = "Couleurs classiques jaune, bleu et vert",
		outfit = {
			Head = 0, Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0,
			HeadColor = Color3.fromRGB(245, 205, 48), TorsoColor = Color3.fromRGB(13, 105, 172),
			LeftArmColor = Color3.fromRGB(245, 205, 48), RightArmColor = Color3.fromRGB(245, 205, 48),
			LeftLegColor = Color3.fromRGB(164, 189, 71), RightLegColor = Color3.fromRGB(164, 189, 71),
			Shirt = 0, Pants = 0, GraphicTShirt = 0, Face = 0,
			HeadScale = 1, WidthScale = 1, HeightScale = 1, DepthScale = 1, Accessories = {}
		}
	},
	{
		name = "Bacon Lord",
		desc = "L'incontournable look Pal Hair légendaire",
		outfit = {
			Head = 0, Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0,
			Shirt = 144076358, Pants = 144076760, Face = 7699174,
			Accessories = { { AssetId = 62234425, AccessoryType = Enum.AccessoryType.Hair, Order = 1 } }
		}
	},
	{
		name = "Cyberpunk Assassin",
		desc = "Style futuriste katana et capuche néon",
		outfit = {
			Head = 0, Shirt = 3986026418, Pants = 3986027192,
			HeadScale = 1, WidthScale = 0.95, HeightScale = 1.05, DepthScale = 1,
			IdleAnimation = 742637544, WalkAnimation = 742640026, RunAnimation = 742638842,
			Accessories = {
				{ AssetId = 48474294, AccessoryType = Enum.AccessoryType.Hat, Order = 1 },
				{ AssetId = 11748379, AccessoryType = Enum.AccessoryType.Back, Order = 2 },
			}
		}
	}
}

-- ============================================================================
--  6. EXTRACTION & GESTION DES HUMANIDESCRIPTION
-- ============================================================================
local function applyProperty(prop, assetId)
	if ApplyPropertyRemote and assetId and assetId ~= 0 then
		pcall(function()
			ApplyPropertyRemote:FireServer({ Property = prop, AssetId = assetId })
		end)
	end
end

local function applyAccessory(accessoryType, assetId, order)
	if ApplyPropertyRemote and assetId and assetId ~= 0 then
		pcall(function()
			ApplyPropertyRemote:FireServer({
				AccessoryData = {
					AccessoryType = accessoryType,
					AssetId = assetId,
					Order = order or 1,
				},
			})
		end)
	end
end

local function getAuthenticDescription(targetPlayer, targetUserId)
	local humdes = nil
	if targetPlayer and targetPlayer.Character then
		local character = targetPlayer.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 2)
		if humanoid then
			local tries = 0
			repeat
				humdes = humanoid:GetAppliedDescription()
				tries = tries + 1
				if not humdes then task.wait(0.2) end
			until humdes or tries >= 4
		end
	end

	local userId = targetUserId or (targetPlayer and targetPlayer.UserId)
	if (not humdes or humdes.Head == nil) and userId and userId > 0 then
		local okApi, apiDesc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if okApi and apiDesc then
			humdes = apiDesc
		end
	end
	return humdes
end

local function getLocalPlayerDescription()
	local humdes = nil
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() humdes = hum:GetAppliedDescription() end) end
	end
	if not humdes then
		pcall(function() humdes = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
	end
	return humdes
end

local OriginalPlayerDescription = getLocalPlayerDescription()

local function buildDescriptionTable(humdes, options, bodyScaleOverrides)
	options = options or CopyOptions
	local base = getLocalPlayerDescription()
	local outfit = {}

	local accTypeToSubKey = {
		[Enum.AccessoryType.Hair] = "hair",
		[Enum.AccessoryType.Hat] = "hat",
		[Enum.AccessoryType.Face] = "face",
		[Enum.AccessoryType.Neck] = "neck",
		[Enum.AccessoryType.Front] = "front",
		[Enum.AccessoryType.Back] = "back",
		[Enum.AccessoryType.Waist] = "waist",
		[Enum.AccessoryType.Shirt] = "shirt",
		[Enum.AccessoryType.Pants] = "pants",
		[Enum.AccessoryType.Jacket] = "jacket",
		[Enum.AccessoryType.Sweater] = "sweater",
		[Enum.AccessoryType.Shorts] = "shorts",
		[Enum.AccessoryType.LeftShoe] = "leftShoe",
		[Enum.AccessoryType.RightShoe] = "rightShoe",
		[Enum.AccessoryType.DressSkirt] = "dressSkirt",
		[Enum.AccessoryType.Eyebrow] = "eyebrow",
		[Enum.AccessoryType.Eyelash] = "eyelash",
	}

	-- 1. Initialiser le skin avec l'équipement actuel du joueur (base)
	if base then
		local allProps = {
			"Head", "Torso", "LeftArm", "LeftLeg", "RightArm", "RightLeg",
			"Face", "Shirt", "Pants", "GraphicTShirt",
			"HeadColor", "TorsoColor", "LeftArmColor", "LeftLegColor", "RightArmColor", "RightLegColor",
			"ClimbAnimation", "FallAnimation", "IdleAnimation", "JumpAnimation", "MoodAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation",
			"HeadScale", "WidthScale", "DepthScale", "HeightScale", "BodyTypeScale", "ProportionScale",
		}
		for _, p in ipairs(allProps) do
			pcall(function() outfit[p] = base[p] end)
		end
		local allAccProps = {
			"FaceAccessory", "HatAccessory", "HairAccessory", "NeckAccessory",
			"FrontAccessory", "BackAccessory", "WaistAccessory", "ShirtAccessory",
			"PantsAccessory", "JacketAccessory", "SweaterAccessory", "ShortsAccessory",
			"LeftShoeAccessory", "RightShoeAccessory", "DressSkirtAccessory",
			"EyebrowAccessory", "EyelashAccessory"
		}
		for _, ap in ipairs(allAccProps) do
			pcall(function() if base[ap] and base[ap] ~= "" then outfit[ap] = base[ap] end end)
		end
	end

	-- 2. Remplacer sélectivement UNIQUEMENT les catégories cochées depuis la cible
	if humdes then
		if options.body then
			local bodyMap = { head = "Head", torso = "Torso", leftArm = "LeftArm", rightArm = "RightArm", leftLeg = "LeftLeg", rightLeg = "RightLeg" }
			for subKey, propName in pairs(bodyMap) do
				if options.body[subKey] then
					pcall(function() outfit[propName] = humdes[propName] end)
				end
			end
		end

		if options.face and options.face.decal then
			pcall(function() outfit["Face"] = humdes["Face"] end)
		end

		if options.clothes then
			if options.clothes.shirt then pcall(function() outfit["Shirt"] = humdes["Shirt"] end) end
			if options.clothes.pants then pcall(function() outfit["Pants"] = humdes["Pants"] end) end
			if options.clothes.graphicTShirt then pcall(function() outfit["GraphicTShirt"] = humdes["GraphicTShirt"] end) end
		end

		if options.colors then
			local colorMap = { head = "HeadColor", torso = "TorsoColor", leftArm = "LeftArmColor", rightArm = "RightArmColor", leftLeg = "LeftLegColor", rightLeg = "RightLegColor" }
			for subKey, propName in pairs(colorMap) do
				if options.colors[subKey] then pcall(function() outfit[propName] = humdes[propName] end) end
			end
		end

		if options.animations then
			local animMap = { climb = "ClimbAnimation", fall = "FallAnimation", idle = "IdleAnimation", jump = "JumpAnimation", mood = "MoodAnimation", run = "RunAnimation", swim = "SwimAnimation", walk = "WalkAnimation" }
			for subKey, propName in pairs(animMap) do
				if options.animations[subKey] then pcall(function() outfit[propName] = humdes[propName] end) end
			end
		end

		if options.scales then
			local scaleProps = { "HeadScale", "WidthScale", "DepthScale", "HeightScale", "BodyTypeScale", "ProportionScale" }
			for _, p in ipairs(scaleProps) do
				pcall(function() outfit[p] = humdes[p] end)
			end
			if bodyScaleOverrides then
				for k, v in pairs(bodyScaleOverrides) do outfit[k] = v end
			end
		end

		-- Accessoires & Cheveux : Préservation et Remplacement granulaire
		local finalAccs = {}
		local myAccs = {}
		if base then
			pcall(function() myAccs = base:GetAccessories(true) end)
		end
		local targetAccs = {}
		pcall(function() targetAccs = humdes:GetAccessories(true) end)

		-- (A) Préserver les accessoires du joueur local pour toutes les catégories décochées
		for _, acc in ipairs(myAccs) do
			local subKey = accTypeToSubKey[acc.AccessoryType]
			if not (options.accessories and subKey and options.accessories[subKey]) then
				table.insert(finalAccs, acc)
			end
		end

		-- (B) Ajouter les accessoires de la cible pour toutes les catégories cochées
		if options.accessories then
			for _, acc in ipairs(targetAccs) do
				local subKey = accTypeToSubKey[acc.AccessoryType]
				if subKey and options.accessories[subKey] then
					table.insert(finalAccs, acc)
				end
			end
		end

		pcall(function() outfit.Accessories = finalAccs end)

		-- Chaînes d'accessoires (Legacy)
		local accPropMap = {
			hair = "HairAccessory", hat = "HatAccessory", face = "FaceAccessory",
			neck = "NeckAccessory", front = "FrontAccessory", back = "BackAccessory",
			waist = "WaistAccessory", shirt = "ShirtAccessory", pants = "PantsAccessory",
			jacket = "JacketAccessory", sweater = "SweaterAccessory", shorts = "ShortsAccessory",
			leftShoe = "LeftShoeAccessory", rightShoe = "RightShoeAccessory",
			dressSkirt = "DressSkirtAccessory", eyebrow = "EyebrowAccessory", eyelash = "EyelashAccessory",
		}
		for subKey, propName in pairs(accPropMap) do
			if options.accessories and options.accessories[subKey] then
				pcall(function() outfit[propName] = (humdes[propName] and humdes[propName] ~= "") and humdes[propName] or "" end)
			else
				pcall(function() outfit[propName] = (base and base[propName] and base[propName] ~= "") and base[propName] or "" end)
			end
		end
	end

	return outfit
end

local function DispatchDescriptionToServer(humdes, options, bodyScaleOverrides)
	if not ApplyOutfitRemote then
		return false, "Remote 'CatalogOnApplyOutfit' introuvable"
	end

	-- Capture de l'état initial AVANT toute modification sur le personnage
	local baseDesc = getLocalPlayerDescription()
	local outfit = buildDescriptionTable(humdes, options, bodyScaleOverrides)

	local accTypeToSubKey = {
		[Enum.AccessoryType.Hair] = "hair", [Enum.AccessoryType.Hat] = "hat", [Enum.AccessoryType.Face] = "face",
		[Enum.AccessoryType.Neck] = "neck", [Enum.AccessoryType.Front] = "front", [Enum.AccessoryType.Back] = "back",
		[Enum.AccessoryType.Waist] = "waist", [Enum.AccessoryType.Shirt] = "shirt", [Enum.AccessoryType.Pants] = "pants",
		[Enum.AccessoryType.Jacket] = "jacket", [Enum.AccessoryType.Sweater] = "sweater", [Enum.AccessoryType.Shorts] = "shorts",
		[Enum.AccessoryType.LeftShoe] = "leftShoe", [Enum.AccessoryType.RightShoe] = "rightShoe",
		[Enum.AccessoryType.DressSkirt] = "dressSkirt", [Enum.AccessoryType.Eyebrow] = "eyebrow", [Enum.AccessoryType.Eyelash] = "eyelash",
	}

	local function reapplyPreservedAccessories()
		if not baseDesc then return end
		pcall(function()
			local myAccs = baseDesc:GetAccessories(true)
			for order, acc in ipairs(myAccs) do
				local subKey = accTypeToSubKey[acc.AccessoryType]
				if not (options.accessories and subKey and options.accessories[subKey]) then
					if acc.AssetId and acc.AssetId ~= 0 then
						applyAccessory(acc.AccessoryType, acc.AssetId, order)
					end
				end
			end
		end)
	end

	local function applySelectedFromTarget()
		pcall(function()
			if options.body then
				local bodyMap = { head = "Head", torso = "Torso", rightArm = "RightArm", leftArm = "LeftArm", leftLeg = "LeftLeg", rightLeg = "RightLeg" }
				for subKey, propName in pairs(bodyMap) do
					if options.body[subKey] then
						local a = humdes[propName]
						if a and a ~= 0 then applyProperty(propName, a) end
					end
				end
			end
			if options.face and options.face.decal then
				local faceId = humdes["Face"]
				if faceId and faceId ~= 0 then applyProperty("Face", faceId) end
			end
			if options.clothes then
				if options.clothes.shirt and humdes.Shirt and humdes.Shirt ~= 0 then applyProperty("Shirt", humdes.Shirt) end
				if options.clothes.pants and humdes.Pants and humdes.Pants ~= 0 then applyProperty("Pants", humdes.Pants) end
				if options.clothes.graphicTShirt and humdes.GraphicTShirt and humdes.GraphicTShirt ~= 0 then applyProperty("GraphicTShirt", humdes.GraphicTShirt) end
			end
			if options.colors then
				local colorMap = { head = "HeadColor", torso = "TorsoColor", leftArm = "LeftArmColor", rightArm = "RightArmColor", leftLeg = "LeftLegColor", rightLeg = "RightLegColor" }
				for subKey, propName in pairs(colorMap) do
					if options.colors[subKey] then
						local a = humdes[propName]
						if a then applyProperty(propName, a) end
					end
				end
			end
			if options.accessories then
				local accs = {}
				pcall(function() accs = humdes:GetAccessories(true) end)
				for order, acc in ipairs(accs) do
					local subKey = accTypeToSubKey[acc.AccessoryType]
					if subKey and options.accessories[subKey] and acc.AssetId and acc.AssetId ~= 0 then
						applyAccessory(acc.AccessoryType, acc.AssetId, order)
					end
				end
			end
		end)
		if options.scales and ApplyPropertyRemote then
			local scaleProps = { "HeadScale", "WidthScale", "HeightScale", "DepthScale", "BodyTypeScale", "ProportionScale" }
			for _, scaleName in ipairs(scaleProps) do
				local scaleVal = outfit[scaleName]
				if scaleVal ~= nil then
					pcall(function() ApplyPropertyRemote:FireServer({ Property = scaleName, AssetId = scaleVal }) end)
				end
			end
		end
	end

	pcall(function() ApplyOutfitRemote:FireServer(outfit) end)
	reapplyPreservedAccessories()
	applySelectedFromTarget()

	task.delay(0.35, function()
		pcall(function() ApplyOutfitRemote:FireServer(outfit) end)
		reapplyPreservedAccessories()
		applySelectedFromTarget()
	end)

	task.delay(0.8, function()
		reapplyPreservedAccessories()
		applySelectedFromTarget()
	end)

	return true, outfit
end

local function isOptionActive(opt)
	if type(opt) == "boolean" then return opt end
	if type(opt) == "table" then
		for _, v in pairs(opt) do
			if v then return true end
		end
	end
	return false
end

local function getActiveAnimProps(animOptions)
	local animMap = { climb = "ClimbAnimation", fall = "FallAnimation", idle = "IdleAnimation", jump = "JumpAnimation", mood = "MoodAnimation", run = "RunAnimation", swim = "SwimAnimation", walk = "WalkAnimation" }
	local active = {}
	if type(animOptions) == "table" then
		for subKey, propName in pairs(animMap) do
			if animOptions[subKey] then table.insert(active, propName) end
		end
	else
		for _, propName in pairs(animMap) do
			table.insert(active, propName)
		end
	end
	return active
end

local AnimOverrideActive = false
local AnimOverrideThread = nil
local function forceAnimationOverride(humdes, outfitTable)
	if not ApplyPropertyRemote then return end
	AnimOverrideActive = false
	if AnimOverrideThread then
		pcall(function() task.cancel(AnimOverrideThread) end)
		AnimOverrideThread = nil
	end

	local animProps = getActiveAnimProps(CopyOptions.animations)
	if #animProps == 0 then return end

	local function getAnimId(prop)
		local val = nil
		if humdes then pcall(function() val = humdes[prop] end) end
		if (not val or val == 0) and outfitTable then val = outfitTable[prop] end
		return (type(val) == "number" and val ~= 0) and val or nil
	end

	local animData = {}
	for _, propName in ipairs(animProps) do
		table.insert(animData, { propName, getAnimId(propName) })
	end

	local function sendAnims()
		for _, pair in ipairs(animData) do
			local prop, val = pair[1], pair[2]
			if val then
				pcall(function() ApplyPropertyRemote:FireServer({ Property = prop, AssetId = val }) end)
			end
		end
	end

	AnimOverrideActive = true
	AnimOverrideThread = task.spawn(function()
		local delays = { 0, 0.5, 1, 2, 5, 10 }
		for _, d in ipairs(delays) do
			if not AnimOverrideActive then break end
			if d > 0 then task.wait(d) end
			if not AnimOverrideActive then break end
			sendAnims()
		end
		AnimOverrideActive = false
		AnimOverrideThread = nil
	end)
end

-- ============================================================================
--  7. UI HELPERS & DESIGN SYSTEM
-- ============================================================================
local C_BG = Color3.fromRGB(10, 10, 12)
local C_PANEL = Color3.fromRGB(18, 18, 22)
local C_CARD = Color3.fromRGB(25, 25, 30)
local C_BORDER = Color3.fromRGB(40, 40, 48)
local C_MUTED = Color3.fromRGB(140, 140, 150)
local C_DIM = Color3.fromRGB(80, 80, 90)
local C_ACTIVE = Color3.fromRGB(35, 35, 42)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SalamangueCloner"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 100
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
	if not pcall(function() ScreenGui.Parent = CoreGui end) then
		ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end)

local eventConnections = {}
local function UnloadScript()
	for _, conn in pairs(eventConnections) do
		pcall(function() if conn and conn.Connected then conn:Disconnect() end end)
	end
	table.clear(eventConnections)
	if ScreenGui then
		pcall(function() ScreenGui:Destroy() end)
	end
	_G.SalamangueClonerInstance = nil
end
_G.SalamangueClonerInstance = UnloadScript

local function addCorner(parent, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 6)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or C_BORDER
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function createButton(parent, text, bgColor, textColor, size, pos)
	local btn = Instance.new("TextButton")
	btn.Parent = parent
	btn.Size = size or UDim2.new(1, 0, 0, 34)
	btn.Position = pos or UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = bgColor or C_PANEL
	btn.BorderSizePixel = 0
	btn.Text = text or ""
	btn.TextColor3 = textColor or CurrentTheme.Accent
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.AutoButtonColor = false
	addCorner(btn, 6)
	addStroke(btn, C_BORDER, 1, 0.4)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
	end)
	return btn
end

-- ============================================================================
--  8. STRUCTURE DE L'INTERFACE
-- ============================================================================
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "SC_Toggle"
FloatBtn.Parent = ScreenGui
FloatBtn.Size = UDim2.new(0, 42, 0, 42)
FloatBtn.Position = UDim2.new(0, 16, 0.5, -21)
FloatBtn.BackgroundColor3 = C_BG
FloatBtn.BackgroundTransparency = 0.15
FloatBtn.BorderSizePixel = 0
FloatBtn.Text = "SC"
FloatBtn.TextColor3 = CurrentTheme.Accent
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 14
FloatBtn.ZIndex = 200
addCorner(FloatBtn, 8)
addStroke(FloatBtn, C_BORDER, 1.2)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 460, 0, 620)
MainFrame.Position = UDim2.new(0, 70, 0.5, -310)
MainFrame.BackgroundColor3 = C_BG
MainFrame.BackgroundTransparency = 0.06
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
addCorner(MainFrame, 10)
addStroke(MainFrame, C_BORDER, 1.2)

local function makeDraggable(dragHandle, frameToMove)
	local dragging, dragStart, startPos
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frameToMove.Position
			local moveConn, releaseConn
			moveConn = UserInputService.InputChanged:Connect(function(i2)
				if dragging and (i2.UserInputType == Enum.UserInputType.MouseMovement or i2.UserInputType == Enum.UserInputType.Touch) then
					local delta = i2.Position - dragStart
					frameToMove.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				end
			end)
			releaseConn = UserInputService.InputEnded:Connect(function(i2)
				if i2.UserInputType == Enum.UserInputType.MouseButton1 or i2.UserInputType == Enum.UserInputType.Touch then
					dragging = false
					if moveConn then moveConn:Disconnect() end
					if releaseConn then releaseConn:Disconnect() end
				end
			end)
		end
	end)
end
makeDraggable(FloatBtn, FloatBtn)

local Header = Instance.new("Frame")
Header.Parent = MainFrame
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = C_PANEL
Header.BackgroundTransparency = 0.2
Header.BorderSizePixel = 0
addCorner(Header, 10)
makeDraggable(Header, MainFrame)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = Header
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Salamangue Cloner"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextColor3 = CurrentTheme.Accent
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = Header
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -13)
CloseBtn.BackgroundColor3 = C_CARD
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.Font = Enum.Font.GothamMedium
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = C_MUTED
addCorner(CloseBtn, 6)
addStroke(CloseBtn, C_BORDER, 1, 0.5)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local StatusBar = Instance.new("Frame")
StatusBar.Parent = MainFrame
StatusBar.Position = UDim2.new(0, 12, 0, 52)
StatusBar.Size = UDim2.new(1, -24, 0, 26)
StatusBar.BackgroundColor3 = C_PANEL
StatusBar.BackgroundTransparency = 0.4
StatusBar.BorderSizePixel = 0
addCorner(StatusBar, 6)
addStroke(StatusBar, C_BORDER, 1, 0.6)

local StatusDot = Instance.new("Frame")
StatusDot.Parent = StatusBar
StatusDot.Position = UDim2.new(0, 10, 0.5, -3)
StatusDot.Size = UDim2.new(0, 6, 0, 6)
StatusDot.BackgroundColor3 = CurrentTheme.Accent
StatusDot.BorderSizePixel = 0
addCorner(StatusDot, 3)

local StatusText = Instance.new("TextLabel")
StatusText.Parent = StatusBar
StatusText.Position = UDim2.new(0, 24, 0, 0)
StatusText.Size = UDim2.new(1, -30, 1, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Prêt (Touche [RightControl] ou [F4] pour basculer)"
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 11
StatusText.TextColor3 = C_MUTED
StatusText.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(msg, isHighlight)
	StatusText.Text = msg or ""
	StatusText.TextColor3 = isHighlight and CurrentTheme.Accent or C_MUTED
	StatusDot.BackgroundColor3 = isHighlight and CurrentTheme.Accent or C_DIM
end

-- ============================================================================
--  9. ONGLETS & NAVIGATION
-- ============================================================================
local TabBar = Instance.new("Frame")
TabBar.Parent = MainFrame
TabBar.Position = UDim2.new(0, 12, 0, 84)
TabBar.Size = UDim2.new(1, -24, 0, 30)
TabBar.BackgroundColor3 = C_PANEL
TabBar.BackgroundTransparency = 0.3
TabBar.BorderSizePixel = 0
addCorner(TabBar, 6)
addStroke(TabBar, C_BORDER, 1, 0.6)

local tabDefs = {
	{ id = "Joueurs", label = "Joueurs" },
	{ id = "HorsLigne", label = "Hors-Ligne" },
	{ id = "Apercu", label = "Aperçu" },
	{ id = "Pieces", label = "Pièces" },
	{ id = "Taille", label = "Taille" },
	{ id = "Favoris", label = "Favoris" },
	{ id = "Outils", label = "Outils" },
}

local TabContainers = {}
local TabButtons = {}
local CurrentTab = "Joueurs"

local TabContentArea = Instance.new("Frame")
TabContentArea.Parent = MainFrame
TabContentArea.Position = UDim2.new(0, 12, 0, 122)
TabContentArea.Size = UDim2.new(1, -24, 1, -174)
TabContentArea.BackgroundTransparency = 1

local function createTabScroll()
	local sc = Instance.new("ScrollingFrame")
	sc.Parent = TabContentArea
	sc.Size = UDim2.new(1, 0, 1, 0)
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 3
	sc.ScrollBarImageColor3 = C_BORDER
	sc.CanvasSize = UDim2.new(0, 0, 0, 0)
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sc.Visible = false

	local lay = Instance.new("UIListLayout")
	lay.Parent = sc
	lay.Padding = UDim.new(0, 6)
	lay.SortOrder = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding")
	pad.Parent = sc
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 2)
	return sc
end

for i, tab in ipairs(tabDefs) do
	TabContainers[tab.id] = createTabScroll()
	local tabBtn = Instance.new("TextButton")
	tabBtn.Parent = TabBar
	local widthPct = 1 / #tabDefs
	tabBtn.Size = UDim2.new(widthPct, -2, 1, -4)
	tabBtn.Position = UDim2.new(widthPct * (i - 1), 1, 0, 2)
	tabBtn.BackgroundTransparency = 1
	tabBtn.BackgroundColor3 = C_ACTIVE
	tabBtn.BorderSizePixel = 0
	tabBtn.Text = tab.label
	tabBtn.Font = Enum.Font.GothamMedium
	tabBtn.TextSize = 10
	tabBtn.TextColor3 = C_MUTED
	addCorner(tabBtn, 5)
	TabButtons[tab.id] = tabBtn
end

local function switchTab(tabId)
	CurrentTab = tabId
	for id, container in pairs(TabContainers) do
		container.Visible = (id == tabId)
	end
	for id, btn in pairs(TabButtons) do
		if id == tabId then
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0, TextColor3 = CurrentTheme.Accent }):Play()
		else
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 1, TextColor3 = C_MUTED }):Play()
		end
	end
end

for tabId, btn in pairs(TabButtons) do
	btn.MouseButton1Click:Connect(function() switchTab(tabId) end)
end

-- ============================================================================
--  10. VARIABLES GLOBALES DE L'ÉTAT DU SKIN & FONCTIONS D'APPARITION
-- ============================================================================
local CurrentHumDes = nil
local SelectedTargetName = nil
local SelectedUserId = nil
local SelectedTargetPlayer = nil
local BaseTargetScales = nil

local SlidersUI = {}
local ApercuModel, TailleModel = nil, nil
local refreshAll3DPreviews, requestDebouncedRebuild, populateInspectorList

local function syncSlidersToScaleOptions()
	for k, sUI in pairs(SlidersUI) do
		local val = ScaleOptions[k] or sUI.limits[3]
		local minV, maxV = sUI.limits[1], sUI.limits[2]
		local pct = math.clamp((val - minV) / ((maxV - minV) or 1), 0, 1)
		sUI.fill.Size = UDim2.new(pct, 0, 1, 0)
		sUI.thumb.Position = UDim2.new(pct, 0, 0.5, 0)
		sUI.label.Text = string.format("%.0f%%", (val / maxV) * 100)
	end
end

local function selectTargetAvatar(targetPlayer, targetUserId, displayName)
	SelectedTargetPlayer = targetPlayer or nil
	SelectedTargetName = displayName or (targetPlayer and targetPlayer.Name) or ("ID " .. tostring(targetUserId))
	SelectedUserId = targetUserId or (targetPlayer and targetPlayer.UserId)
	setStatus("Chargement de " .. SelectedTargetName .. "...", true)

	task.spawn(function()
		local humdes = getAuthenticDescription(targetPlayer, targetUserId)
		if not humdes then
			setStatus("Erreur de chargement", false)
			return
		end
		CurrentHumDes = humdes
		BaseTargetScales = {
			HeadScale = humdes.HeadScale or 1,
			WidthScale = humdes.WidthScale or 1,
			HeightScale = humdes.HeightScale or 1,
			DepthScale = humdes.DepthScale or 1,
			BodyTypeScale = humdes.BodyTypeScale or 0,
			ProportionScale = humdes.ProportionScale or 0,
		}
		for k, v in pairs(BaseTargetScales) do ScaleOptions[k] = v end
		syncSlidersToScaleOptions()
		if refreshAll3DPreviews then pcall(function() refreshAll3DPreviews(humdes, SelectedTargetName) end) end
		if populateInspectorList then pcall(function() populateInspectorList(humdes) end) end
		setStatus(SelectedTargetName .. " sélectionné", true)
	end)
end

-- ============================================================================
--  11. CONSTRUCTION MODULAIRE DES ONGLETS
-- ============================================================================

-- ONGLET 1: JOUEURS
local refreshPlayerList
local function buildJoueursTab()
	local JoueursTab = TabContainers["Joueurs"]
	local PlayerSortMode = "Distance"

	local SearchBarRow = Instance.new("Frame")
	SearchBarRow.Parent = JoueursTab
	SearchBarRow.Size = UDim2.new(1, 0, 0, 34)
	SearchBarRow.BackgroundColor3 = C_PANEL
	SearchBarRow.BackgroundTransparency = 0.3
	addCorner(SearchBarRow, 6)
	addStroke(SearchBarRow, C_BORDER, 1, 0.5)

	local SearchInput = Instance.new("TextBox")
	SearchInput.Parent = SearchBarRow
	SearchInput.Position = UDim2.new(0, 10, 0, 0)
	SearchInput.Size = UDim2.new(1, -130, 1, 0)
	SearchInput.BackgroundTransparency = 1
	SearchInput.PlaceholderText = "Rechercher un joueur..."
	SearchInput.PlaceholderColor3 = C_DIM
	SearchInput.Text = ""
	SearchInput.TextColor3 = CurrentTheme.Accent
	SearchInput.Font = Enum.Font.Gotham
	SearchInput.TextSize = 11
	SearchInput.TextXAlignment = Enum.TextXAlignment.Left

	local ClickToCloneBtn = createButton(SearchBarRow, "🖱️ Clic 3D", C_CARD, CurrentTheme.Accent, UDim2.new(0, 110, 0, 26), UDim2.new(1, -116, 0.5, -13))
	ClickToCloneBtn.TextSize = 10

	local SortBarRow = Instance.new("Frame")
	SortBarRow.Parent = JoueursTab
	SortBarRow.Size = UDim2.new(1, 0, 0, 28)
	SortBarRow.BackgroundTransparency = 1

	local sortDefs = { { id = "Distance", label = "Proximité" }, { id = "Amis", label = "Amis" }, { id = "Alphabetique", label = "A-Z" } }
	local sortBtns = {}
	for i, sDef in ipairs(sortDefs) do
		local sBtn = Instance.new("TextButton")
		sBtn.Parent = SortBarRow
		local wPct = 1 / #sortDefs
		sBtn.Size = UDim2.new(wPct, -4, 1, 0)
		sBtn.Position = UDim2.new(wPct * (i - 1), 2, 0, 0)
		sBtn.BackgroundColor3 = (PlayerSortMode == sDef.id) and CurrentTheme.Accent or C_CARD
		sBtn.BackgroundTransparency = (PlayerSortMode == sDef.id) and 0 or 0.4
		sBtn.BorderSizePixel = 0
		sBtn.Text = sDef.label
		sBtn.Font = Enum.Font.GothamMedium
		sBtn.TextSize = 10
		sBtn.TextColor3 = (PlayerSortMode == sDef.id) and CurrentTheme.TextDark or C_MUTED
		addCorner(sBtn, 4)
		addStroke(sBtn, C_BORDER, 1, 0.3)
		sortBtns[sDef.id] = sBtn
	end

	local PlayerListContainer = Instance.new("Frame")
	PlayerListContainer.Parent = JoueursTab
	PlayerListContainer.Size = UDim2.new(1, 0, 0, 0)
	PlayerListContainer.AutomaticSize = Enum.AutomaticSize.Y
	PlayerListContainer.BackgroundTransparency = 1

	local pListLayout = Instance.new("UIListLayout")
	pListLayout.Parent = PlayerListContainer
	pListLayout.Padding = UDim.new(0, 5)

	refreshPlayerList = function(query)
		query = string.lower(query or "")
		for _, child in pairs(PlayerListContainer:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local playerList = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then table.insert(playerList, p) end
		end

		local localChar = LocalPlayer.Character
		local localPos = localChar and localChar:FindFirstChild("HumanoidRootPart") and localChar.HumanoidRootPart.Position

		if PlayerSortMode == "Distance" and localPos then
			table.sort(playerList, function(a, b)
				local charA = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
				local charB = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
				local distA = charA and (charA.Position - localPos).Magnitude or 999999
				local distB = charB and (charB.Position - localPos).Magnitude or 999999
				return distA < distB
			end)
		elseif PlayerSortMode == "Amis" then
			table.sort(playerList, function(a, b)
				local isFriendA, isFriendB = false, false
				pcall(function() isFriendA = LocalPlayer:IsFriendsWith(a.UserId) end)
				pcall(function() isFriendB = LocalPlayer:IsFriendsWith(b.UserId) end)
				if isFriendA ~= isFriendB then return isFriendA end
				return a.Name < b.Name
			end)
		else
			table.sort(playerList, function(a, b) return a.Name < b.Name end)
		end

		for _, p in ipairs(playerList) do
			if query == "" or p.Name:lower():find(query, 1, true) or p.DisplayName:lower():find(query, 1, true) then
				local row = Instance.new("Frame")
				row.Parent = PlayerListContainer
				row.Size = UDim2.new(1, 0, 0, 44)
				row.BackgroundColor3 = C_PANEL
				row.BackgroundTransparency = 0.3
				addCorner(row, 6)
				addStroke(row, C_BORDER, 1, 0.6)

				local thumb = Instance.new("ImageLabel")
				thumb.Parent = row
				thumb.Position = UDim2.new(0, 8, 0.5, -16)
				thumb.Size = UDim2.new(0, 32, 0, 32)
				thumb.BackgroundColor3 = C_CARD
				thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
				addCorner(thumb, 16)

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Parent = row
				nameLabel.Position = UDim2.new(0, 48, 0, 6)
				nameLabel.Size = UDim2.new(1, -165, 0, 16)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = p.DisplayName
				nameLabel.Font = Enum.Font.GothamMedium
				nameLabel.TextSize = 12
				nameLabel.TextColor3 = CurrentTheme.Accent
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left

				local userLabel = Instance.new("TextLabel")
				userLabel.Parent = row
				userLabel.Position = UDim2.new(0, 48, 0, 22)
				userLabel.Size = UDim2.new(1, -165, 0, 14)
				userLabel.BackgroundTransparency = 1
				local extraTag = ""
				if localPos and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					extraTag = " • " .. tostring(math.floor((p.Character.HumanoidRootPart.Position - localPos).Magnitude)) .. "m"
				end
				userLabel.Text = "@" .. p.Name .. extraTag
				userLabel.Font = Enum.Font.Gotham
				userLabel.TextSize = 10
				userLabel.TextColor3 = C_MUTED
				userLabel.TextXAlignment = Enum.TextXAlignment.Left

				local apercuBtn = createButton(row, "Voir", C_CARD, C_MUTED, UDim2.new(0, 42, 0, 28), UDim2.new(1, -112, 0.5, -14))
				apercuBtn.MouseButton1Click:Connect(function()
					selectTargetAvatar(p, p.UserId, p.Name)
					switchTab("Apercu")
				end)

				local copyRowBtn = createButton(row, "Copier", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0, 60, 0, 28), UDim2.new(1, -66, 0.5, -14))
				copyRowBtn.MouseButton1Click:Connect(function()
					selectTargetAvatar(p, p.UserId, p.Name)
					task.delay(0.2, function() _G.SalamangueClonerApply() end)
				end)
			end
		end
	end

	for sId, b in pairs(sortBtns) do
		b.MouseButton1Click:Connect(function()
			PlayerSortMode = sId
			for id, b2 in pairs(sortBtns) do
				local active = (id == sId)
				b2.BackgroundColor3 = active and CurrentTheme.Accent or C_CARD
				b2.BackgroundTransparency = active and 0 or 0.4
				b2.TextColor3 = active and CurrentTheme.TextDark or C_MUTED
			end
			refreshPlayerList(SearchInput.Text)
		end)
	end

	SearchInput:GetPropertyChangedSignal("Text"):Connect(function() refreshPlayerList(SearchInput.Text) end)

	local isClickToCloneActive = false
	local clickToCloneConn = nil
	ClickToCloneBtn.MouseButton1Click:Connect(function()
		isClickToCloneActive = not isClickToCloneActive
		if isClickToCloneActive then
			ClickToCloneBtn.BackgroundColor3 = CurrentTheme.Accent
			ClickToCloneBtn.TextColor3 = CurrentTheme.TextDark
			setStatus("Cliquez sur un joueur dans le jeu...", true)
			local mouse = LocalPlayer:GetMouse()
			clickToCloneConn = mouse.Button1Down:Connect(function()
				local target = mouse.Target
				if target then
					local char = target:FindFirstAncestorOfClass("Model")
					if char then
						local targetP = Players:GetPlayerFromCharacter(char)
						if targetP and targetP ~= LocalPlayer then
							selectTargetAvatar(targetP, targetP.UserId, targetP.Name)
							ClickToCloneBtn.BackgroundColor3 = C_CARD
							ClickToCloneBtn.TextColor3 = CurrentTheme.Accent
							if clickToCloneConn then clickToCloneConn:Disconnect() end
							isClickToCloneActive = false
							_G.SalamangueClonerApply()
						end
					end
				end
			end)
		else
			ClickToCloneBtn.BackgroundColor3 = C_CARD
			ClickToCloneBtn.TextColor3 = CurrentTheme.Accent
			if clickToCloneConn then clickToCloneConn:Disconnect() end
			setStatus("Prêt", false)
		end
	end)
end

-- ONGLET 2: HORS-LIGNE
local function buildHorsLigneTab()
	local HorsLigneTab = TabContainers["HorsLigne"]
	local OffCard = Instance.new("Frame")
	OffCard.Parent = HorsLigneTab
	OffCard.Size = UDim2.new(1, 0, 0, 90)
	OffCard.BackgroundColor3 = C_PANEL
	OffCard.BackgroundTransparency = 0.3
	addCorner(OffCard, 6)
	addStroke(OffCard, C_BORDER, 1, 0.6)

	local OffTitle = Instance.new("TextLabel")
	OffTitle.Parent = OffCard
	OffTitle.Position = UDim2.new(0, 10, 0, 8)
	OffTitle.Size = UDim2.new(1, -20, 0, 16)
	OffTitle.BackgroundTransparency = 1
	OffTitle.Text = "Chargement hors-ligne (API Roblox)"
	OffTitle.Font = Enum.Font.GothamMedium
	OffTitle.TextSize = 12
	OffTitle.TextColor3 = CurrentTheme.Accent
	OffTitle.TextXAlignment = Enum.TextXAlignment.Left

	local OffInputRow = Instance.new("Frame")
	OffInputRow.Parent = OffCard
	OffInputRow.Position = UDim2.new(0, 10, 0, 32)
	OffInputRow.Size = UDim2.new(1, -20, 0, 34)
	OffInputRow.BackgroundColor3 = C_CARD
	OffInputRow.BackgroundTransparency = 0.4
	addCorner(OffInputRow, 6)

	local OffBox = Instance.new("TextBox")
	OffBox.Parent = OffInputRow
	OffBox.Position = UDim2.new(0, 10, 0, 0)
	OffBox.Size = UDim2.new(1, -90, 1, 0)
	OffBox.BackgroundTransparency = 1
	OffBox.PlaceholderText = "Pseudo ou UserID..."
	OffBox.PlaceholderColor3 = C_DIM
	OffBox.Text = ""
	OffBox.TextColor3 = CurrentTheme.Accent
	OffBox.Font = Enum.Font.Gotham
	OffBox.TextSize = 12
	OffBox.TextXAlignment = Enum.TextXAlignment.Left

	local OffSearchBtn = createButton(OffInputRow, "Charger", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0, 72, 0, 26), UDim2.new(1, -76, 0.5, -13))

	local OffResultCard = Instance.new("Frame")
	OffResultCard.Parent = HorsLigneTab
	OffResultCard.Size = UDim2.new(1, 0, 0, 168)
	OffResultCard.BackgroundColor3 = C_PANEL
	OffResultCard.BackgroundTransparency = 0.3
	OffResultCard.Visible = false
	addCorner(OffResultCard, 6)
	addStroke(OffResultCard, C_BORDER, 1, 0.6)

	local OffResultThumb = Instance.new("ImageLabel")
	OffResultThumb.Parent = OffResultCard
	OffResultThumb.Position = UDim2.new(0, 12, 0, 12)
	OffResultThumb.Size = UDim2.new(0, 52, 0, 52)
	OffResultThumb.BackgroundColor3 = C_CARD
	addCorner(OffResultThumb, 26)

	local OffResultName = Instance.new("TextLabel")
	OffResultName.Parent = OffResultCard
	OffResultName.Position = UDim2.new(0, 72, 0, 10)
	OffResultName.Size = UDim2.new(1, -82, 0, 18)
	OffResultName.BackgroundTransparency = 1
	OffResultName.Font = Enum.Font.GothamBold
	OffResultName.TextSize = 13
	OffResultName.TextColor3 = CurrentTheme.Accent
	OffResultName.TextXAlignment = Enum.TextXAlignment.Left

	local OffResultId = Instance.new("TextLabel")
	OffResultId.Parent = OffResultCard
	OffResultId.Position = UDim2.new(0, 72, 0, 28)
	OffResultId.Size = UDim2.new(1, -82, 0, 14)
	OffResultId.BackgroundTransparency = 1
	OffResultId.Font = Enum.Font.Gotham
	OffResultId.TextSize = 11
	OffResultId.TextColor3 = C_MUTED
	OffResultId.TextXAlignment = Enum.TextXAlignment.Left

	local OffResultPresence = Instance.new("TextLabel")
	OffResultPresence.Parent = OffResultCard
	OffResultPresence.Position = UDim2.new(0, 72, 0, 44)
	OffResultPresence.Size = UDim2.new(1, -82, 0, 28)
	OffResultPresence.BackgroundTransparency = 1
	OffResultPresence.Font = Enum.Font.GothamMedium
	OffResultPresence.TextSize = 10
	OffResultPresence.TextColor3 = CurrentTheme.Accent
	OffResultPresence.TextWrapped = true
	OffResultPresence.TextXAlignment = Enum.TextXAlignment.Left
	OffResultPresence.Text = "Statut : Chargement..."

	local OffApplyBtn = createButton(OffResultCard, "Copier le Skin", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0.48, -4, 0, 28), UDim2.new(0, 12, 0, 88))
	local OffPreviewBtn = createButton(OffResultCard, "Aperçu 3D", C_CARD, CurrentTheme.Accent, UDim2.new(0.48, -4, 0, 28), UDim2.new(0.52, 0, 0, 88))
	local OffJoinBtn = createButton(OffResultCard, "🚀 Rejoindre son Serveur (Sniper)", C_CARD, CurrentTheme.Accent, UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 0, 124))
	OffJoinBtn.TextSize = 11

	local function searchOffline(text)
		text = (text or ""):gsub("%s+", "")
		if text == "" then return end
		setStatus("Recherche...", true)
		task.spawn(function()
			local rId = tonumber(text)
			local rName = text
			if not rId or rId <= 0 then
				local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(text) end)
				if ok and uid and uid > 0 then rId = uid else setStatus("Joueur introuvable", false) return end
			else
				local ok, nm = pcall(function() return Players:GetNameFromUserIdAsync(rId) end)
				if ok and nm then rName = nm end
			end
			selectTargetAvatar(nil, rId, rName)
			OffResultThumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. rId .. "&w=150&h=150"
			OffResultName.Text = rName
			OffResultId.Text = "ID: " .. tostring(rId)
			OffResultPresence.Text = "Statut : Vérification..."
			OffResultCard.Visible = true

			local pres = getPlayerPresence(rId)
			if pres then
				OffResultPresence.Text = pres.label
				OffResultPresence.TextColor3 = (pres.type == 2) and Color3.fromRGB(80, 240, 140) or (pres.type == 1 and Color3.fromRGB(0, 200, 255) or C_MUTED)
			else
				OffResultPresence.Text = "Statut : Non disponible"
				OffResultPresence.TextColor3 = C_MUTED
			end
		end)
	end
	OffSearchBtn.MouseButton1Click:Connect(function() searchOffline(OffBox.Text) end)
	OffBox.FocusLost:Connect(function(enter) if enter then searchOffline(OffBox.Text) end end)
	OffApplyBtn.MouseButton1Click:Connect(function() _G.SalamangueClonerApply() end)
	OffPreviewBtn.MouseButton1Click:Connect(function() switchTab("Apercu") end)
	OffJoinBtn.MouseButton1Click:Connect(function()
		if SelectedUserId or SelectedTargetName then
			sniperJoinPlayer(tostring(SelectedUserId or SelectedTargetName))
		end
	end)
end

-- ONGLET 3: APERÇU 3D & INSPECTEUR
local function buildApercuTab()
	local ApercuTab = TabContainers["Apercu"]
	local ViewportCard = Instance.new("Frame")
	ViewportCard.Parent = ApercuTab
	ViewportCard.Size = UDim2.new(1, 0, 0, 250)
	ViewportCard.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	ViewportCard.BackgroundTransparency = 0.2
	addCorner(ViewportCard, 6)
	addStroke(ViewportCard, C_BORDER, 1, 0.6)

	local PreviewViewport = Instance.new("ViewportFrame")
	PreviewViewport.Parent = ViewportCard
	PreviewViewport.Size = UDim2.new(1, 0, 1, 0)
	PreviewViewport.BackgroundTransparency = 1

	local ViewportCamera = Instance.new("Camera")
	ViewportCamera.FieldOfView = 50
	PreviewViewport.CurrentCamera = ViewportCamera

	local PreviewTitleBar = Instance.new("Frame")
	PreviewTitleBar.Parent = ViewportCard
	PreviewTitleBar.Size = UDim2.new(1, 0, 0, 28)
	PreviewTitleBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	PreviewTitleBar.BackgroundTransparency = 0.6

	local PreviewTargetLabel = Instance.new("TextLabel")
	PreviewTargetLabel.Parent = PreviewTitleBar
	PreviewTargetLabel.Position = UDim2.new(0, 10, 0, 0)
	PreviewTargetLabel.Size = UDim2.new(1, -170, 1, 0)
	PreviewTargetLabel.BackgroundTransparency = 1
	PreviewTargetLabel.Text = "Aucun avatar"
	PreviewTargetLabel.Font = Enum.Font.GothamMedium
	PreviewTargetLabel.TextSize = 11
	PreviewTargetLabel.TextColor3 = C_MUTED
	PreviewTargetLabel.TextXAlignment = Enum.TextXAlignment.Left

	local ZoomInBtn = createButton(PreviewTitleBar, "+", C_CARD, CurrentTheme.Accent, UDim2.new(0, 22, 0, 20), UDim2.new(1, -165, 0.5, -10))
	local ZoomOutBtn = createButton(PreviewTitleBar, "-", C_CARD, CurrentTheme.Accent, UDim2.new(0, 22, 0, 20), UDim2.new(1, -140, 0.5, -10))
	local ResetCamBtn = createButton(PreviewTitleBar, "Reset", C_CARD, C_MUTED, UDim2.new(0, 52, 0, 20), UDim2.new(1, -115, 0.5, -10))
	ResetCamBtn.TextSize = 9
	local AutoRotateToggle = createButton(PreviewTitleBar, "Auto-Rot", C_ACTIVE, CurrentTheme.Accent, UDim2.new(0, 56, 0, 20), UDim2.new(1, -60, 0.5, -10))
	AutoRotateToggle.TextSize = 9

	local isRotating = true
	local rotAngle, pitchAngle, camDist, camHeight = 0, 0, 7.5, 0.5

	AutoRotateToggle.MouseButton1Click:Connect(function()
		isRotating = not isRotating
		AutoRotateToggle.TextColor3 = isRotating and CurrentTheme.Accent or C_DIM
		AutoRotateToggle.BackgroundColor3 = isRotating and C_ACTIVE or C_CARD
	end)
	ZoomInBtn.MouseButton1Click:Connect(function() camDist = math.clamp(camDist - 1.0, 3.0, 14.0) end)
	ZoomOutBtn.MouseButton1Click:Connect(function() camDist = math.clamp(camDist + 1.0, 3.0, 14.0) end)
	ResetCamBtn.MouseButton1Click:Connect(function() camDist, pitchAngle, rotAngle = 7.5, 0, 0 end)

	local isDragging = false
	local dragStart = Vector2.new(0, 0)
	local startRot, startPitch = 0, 0

	PreviewViewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			isRotating = false
			AutoRotateToggle.TextColor3 = C_DIM
			AutoRotateToggle.BackgroundColor3 = C_CARD
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startRot = rotAngle
			startPitch = pitchAngle
		end
	end)

	PreviewViewport.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			rotAngle = startRot - ((input.Position.X - dragStart.X) * 0.015)
			pitchAngle = math.clamp(startPitch + ((input.Position.Y - dragStart.Y) * 0.01), -0.8, 0.8)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			camDist = math.clamp(camDist - (input.Position.Z * 0.8), 3.0, 14.0)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)

	table.insert(eventConnections, RunService.RenderStepped:Connect(function(dt)
		if isRotating and MainFrame.Visible then rotAngle = rotAngle + (dt * 0.8) end
		if MainFrame.Visible then
			local x = math.sin(rotAngle) * camDist
			local z = math.cos(rotAngle) * camDist
			local y = camHeight + math.sin(pitchAngle) * camDist
			local targetCF = CFrame.new(Vector3.new(x, y, z), Vector3.new(0, -0.2, 0))
			ViewportCamera.CFrame = targetCF
		end
	end))

	-- Emotes
	local EmoteBarCard = Instance.new("Frame")
	EmoteBarCard.Parent = ApercuTab
	EmoteBarCard.Size = UDim2.new(1, 0, 0, 36)
	EmoteBarCard.BackgroundColor3 = C_PANEL
	EmoteBarCard.BackgroundTransparency = 0.3
	addCorner(EmoteBarCard, 6)

	local emoteDefs = {
		{ label = "Dance 1", id = "http://www.roblox.com/asset/?id=507771019" },
		{ label = "Dance 2", id = "http://www.roblox.com/asset/?id=507776043" },
		{ label = "Wave 👋", id = "http://www.roblox.com/asset/?id=507770239" },
		{ label = "Point 👉", id = "http://www.roblox.com/asset/?id=507770453" },
		{ label = "Cheer 🎉", id = "http://www.roblox.com/asset/?id=507770677" },
	}
	local currentTrack = nil
	for idx, eDef in ipairs(emoteDefs) do
		local eBtn = createButton(EmoteBarCard, eDef.label, C_CARD, CurrentTheme.Accent, UDim2.new(1 / #emoteDefs, -4, 1, -8), UDim2.new((1 / #emoteDefs) * (idx - 1), 2, 0, 4))
		eBtn.TextSize = 10
		eBtn.MouseButton1Click:Connect(function()
			if ApercuModel then
				local hum = ApercuModel:FindFirstChildOfClass("Humanoid")
				if hum then
					local anim = Instance.new("Animation")
					anim.AnimationId = eDef.id
					pcall(function()
						if currentTrack then currentTrack:Stop() end
						currentTrack = hum:LoadAnimation(anim)
						currentTrack:Play()
					end)
				end
			end
		end)
	end

	-- Inspecteur
	local InspectorHeader = Instance.new("Frame")
	InspectorHeader.Parent = ApercuTab
	InspectorHeader.Size = UDim2.new(1, 0, 0, 28)
	InspectorHeader.BackgroundColor3 = C_PANEL
	InspectorHeader.BackgroundTransparency = 0.4
	addCorner(InspectorHeader, 6)

	local InspectorTitle = Instance.new("TextLabel")
	InspectorTitle.Parent = InspectorHeader
	InspectorTitle.Position = UDim2.new(0, 10, 0, 0)
	InspectorTitle.Size = UDim2.new(1, -20, 1, 0)
	InspectorTitle.BackgroundTransparency = 1
	InspectorTitle.Text = "📦 Inspecteur de Pièces & Asset IDs"
	InspectorTitle.Font = Enum.Font.GothamMedium
	InspectorTitle.TextSize = 11
	InspectorTitle.TextColor3 = CurrentTheme.Accent
	InspectorTitle.TextXAlignment = Enum.TextXAlignment.Left

	local InspectorListContainer = Instance.new("Frame")
	InspectorListContainer.Parent = ApercuTab
	InspectorListContainer.Size = UDim2.new(1, 0, 0, 0)
	InspectorListContainer.AutomaticSize = Enum.AutomaticSize.Y
	InspectorListContainer.BackgroundTransparency = 1

	local inspLayout = Instance.new("UIListLayout")
	inspLayout.Parent = InspectorListContainer
	inspLayout.Padding = UDim.new(0, 4)

	populateInspectorList = function(humdes)
		for _, child in pairs(InspectorListContainer:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
		end
		if not humdes then return end
		local items = {}
		if humdes.Shirt and humdes.Shirt ~= 0 then table.insert(items, { type = "Chemise 2D", id = humdes.Shirt }) end
		if humdes.Pants and humdes.Pants ~= 0 then table.insert(items, { type = "Pantalon 2D", id = humdes.Pants }) end
		if humdes.Face and humdes.Face ~= 0 then table.insert(items, { type = "Visage / Face", id = humdes.Face }) end
		if humdes.Head and humdes.Head ~= 0 then table.insert(items, { type = "Tête Mesh", id = humdes.Head }) end
		if humdes.RightLeg and humdes.RightLeg ~= 0 then table.insert(items, { type = "Jambe droite", id = humdes.RightLeg }) end

		local rawAccs = {}
		pcall(function() rawAccs = humdes:GetAccessories(true) end)
		for _, a in ipairs(rawAccs) do
			if a.AssetId and a.AssetId ~= 0 then
				local tName = (typeof(a.AccessoryType) == "EnumItem" and a.AccessoryType.Name) or "Accessoire"
				table.insert(items, { type = tName, id = a.AssetId })
			end
		end

		if #items == 0 then
			local noItem = Instance.new("TextLabel")
			noItem.Parent = InspectorListContainer
			noItem.Size = UDim2.new(1, 0, 0, 30)
			noItem.BackgroundTransparency = 1
			noItem.Text = "Aucun accessoire détecté"
			noItem.Font = Enum.Font.Gotham
			noItem.TextSize = 11
			noItem.TextColor3 = C_DIM
			return
		end

		for _, it in ipairs(items) do
			local row = Instance.new("Frame")
			row.Parent = InspectorListContainer
			row.Size = UDim2.new(1, 0, 0, 32)
			row.BackgroundColor3 = C_PANEL
			row.BackgroundTransparency = 0.4
			addCorner(row, 4)
			addStroke(row, C_BORDER, 1, 0.4)

			local lbl = Instance.new("TextLabel")
			lbl.Parent = row
			lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.Size = UDim2.new(1, -110, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = it.type .. " : " .. tostring(it.id)
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 11
			lbl.TextColor3 = CurrentTheme.Accent
			lbl.TextXAlignment = Enum.TextXAlignment.Left

			local copyIdBtn = createButton(row, "Copier ID", C_CARD, CurrentTheme.Accent, UDim2.new(0, 80, 0, 22), UDim2.new(1, -86, 0.5, -11))
			copyIdBtn.TextSize = 10
			copyIdBtn.MouseButton1Click:Connect(function()
				local ok = copyToClipboard(tostring(it.id))
				setStatus(ok and ("ID " .. tostring(it.id) .. " copié !") or "Presse-papier indisponible", ok)
			end)
		end
	end

	refreshAll3DPreviews = function(humdes, name)
		humdes = humdes or CurrentHumDes
		if not humdes then return end
		local targetName = name or SelectedTargetName or "Avatar"
		local scaledDesc = humdes:Clone()
		scaledDesc.HeadScale = ScaleOptions.HeadScale or 1
		scaledDesc.WidthScale = ScaleOptions.WidthScale or 1
		scaledDesc.HeightScale = ScaleOptions.HeightScale or 1
		scaledDesc.DepthScale = ScaleOptions.DepthScale or 1
		scaledDesc.BodyTypeScale = ScaleOptions.BodyTypeScale or 0
		scaledDesc.ProportionScale = ScaleOptions.ProportionScale or 0

		PreviewTargetLabel.Text = targetName
		for _, ch in pairs(PreviewViewport:GetChildren()) do
			if ch:IsA("Model") or ch:IsA("WorldModel") then ch:Destroy() end
		end
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(scaledDesc, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			local wm = Instance.new("WorldModel")
			wm.Parent = PreviewViewport
			model.Parent = wm
			local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if rootPart then model:PivotTo(CFrame.new(0, -1.2, 0)) else model:PivotTo(CFrame.new(0, 0, 0)) end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
			ApercuModel = model
		end
	end
end

-- ONGLET 4: PIÈCES & FILTRES
local function buildPiecesTab()
	local PiecesTab = TabContainers["Pieces"]
	local pieceDefs = {
		{
			key = "body", label = "Corps", desc = "Tête, buste et membres",
			subs = { { key = "head", label = "Tête" }, { key = "torso", label = "Buste" }, { key = "leftArm", label = "Bras gauche" }, { key = "rightArm", label = "Bras droit" }, { key = "leftLeg", label = "Jambe gauche" }, { key = "rightLeg", label = "Jambe droite" } },
		},
		{ key = "face", label = "Visage & Maquillage", desc = "Décal du visage", subs = { { key = "decal", label = "Décal visage" } } },
		{ key = "clothes", label = "Vêtements 2D", desc = "Chemises et pantalons classiques", subs = { { key = "shirt", label = "Chemise" }, { key = "pants", label = "Pantalon" }, { key = "graphicTShirt", label = "T-Shirt graphique" } } },
		{
			key = "accessories", label = "Accessoires", desc = "Cheveux, chapeaux, lunettes, vêtements 3D",
			subs = { { key = "hair", label = "Cheveux" }, { key = "hat", label = "Chapeaux" }, { key = "face", label = "Lunettes / Face" }, { key = "neck", label = "Cou" }, { key = "front", label = "Devant" }, { key = "back", label = "Dos" }, { key = "waist", label = "Taille" }, { key = "shirt", label = "Vêtement haut 3D" }, { key = "pants", label = "Vêtement bas 3D" }, { key = "jacket", label = "Veste" }, { key = "sweater", label = "Pull" }, { key = "shorts", label = "Short" }, { key = "leftShoe", label = "Chaussure gauche" }, { key = "rightShoe", label = "Chaussure droite" }, { key = "dressSkirt", label = "Robe / Jupe" }, { key = "eyebrow", label = "Sourcils" }, { key = "eyelash", label = "Cils" } },
		},
		{
			key = "colors", label = "Couleurs de peau", desc = "Teintes des 6 membres",
			subs = { { key = "head", label = "Tête" }, { key = "torso", label = "Buste" }, { key = "leftArm", label = "Bras gauche" }, { key = "rightArm", label = "Bras droit" }, { key = "leftLeg", label = "Jambe gauche" }, { key = "rightLeg", label = "Jambe droite" } },
		},
		{
			key = "animations", label = "Animations", desc = "Pack d'animations de mouvement",
			subs = { { key = "idle", label = "Idle" }, { key = "walk", label = "Marche" }, { key = "run", label = "Course" }, { key = "jump", label = "Saut" }, { key = "fall", label = "Chute" }, { key = "climb", label = "Grimpe" }, { key = "swim", label = "Nage" }, { key = "mood", label = "Humeur" } },
		},
		{ key = "scales", label = "Proportions", desc = "Tailles et corpulence", subs = {} },
	}

	for _, pDef in ipairs(pieceDefs) do
		local hasSubs = #pDef.subs > 0
		local isExpanded = false
		local collapsedHeight = 44
		local expandedHeight = collapsedHeight + (#pDef.subs * 32) + 8

		local pCard = Instance.new("Frame")
		pCard.Parent = PiecesTab
		pCard.Size = UDim2.new(1, 0, 0, collapsedHeight)
		pCard.BackgroundColor3 = C_PANEL
		pCard.BackgroundTransparency = 0.3
		pCard.ClipsDescendants = true
		addCorner(pCard, 6)
		addStroke(pCard, C_BORDER, 1, 0.6)

		local isCatActive = isOptionActive(CopyOptions[pDef.key])
		local pToggle = createButton(pCard, isCatActive and "ON" or "OFF", isCatActive and CurrentTheme.Accent or C_CARD, isCatActive and CurrentTheme.TextDark or C_MUTED, UDim2.new(0, 44, 0, 24), UDim2.new(0, 8, 0, 10))
		pToggle.Font = Enum.Font.GothamBold
		pToggle.TextSize = 10

		local pLabel = Instance.new("TextLabel")
		pLabel.Parent = pCard
		pLabel.Position = UDim2.new(0, 60, 0, 6)
		pLabel.Size = UDim2.new(1, -120, 0, 16)
		pLabel.BackgroundTransparency = 1
		pLabel.Text = pDef.label
		pLabel.Font = Enum.Font.GothamMedium
		pLabel.TextSize = 12
		pLabel.TextColor3 = CurrentTheme.Accent
		pLabel.TextXAlignment = Enum.TextXAlignment.Left

		local pSub = Instance.new("TextLabel")
		pSub.Parent = pCard
		pSub.Position = UDim2.new(0, 60, 0, 22)
		pSub.Size = UDim2.new(1, -120, 0, 14)
		pSub.BackgroundTransparency = 1
		pSub.Text = pDef.desc
		pSub.Font = Enum.Font.Gotham
		pSub.TextSize = 10
		pSub.TextColor3 = C_MUTED
		pSub.TextXAlignment = Enum.TextXAlignment.Left

		local function updateParentToggle()
			local active = isOptionActive(CopyOptions[pDef.key])
			pToggle.BackgroundColor3 = active and CurrentTheme.Accent or C_CARD
			pToggle.TextColor3 = active and CurrentTheme.TextDark or C_MUTED
			pToggle.Text = active and "ON" or "OFF"
		end

		if hasSubs then
			local arrowBtn = Instance.new("TextButton")
			arrowBtn.Parent = pCard
			arrowBtn.Size = UDim2.new(0, 24, 0, 24)
			arrowBtn.Position = UDim2.new(1, -32, 0, 10)
			arrowBtn.BackgroundTransparency = 1
			arrowBtn.Text = ">"
			arrowBtn.Font = Enum.Font.GothamBold
			arrowBtn.TextSize = 12
			arrowBtn.TextColor3 = C_MUTED

			local subsContainer = Instance.new("Frame")
			subsContainer.Parent = pCard
			subsContainer.Position = UDim2.new(0, 0, 0, collapsedHeight)
			subsContainer.Size = UDim2.new(1, 0, 1, -collapsedHeight)
			subsContainer.BackgroundTransparency = 1

			local subBtns = {}
			for si, subDef in ipairs(pDef.subs) do
				local subRow = Instance.new("Frame")
				subRow.Parent = subsContainer
				subRow.Size = UDim2.new(1, -16, 0, 28)
				subRow.Position = UDim2.new(0, 8, 0, (si - 1) * 32 + 4)
				subRow.BackgroundColor3 = C_CARD
				subRow.BackgroundTransparency = 0.5
				addCorner(subRow, 4)

				local subLabel = Instance.new("TextLabel")
				subLabel.Parent = subRow
				subLabel.Position = UDim2.new(0, 10, 0, 0)
				subLabel.Size = UDim2.new(1, -64, 1, 0)
				subLabel.BackgroundTransparency = 1
				subLabel.Text = subDef.label
				subLabel.Font = Enum.Font.Gotham
				subLabel.TextSize = 11
				subLabel.TextColor3 = CurrentTheme.Accent
				subLabel.TextXAlignment = Enum.TextXAlignment.Left

				local val = CopyOptions[pDef.key] and CopyOptions[pDef.key][subDef.key]
				local subToggle = createButton(subRow, val and "ON" or "OFF", val and CurrentTheme.Accent or C_CARD, val and CurrentTheme.TextDark or C_MUTED, UDim2.new(0, 40, 0, 20), UDim2.new(1, -48, 0.5, -10))
				subToggle.Font = Enum.Font.GothamBold
				subToggle.TextSize = 9

				subBtns[subDef.key] = subToggle
				subToggle.MouseButton1Click:Connect(function()
					CopyOptions[pDef.key][subDef.key] = not CopyOptions[pDef.key][subDef.key]
					local newVal = CopyOptions[pDef.key][subDef.key]
					subToggle.BackgroundColor3 = newVal and CurrentTheme.Accent or C_CARD
					subToggle.TextColor3 = newVal and CurrentTheme.TextDark or C_MUTED
					subToggle.Text = newVal and "ON" or "OFF"
					updateParentToggle()
					persistSettings()
				end)
			end

			arrowBtn.MouseButton1Click:Connect(function()
				isExpanded = not isExpanded
				arrowBtn.Text = isExpanded and "v" or ">"
				TweenService:Create(pCard, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, isExpanded and expandedHeight or collapsedHeight) }):Play()
			end)

			pToggle.MouseButton1Click:Connect(function()
				local catOpt = CopyOptions[pDef.key]
				local allOn = isOptionActive(catOpt)
				for subKey, _ in pairs(catOpt) do catOpt[subKey] = not allOn end
				updateParentToggle()
				for subKey, btn in pairs(subBtns) do
					local v = catOpt[subKey]
					btn.BackgroundColor3 = v and CurrentTheme.Accent or C_CARD
					btn.TextColor3 = v and CurrentTheme.TextDark or C_MUTED
					btn.Text = v and "ON" or "OFF"
				end
				persistSettings()
			end)
		else
			pToggle.MouseButton1Click:Connect(function()
				CopyOptions[pDef.key] = not CopyOptions[pDef.key]
				updateParentToggle()
				persistSettings()
			end)
		end
	end
end

-- ONGLET 5: TAILLE
local function buildTailleTab()
	local TailleTab = TabContainers["Taille"]
	local rebuildDebounce = false
	requestDebouncedRebuild = function()
		if rebuildDebounce then return end
		rebuildDebounce = true
		task.delay(0.18, function()
			rebuildDebounce = false
			if CurrentHumDes and refreshAll3DPreviews then pcall(function() refreshAll3DPreviews() end) end
		end)
	end

	for scaleKey, scaleInfo in pairs(ScaleLimits) do
		local sCard = Instance.new("Frame")
		sCard.Parent = TailleTab
		sCard.Size = UDim2.new(1, 0, 0, 48)
		sCard.BackgroundColor3 = C_PANEL
		sCard.BackgroundTransparency = 0.3
		addCorner(sCard, 6)
		addStroke(sCard, C_BORDER, 1, 0.6)

		local sTitle = Instance.new("TextLabel")
		sTitle.Parent = sCard
		sTitle.Position = UDim2.new(0, 10, 0, 6)
		sTitle.Size = UDim2.new(0.6, 0, 0, 16)
		sTitle.BackgroundTransparency = 1
		sTitle.Text = scaleInfo[4]
		sTitle.Font = Enum.Font.GothamMedium
		sTitle.TextSize = 11
		sTitle.TextColor3 = CurrentTheme.Accent
		sTitle.TextXAlignment = Enum.TextXAlignment.Left

		local sVal = Instance.new("TextLabel")
		sVal.Parent = sCard
		sVal.Position = UDim2.new(0.6, 0, 0, 6)
		sVal.Size = UDim2.new(0.4, -10, 0, 16)
		sVal.BackgroundTransparency = 1
		sVal.Text = string.format("%.0f%%", (ScaleOptions[scaleKey] / scaleInfo[2]) * 100)
		sVal.Font = Enum.Font.GothamMedium
		sVal.TextSize = 11
		sVal.TextColor3 = C_MUTED
		sVal.TextXAlignment = Enum.TextXAlignment.Right

		local sBar = Instance.new("Frame")
		sBar.Parent = sCard
		sBar.Position = UDim2.new(0, 10, 0, 28)
		sBar.Size = UDim2.new(1, -20, 0, 6)
		sBar.BackgroundColor3 = C_CARD
		sBar.BackgroundTransparency = 0.2
		addCorner(sBar, 3)

		local sFill = Instance.new("Frame")
		sFill.Parent = sBar
		sFill.Size = UDim2.new((ScaleOptions[scaleKey] - scaleInfo[1]) / (scaleInfo[2] - scaleInfo[1]), 0, 1, 0)
		sFill.BackgroundColor3 = CurrentTheme.Accent
		addCorner(sFill, 3)

		local sThumb = Instance.new("Frame")
		sThumb.Parent = sBar
		sThumb.AnchorPoint = Vector2.new(0.5, 0.5)
		sThumb.Position = UDim2.new(sFill.Size.X.Scale, 0, 0.5, 0)
		sThumb.Size = UDim2.new(0, 12, 0, 12)
		sThumb.BackgroundColor3 = CurrentTheme.Accent
		addCorner(sThumb, 6)

		SlidersUI[scaleKey] = { fill = sFill, thumb = sThumb, label = sVal, limits = scaleInfo }

		local function updateSlider(posX)
			local minX = sBar.AbsolutePosition.X
			local maxX = minX + sBar.AbsoluteSize.X
			local pct = math.clamp((posX - minX) / ((maxX - minX) or 1), 0, 1)
			local realVal = scaleInfo[1] + (scaleInfo[2] - scaleInfo[1]) * pct
			ScaleOptions[scaleKey] = realVal
			sFill.Size = UDim2.new(pct, 0, 1, 0)
			sThumb.Position = UDim2.new(pct, 0, 0.5, 0)
			sVal.Text = string.format("%.0f%%", (realVal / scaleInfo[2]) * 100)
			requestDebouncedRebuild()
		end

		sBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				updateSlider(input.Position.X)
				local moveConn, endConn
				moveConn = UserInputService.InputChanged:Connect(function(i2)
					if i2.UserInputType == Enum.UserInputType.MouseMovement or i2.UserInputType == Enum.UserInputType.Touch then
						updateSlider(i2.Position.X)
					end
				end)
				endConn = UserInputService.InputEnded:Connect(function(i2)
					if i2.UserInputType == Enum.UserInputType.MouseButton1 or i2.UserInputType == Enum.UserInputType.Touch then
						if moveConn then moveConn:Disconnect() end
						if endConn then endConn:Disconnect() end
						if CurrentHumDes then pcall(function() refreshAll3DPreviews() end) end
					end
				end)
			end
		end)
	end

	local ApplyScalesBtn = createButton(TailleTab, "Appliquer proportions", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, 0, 0, 32))
	ApplyScalesBtn.MouseButton1Click:Connect(function()
		if not CurrentHumDes then CurrentHumDes = getAuthenticDescription(LocalPlayer, LocalPlayer.UserId) end
		_G.SalamangueClonerApply()
	end)

	local ResetScalesBtn = createButton(TailleTab, "Rétablir proportions cible", C_CARD, C_MUTED, UDim2.new(1, 0, 0, 30))
	ResetScalesBtn.MouseButton1Click:Connect(function()
		if BaseTargetScales then
			for k, v in pairs(BaseTargetScales) do ScaleOptions[k] = v end
			syncSlidersToScaleOptions()
			refreshAll3DPreviews()
			if CurrentHumDes then
				task.spawn(function()
					DispatchDescriptionToServer(CurrentHumDes, { body = false, face = false, clothes = false, colors = false, animations = false, scales = true, accessories = false }, ScaleOptions)
				end)
			end
			setStatus("Proportions cible rétablies", true)
		end
	end)
end

-- ONGLET 6: FAVORIS & PRESETS
local function buildFavorisTab()
	local FavorisTab = TabContainers["Favoris"]
	local SaveCurrentBtn = createButton(FavorisTab, "💾 Enregistrer le skin actuel", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, 0, 0, 32))

	local CodeShareCard = Instance.new("Frame")
	CodeShareCard.Parent = FavorisTab
	CodeShareCard.Size = UDim2.new(1, 0, 0, 38)
	CodeShareCard.BackgroundColor3 = C_PANEL
	CodeShareCard.BackgroundTransparency = 0.3
	addCorner(CodeShareCard, 6)

	local ImportBox = Instance.new("TextBox")
	ImportBox.Parent = CodeShareCard
	ImportBox.Position = UDim2.new(0, 8, 0, 5)
	ImportBox.Size = UDim2.new(1, -95, 1, -10)
	ImportBox.BackgroundColor3 = C_CARD
	ImportBox.BackgroundTransparency = 0.3
	ImportBox.PlaceholderText = "Coller un code de skin..."
	ImportBox.PlaceholderColor3 = C_DIM
	ImportBox.Text = ""
	ImportBox.TextColor3 = CurrentTheme.Accent
	ImportBox.Font = Enum.Font.Gotham
	ImportBox.TextSize = 10
	addCorner(ImportBox, 4)

	local ImportBtn = createButton(CodeShareCard, "Importer", C_CARD, CurrentTheme.Accent, UDim2.new(0, 80, 1, -10), UDim2.new(1, -85, 0, 5))
	ImportBtn.TextSize = 10

	local SavedListContainer = Instance.new("Frame")
	SavedListContainer.Parent = FavorisTab
	SavedListContainer.Size = UDim2.new(1, 0, 0, 0)
	SavedListContainer.AutomaticSize = Enum.AutomaticSize.Y
	SavedListContainer.BackgroundTransparency = 1

	local sListLayout = Instance.new("UIListLayout")
	sListLayout.Parent = SavedListContainer
	sListLayout.Padding = UDim.new(0, 5)

	local scaleProps = { "HeadScale", "WidthScale", "HeightScale", "DepthScale", "BodyTypeScale", "ProportionScale" }

	local function applyOutfitData(outfitPayload, skinName)
		local ready, waitS = canApplyOutfit()
		if not ready then setStatus("Attendez " .. tostring(waitS) .. "s", false) return end
		setStatus("Application de " .. skinName .. "...", true)
		task.spawn(function()
			-- 1. Synchronisation exacte des proportions dans ScaleOptions et curseurs UI
			for _, sProp in ipairs(scaleProps) do
				if outfitPayload[sProp] ~= nil then
					ScaleOptions[sProp] = outfitPayload[sProp]
				end
			end
			syncSlidersToScaleOptions()

			-- 2. Mise à jour de CurrentHumDes pour l'aperçu 3D et les futures sauvegardes
			if not CurrentHumDes then
				CurrentHumDes = Instance.new("HumanoidDescription")
			end
			for prop, val in pairs(outfitPayload) do
				if prop ~= "Accessories" then
					pcall(function() CurrentHumDes[prop] = val end)
				end
			end
			for _, sProp in ipairs(scaleProps) do
				if outfitPayload[sProp] ~= nil then
					pcall(function() CurrentHumDes[sProp] = outfitPayload[sProp] end)
				end
			end
			if outfitPayload.Accessories and type(outfitPayload.Accessories) == "table" then
				pcall(function() CurrentHumDes:SetAccessories(outfitPayload.Accessories, true) end)
			end
			refreshAll3DPreviews(CurrentHumDes, skinName)
			populateInspectorList(CurrentHumDes)

			-- 3. Application serveur de l'outfit complet (Bloxbiz FE)
			local ok = pcall(function() ApplyOutfitRemote:FireServer(outfitPayload) end)

			-- 4. Application des détails de proportions et de chaque membre individuellement
			local function applyDetails()
				pcall(function()
					if ApplyPropertyRemote then
						for _, sProp in ipairs(scaleProps) do
							local sVal = outfitPayload[sProp]
							if sVal ~= nil then
								ApplyPropertyRemote:FireServer({ Property = sProp, AssetId = sVal })
							end
						end
						local bodyProps = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Shirt", "Pants", "GraphicTShirt", "Face" }
						for _, bProp in ipairs(bodyProps) do
							local bVal = outfitPayload[bProp]
							if bVal and bVal ~= 0 then
								ApplyPropertyRemote:FireServer({ Property = bProp, AssetId = bVal })
							end
						end
						if outfitPayload.Accessories and type(outfitPayload.Accessories) == "table" then
							for order, acc in ipairs(outfitPayload.Accessories) do
								if acc.AssetId and acc.AssetId ~= 0 then
									applyAccessory(acc.AccessoryType, acc.AssetId, order)
								end
							end
						end
					end
				end)
			end

			task.delay(0.35, function()
				pcall(function() ApplyOutfitRemote:FireServer(outfitPayload) end)
				applyDetails()
			end)

			task.delay(0.8, function()
				applyDetails()
			end)

			if ok and isOptionActive(CopyOptions.animations) then
				forceAnimationOverride(CurrentHumDes, outfitPayload)
			end
			setStatus(ok and (skinName .. " appliqué avec proportions exactes !") or "Erreur", ok)
		end)
	end

	local function refreshSavedSkinsList()
		for _, child in pairs(SavedListContainer:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
		end
		if #SavedSkins == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Parent = SavedListContainer
			emptyLabel.Size = UDim2.new(1, 0, 0, 32)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = "Aucun favori enregistré"
			emptyLabel.Font = Enum.Font.Gotham
			emptyLabel.TextSize = 11
			emptyLabel.TextColor3 = C_DIM
			return
		end
		for idx, sk in ipairs(SavedSkins) do
			local row = Instance.new("Frame")
			row.Parent = SavedListContainer
			row.Size = UDim2.new(1, 0, 0, 44)
			row.BackgroundColor3 = C_PANEL
			row.BackgroundTransparency = 0.3
			addCorner(row, 6)
			addStroke(row, C_BORDER, 1, 0.6)

			local nameBtn = Instance.new("TextButton")
			nameBtn.Parent = row
			nameBtn.Position = UDim2.new(0, 10, 0, 6)
			nameBtn.Size = UDim2.new(1, -185, 0, 16)
			nameBtn.BackgroundTransparency = 1
			nameBtn.Text = sk.name or ("Skin " .. idx)
			nameBtn.Font = Enum.Font.GothamMedium
			nameBtn.TextSize = 12
			nameBtn.TextColor3 = CurrentTheme.Accent
			nameBtn.TextXAlignment = Enum.TextXAlignment.Left
			nameBtn.AutoButtonColor = false

			local nameEdit = Instance.new("TextBox")
			nameEdit.Parent = row
			nameEdit.Position = UDim2.new(0, 10, 0, 4)
			nameEdit.Size = UDim2.new(1, -185, 0, 20)
			nameEdit.BackgroundColor3 = C_CARD
			nameEdit.Font = Enum.Font.GothamMedium
			nameEdit.TextSize = 12
			nameEdit.TextColor3 = CurrentTheme.Accent
			nameEdit.PlaceholderText = "Nom du favori"
			nameEdit.TextXAlignment = Enum.TextXAlignment.Left
			nameEdit.ClearTextOnFocus = false
			nameEdit.Visible = false
			addCorner(nameEdit, 4)
			addStroke(nameEdit, CurrentTheme.Accent, 1, 0.5)

			nameBtn.MouseButton1Click:Connect(function()
				nameBtn.Visible = false
				nameEdit.Visible = true
				nameEdit.Text = sk.name or ("Skin " .. idx)
				nameEdit:CaptureFocus()
			end)

			nameEdit.FocusLost:Connect(function(enterPressed)
				local newName = nameEdit.Text:match("^%s*(.-)%s*$")
				if newName and #newName > 0 then
					sk.name = newName
					persistSkinsToFile()
					nameBtn.Text = newName
				end
				nameEdit.Visible = false
				nameBtn.Visible = true
			end)

			local dateLbl = Instance.new("TextLabel")
			dateLbl.Parent = row
			dateLbl.Position = UDim2.new(0, 10, 0, 22)
			dateLbl.Size = UDim2.new(1, -185, 0, 14)
			dateLbl.BackgroundTransparency = 1
			dateLbl.Text = sk.date or ""
			dateLbl.Font = Enum.Font.Gotham
			dateLbl.TextSize = 10
			dateLbl.TextColor3 = C_MUTED
			dateLbl.TextXAlignment = Enum.TextXAlignment.Left

			local exportBtn = createButton(row, "📤", C_CARD, CurrentTheme.Accent, UDim2.new(0, 26, 0, 26), UDim2.new(1, -176, 0.5, -13))
			local viewFavBtn = createButton(row, "Voir", C_CARD, CurrentTheme.Accent, UDim2.new(0, 40, 0, 26), UDim2.new(1, -146, 0.5, -13))
			local applyFavBtn = createButton(row, "Copier", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0, 60, 0, 26), UDim2.new(1, -102, 0.5, -13))
			local delFavBtn = createButton(row, "×", C_CARD, C_MUTED, UDim2.new(0, 26, 0, 26), UDim2.new(1, -36, 0.5, -13))

			exportBtn.MouseButton1Click:Connect(function()
				local ok, encoded = pcall(function() return HttpService:JSONEncode(serializeValue(sk.outfit)) end)
				if ok and encoded then
					local cp = copyToClipboard(encoded)
					setStatus(cp and "Code du skin copié !" or "Erreur", cp)
				end
			end)

			viewFavBtn.MouseButton1Click:Connect(function()
				task.spawn(function()
					local outfit = sk.outfit
					local targetDes = Instance.new("HumanoidDescription")
					for prop, val in pairs(outfit) do
						if prop ~= "Accessories" then pcall(function() targetDes[prop] = val end) end
					end
					if outfit.Accessories and type(outfit.Accessories) == "table" then
						pcall(function() targetDes:SetAccessories(outfit.Accessories, true) end)
					end

					-- Synchroniser les proportions exactes
					for _, sProp in ipairs(scaleProps) do
						if outfit[sProp] ~= nil then
							pcall(function() targetDes[sProp] = outfit[sProp] end)
							ScaleOptions[sProp] = outfit[sProp]
						end
					end
					syncSlidersToScaleOptions()

					CurrentHumDes = targetDes
					SelectedTargetName = sk.name or "Favori"
					refreshAll3DPreviews(targetDes, sk.name)
					populateInspectorList(targetDes)
					switchTab("Apercu")
					setStatus(sk.name .. " chargé avec proportions exactes", true)
				end)
			end)

			applyFavBtn.MouseButton1Click:Connect(function() applyOutfitData(sk.outfit, sk.name) end)
			delFavBtn.MouseButton1Click:Connect(function()
				table.remove(SavedSkins, idx)
				persistSkinsToFile()
				refreshSavedSkinsList()
				setStatus("Favori supprimé", false)
			end)
		end
	end

	SaveCurrentBtn.MouseButton1Click:Connect(function()
		if not CurrentHumDes then CurrentHumDes = getLocalPlayerDescription() end
		local skinName = SelectedTargetName or ("Skin " .. (#SavedSkins + 1))
		
		-- Injecter les proportions actives de ScaleOptions dans CurrentHumDes
		if CurrentHumDes then
			for _, sProp in ipairs(scaleProps) do
				if ScaleOptions[sProp] ~= nil then
					pcall(function() CurrentHumDes[sProp] = ScaleOptions[sProp] end)
				end
			end
		end

		local finalPayload = buildDescriptionTable(CurrentHumDes, CopyOptions, ScaleOptions)
		for _, sProp in ipairs(scaleProps) do
			if ScaleOptions[sProp] ~= nil then
				finalPayload[sProp] = ScaleOptions[sProp]
			end
		end

		table.insert(SavedSkins, { name = skinName, date = os.date("%d/%m %H:%M"), outfit = finalPayload, userId = SelectedUserId or nil })
		persistSkinsToFile()
		refreshSavedSkinsList()
		setStatus("Skin et proportions exactes sauvegardés !", true)
	end)

	ImportBtn.MouseButton1Click:Connect(function()
		local raw = ImportBox.Text:gsub("%s+", "")
		if raw == "" then return end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(decoded) == "table" then
			table.insert(SavedSkins, { name = "Importé " .. (#SavedSkins + 1), date = os.date("%d/%m %H:%M"), outfit = deserializeValue(decoded) })
			persistSkinsToFile()
			refreshSavedSkinsList()
			ImportBox.Text = ""
			setStatus("Skin importé avec succès !", true)
		else
			setStatus("Code invalide", false)
		end
	end)

	-- Presets Section
	local PresetsListContainer = Instance.new("Frame")
	PresetsListContainer.Parent = FavorisTab
	PresetsListContainer.Size = UDim2.new(1, 0, 0, 0)
	PresetsListContainer.AutomaticSize = Enum.AutomaticSize.Y
	PresetsListContainer.BackgroundTransparency = 1

	local pListLay = Instance.new("UIListLayout")
	pListLay.Parent = PresetsListContainer
	pListLay.Padding = UDim.new(0, 5)

	for _, pr in ipairs(BuiltInPresets) do
		local row = Instance.new("Frame")
		row.Parent = PresetsListContainer
		row.Size = UDim2.new(1, 0, 0, 42)
		row.BackgroundColor3 = C_PANEL
		row.BackgroundTransparency = 0.3
		addCorner(row, 6)

		local nLbl = Instance.new("TextLabel")
		nLbl.Parent = row
		nLbl.Position = UDim2.new(0, 10, 0, 5)
		nLbl.Size = UDim2.new(1, -115, 0, 16)
		nLbl.BackgroundTransparency = 1
		nLbl.Text = pr.name
		nLbl.Font = Enum.Font.GothamMedium
		nLbl.TextSize = 12
		nLbl.TextColor3 = CurrentTheme.Accent
		nLbl.TextXAlignment = Enum.TextXAlignment.Left

		local dLbl = Instance.new("TextLabel")
		dLbl.Parent = row
		dLbl.Position = UDim2.new(0, 10, 0, 21)
		dLbl.Size = UDim2.new(1, -115, 0, 14)
		dLbl.BackgroundTransparency = 1
		dLbl.Text = pr.desc
		dLbl.Font = Enum.Font.Gotham
		dLbl.TextSize = 10
		dLbl.TextColor3 = C_MUTED
		dLbl.TextXAlignment = Enum.TextXAlignment.Left

		local prApplyBtn = createButton(row, "Appliquer", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0, 68, 0, 26), UDim2.new(1, -74, 0.5, -13))
		prApplyBtn.TextSize = 11
		prApplyBtn.MouseButton1Click:Connect(function() applyOutfitData(pr.outfit, pr.name) end)
	end

	refreshSavedSkinsList()
end

-- ONGLET 7: OUTILS
local function buildOutilsTab()
	local OutilsTab = TabContainers["Outils"]

	-- 1. Équipement par ID Direct
	local CustomEquipCard = Instance.new("Frame")
	CustomEquipCard.Parent = OutilsTab
	CustomEquipCard.Size = UDim2.new(1, 0, 0, 116)
	CustomEquipCard.BackgroundColor3 = C_PANEL
	CustomEquipCard.BackgroundTransparency = 0.3
	addCorner(CustomEquipCard, 6)
	addStroke(CustomEquipCard, C_BORDER, 1, 0.6)

	local CustomEquipTitle = Instance.new("TextLabel")
	CustomEquipTitle.Parent = CustomEquipCard
	CustomEquipTitle.Position = UDim2.new(0, 10, 0, 6)
	CustomEquipTitle.Size = UDim2.new(1, -20, 0, 16)
	CustomEquipTitle.BackgroundTransparency = 1
	CustomEquipTitle.Text = "🔍 Équiper un Asset par ID Roblox"
	CustomEquipTitle.Font = Enum.Font.GothamMedium
	CustomEquipTitle.TextSize = 11
	CustomEquipTitle.TextColor3 = CurrentTheme.Accent
	CustomEquipTitle.TextXAlignment = Enum.TextXAlignment.Left

	local CustomIdInput = Instance.new("TextBox")
	CustomIdInput.Parent = CustomEquipCard
	CustomIdInput.Position = UDim2.new(0, 10, 0, 26)
	CustomIdInput.Size = UDim2.new(1, -20, 0, 28)
	CustomIdInput.BackgroundColor3 = C_CARD
	CustomIdInput.BackgroundTransparency = 0.4
	CustomIdInput.PlaceholderText = "Entrez un Asset ID Roblox (ex: 139607718)..."
	CustomIdInput.PlaceholderColor3 = C_DIM
	CustomIdInput.Text = ""
	CustomIdInput.TextColor3 = CurrentTheme.Accent
	CustomIdInput.Font = Enum.Font.Gotham
	CustomIdInput.TextSize = 11
	CustomIdInput.TextXAlignment = Enum.TextXAlignment.Left
	addCorner(CustomIdInput, 4)

	local customCategorySelected = "Hat"
	local customTypeButtons = {}
	local typeRow = Instance.new("Frame")
	typeRow.Parent = CustomEquipCard
	typeRow.Position = UDim2.new(0, 10, 0, 58)
	typeRow.Size = UDim2.new(1, -20, 0, 22)
	typeRow.BackgroundTransparency = 1

	local customCategories = {
		{ id = "Hat", label = "Chapeau", enum = Enum.AccessoryType.Hat },
		{ id = "Hair", label = "Cheveux", enum = Enum.AccessoryType.Hair },
		{ id = "Face", label = "Lunettes", enum = Enum.AccessoryType.Face },
		{ id = "Shirt", label = "Chemise", prop = "Shirt" },
		{ id = "Pants", label = "Pantalon", prop = "Pants" },
		{ id = "RightLeg", label = "Jambe D.", prop = "RightLeg" },
		{ id = "Head", label = "Tête", prop = "Head" },
	}

	for cIdx, cDef in ipairs(customCategories) do
		local cBtn = Instance.new("TextButton")
		cBtn.Parent = typeRow
		local wPct = 1 / #customCategories
		cBtn.Size = UDim2.new(wPct, -2, 1, 0)
		cBtn.Position = UDim2.new(wPct * (cIdx - 1), 1, 0, 0)
		cBtn.BackgroundColor3 = (customCategorySelected == cDef.id) and CurrentTheme.Accent or C_CARD
		cBtn.BorderSizePixel = 0
		cBtn.Text = cDef.label
		cBtn.Font = Enum.Font.Gotham
		cBtn.TextSize = 8
		cBtn.TextColor3 = (customCategorySelected == cDef.id) and CurrentTheme.TextDark or C_MUTED
		addCorner(cBtn, 3)

		cBtn.MouseButton1Click:Connect(function()
			customCategorySelected = cDef.id
			for _, b in pairs(customTypeButtons) do
				b.btn.BackgroundColor3 = (customCategorySelected == b.id) and CurrentTheme.Accent or C_CARD
				b.btn.TextColor3 = (customCategorySelected == b.id) and CurrentTheme.TextDark or C_MUTED
			end
		end)
		table.insert(customTypeButtons, { id = cDef.id, btn = cBtn })
	end

	local CustomEquipActionBtn = createButton(CustomEquipCard, "Équiper cet ID sur le Skin", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 86))
	CustomEquipActionBtn.TextSize = 10
	CustomEquipActionBtn.MouseButton1Click:Connect(function()
		local idNum = tonumber(CustomIdInput.Text:gsub("%s+", ""))
		if not idNum or idNum <= 0 then setStatus("Veuillez entrer un Asset ID valide", false) return end
		if not CurrentHumDes then CurrentHumDes = getLocalPlayerDescription() or Instance.new("HumanoidDescription") end

		for _, cDef in ipairs(customCategories) do
			if cDef.id == customCategorySelected then
				if cDef.prop then
					pcall(function() CurrentHumDes[cDef.prop] = idNum end)
					applyProperty(cDef.prop, idNum)
				elseif cDef.enum then
					local currentAccs = {}
					pcall(function() currentAccs = CurrentHumDes:GetAccessories(true) end)
					table.insert(currentAccs, { AssetId = idNum, AccessoryType = cDef.enum, Order = #currentAccs + 1 })
					pcall(function() CurrentHumDes:SetAccessories(currentAccs, true) end)
					applyAccessory(cDef.enum, idNum, #currentAccs)
				end
			end
		end
		refreshAll3DPreviews()
		populateInspectorList(CurrentHumDes)
		setStatus("Asset ID " .. tostring(idNum) .. " équipé !", true)
	end)

	-- 2. Rainbow Mode
	local RainbowCard = Instance.new("Frame")
	RainbowCard.Parent = OutilsTab
	RainbowCard.Size = UDim2.new(1, 0, 0, 78)
	RainbowCard.BackgroundColor3 = C_PANEL
	RainbowCard.BackgroundTransparency = 0.3
	addCorner(RainbowCard, 6)
	addStroke(RainbowCard, C_BORDER, 1, 0.6)

	local RainbowTitle = Instance.new("TextLabel")
	RainbowTitle.Parent = RainbowCard
	RainbowTitle.Position = UDim2.new(0, 10, 0, 8)
	RainbowTitle.Size = UDim2.new(1, -20, 0, 16)
	RainbowTitle.BackgroundTransparency = 1
	RainbowTitle.Text = "🌈 Mode Rainbow Skin (Chroma RGB FE)"
	RainbowTitle.Font = Enum.Font.GothamMedium
	RainbowTitle.TextSize = 11
	RainbowTitle.TextColor3 = CurrentTheme.Accent
	RainbowTitle.TextXAlignment = Enum.TextXAlignment.Left

	local RainbowToggleBtn = createButton(RainbowCard, "Activer le Mode Rainbow Skin", C_CARD, CurrentTheme.Accent, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 34))
	local isRainbowActive = false
	local rainbowThread = nil
	RainbowToggleBtn.MouseButton1Click:Connect(function()
		isRainbowActive = not isRainbowActive
		if isRainbowActive then
			RainbowToggleBtn.BackgroundColor3 = CurrentTheme.Accent
			RainbowToggleBtn.TextColor3 = CurrentTheme.TextDark
			RainbowToggleBtn.Text = "Désactiver le Mode Rainbow"
			setStatus("Mode Rainbow Skin activé !", true)
			rainbowThread = task.spawn(function()
				local hue = 0
				while isRainbowActive do
					hue = (hue + 0.05) % 1
					local col = Color3.fromHSV(hue, 0.9, 1.0)
					if CurrentHumDes then
						CurrentHumDes.HeadColor = col CurrentHumDes.TorsoColor = col
						CurrentHumDes.LeftArmColor = col CurrentHumDes.RightArmColor = col
						CurrentHumDes.LeftLegColor = col CurrentHumDes.RightLegColor = col
					end
					pcall(function() ApplyOutfitRemote:FireServer({ HeadColor = col, TorsoColor = col, LeftArmColor = col, RightArmColor = col, LeftLegColor = col, RightLegColor = col }) end)
					task.wait(0.6)
				end
			end)
		else
			RainbowToggleBtn.BackgroundColor3 = C_CARD
			RainbowToggleBtn.TextColor3 = CurrentTheme.Accent
			RainbowToggleBtn.Text = "Activer le Mode Rainbow Skin"
			if rainbowThread then pcall(function() task.cancel(rainbowThread) end) end
			setStatus("Mode Rainbow désactivé", false)
		end
	end)

	-- 3. Modificateurs Headless & Korblox
	local ModifCard = Instance.new("Frame")
	ModifCard.Parent = OutilsTab
	ModifCard.Size = UDim2.new(1, 0, 0, 78)
	ModifCard.BackgroundColor3 = C_PANEL
	ModifCard.BackgroundTransparency = 0.3
	addCorner(ModifCard, 6)
	addStroke(ModifCard, C_BORDER, 1, 0.6)

	local ModifTitle = Instance.new("TextLabel")
	ModifTitle.Parent = ModifCard
	ModifTitle.Position = UDim2.new(0, 10, 0, 8)
	ModifTitle.Size = UDim2.new(1, -20, 0, 16)
	ModifTitle.BackgroundTransparency = 1
	ModifTitle.Text = "🎭 Modificateurs Rapides (Sauvegardés dans Favoris)"
	ModifTitle.Font = Enum.Font.GothamMedium
	ModifTitle.TextSize = 11
	ModifTitle.TextColor3 = CurrentTheme.Accent
	ModifTitle.TextXAlignment = Enum.TextXAlignment.Left

	local HeadlessBtn = createButton(ModifCard, "Tête Headless", C_CARD, CurrentTheme.Accent, UDim2.new(0.48, -4, 0, 32), UDim2.new(0, 10, 0, 34))
	local KorbloxBtn = createButton(ModifCard, "Jambe Korblox", C_CARD, CurrentTheme.Accent, UDim2.new(0.48, -4, 0, 32), UDim2.new(0.52, 0, 0, 34))

	HeadlessBtn.MouseButton1Click:Connect(function()
		if not CurrentHumDes then CurrentHumDes = getLocalPlayerDescription() end
		if CurrentHumDes then
			CurrentHumDes.Head = 134082579
			refreshAll3DPreviews()
			populateInspectorList(CurrentHumDes)
		end
		applyProperty("Head", 134082579)
		setStatus("Headless appliqué et injecté dans le skin !", true)
	end)

	KorbloxBtn.MouseButton1Click:Connect(function()
		if not CurrentHumDes then CurrentHumDes = getLocalPlayerDescription() end
		if CurrentHumDes then
			CurrentHumDes.RightLeg = 139607718
			refreshAll3DPreviews()
			populateInspectorList(CurrentHumDes)
		end
		applyProperty("RightLeg", 139607718)
		setStatus("Jambe Korblox appliquée et injectée dans le skin !", true)
	end)

	-- 4. Auto-Reapply Respawn
	local RespawnCard = Instance.new("Frame")
	RespawnCard.Parent = OutilsTab
	RespawnCard.Size = UDim2.new(1, 0, 0, 68)
	RespawnCard.BackgroundColor3 = C_PANEL
	RespawnCard.BackgroundTransparency = 0.3
	addCorner(RespawnCard, 6)

	local RespawnTitle = Instance.new("TextLabel")
	RespawnTitle.Parent = RespawnCard
	RespawnTitle.Position = UDim2.new(0, 10, 0, 8)
	RespawnTitle.Size = UDim2.new(1, -70, 0, 16)
	RespawnTitle.BackgroundTransparency = 1
	RespawnTitle.Text = "⚡ Auto-Reapply au Respawn"
	RespawnTitle.Font = Enum.Font.GothamMedium
	RespawnTitle.TextSize = 11
	RespawnTitle.TextColor3 = CurrentTheme.Accent
	RespawnTitle.TextXAlignment = Enum.TextXAlignment.Left

	local RespawnSub = Instance.new("TextLabel")
	RespawnSub.Parent = RespawnCard
	RespawnSub.Position = UDim2.new(0, 10, 0, 26)
	RespawnSub.Size = UDim2.new(1, -70, 0, 30)
	RespawnSub.BackgroundTransparency = 1
	RespawnSub.Text = "Réapplique automatiquement votre skin actif après chaque mort/reset."
	RespawnSub.Font = Enum.Font.Gotham
	RespawnSub.TextSize = 9
	RespawnSub.TextColor3 = C_MUTED
	RespawnSub.TextWrapped = true
	RespawnSub.TextXAlignment = Enum.TextXAlignment.Left

	local RespawnToggle = createButton(RespawnCard, AutoReapplyOnRespawn and "ON" or "OFF", AutoReapplyOnRespawn and CurrentTheme.Accent or C_CARD, AutoReapplyOnRespawn and CurrentTheme.TextDark or C_MUTED, UDim2.new(0, 48, 0, 26), UDim2.new(1, -58, 0.5, -13))
	RespawnToggle.Font = Enum.Font.GothamBold
	RespawnToggle.TextSize = 10
	RespawnToggle.MouseButton1Click:Connect(function()
		AutoReapplyOnRespawn = not AutoReapplyOnRespawn
		RespawnToggle.BackgroundColor3 = AutoReapplyOnRespawn and CurrentTheme.Accent or C_CARD
		RespawnToggle.TextColor3 = AutoReapplyOnRespawn and CurrentTheme.TextDark or C_MUTED
		RespawnToggle.Text = AutoReapplyOnRespawn and "ON" or "OFF"
		persistSettings()
	end)

	-- 5. Restaurer mon skin d'origine
	local RestoreOriginalBtn = createButton(OutilsTab, "↺ Restaurer mon skin d'origine", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, 0, 0, 34))
	RestoreOriginalBtn.MouseButton1Click:Connect(function()
		if OriginalPlayerDescription then
			CurrentHumDes = OriginalPlayerDescription
			SelectedTargetName = "Mon Skin Initial"
			_G.SalamangueClonerApply()
			refreshAll3DPreviews()
			setStatus("Skin d'origine restauré !", true)
		end
	end)

	-- 6. Randomizer Mashup
	local RandomizerCard = Instance.new("Frame")
	RandomizerCard.Parent = OutilsTab
	RandomizerCard.Size = UDim2.new(1, 0, 0, 78)
	RandomizerCard.BackgroundColor3 = C_PANEL
	RandomizerCard.BackgroundTransparency = 0.3
	addCorner(RandomizerCard, 6)

	local RandBtn = createButton(RandomizerCard, "🎲 Générer un Skin Hybride Aléatoire", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 24))
	RandBtn.MouseButton1Click:Connect(function()
		local plrs = Players:GetPlayers()
		if #plrs <= 1 then setStatus("Pas assez de joueurs", false) return end
		setStatus("Génération...", true)
		task.spawn(function()
			local hybrid = Instance.new("HumanoidDescription")
			for _, p in ipairs(plrs) do
				local des = getAuthenticDescription(p, p.UserId)
				if des then
					if math.random(1, 2) == 1 and des.Shirt and des.Shirt ~= 0 then hybrid.Shirt = des.Shirt end
					if math.random(1, 2) == 1 and des.Pants and des.Pants ~= 0 then hybrid.Pants = des.Pants end
					if math.random(1, 2) == 1 and des.Face and des.Face ~= 0 then hybrid.Face = des.Face end
					if math.random(1, 2) == 1 and des.Head and des.Head ~= 0 then hybrid.Head = des.Head end
				end
			end
			CurrentHumDes = hybrid
			SelectedTargetName = "Mélange Hybride"
			_G.SalamangueClonerApply()
			refreshAll3DPreviews()
			setStatus("Skin hybride généré !", true)
		end)
	end)

	-- 7. Stalker
	local StalkerCard = Instance.new("Frame")
	StalkerCard.Parent = OutilsTab
	StalkerCard.Size = UDim2.new(1, 0, 0, 78)
	StalkerCard.BackgroundColor3 = C_PANEL
	StalkerCard.BackgroundTransparency = 0.3
	addCorner(StalkerCard, 6)

	local StalkerToggleBtn = createButton(StalkerCard, "📡 Activer le Suivi Temps Réel", C_CARD, CurrentTheme.Accent, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 24))
	local isStalkerActive = false
	local stalkerThread = nil

	StalkerToggleBtn.MouseButton1Click:Connect(function()
		isStalkerActive = not isStalkerActive
		if isStalkerActive then
			if not SelectedTargetPlayer then
				isStalkerActive = false
				setStatus("Sélectionnez d'abord un joueur", false)
				return
			end
			StalkerToggleBtn.BackgroundColor3 = CurrentTheme.Accent
			StalkerToggleBtn.TextColor3 = CurrentTheme.TextDark
			StalkerToggleBtn.Text = "Désactiver le Suivi"
			setStatus("Suivi activé sur @" .. SelectedTargetPlayer.Name, true)
			stalkerThread = task.spawn(function()
				while isStalkerActive and SelectedTargetPlayer and SelectedTargetPlayer.Parent do
					task.wait(4)
					if isStalkerActive and SelectedTargetPlayer then
						local newDes = getAuthenticDescription(SelectedTargetPlayer, SelectedTargetPlayer.UserId)
						if newDes then
							CurrentHumDes = newDes
							_G.SalamangueClonerApply()
						end
					end
				end
			end)
		else
			StalkerToggleBtn.BackgroundColor3 = C_CARD
			StalkerToggleBtn.TextColor3 = CurrentTheme.Accent
			StalkerToggleBtn.Text = "📡 Activer le Suivi Temps Réel"
			if stalkerThread then pcall(function() task.cancel(stalkerThread) end) end
			setStatus("Suivi désactivé", false)
		end
	end)

	-- 8. Server Sniper (Rejoindre un Joueur)
	local SniperCard = Instance.new("Frame")
	SniperCard.Parent = OutilsTab
	SniperCard.Size = UDim2.new(1, 0, 0, 124)
	SniperCard.BackgroundColor3 = C_PANEL
	SniperCard.BackgroundTransparency = 0.3
	addCorner(SniperCard, 6)
	addStroke(SniperCard, C_BORDER, 1, 0.6)

	local SniperTitle = Instance.new("TextLabel")
	SniperTitle.Parent = SniperCard
	SniperTitle.Position = UDim2.new(0, 10, 0, 6)
	SniperTitle.Size = UDim2.new(1, -20, 0, 16)
	SniperTitle.BackgroundTransparency = 1
	SniperTitle.Text = "🎯 Rejoindre un Joueur (Server Sniper)"
	SniperTitle.Font = Enum.Font.GothamMedium
	SniperTitle.TextSize = 11
	SniperTitle.TextColor3 = CurrentTheme.Accent
	SniperTitle.TextXAlignment = Enum.TextXAlignment.Left

	local SniperInput = Instance.new("TextBox")
	SniperInput.Parent = SniperCard
	SniperInput.Position = UDim2.new(0, 10, 0, 26)
	SniperInput.Size = UDim2.new(1, -20, 0, 28)
	SniperInput.BackgroundColor3 = C_CARD
	SniperInput.BackgroundTransparency = 0.4
	SniperInput.PlaceholderText = "Entrez un Pseudo ou UserID à rejoindre..."
	SniperInput.PlaceholderColor3 = C_DIM
	SniperInput.Text = ""
	SniperInput.TextColor3 = CurrentTheme.Accent
	SniperInput.Font = Enum.Font.Gotham
	SniperInput.TextSize = 11
	SniperInput.TextXAlignment = Enum.TextXAlignment.Left
	addCorner(SniperInput, 4)

	local SniperActionBtn = createButton(SniperCard, "🚀 Trouver & Rejoindre son Serveur", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 58))
	SniperActionBtn.TextSize = 10

	local SniperStatusLbl = Instance.new("TextLabel")
	SniperStatusLbl.Parent = SniperCard
	SniperStatusLbl.Position = UDim2.new(0, 10, 0, 90)
	SniperStatusLbl.Size = UDim2.new(1, -20, 0, 28)
	SniperStatusLbl.BackgroundTransparency = 1
	SniperStatusLbl.Text = "Entrez un pseudo pour détecter son jeu et serveur"
	SniperStatusLbl.Font = Enum.Font.Gotham
	SniperStatusLbl.TextSize = 10
	SniperStatusLbl.TextColor3 = C_MUTED
	SniperStatusLbl.TextWrapped = true
	SniperStatusLbl.TextXAlignment = Enum.TextXAlignment.Center

	SniperActionBtn.MouseButton1Click:Connect(function()
		sniperJoinPlayer(SniperInput.Text, function(msg, isHighlight)
			SniperStatusLbl.Text = msg
			SniperStatusLbl.TextColor3 = isHighlight and CurrentTheme.Accent or Color3.fromRGB(255, 80, 80)
			setStatus(msg, isHighlight)
		end)
	end)

	-- 9. Thèmes
	local ThemeCard = Instance.new("Frame")
	ThemeCard.Parent = OutilsTab
	ThemeCard.Size = UDim2.new(1, 0, 0, 78)
	ThemeCard.BackgroundColor3 = C_PANEL
	ThemeCard.BackgroundTransparency = 0.3
	addCorner(ThemeCard, 6)

	local ThemeRow = Instance.new("Frame")
	ThemeRow.Parent = ThemeCard
	ThemeRow.Position = UDim2.new(0, 10, 0, 32)
	ThemeRow.Size = UDim2.new(1, -20, 0, 34)
	ThemeRow.BackgroundTransparency = 1

	local tNames = { "Blanc Minimal", "Cyan Neon", "Violet Cyber", "Rouge Crimson", "Vert Émeraude" }
	for idx, thName in ipairs(tNames) do
		local th = Themes[thName]
		local tBtn = Instance.new("TextButton")
		tBtn.Parent = ThemeRow
		local w = 1 / #tNames
		tBtn.Size = UDim2.new(w, -4, 1, 0)
		tBtn.Position = UDim2.new(w * (idx - 1), 2, 0, 0)
		tBtn.BackgroundColor3 = th.Accent
		tBtn.BorderSizePixel = 0
		tBtn.Text = ""
		addCorner(tBtn, 4)
		addStroke(tBtn, (CurrentThemeName == thName) and Color3.fromRGB(255, 255, 255) or C_BORDER, 1.5)
		tBtn.MouseButton1Click:Connect(function()
			CurrentThemeName = thName
			CurrentTheme = th
			persistSettings()
			setStatus("Thème " .. thName .. " activé ! Réouverture recommandée.", true)
		end)
	end
end

-- ============================================================================
--  12. BOTTOM BAR & CONTRÔLE PRINCIPAL
-- ============================================================================
local BottomBar = Instance.new("Frame")
BottomBar.Parent = MainFrame
BottomBar.Position = UDim2.new(0, 12, 1, -44)
BottomBar.Size = UDim2.new(1, -24, 0, 34)
BottomBar.BackgroundColor3 = C_PANEL
BottomBar.BackgroundTransparency = 0.2
addCorner(BottomBar, 8)
addStroke(BottomBar, C_BORDER, 1, 0.6)

local MainCopyBtn = createButton(BottomBar, "COPIER LE SKIN", CurrentTheme.Accent, CurrentTheme.TextDark, UDim2.new(0.72, -4, 1, -6), UDim2.new(0, 3, 0, 3))
MainCopyBtn.Font = Enum.Font.GothamBold
MainCopyBtn.TextSize = 12

local MainUnloadBtn = createButton(BottomBar, "Fermer", C_CARD, C_MUTED, UDim2.new(0.28, -4, 1, -6), UDim2.new(0.72, 4, 0, 3))

local function ApplyCurrentSelectedSkin()
	if not CurrentHumDes then setStatus("Sélectionnez d'abord un joueur", false) return false end
	local ready, waitS = canApplyOutfit()
	if not ready then setStatus("Attendez " .. tostring(waitS) .. "s", false) return false end
	local targetName = SelectedTargetName or "Cible"
	setStatus("Copie de " .. targetName .. "...", true)
	task.spawn(function()
		local ok = DispatchDescriptionToServer(CurrentHumDes, CopyOptions, ScaleOptions)
		if ok then
			setStatus(targetName .. " copié avec succès", true)
			if isOptionActive(CopyOptions.animations) then forceAnimationOverride(CurrentHumDes, nil) end
		else
			setStatus("Erreur lors de la copie", false)
		end
	end)
	return true
end
_G.SalamangueClonerApply = ApplyCurrentSelectedSkin

MainCopyBtn.MouseButton1Click:Connect(ApplyCurrentSelectedSkin)
MainUnloadBtn.MouseButton1Click:Connect(UnloadScript)

-- ============================================================================
--  13. INITIALISATION & LISTENERS
-- ============================================================================
buildJoueursTab()
buildHorsLigneTab()
buildApercuTab()
buildPiecesTab()
buildTailleTab()
buildFavorisTab()
buildOutilsTab()

local function toggleUI()
	MainFrame.Visible = not MainFrame.Visible
	if MainFrame.Visible then
		if refreshPlayerList then pcall(function() refreshPlayerList() end) end
		if CurrentHumDes and refreshAll3DPreviews then pcall(function() refreshAll3DPreviews(CurrentHumDes, SelectedTargetName) end) end
	end
end

FloatBtn.MouseButton1Click:Connect(toggleUI)

table.insert(eventConnections, LocalPlayer.CharacterAdded:Connect(function()
	if AutoReapplyOnRespawn and CurrentHumDes then
		task.delay(1.5, function()
			if CurrentHumDes then
				_G.SalamangueClonerApply()
				setStatus("Skin réappliqué après respawn !", true)
			end
		end)
	end
end))

table.insert(eventConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed then
		if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.F4 or input.KeyCode == Enum.KeyCode.Insert then
			toggleUI()
		end
	end
end))

table.insert(eventConnections, Players.PlayerAdded:Connect(function()
	if MainFrame.Visible and CurrentTab == "Joueurs" and refreshPlayerList then refreshPlayerList() end
end))

table.insert(eventConnections, Players.PlayerRemoving:Connect(function()
	if MainFrame.Visible and CurrentTab == "Joueurs" and refreshPlayerList then refreshPlayerList() end
end))

switchTab("Joueurs")
if refreshPlayerList then refreshPlayerList() end
MainFrame.Visible = true

print("[Salamangue Cloner Ultimate] Initialisé avec succès.")
