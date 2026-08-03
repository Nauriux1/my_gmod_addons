local MODE = MODE

MODE.name = "survival"
MODE.Chance = 0.25
MODE.ROUND_TIME = 900
MODE.start_time = 10
MODE.MaxWaves = 10

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()
	self.CurrentWave = 0
	self.WaveActive = false
	self.EnemiesAlive = 0

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

	timer.Simple(5, function()
		if zb.CROUND == "survival" and zb.ROUND_STATE == 1 then
			self:StartNextWave()
		end
	end)
end

function MODE:GetTeamSpawn()
	local survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_SurvivorSpawn"))
	if not survivors or not next(survivors) then
		survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Spawnpoint"))
	end
	return survivors, survivors
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not ply:Alive() or ply:Team() == TEAM_SPECTATOR then continue end
			pcall(function() ply:SetModel(MODE.SurvivorModel or "models/player/group01/male_02.mdl") end)
			zb.GiveRole(ply, "Survivor", Color(100, 200, 255))
			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")
			pcall(function() ply:AllowFlashlight(true) end)
		end
	end)
end

function MODE:StartNextWave()
	if self.CurrentWave >= (self.MaxWaves or 10) then
		PrintMessage(HUD_PRINTTALK, "All waves survived! Victory!")
		zb.ROUND_STATE = 2
		return
	end

	self.CurrentWave = self.CurrentWave + 1
	self.WaveActive = true

	local count = 3 + self.CurrentWave * 2
	local points = zb.GetMapPoints("Tubby_WaveSpawn") or {}
	if #points == 0 then points = zb.GetMapPoints("Tubby_EnemySpawn") or {} end

	self.EnemiesAlive = 0

	for i = 1, count do
		local pos
		if #points > 0 then
			pos = table.Random(points).pos
		else
			pos = zb:GetRandomSpawn()
		end
		if not pos then continue end

		local class = self.WaveNPCClass or "npc_zombie"
		if self.CurrentWave >= 5 then class = "npc_fastzombie" end
		if self.CurrentWave >= 8 then class = "npc_poisonzombie" end

		local npc = ents.Create(class)
		if not IsValid(npc) then continue end
		npc:SetPos(pos + Vector(0, 0, 10))
		npc:Spawn()
		npc:Activate()
		npc:SetHealth(50 + self.CurrentWave * 25)
		npc:SetMaxHealth(50 + self.CurrentWave * 25)

		for _, ply in player.Iterator() do
			if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
				npc:AddEntityRelationship(ply, D_HT, 99)
			end
		end

		self.EnemiesAlive = self.EnemiesAlive + 1
		npc.TubbyWaveEnemy = true

		npc:CallOnRemove("TubbyWaveDeath", function()
			if zb.CROUND ~= "survival" then return end
			local m = zb.modes["survival"]
			if not m then return end
			m.EnemiesAlive = math.max(0, (m.EnemiesAlive or 1) - 1)
			if m.EnemiesAlive <= 0 and m.WaveActive then
				m.WaveActive = false
				PrintMessage(HUD_PRINTTALK, "Wave " .. m.CurrentWave .. " cleared!")
				timer.Simple(8, function()
					if zb.CROUND == "survival" and zb.ROUND_STATE == 1 then
						m:StartNextWave()
					end
				end)
			end
		end)
	end

	PrintMessage(HUD_PRINTTALK, "Wave " .. self.CurrentWave .. " / " .. (self.MaxWaves or 10) .. " — " .. count .. " enemies!")
end

function MODE:ShouldRoundEnd()
	local alive = zb:CheckAlive(true)
	if #alive == 0 then return true, 1 end
	if self.CurrentWave >= (self.MaxWaves or 10) and not self.WaveActive and (self.EnemiesAlive or 0) <= 0 then
		return true, 0
	end
	return false
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
end
