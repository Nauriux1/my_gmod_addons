-- Tubbycity appearance:
-- Players stay as Teletubby / Slendytubbies-style characters.
-- Appearance menu is enabled for bodygroup (and skin) customization.
-- Add your playermodel paths to zb.Tubby.Models below.

zb = zb or {}
zb.Tubby = zb.Tubby or {}

-- Allowed Teletubby player models (add yours here as you pack them)
zb.Tubby.Models = zb.Tubby.Models or {
	-- Examples — replace with your real model paths:
	-- "models/slendytubbies/tinky.mdl",
	-- "models/slendytubbies/dipsy.mdl",
}

-- Fallback until custom models are added
zb.Tubby.DefaultModel = zb.Tubby.DefaultModel or "models/player/group01/male_02.mdl"

function zb.Tubby.IsAllowedModel(mdl)
	if not mdl or mdl == "" then return false end
	mdl = string.lower(mdl)
	for _, allowed in ipairs(zb.Tubby.Models) do
		if string.lower(allowed) == mdl then return true end
	end
	-- If the list is empty, accept any model that looks like a tubby path
	if #zb.Tubby.Models == 0 then
		if string.find(mdl, "tubby", 1, true)
			or string.find(mdl, "teletub", 1, true)
			or string.find(mdl, "slendytub", 1, true)
			or string.find(mdl, "dipsy", 1, true)
			or string.find(mdl, "tinky", 1, true)
			or string.find(mdl, "po", 1, true)
			or string.find(mdl, "lala", 1, true)
			or string.find(mdl, "custard", 1, true) then
			return true
		end
	end
	return false
end

function zb.Tubby.GetPlayerModel(ply)
	if not IsValid(ply) then return zb.Tubby.DefaultModel end

	-- Prefer appearance / saved choice
	local mdl = ply.TubbyModel
	if (not mdl or mdl == "") and ply.CurAppearance and ply.CurAppearance.Model then
		mdl = ply.CurAppearance.Model
	end
	if (not mdl or mdl == "") and ply.GetInfo then
		mdl = ply:GetInfo("cl_playermodel") -- rarely useful, but harmless
	end

	if zb.Tubby.IsAllowedModel(mdl) then
		return mdl
	end

	if #zb.Tubby.Models > 0 then
		return zb.Tubby.Models[1]
	end

	return zb.Tubby.DefaultModel
end

function zb.Tubby.ApplyBodygroups(ply, data)
	if not IsValid(ply) then return end
	data = data or ply.CurAppearance or {}

	-- Support several common storage shapes
	local groups = data.Bodygroups or data.bodygroups or data.BGs or ply.TubbyBodygroups
	if istable(groups) then
		for id, val in pairs(groups) do
			local gid = tonumber(id)
			local gval = tonumber(val)
			if gid and gval then
				pcall(function() ply:SetBodygroup(gid, gval) end)
			end
		end
	end

	-- Compact string form "0102..." like many GMod menus use
	if isstring(data.BodygroupString) then
		pcall(function() ply:SetBodyGroups(data.BodygroupString) end)
	end

	local skin = data.Skin or data.skin
	if skin ~= nil then
		pcall(function() ply:SetSkin(tonumber(skin) or 0) end)
	end
end

function zb.Tubby.Apply(ply)
	if not IsValid(ply) then return end

	local mdl = zb.Tubby.GetPlayerModel(ply)
	pcall(function() ply:SetModel(mdl) end)

	-- Clear submaterials that human faces/clothes may have set
	pcall(function() ply:SetSubMaterial() end)

	zb.Tubby.ApplyBodygroups(ply, ply.CurAppearance)

	-- Keep a stable player color if present
	if ply.GetPlayerColor then
		local col = ply:GetPlayerColor()
		if col then ply:SetPlayerColor(col) end
	end
end

if SERVER then
	-- Re-enable ApplyAppearance: teletubby model + bodygroups from appearance data
	function ApplyAppearance(ply, ...)
		if not IsValid(ply) then return end
		zb.Tubby.Apply(ply)
	end

	-- Optional: still allow Homigrad appearance pipeline to run, then clamp model
	hook.Add("PlayerSpawn", "Tubby_ApplyAppearance", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) or not ply:Alive() then return end
			zb.Tubby.Apply(ply)
		end)
	end)

	-- Persist bodygroup choices from client appearance UI if it sends a table
	util.AddNetworkString("Tubby_SaveAppearance")
	net.Receive("Tubby_SaveAppearance", function(len, ply)
		if not IsValid(ply) then return end
		local mdl = net.ReadString()
		local bgCount = net.ReadUInt(8)
		local groups = {}
		for i = 1, bgCount do
			local id = net.ReadUInt(8)
			local val = net.ReadUInt(8)
			groups[id] = val
		end
		local skin = net.ReadUInt(8)

		if zb.Tubby.IsAllowedModel(mdl) or #zb.Tubby.Models == 0 then
			ply.TubbyModel = mdl
		end
		ply.TubbyBodygroups = groups
		ply.CurAppearance = ply.CurAppearance or {}
		ply.CurAppearance.Model = ply.TubbyModel or mdl
		ply.CurAppearance.Bodygroups = groups
		ply.CurAppearance.Skin = skin

		if ply:Alive() then
			zb.Tubby.Apply(ply)
		end
	end)
end

if CLIENT then
	-- Appearance menu is allowed again (bodygroups / skin for tubby models).
	-- Helper clientside API for custom UI or existing appearance panels.
	function zb.Tubby.SendAppearance(mdl, bodygroups, skin)
		net.Start("Tubby_SaveAppearance")
			net.WriteString(mdl or "")
			local keys = {}
			if istable(bodygroups) then
				for id, val in pairs(bodygroups) do
					keys[#keys + 1] = {tonumber(id) or 0, tonumber(val) or 0}
				end
			end
			net.WriteUInt(#keys, 8)
			for _, kv in ipairs(keys) do
				net.WriteUInt(kv[1], 8)
				net.WriteUInt(kv[2], 8)
			end
			net.WriteUInt(tonumber(skin) or 0, 8)
		net.SendToServer()
	end
end
