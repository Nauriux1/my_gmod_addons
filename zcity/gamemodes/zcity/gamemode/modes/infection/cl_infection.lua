local MODE = MODE

function MODE:RoundStart()
	chat.AddText(Color(80, 200, 80), "Infection: One starts infected. Spread or survive.")
end

hook.Add("HUDPaint", "Tubby_InfectionHUD", function()
	if not zb or zb.CROUND ~= "infection" or zb.ROUND_STATE ~= 1 then return end
	draw.SimpleText("INFECTION", "ZB_InterfaceMedium", ScrW() * 0.5, 40, Color(80, 200, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
