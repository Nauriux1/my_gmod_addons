-- создано для совмещения фильтров игроков из разных источников

if not CLIENT then return end

local function IsZCity()
    return engine.ActiveGamemode() == "zcity"
end

ZB_ScoreboardFilter = ZB_ScoreboardFilter or {}
ZB_ScoreboardFilter.predicates = ZB_ScoreboardFilter.predicates or {}

function ZB_ScoreboardFilter.Register(id, fn)
    ZB_ScoreboardFilter.predicates[id] = fn
end

function ZB_ScoreboardFilter.Unregister(id)
    ZB_ScoreboardFilter.predicates[id] = nil
end

local function ShouldExclude(ply)
    for _, fn in pairs(ZB_ScoreboardFilter.predicates) do
        local ok, res = pcall(fn, ply)
        if ok and res then return true end
    end
    return false
end

hook.Add("InitPostEntity", "zb_scoreboard_filter_patch", function()
    if ZB_ScoreboardFilter._patched then return end
    ZB_ScoreboardFilter._patched = true

    local originalShow = GAMEMODE.ScoreboardShow
    if not originalShow then return end

    GAMEMODE.ScoreboardShow = function(self)
        if not IsZCity() then
            return originalShow(self)
        end

        local anyExcluded = false
        for _, ply in ipairs(player.GetAll()) do
            if ShouldExclude(ply) then
                anyExcluded = true
                break
            end
        end

        if not anyExcluded then
            return originalShow(self)
        end

        local realIterator = player.Iterator

        player.Iterator = function()
            local filtered = {}
            for _, ply in ipairs(player.GetAll()) do
                if not ShouldExclude(ply) then
                    filtered[#filtered + 1] = ply
                end
            end
            local i = 0
            return function()
                i = i + 1
                if filtered[i] == nil then return end
                return i, filtered[i]
            end
        end

        local ok, err = pcall(originalShow, self)

        player.Iterator = realIterator

        if not ok then
            ErrorNoHalt("[zb_scoreboard_filter] ScoreboardShow error: " .. tostring(err) .. "\n")
        end

        return true
    end
end)
-- designed and realized by alagri & omnissiah respectively
