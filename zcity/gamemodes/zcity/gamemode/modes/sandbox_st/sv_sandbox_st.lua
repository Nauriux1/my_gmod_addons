local MODE = MODE

MODE.name = "sandbox_st"
MODE.Chance = 0.05
MODE.ROUND_TIME = 3600
MODE.start_time = 0
MODE.OverrideSpawn = true

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()
	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			ply:SetupTeam(0)
		end
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
	PrintMessage(HUD_PRINTTALK, "Sandbox: Free play. Admins can spawn NPCs / props.")
end

function MODE:GetTeamSpawn()
	local spawns = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_SurvivorSpawn"))
	if not spawns or not next(spawns) then
		spawns = zb.TranslatePointsToVectors(zb.GetMapPoints("Spawnpoint"))
	end
	return spawns, spawns
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not ply:Alive() or ply:Team() == TEAM_SPECTATOR then continue end
			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")
			pcall(function() ply:AllowFlashlight(true) end)
			if ply:IsAdmin() then
				-- Admins keep more freedom in sandbox
			end
		end
	end)
end

function MODE:ShouldRoundEnd()
	return false -- sandbox runs until force end
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:RoundThink()
end

function MODE:EndRound()
end

function MODE:PlayerDeath(ply)
end

function MODE:CanSpawn()
	return true
end
