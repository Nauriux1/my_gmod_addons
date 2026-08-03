local MODE = MODE

function MODE:RoundStart()
	chat.AddText(Color(180, 80, 255), "Survival: Survive 10 waves of enemies.")
end

hook.Add("HUDPaint", "Tubby_SurvivalHUD", function()
	if not zb or zb.CROUND ~= "survival" or zb.ROUND_STATE ~= 1 then return end
	local mode = zb.modes and zb.modes["survival"]
	local wave = mode and mode.CurrentWave or 0
	draw.SimpleText("SURVIVAL — Wave " .. tostring(wave), "ZB_InterfaceMedium", ScrW() * 0.5, 40, Color(180, 80, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
