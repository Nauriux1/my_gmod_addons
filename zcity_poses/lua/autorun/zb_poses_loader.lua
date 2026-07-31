-- zb_poses loader

local root = "homigrad/poses/"

local function inc(f)
    local path = root .. f
    if SERVER then AddCSLuaFile(path) end
    include(path)
end

inc("sh_poses.lua")

if SERVER then
    inc("sv_poses.lua")
end

if CLIENT then
    include(root .. "cl_poses.lua")
end

if SERVER then
    AddCSLuaFile(root .. "cl_poses.lua")
end

print("[zb_poses] loaded (sequence + radial)")
