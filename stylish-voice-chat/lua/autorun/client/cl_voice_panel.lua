-- Stylish Voice Chat HUD (QoL version)
-- Client-side only

if SERVER then return end

local config = {
    width = 260,
    height = 60,
    padding = 10,
    spacing = 6,
    radius = 8,
    maxDistance = 2000,

    bgColor = Color(25, 25, 35, 230),
    shadowColor = Color(0, 0, 0, 120),
    accentColor = Color(100, 150, 255),
    speakColor = Color(100, 255, 150),
    mutedColor = Color(255, 100, 100),
    textColor = Color(255, 255, 255),
}

local voicePanels = {}

-- =========================
-- Voice Panel
-- =========================
local PANEL = {}

function PANEL:Init()
    self:SetSize(config.width, config.height)

    self.alpha = 0
    self.targetAlpha = 0
    self.barWidth = 0

    self.waves = {}
    self.nextWave = 0

    self.avatar = vgui.Create("AvatarImage", self)
    self.avatar:SetSize(40, 40)
    self.avatar:SetPos(config.padding, config.padding)

    self.nameLabel = vgui.Create("DLabel", self)
    self.nameLabel:SetFont("DermaDefault")
    self.nameLabel:SetTextColor(config.textColor)
    self.nameLabel:SetPos(60, 12)
end

function PANEL:SetPlayer(ply)
    self.ply = ply
    self.avatar:SetPlayer(ply, 64)
    self.nameLabel:SetText(ply:Nick())
    self.nameLabel:SizeToContents()
end

function PANEL:SetSpeaking(state)
    self.targetAlpha = state and 255 or 0
end

function PANEL:Think()
    -- fade in / out
    self.alpha = Lerp(FrameTime() * 10, self.alpha, self.targetAlpha)

    -- distance fade
    if IsValid(self.ply) then
        local dist = LocalPlayer():GetPos():Distance(self.ply:GetPos())
        local fade = math.Clamp(1 - (dist / config.maxDistance), 0.3, 1)
        self:SetAlpha(self.alpha * fade)
    else
        self:SetAlpha(self.alpha)
    end

    local vol = 0
    if IsValid(self.ply) then
        vol = math.Clamp(self.ply:VoiceVolume(), 0, 1)
    end

    -- speaking bar
    self.barWidth = Lerp(FrameTime() * 12, self.barWidth, vol * 160)

    -- create sound waves
    if vol > 0.15 and CurTime() > self.nextWave and self.alpha > 5 then
        table.insert(self.waves, {
            radius = 6,
            alpha = 150
        })
        self.nextWave = CurTime() + 0.15
    end

    -- update waves
    for i = #self.waves, 1, -1 do
        local w = self.waves[i]
        w.radius = w.radius + FrameTime() * 70
        w.alpha = w.alpha - FrameTime() * 220
        if w.alpha <= 0 then
            table.remove(self.waves, i)
        end
    end

    if self.alpha < 2 and self.targetAlpha == 0 then
        self:Remove()
    end
end

function PANEL:Paint(w, h)
    -- shadow
    draw.RoundedBox(
        config.radius,
        2, 2, w, h,
        ColorAlpha(config.shadowColor, self.alpha)
    )

    -- background
    draw.RoundedBox(
        config.radius,
        0, 0, w, h,
        ColorAlpha(config.bgColor, self.alpha)
    )

    -- top accent
    draw.RoundedBox(
        config.radius,
        0, 0, w, 3,
        ColorAlpha(config.accentColor, self.alpha)
    )

    -- sound waves (behind avatar)
    local cx = config.padding + 20
    local cy = config.padding + 20

    for _, wave in ipairs(self.waves) do
        surface.SetDrawColor(
            config.speakColor.r,
            config.speakColor.g,
            config.speakColor.b,
            math.min(wave.alpha, self.alpha)
        )
        draw.NoTexture()
        surface.DrawCircle(cx, cy, wave.radius)
    end

    -- speaking bar
    draw.RoundedBox(
        4,
        60, h - 14,
        self.barWidth, 6,
        ColorAlpha(config.speakColor, self.alpha)
    )

    -- mute icon
    if IsValid(self.ply) and self.ply:IsMuted() then
        draw.SimpleText(
            "X",
            "DermaLarge",
            w - 18,
            h / 2 - 12,
            ColorAlpha(config.mutedColor, self.alpha),
            TEXT_ALIGN_CENTER
        )
    end
end

vgui.Register("StylishVoicePanel", PANEL, "DPanel")

-- =========================
-- Helpers
-- =========================
local function CreateVoicePanel(ply)
    local panel = vgui.Create("StylishVoicePanel")
    panel:SetPlayer(ply)
    panel:SetSpeaking(true)
    voicePanels[ply] = panel
end

local function UpdatePositions()
    local y = ScrH() - 120
    local i = 0

    for _, panel in pairs(voicePanels) do
        if IsValid(panel) then
            panel:SetPos(
                ScrW() - config.width - 20,
                y - i * (config.height + config.spacing)
            )
            i = i + 1
        end
    end
end

-- =========================
-- Hooks
-- =========================
hook.Add("PlayerStartVoice", "StylishVoice_Start", function(ply)
    if not IsValid(ply) then return end

    if not IsValid(voicePanels[ply]) then
        CreateVoicePanel(ply)
    end

    voicePanels[ply]:SetSpeaking(true)
    return true -- hide default HUD
end)

hook.Add("PlayerEndVoice", "StylishVoice_End", function(ply)
    if IsValid(voicePanels[ply]) then
        voicePanels[ply]:SetSpeaking(false)
    end
end)

hook.Add("HUDPaint", "StylishVoice_Update", function()
    UpdatePositions()
end)

hook.Add("PlayerDisconnected", "StylishVoice_Cleanup", function(ply)
    if IsValid(voicePanels[ply]) then
        voicePanels[ply]:Remove()
    end
    voicePanels[ply] = nil
end)

print("[Stylish Voice Chat] Loaded (QoL version)")
