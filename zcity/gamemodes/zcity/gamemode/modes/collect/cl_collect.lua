local MODE = MODE

function MODE:RoundStart()
	chat.AddText(Color(100, 200, 255), "Collect mode: Find all Tubby Custards. Avoid the enemy.")
end

function MODE:EndRound()
	chat.AddText(Color(255, 200, 50), "Round over.")
end

hook.Add("HUDPaint", "Tubby_CollectHUD", function()
	if not zb or not zb.CROUND or zb.CROUND ~= "collect" then return end
	if zb.ROUND_STATE ~= 1 then return end

	local mode = zb.modes and zb.modes["collect"]
	if not mode then return end

	draw.SimpleText("COLLECT", "ZB_InterfaceMedium", ScrW() * 0.5, 40, Color(255, 200, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("Find the Tubby Custards. Stay quiet.", "ZB_InterfaceSmall", ScrW() * 0.5, 65, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
