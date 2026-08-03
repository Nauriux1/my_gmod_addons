-- Tubbycity appearance bridge (gamemode side).
-- Real editor lives in zcity/homigrad/new_appearance/
-- This only ensures ApplyAppearance exists early and re-applies bodygroups for tubbies.

zb = zb or {}
zb.Tubby = zb.Tubby or {}

function zb.Tubby.Apply(ply)
	if not IsValid(ply) then return end
	if ApplyAppearance then
		ApplyAppearance(ply, nil, nil, nil, true)
	elseif hg and hg.Appearance and hg.Appearance.ForceApplyAppearance and ply.CurAppearance then
		hg.Appearance.ForceApplyAppearance(ply, ply.CurAppearance)
	end
	if ply.CurAppearance then
		hook.Run("ZB_AppearancePostApply", ply, ply.CurAppearance)
	end
end

if SERVER then
	hook.Add("HomigradRun", "Tubby_AppearanceBridge", function()
		if not ApplyAppearance and hg and hg.Appearance and hg.Appearance.ApplyAppearance then
			ApplyAppearance = hg.Appearance.ApplyAppearance
		end
	end)

	hook.Add("PlayerSpawn", "Tubby_ApplyAppearance", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) or not ply:Alive() then return end
			if zb.Tubby and zb.Tubby.Apply then zb.Tubby.Apply(ply) end
		end)
	end)
end
