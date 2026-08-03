-- Tubbycity: disable ZCity appearance customization.
-- Players will use Slendytubbies character models (added by the content creator).

if SERVER then
	-- Stub global ApplyAppearance so spawn / modes do not apply human faces/clothes
	function ApplyAppearance(ply, ...)
		-- intentionally empty — modes set models themselves
	end

	if hg and hg.Appearance then
		hg.Appearance.ForceApplyAppearance = function()
			return
		end
	end
end

if CLIENT then
	-- Hide / block appearance menu button if the experience/account UI opens it
	hook.Add("InitPostEntity", "Tubby_DisableAppearanceMenu", function()
		timer.Simple(1, function()
			-- Prevent opening appearance panels by name patterns
			hook.Add("VGUIMousePressed", "Tubby_BlockAppearance", function(pnl, code)
				if not IsValid(pnl) then return end
				local text = ""
				if pnl.GetText then text = tostring(pnl:GetText() or "") end
				local class = pnl:GetClassName() or ""
				local lower = string.lower(text .. " " .. class)
				if string.find(lower, "appear", 1, true)
					or string.find(lower, "character", 1, true)
					or string.find(lower, "identity", 1, true)
					or string.find(lower, "face", 1, true) then
					-- soft block: do not hard-return true (can break other UI), just notify
					chat.AddText(Color(255, 180, 80), "[Tubbycity] Appearance is disabled. Slendytubbies models are used.")
				end
			end)
		end)
	end)
end
