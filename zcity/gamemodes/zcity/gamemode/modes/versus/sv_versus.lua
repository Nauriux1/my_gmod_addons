local MODE = MODE

MODE.name = "versus"
MODE.Chance = 0.25
MODE.ROUND_TIME = 600
MODE.start_time = 5
MODE.CustardCount = 10

function MODE:CanLaunch()
	return #player.GetHumans() >= 2 or #player.GetAll() >= 2
end

function MODE:Intermission()
	game.CleanUpMap()

	local candidates = {}
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		table.insert(candidates, ply)
	end

	-- Pick one enemy player
	self.EnemyPlayer = table.Random(candidates)

	for _, ply in ipairs(candidates) do
		if ply == self.EnemyPlayer then
			ply:SetupTeam(1) -- Enemy
		else
			ply:SetupTeam(0) -- Survivor
		end
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
	self:SpawnCustards()
end

function MODE:GetTeamSpawn()
	local survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_SurvivorSpawn"))
	local enemy = zb.TranslatePointsToVectors(zb.GetMapPoints("Tubby_EnemySpawn"))

	if not survivors or not next(survivors) then
		survivors = zb.TranslatePointsToVectors(zb.GetMapPoints("Spawnpoint"))
	end
	if not enemy or not next(enemy) then
		enemy = survivors
	end

	return survivors, enemy
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end

			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 1 then
				pcall(function() ply:SetModel(MODE.EnemyModel or "models/player/zombie_fast.mdl") end)
				zb.GiveRole(ply, "Enemy", Color(200, 50, 50))
				-- Enemy is stronger / faster feel — basic kit
				ply:SetWalkSpeed(280)
				ply:SetRunSpeed(380)
				ply:SetHealth(300)
				ply:SetMaxHealth(300)
			else
				pcall(function() ply:SetModel(MODE.SurvivorModel or "models/player/group01/male_02.mdl") end)
				zb.GiveRole(ply, "Survivor", Color(100, 200, 255))
				pcall(function() ply:AllowFlashlight(true) end)
			end

			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1, function()
				if IsValid(ply) then ply.noSound = false end
			end)
			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:SpawnCustards()
	local points = zb.GetMapPoints("Tubby_Custard") or {}
	local count = self.CustardCount or 10
	self.CustardsLeft = 0
	self.ActiveCustards = {}

	if #points == 0 then
		for i = 1, count do
			local pos = zb:GetRandomSpawn()
			if pos then
				local ent = ents.Create("ent_tubby_custard")
				if IsValid(ent) then
					ent:SetPos(pos + Vector(0, 0, 8))
					ent:Spawn()
					self.CustardsLeft = self.CustardsLeft + 1
				end
			end
		end
		return
	end

	local shuffled = table.Copy(points)
	table.Shuffle(shuffled)
	for i = 1, math.min(count, #shuffled) do
		local p = shuffled[i]
		local ent = ents.Create("ent_tubby_custard")
		if IsValid(ent) then
			ent:SetPos(p.pos + Vector(0, 0, 8))
			ent:SetAngles(p.ang or Angle(0, 0, 0))
			ent:Spawn()
			self.CustardsLeft = self.CustardsLeft + 1
		end
	end
end

function MODE:OnCustardCollected(ply, ent)
	if ply:Team() ~= 0 then return end
	if not self.CustardsLeft then return end
	self.CustardsLeft = math.max(0, self.CustardsLeft - 1)
	PrintMessage(HUD_PRINTTALK, string.format("%s collected a Tubby Custard! (%d left)", ply:Nick(), self.CustardsLeft))
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	if (self.CustardsLeft or 1) <= 0 then
		return true, 0 -- survivors collected all
	end

	local teams = zb:CheckAliveTeams(true)
	local survivors = teams[0] or {}
	local enemy = teams[1] or {}

	if #survivors == 0 then
		return true, 1 -- enemy wiped survivors
	end
	if #enemy == 0 then
		return true, 0 -- enemy died
	end

	return false
end

function MODE:RoundThink()
end

function MODE:EndRound()
end

function MODE:PlayerDeath(ply)
end

function MODE:CanSpawn()
end
