--
zb = zb or {}

zb.Experience = zb.Experience or {}
zb.Experience.PlayerInstances = zb.Experience.PlayerInstances or {}
zb.Experience.Active = zb.Experience.Active or false

local function HasMySQL()
	return mysql ~= nil
end

hook.Add("DatabaseConnected", "ExperienceCreateData", function()
	if not HasMySQL() then return end
	local query = mysql:Create("zb_experience")
		query:Create("steamid", "VARCHAR(20) NOT NULL")
		query:Create("steam_name", "VARCHAR(32) NOT NULL")
		query:Create("skill", "FLOAT NOT NULL")
		query:Create("experience", "INT NOT NULL")
        query:Create("deaths", "INT NOT NULL")
        query:Create("kills", "INT NOT NULL")
        query:Create("suicides", "INT NOT NULL")
		query:PrimaryKey("steamid")
	query:Execute()

    zb.Experience.Active = true
end)

hook.Add( "PlayerInitialSpawn","ZB_Exp_OnInitSpawn", function( ply )
    local name = ply:Name()
	local steamID64 = ply:SteamID64()

    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }

    if not HasMySQL() or not zb.Experience.Active then
        return
    end

	local query = mysql:Select("zb_experience")
		query:Select("skill")
		query:Select("experience")
        query:Select("deaths")
        query:Select("kills")
        query:Select("suicides")
		query:Where("steamid", steamID64)
		query:Callback(function(result)
			if (IsValid(ply) and istable(result) and #result > 0 and result[1].experience) then
				local updateQuery = mysql:Update("zb_experience")
					updateQuery:Update("steam_name", name)
					updateQuery:Where("steamid", steamID64)
				updateQuery:Execute()

				zb.Experience.PlayerInstances[steamID64] = {
                    skill = tonumber(result[1].skill) or 0,
                    experience = tonumber(result[1].experience) or 0,
                    deaths = tonumber(result[1].deaths) or 0,
                    kills = tonumber(result[1].kills) or 0,
                    suicides = tonumber(result[1].suicides) or 0,
                }
			else
				local insertQuery = mysql:Insert("zb_experience")
					insertQuery:Insert("steamid", steamID64)
					insertQuery:Insert("steam_name", name)
					insertQuery:Insert("skill", 0)
		            insertQuery:Insert("experience", 0)
                    insertQuery:Insert("deaths", 0)
		            insertQuery:Insert("kills", 0)
                    insertQuery:Insert("suicides", 0)
				insertQuery:Execute()

				zb.Experience.PlayerInstances[steamID64] = {
                    skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
                }
			end
		end)
	query:Execute()
end)

local plyMeta = FindMetaTable("Player")

function plyMeta:GetExp()
    local inst = zb.Experience.PlayerInstances[self:SteamID64()]
    if not inst then return 0 end
    return math.Round(inst.experience or 0)
end

function plyMeta:GiveExp( ammout )
    local steamID64 = self:SteamID64()

    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }

    local inst = zb.Experience.PlayerInstances[steamID64]
    inst.experience = math.max((inst.experience or 0) + (ammout or 0), 0)

	if HasMySQL() and zb.Experience.Active then
		local updateQuery = mysql:Update("zb_experience")
			updateQuery:Update("experience", self:GetExp(),0)
			updateQuery:Where("steamid", steamID64)
		updateQuery:Execute()
	end

    if self.PS_AddPoints then
        local points = math.min((ammout or 0) / 5, 10) * (1 + (self.EA_HasAccess and self:EA_HasAccess() and 2 or 0))
        local mul = math.min(player.GetCount() / 10, 1)
        self:PS_AddPoints(math.Round(points * mul,0))
    end
end

function plyMeta:GetSkill()
    local inst = zb.Experience.PlayerInstances[self:SteamID64()]
    return inst and inst.skill or 0
end

function plyMeta:GiveSkill( ammout )
    local steamID64 = self:SteamID64()
    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }
    local inst = zb.Experience.PlayerInstances[steamID64]
    inst.skill = math.max((inst.skill or 0) + (ammout or 0), 0)

	if not HasMySQL() or not zb.Experience.Active then return end

	local updateQuery = mysql:Update("zb_experience")
		updateQuery:Update("skill", self:GetSkill())
		updateQuery:Where("steamid", steamID64)
	updateQuery:Execute()
end

function plyMeta:GetDeaths()
    local inst = zb.Experience.PlayerInstances[self:SteamID64()]
    return inst and inst.deaths or 0
end

function plyMeta:GiveDeaths( ammout )
    local steamID64 = self:SteamID64()
    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }
    local inst = zb.Experience.PlayerInstances[steamID64]
    inst.deaths = math.max((inst.deaths or 0) + (ammout or 0), 0)
	if not HasMySQL() or not zb.Experience.Active then return end
	local updateQuery = mysql:Update("zb_experience")
		updateQuery:Update("deaths", self:GetDeaths())
		updateQuery:Where("steamid", steamID64)
	updateQuery:Execute()
end

function plyMeta:GetKills()
    local inst = zb.Experience.PlayerInstances[self:SteamID64()]
    return inst and inst.kills or 0
end

function plyMeta:GiveKills( ammout )
    local steamID64 = self:SteamID64()
    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }
    local inst = zb.Experience.PlayerInstances[steamID64]
    inst.kills = math.max((inst.kills or 0) + (ammout or 0), 0)
	if not HasMySQL() or not zb.Experience.Active then return end
	local updateQuery = mysql:Update("zb_experience")
		updateQuery:Update("kills", self:GetKills())
		updateQuery:Where("steamid", steamID64)
	updateQuery:Execute()
end

function plyMeta:GetSuicides()
    local inst = zb.Experience.PlayerInstances[self:SteamID64()]
    return inst and inst.suicides or 0
end

function plyMeta:GiveSuicides( ammout )
    local steamID64 = self:SteamID64()
    zb.Experience.PlayerInstances[steamID64] = zb.Experience.PlayerInstances[steamID64] or {
        skill = 0, experience = 0, deaths = 0, kills = 0, suicides = 0
    }
    local inst = zb.Experience.PlayerInstances[steamID64]
    inst.suicides = math.max((inst.suicides or 0) + (ammout or 0), 0)
	if not HasMySQL() or not zb.Experience.Active then return end
	local updateQuery = mysql:Update("zb_experience")
		updateQuery:Update("suicides", self:GetSuicides())
		updateQuery:Where("steamid", steamID64)
	updateQuery:Execute()
end

util.AddNetworkString("zb_xp_get")

net.Receive("zb_xp_get",function(len,ply)
    local get_ply = net.ReadEntity()
    if not IsValid(get_ply) then return end
    net.Start("zb_xp_get")
        net.WriteEntity( get_ply )
        net.WriteFloat( get_ply:GetSkill() )
        net.WriteInt( get_ply:GetExp(), 19 )
    net.Send(ply)
end)
