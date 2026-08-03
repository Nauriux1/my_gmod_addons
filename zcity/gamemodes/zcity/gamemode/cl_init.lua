zb = zb or {}
hg = hg or {}
include("shared.lua")
include("loader.lua")

-- NOTE: Full original cl_init was accidentally truncated in a prior commit.
-- This bootstrap keeps the gamemode loading; restore scoreboard/spectate from git history if needed:
-- git show 1436dc652e92246a99fa0e7bb3dfefef31c5d12f:zcity/gamemodes/zcity/gamemode/cl_init.lua

if not ConVarExists("hg_newspectate") then
    CreateClientConVar("hg_newspectate", "1", true, false, "Enables smooth spectator camera transitions", 0, 1)
end

function CurrentRound()
	return zb.modes and zb.modes[zb.CROUND]
end

zb.ROUND_STATE = 0
spect, prevspect, viewmode = nil, nil, 1

net.Receive("ZB_SpectatePlayer", function(len)
	spect = net.ReadEntity()
	prevspect = net.ReadEntity()
	viewmode = net.ReadInt(4)
end)

zb.ROUND_TIME = zb.ROUND_TIME or 400
zb.ROUND_START = zb.ROUND_START or CurTime()
zb.ROUND_BEGIN = zb.ROUND_BEGIN or CurTime() + 5

net.Receive("updtime", function()
	zb.ROUND_TIME = net.ReadFloat()
	zb.ROUND_START = net.ReadFloat()
	zb.ROUND_BEGIN = net.ReadFloat()
end)

local blur = Material("pp/blurscreen")
function hg.DrawBlur(panel, amount, passes, alpha)
	if is3d2d then return end
	amount = amount or 5
	local pot = hg.ConVars and hg.ConVars.potatopc
	if pot and pot.GetBool and pot:GetBool() then
		surface.SetDrawColor(0, 0, 0, alpha or (amount * 20))
		surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
	else
		surface.SetMaterial(blur)
		surface.SetDrawColor(0, 0, 0, alpha or 125)
		surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
		local x, y = panel:LocalToScreen(0, 0)
		for i = -(passes or 0.2), 1, 0.2 do
			blur:SetFloat("$blur", i * amount)
			blur:Recompute()
			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
		end
	end
end

BlurBackground = BlurBackground or hg.DrawBlur

zb.fade = zb.fade or 0
hook.Add("RenderScreenspaceEffects", "Tubby_Fade", function()
	if zb.fade > 0 then
		zb.fade = math.Approach(zb.fade, 0, FrameTime())
		surface.SetDrawColor(0, 0, 0, 255 * math.min(zb.fade, 1))
		surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
	end
end)

net.Receive("RoundInfo", function()
	local rnd = net.ReadString()
	hook.Run("RoundInfoCalled", rnd)
	if zb.CROUND ~= rnd and hg.DynaMusic then
		hg.DynaMusic:Stop()
	end
	zb.CROUND = rnd
	zb.ROUND_STATE = net.ReadInt(4)
	if zb.ROUND_STATE == 0 then zb.fade = 7 end
	local mode = CurrentRound()
	if mode then
		if zb.ROUND_STATE == 3 and mode.EndRound then mode:EndRound()
		elseif zb.ROUND_STATE == 1 and mode.RoundStart then mode:RoundStart() end
	end
end)

-- Minimal fonts used by ST modes
local function font()
	return "Bahnschrift"
end
surface.CreateFont("ZB_InterfaceSmall", {font = font(), size = ScreenScale(6), weight = 400, antialias = true})
surface.CreateFont("ZB_InterfaceMedium", {font = font(), size = ScreenScale(10), weight = 400, antialias = true})
surface.CreateFont("ZB_InterfaceMediumLarge", {font = font(), size = 35, weight = 400, antialias = true})
surface.CreateFont("ZB_InterfaceLarge", {font = font(), size = ScreenScale(20), weight = 400, antialias = true})
surface.CreateFont("ZB_ScrappersMedium", {font = font(), size = ScreenScale(10), weight = 400, antialias = true})

function GM:AddHint(name, delay)
	return false
end

function GM:ScoreboardShow()
	return false
end

function GM:ScoreboardHide()
end
