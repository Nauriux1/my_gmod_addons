hg = hg or {}
hg.Appearance = hg.Appearance or {}
local APmodule = hg.Appearance

APmodule.PlayerModels = APmodule.PlayerModels or { [1] = {}, [2] = {} }
APmodule.FuckYouModels = APmodule.FuckYouModels or { {}, {} }
APmodule.Bodygroups = APmodule.Bodygroups or {}
APmodule.Clothes = APmodule.Clothes or { [1] = { normal = "" }, [2] = { normal = "" } }
APmodule.FacemapsSlots = APmodule.FacemapsSlots or {}
APmodule.RandomNames = APmodule.RandomNames or {
	[1] = { "Tinky", "Dipsy", "Custard" },
	[2] = { "Laa-Laa", "Po", "Noonoo" },
}

local allowed = {}
for _, c in ipairs(string.ToTable(" abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_'")) do
	allowed[c] = true
end

function APmodule.IsInvalidName(name)
	if not isstring(name) then return true end
	local trimmed = string.Trim(name)
	if trimmed == "" or #trimmed < 2 or #trimmed > 32 then return true end
	local ret = hook.Run("ZB_IsInvalidName", name)
	if ret ~= nil then return ret end
	return false
end

function APmodule.GenerateRandomName(iSex)
	local sex = iSex or math.random(1, 2)
	local list = APmodule.RandomNames[sex] or APmodule.RandomNames[1]
	return list[math.random(#list)]
end

local access = {}
local hg_appearance_access_for_all = ConVarExists("hg_appearance_access_for_all") and GetConVar("hg_appearance_access_for_all") or CreateConVar("hg_appearance_access_for_all", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Toggle free items in appearance for everyone", 0, 1)
if SERVER then
	SetGlobalBool("hg_appearance_access_for_all", hg_appearance_access_for_all:GetBool())
	cvars.AddChangeCallback("hg_appearance_access_for_all", function()
		SetGlobalBool("hg_appearance_access_for_all", hg_appearance_access_for_all:GetBool())
	end)
end

function APmodule.GetAccessToAll(ply)
	return GetGlobalBool("hg_appearance_access_for_all") or (IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())) or (IsValid(ply) and access[ply:SteamID()])
end

function APmodule.AppAddModel(strName, strMdl, bFemale, tSubmaterialSlots)
	APmodule.PlayerModels[bFemale and 2 or 1][strName] = {
		mdl = strMdl,
		submatSlots = tSubmaterialSlots or {},
		sex = bFemale and true or false,
	}
	APmodule.FuckYouModels[bFemale and 2 or 1][strMdl] = APmodule.PlayerModels[bFemale and 2 or 1][strName]
end

function APmodule.GetRandomAppearance()
	local sex = math.random(1, 2)
	local models = APmodule.PlayerModels[sex]
	local keys = {}
	for k in pairs(models) do keys[#keys + 1] = k end
	-- Prefer tubby-flagged models when present
	local tubbyKeys = {}
	for _, k in ipairs(keys) do
		if models[k].tubby then tubbyKeys[#tubbyKeys + 1] = k end
	end
	if #tubbyKeys > 0 then keys = tubbyKeys end

	local modelKey = (#keys > 0) and keys[math.random(#keys)] or "Male 01"
	return {
		AName = APmodule.GenerateRandomName(sex),
		AModel = modelKey,
		AColor = Color(math.random(50, 255), math.random(50, 255), math.random(50, 255)),
		AClothes = { main = "normal", pants = "normal", boots = "normal", hands = "normal" },
		AAttachments = {},
		ABodygroups = {},
		AFacemap = "",
		ASkin = 0,
	}
end

function APmodule.AppearanceValidater(tbl)
	if not istable(tbl) then return false end
	if not isstring(tbl.AModel) or tbl.AModel == "" then return false end
	local found = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel]
	if not found then
		-- Allow direct model paths for custom tubbies
		if isstring(tbl.AModel) and string.EndsWith(string.lower(tbl.AModel), ".mdl") then
			return true
		end
		return false
	end
	return true
end

-- Fallback human models so the system works before tubby models are packed
if not next(APmodule.PlayerModels[1]) then
	APmodule.AppAddModel("Male 01", "models/player/group01/male_02.mdl", false, {})
	APmodule.AppAddModel("Female 01", "models/player/group01/female_02.mdl", true, {})
end
