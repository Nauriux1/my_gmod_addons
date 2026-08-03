local MODE = MODE

function MODE:RoundStart()
	chat.AddText(Color(200, 50, 50), "Versus: One player is the enemy. Collect custards or stop the survivors.")
end

hook.Add("HUDPaint", "Tubby_VersusHUD", function()
	if not zb or zb.CROUND ~= "versus" or zb.ROUND_STATE ~= 1 then return end
	draw.SimpleText("VERSUS", "ZB_InterfaceMedium", ScrW() * 0.5, 40, Color(200, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
