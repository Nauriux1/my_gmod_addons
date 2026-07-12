if not SERVER then return end

local function IsZCity()
    return engine.ActiveGamemode() == "zcity"
end

local CRUSHER_SUBROLE = "traitor_strangler"

local CHECK_RATE = 0.5

CreateConVar("zb_zh_dread_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "ZHorror: enable crusher dread (raises heartrate near a crusher)", 0, 1)
CreateConVar("zb_zh_dread_range", "900", FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "ZHorror: crusher dread range", 25, 1500)

local function DreadEnabled()
    local cv = GetConVar("zb_zh_dread_enabled")
    return not cv or cv:GetBool()
end

local function DreadRange()
    local cv = GetConVar("zb_zh_dread_range")
    return (cv and cv:GetInt()) or 900
end

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply.SubRole == CRUSHER_SUBROLE or ply.SubRole == CRUSHER_SUBROLE .. "_soe")
end

timer.Create("ZB_CrusherDread", CHECK_RATE, 0, function()
    if not IsZCity() then return end
    if not DreadEnabled() then return end

    local range = DreadRange()

    local crushers = {}
    for _, ply in player.Iterator() do
        if IsCrusher(ply) and ply:Alive() then
            crushers[#crushers + 1] = ply
        end
    end
    if #crushers == 0 then return end

    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        if IsCrusher(ply) then continue end
        local org = ply.organism
        if not org or org.otrub then continue end

        local nearest = math.huge
        local plyPos = ply:GetPos()
        for _, cr in ipairs(crushers) do
            local d = plyPos:Distance(cr:GetPos())
            if d < nearest then nearest = d end
        end

        if nearest <= range then
            local closeness = 1 - (nearest / range)
            org.fearadd = math.max(org.fearadd or 0, 1 + closeness * 2)
        end
    end
end)
