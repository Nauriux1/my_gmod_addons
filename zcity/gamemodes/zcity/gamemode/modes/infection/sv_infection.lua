local MODE = MODE

MODE.name = "infection"
MODE.Chance = 0.2
MODE.ROUND_TIME = 480
MODE.start_time = 8

function MODE:CanLaunch()
	return #player.GetAll() >= 2
end

function MODE:Intermission()
	game.CleanUpMap()

	local candidates = {}
	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then table.insert(candidates, ply) end
	end

	self.PatientZero = table.Random(candidates)

	for _, ply in ipairs(candidates) do
		if ply == self.PatientZero then
			ply:SetupTeam(2) -- Infected
		else
			ply:SetupTeam(0)
		end
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
end

function MODE:GetTeamSpawn()
	local survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_SurvivorSpawn"))
	local infected = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_EnemySpawn"))
	if not survivors or not next(survivors) then
		survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Spawnpoint"))
	end
	if not infected or not next(infected) then infected = survivors end
	return survivors, infected
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not ply:Alive() or ply:Team() == TEAM_SPECTATOR then continue end

			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			if ply:Team() == 2 then
				pcall(function() ply:SetModel(MODE.InfectedModel or "models/player/zombie_classic.mdl") end)
				zb.GiveRole(ply, "Infected", Color(80, 200, 80))
				ply:SetWalkSpeed(300)
				ply:SetRunSpeed(400)
				ply:SetHealth(250)
				ply:SetMaxHealth(250)
			else
				pcall(function() ply:SetModel(MODE.SurvivorModel or "models/player/group01/male_02.mdl") end)
				zb.GiveRole(ply, "Survivor", Color(100, 200, 255))
				pcall(function() ply:AllowFlashlight(true) end)
			end
		end
	end)
end

function MODE:InfectPlayer(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if ply:Team() == 2 then return end

	ply:SetTeam(2)
	pcall(function() ply:SetModel(MODE.InfectedModel or "models/player/zombie_classic.mdl") end)
	zb.GiveRole(ply, "Infected", Color(80, 200, 80))
	ply:SetWalkSpeed(300)
	ply:SetRunSpeed(400)
	ply:SetHealth(200)
	ply:SetMaxHealth(200)
	PrintMessage(HUD_PRINTTALK, ply:Nick() .. " has been infected!")
end

function MODE:PlayerDeath(ply, inflictor, attacker)
	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	if attacker:Team() == 2 and ply:Team() == 0 then
		-- Respawn as infected after short delay
		timer.Simple(3, function()
			if not IsValid(ply) then return end
			if zb.ROUND_STATE ~= 1 then return end
			ply:Spawn()
			self:InfectPlayer(ply)
		end)
	end
end

function MODE:ShouldRoundEnd()
	local teams = zb:CheckAliveTeams(true)
	local survivors = teams[0] or {}
	local infected = teams[2] or {}

	if #survivors == 0 then return true, 2 end
	if #infected == 0 then return true, 0 end
	return false
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:RoundThink()
end

function MODE:EndRound()
end

function MODE:CanSpawn()
end
