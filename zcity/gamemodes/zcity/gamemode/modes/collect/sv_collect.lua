local MODE = MODE

MODE.name = "collect"
MODE.Chance = 0.35
MODE.ROUND_TIME = 600
MODE.start_time = 5
MODE.CustardCount = 10

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		ply:SetupTeam(0) -- all survivors
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		ply:Freeze(false)
	end

	self:SpawnCustards()
	self:SpawnEnemyNPC()
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
			if not ply:Alive() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end

			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			-- Placeholder model until Slendytubbies player models are added
			pcall(function()
				ply:SetModel(MODE.SurvivorModel or "models/player/group01/male_02.mdl")
			end)

			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")
			-- Flashlight-style light source feel (use default flashlight)
			pcall(function() ply:AllowFlashlight(true) end)

			zb.GiveRole(ply, "Survivor", Color(100, 200, 255))

			timer.Simple(0.1, function()
				if IsValid(ply) then ply.noSound = false end
			end)
			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:SpawnCustards()
	local points = zb.GetMapPoints("Tubby_Custard") or {}
	local count = math.min(self.CustardCount or 10, math.max(#points, 1))

	self.CustardsLeft = 0
	self.ActiveCustards = {}

	if #points == 0 then
		-- Fallback: random nav / spawn positions
		for i = 1, count do
			local pos = zb:GetRandomSpawn()
			if pos then
				local ent = ents.Create("ent_tubby_custard")
				if IsValid(ent) then
					ent:SetPos(pos + Vector(0, 0, 8))
					ent:Spawn()
					self.CustardsLeft = self.CustardsLeft + 1
					table.insert(self.ActiveCustards, ent)
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
			table.insert(self.ActiveCustards, ent)
		end
	end
end

function MODE:SpawnEnemyNPC()
	local points = zb.GetMapPoints("Tubby_EnemySpawn") or {}
	local pos

	if #points > 0 then
		pos = table.Random(points).pos
	else
		pos = zb:GetRandomSpawn()
	end

	if not pos then return end

	local npc = ents.Create(self.EnemyNPCClass or "npc_fastzombie")
	if not IsValid(npc) then return end

	npc:SetPos(pos + Vector(0, 0, 10))
	npc:Spawn()
	npc:Activate()
	npc:SetHealth(500)
	npc:SetMaxHealth(500)

	-- Prefer hunting players
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
			npc:AddEntityRelationship(ply, D_HT, 99)
		end
	end

	self.EnemyNPC = npc
end

function MODE:OnCustardCollected(ply, ent)
	if not self.CustardsLeft then return end
	self.CustardsLeft = math.max(0, self.CustardsLeft - 1)

	PrintMessage(HUD_PRINTTALK, string.format("%s collected a Tubby Custard! (%d left)", ply:Nick(), self.CustardsLeft))

	if self.CustardsLeft <= 0 then
		-- Survivors win
		zb.ROUND_STATE = 2
		PrintMessage(HUD_PRINTTALK, "All custards collected! Survivors win!")
	end
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	if (self.CustardsLeft or 1) <= 0 then
		return true, 0 -- survivors win
	end

	local alive = zb:CheckAlive(true)
	if #alive == 0 then
		return true, 1 -- enemy / wipe
	end

	return false
end

function MODE:RoundThink()
	-- Keep NPC hostile if it exists
	if IsValid(self.EnemyNPC) then
		for _, ply in player.Iterator() do
			if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
				self.EnemyNPC:AddEntityRelationship(ply, D_HT, 99)
			end
		end
	end
end

function MODE:EndRound()
	local endround, winner = self:ShouldRoundEnd()
	for _, ply in player.Iterator() do
		if ply:Team() == 0 and (self.CustardsLeft or 1) <= 0 then
			pcall(function() ply:GiveExp(math.random(20, 40)) end)
		end
	end
end

function MODE:PlayerDeath(ply)
	-- Collect is fail-on-death style for the group if all die
end

function MODE:CanSpawn()
end
