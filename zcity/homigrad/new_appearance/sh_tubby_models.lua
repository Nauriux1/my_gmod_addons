-- Tubbycity: register Teletubby / Slendytubbies playermodels into the Appearance system.
-- Add your model paths to zb.Tubby.Models (or below). Bodygroups use native model bodygroups via the editor.

hg = hg or {}
hg.Appearance = hg.Appearance or {}
hg.Appearance.PlayerModels = hg.Appearance.PlayerModels or { [1] = {}, [2] = {} }
hg.Appearance.FuckYouModels = hg.Appearance.FuckYouModels or { {}, {} }

zb = zb or {}
zb.Tubby = zb.Tubby or {}

-- Fill this list with your packed teletubby player models
zb.Tubby.Models = zb.Tubby.Models or {
	-- "models/slendytubbies/tinky.mdl",
	-- "models/slendytubbies/dipsy.mdl",
	-- "models/slendytubbies/lala.mdl",
	-- "models/slendytubbies/po.mdl",
}

local function RegisterTubbyModel(displayName, mdlPath)
	if not mdlPath or mdlPath == "" then return end
	for sex = 1, 2 do
		hg.Appearance.PlayerModels[sex][displayName] = {
			mdl = mdlPath,
			submatSlots = {},
			sex = (sex == 2),
			tubby = true,
		}
		hg.Appearance.FuckYouModels[sex][mdlPath] = hg.Appearance.PlayerModels[sex][displayName]
	end
end

local function RegisterAll()
	for i, mdl in ipairs(zb.Tubby.Models) do
		local name = "Tubby " .. tostring(i)
		local base = string.GetFileFromFilename and string.GetFileFromFilename(mdl) or mdl
		base = string.StripExtension and string.StripExtension(base) or base
		if base and base ~= "" then
			name = "Tubby " .. string.NiceName(base)
		end
		RegisterTubbyModel(name, mdl)
	end
end

hook.Add("HomigradRun", "Tubby_RegisterAppearanceModels", function()
	RegisterAll()
end)

if hg.loaded then
	RegisterAll()
end

hook.Add("ZB_AppearancePostApply", "Tubby_ApplyBodygroups", function(ply, tbl)
	if not IsValid(ply) or not tbl then return end
	local mdl = ply:GetModel() or ""
	local isTubby = false
	for sex = 1, 2 do
		local data = hg.Appearance.FuckYouModels[sex] and hg.Appearance.FuckYouModels[sex][mdl]
		if data and data.tubby then isTubby = true break end
	end
	if not isTubby then
		local lower = string.lower(mdl)
		if string.find(lower, "tubby", 1, true)
			or string.find(lower, "teletub", 1, true)
			or string.find(lower, "slendytub", 1, true) then
			isTubby = true
		end
	end
	if not isTubby then return end

	if istable(tbl.ABodygroups) then
		for id, val in pairs(tbl.ABodygroups) do
			pcall(function() ply:SetBodygroup(tonumber(id) or 0, tonumber(val) or 0) end)
		end
	end
	if isstring(tbl.ABodygroupString) then
		pcall(function() ply:SetBodyGroups(tbl.ABodygroupString) end)
	end
	if tbl.ASkin ~= nil then
		pcall(function() ply:SetSkin(tonumber(tbl.ASkin) or 0) end)
	end
end
