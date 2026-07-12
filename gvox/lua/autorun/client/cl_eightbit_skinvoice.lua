include("autorun/sh_eightbit_skinvoice.lua")

CreateClientConVar("gvox_language", "en", true, false)

local L = EIGHTBIT_SKINVOICE.GetText
local GetPresetName = EIGHTBIT_SKINVOICE.GetPresetName

local rules = {}
local menuFrame = nil

local UI = {
    bg          = Color(15, 18, 28, 245),
    bg2         = Color(21, 25, 38, 250),
    card        = Color(24, 29, 44, 235),
    card2       = Color(29, 35, 52, 235),
    stroke      = Color(255, 255, 255, 10),
    stroke2     = Color(124, 92, 255, 70),

    text        = Color(238, 240, 255),
    subtext     = Color(155, 163, 190),
    muted       = Color(110, 118, 145),

    accent      = Color(124, 92, 255),
    accent2     = Color(98, 74, 214),
    accentHover = Color(140, 110, 255),

    danger      = Color(220, 90, 120),
    danger2     = Color(170, 65, 95),

    input       = Color(17, 21, 33, 240),
    inputHover  = Color(20, 25, 40, 245),
    rowHover    = Color(255, 255, 255, 8),
    rowSelect   = Color(124, 92, 255, 55),
}

surface.CreateFont("gVOX.Title", {
    font = "Roboto",
    size = 24,
    weight = 700,
    antialias = true
})

surface.CreateFont("gVOX.Subtitle", {
    font = "Roboto",
    size = 16,
    weight = 400,
    antialias = true
})

surface.CreateFont("gVOX.Text", {
    font = "Roboto",
    size = 16,
    weight = 500,
    antialias = true
})

surface.CreateFont("gVOX.Small", {
    font = "Roboto",
    size = 14,
    weight = 400,
    antialias = true
})

local function RoundedBox(r, x, y, w, h, col)
    draw.RoundedBox(r, x, y, w, h, col)
end

local function PaintCard(self, w, h)
    RoundedBox(12, 0, 0, w, h, UI.card)
    surface.SetDrawColor(UI.stroke)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function StyleButton(btn, mode)
    btn:SetText("")
    btn._Text = ""
    btn._Mode = mode or "default"

    function btn:SetButtonText(text)
        self._Text = text or ""
    end

    btn.Paint = function(self, w, h)
        local bg = UI.card2
        local outline = UI.stroke

        if self._Mode == "accent" then
            bg = self:IsHovered() and UI.accentHover or UI.accent
            outline = UI.stroke2
        elseif self._Mode == "danger" then
            bg = self:IsHovered() and UI.danger or UI.danger2
            outline = Color(255, 255, 255, 12)
        else
            bg = self:IsHovered() and Color(35, 41, 60, 245) or UI.card2
        end

        RoundedBox(10, 0, 0, w, h, bg)
        surface.SetDrawColor(outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(self._Text, "gVOX.Text", w / 2, h / 2, UI.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function StyleTextEntry(entry)
    entry:SetFont("gVOX.Text")
    entry:SetTextColor(UI.text)
    entry:SetCursorColor(UI.text)
    entry:SetHighlightColor(Color(124, 92, 255, 80))
    entry:SetPaintBackground(false)

    entry.Paint = function(self, w, h)
        RoundedBox(10, 0, 0, w, h, self:HasFocus() and UI.inputHover or UI.input)
        surface.SetDrawColor(self:HasFocus() and UI.stroke2 or UI.stroke)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        self:DrawTextEntryText(UI.text, UI.accent, UI.text)

        if self:GetValue() == "" and not self:HasFocus() and self:GetPlaceholderText() ~= "" then
            draw.SimpleText(self:GetPlaceholderText(), "gVOX.Text", 12, h / 2, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function StyleComboBox(box)
    box:SetText("")
    box:SetValue("")
    box:SetFont("gVOX.Text")
    box:SetTextColor(Color(0, 0, 0, 0))
    box:SetPaintBackground(false)

    if IsValid(box.DropButton) then
        box.DropButton:SetVisible(false)
        box.DropButton:SetText("")
        box.DropButton.Paint = function() end
    end

    box.Paint = function(self, w, h)
        RoundedBox(10, 0, 0, w, h, self:IsMenuOpen() and UI.inputHover or UI.input)
        surface.SetDrawColor(self:IsMenuOpen() and UI.stroke2 or UI.stroke)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local txt = self:GetText()
        if txt == "" then
            txt = "Select preset"
            draw.SimpleText(txt, "gVOX.Text", 12, h / 2, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(txt, "gVOX.Text", 12, h / 2, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        draw.SimpleText("⌄", "gVOX.Text", w - 16, h / 2 - 1, UI.subtext, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local oldOpenMenu = box.OpenMenu
    box.OpenMenu = function(self, ...)
        oldOpenMenu(self, ...)

        if not IsValid(self.Menu) then return end

        self.Menu.Paint = function(menu, w, h)
            RoundedBox(10, 0, 0, w, h, Color(19, 23, 35, 252))
            surface.SetDrawColor(UI.stroke2)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local canvas = self.Menu:GetCanvas()
        if not IsValid(canvas) then return end

        for _, pnl in ipairs(canvas:GetChildren()) do
            if IsValid(pnl) then
                pnl:SetFont("gVOX.Text")
                pnl:SetTextColor(UI.text)
                pnl:SetContentAlignment(4)
                pnl:SetTextInset(12, 0)

                pnl.Paint = function(s, w, h)
                    if s:IsHovered() then
                        RoundedBox(8, 4, 2, w - 8, h - 4, Color(124, 92, 255, 40))
                    end
                end
            end
        end
    end
end

local function UpdateMenuList()
    if not IsValid(menuFrame) then return end
    local ruleList = menuFrame.ruleList
    if not ruleList then return end

    ruleList:Clear()
    for _, rule in ipairs(rules) do
        local presetName = GetPresetName(rule.preset_id)
        ruleList:AddLine(rule.model, presetName)
    end
end

net.Receive("eightbit_skinvoice_send_rules", function()
    local count = net.ReadUInt(16)
    rules = {}

    for i = 1, count do
        local model = net.ReadString()
        local preset_id = net.ReadUInt(8)
        table.insert(rules, { model = model, preset_id = preset_id })
    end

    UpdateMenuList()
end)

local function RequestRules()
    net.Start("eightbit_skinvoice_request_rules")
    net.SendToServer()
end

local function OpenMenu()
    if not LocalPlayer():IsSuperAdmin() then
        chat.AddText(Color(255, 0, 0), L("msg_admin_only"))
        return
    end

    if IsValid(menuFrame) then
        menuFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(840, 540)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    menuFrame = frame

    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)

        RoundedBox(14, 0, 0, w, h, UI.bg)
        surface.SetDrawColor(UI.stroke)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        RoundedBox(14, 0, 0, w, 68, UI.bg2)

        draw.SimpleText(L("menu_title"), "gVOX.Title", 20, 24, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Manage voice preset rules", "gVOX.Subtitle", 20, 49, UI.subtext, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(Color(124, 92, 255, 35))
        surface.DrawRect(0, 67, w, 1)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(34, 34)
    closeBtn:SetPos(frame:GetWide() - 46, 17)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        local bg = self:IsHovered() and Color(55, 35, 50, 255) or Color(35, 39, 55, 255)
        RoundedBox(10, 0, 0, w, h, bg)
        surface.SetDrawColor(self:IsHovered() and Color(255, 120, 160, 100) or UI.stroke)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("✕", "gVOX.Text", w / 2, h / 2, UI.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function()
		surface.PlaySound("buttons/combine_button1.wav")
        frame:Close()
    end

    local body = vgui.Create("DPanel", frame)
    body:SetPos(14, 82)
    body:SetSize(frame:GetWide() - 28, frame:GetTall() - 96)
    body.Paint = nil

    local left = vgui.Create("DPanel", body)
    left:SetPos(0, 0)
    left:SetSize(500, body:GetTall())
    left.Paint = PaintCard

    local leftTitle = vgui.Create("DLabel", left)
    leftTitle:SetFont("gVOX.Text")
    leftTitle:SetTextColor(UI.text)
    leftTitle:SetText("Rules")
    leftTitle:SetPos(14, 12)
    leftTitle:SizeToContents()

    local leftSub = vgui.Create("DLabel", left)
    leftSub:SetFont("gVOX.Small")
    leftSub:SetTextColor(UI.subtext)
    leftSub:SetText("Voice presets linked to models")
    leftSub:SetPos(14, 32)
    leftSub:SizeToContents()

    local ruleList = vgui.Create("DListView", left)
    ruleList:SetPos(12, 58)
    ruleList:SetSize(left:GetWide() - 24, left:GetTall() - 70)
    ruleList:SetMultiSelect(false)
    ruleList:AddColumn("Model")
    ruleList:AddColumn("Preset")
    frame.ruleList = ruleList

    ruleList:SetHeaderHeight(28)
    ruleList:SetDataHeight(30)

    ruleList.Paint = function(self, w, h)
        RoundedBox(10, 0, 0, w, h, Color(17, 21, 33, 220))
        surface.SetDrawColor(UI.stroke)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    for _, col in ipairs(ruleList.Columns or {}) do
        col.Header:SetFont("gVOX.Small")
        col.Header:SetTextColor(UI.subtext)
        col.Header:SetContentAlignment(4)
        col.Header.Paint = function(self, w, h)
            surface.SetDrawColor(Color(255,255,255,6))
            surface.DrawRect(0, 0, w, h)
        end
    end

    ruleList.VBar.Paint = function() end
    ruleList.VBar.btnUp.Paint = function() end
    ruleList.VBar.btnDown.Paint = function() end
    ruleList.VBar.btnGrip.Paint = function(self, w, h)
        RoundedBox(6, 2, 0, w - 4, h, Color(90, 95, 120, 140))
    end

    local oldAddLine = ruleList.AddLine
    ruleList.AddLine = function(self, ...)
        local line = oldAddLine(self, ...)
        line:SetTall(30)

        line.Paint = function(s, w, h)
            local bg = s:IsSelected() and UI.rowSelect or (s:IsHovered() and UI.rowHover or Color(0,0,0,0))
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(Color(255,255,255,5))
            surface.DrawLine(8, h - 1, w - 8, h - 1)
        end

        for _, col in ipairs(line.Columns or {}) do
            col:SetFont("gVOX.Text")
            col:SetTextColor(UI.text)
        end

        return line
    end

    local right = vgui.Create("DPanel", body)
    right:SetPos(514, 0)
    right:SetSize(body:GetWide() - 514, body:GetTall())
    right.Paint = PaintCard

    local rightTitle = vgui.Create("DLabel", right)
    rightTitle:SetFont("gVOX.Text")
    rightTitle:SetTextColor(UI.text)
    rightTitle:SetText("Editor")
    rightTitle:SetPos(14, 12)
    rightTitle:SizeToContents()

    local rightSub = vgui.Create("DLabel", right)
    rightSub:SetFont("gVOX.Small")
    rightSub:SetTextColor(UI.subtext)
    rightSub:SetText("Add, update or remove a rule")
    rightSub:SetPos(14, 32)
    rightSub:SizeToContents()

    local modelLabel = vgui.Create("DLabel", right)
    modelLabel:SetFont("gVOX.Small")
    modelLabel:SetTextColor(UI.subtext)
    modelLabel:SetText(L("model_label"))
    modelLabel:SetPos(14, 74)
    modelLabel:SizeToContents()

    local modelEntry = vgui.Create("DTextEntry", right)
    modelEntry:SetPos(14, 94)
    modelEntry:SetSize(right:GetWide() - 28, 36)
    modelEntry:SetPlaceholderText("models/player/combine_soldier.mdl")
    StyleTextEntry(modelEntry)
    frame.modelEntry = modelEntry

    local presetLabel = vgui.Create("DLabel", right)
    presetLabel:SetFont("gVOX.Small")
    presetLabel:SetTextColor(UI.subtext)
    presetLabel:SetText(L("preset_label"))
    presetLabel:SetPos(14, 144)
    presetLabel:SizeToContents()

    local presetCombo = vgui.Create("DComboBox", right)
    presetCombo:SetPos(14, 164)
    presetCombo:SetSize(right:GetWide() - 28, 36)
    StyleComboBox(presetCombo)
    frame.presetCombo = presetCombo

    for _, p in ipairs(EIGHTBIT_SKINVOICE.PresetList) do
        presetCombo:AddChoice(GetPresetName(p.id), p.id)
    end
    presetCombo:ChooseOptionID(1)

    local addBtn = vgui.Create("DButton", right)
    addBtn:SetPos(14, 220)
    addBtn:SetSize(right:GetWide() - 28, 38)
    StyleButton(addBtn, "accent")
    addBtn:SetButtonText(L("add_button"))
    addBtn.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
        local model = modelEntry:GetValue():Trim()
        if model == "" then
            LocalPlayer():ChatPrint(L("msg_enter_model"))
            return
        end

        local preset_id = presetCombo:GetOptionData(presetCombo:GetSelectedID())
        if not preset_id then
            LocalPlayer():ChatPrint(L("msg_select_preset"))
            return
        end

        net.Start("eightbit_skinvoice_add_rule")
        net.WriteString(model)
        net.WriteUInt(preset_id, 8)
        net.SendToServer()
    end

    local removeBtn = vgui.Create("DButton", right)
    removeBtn:SetPos(14, 266)
    removeBtn:SetSize(right:GetWide() - 28, 38)
    StyleButton(removeBtn, "danger")
    removeBtn:SetButtonText(L("remove_button"))
    removeBtn.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
        local selected = ruleList:GetSelectedLine()
        if not selected then
            LocalPlayer():ChatPrint(L("msg_select_rule"))
            return
        end

        local model = ruleList:GetLine(selected):GetValue(1)
        net.Start("eightbit_skinvoice_remove_rule")
        net.WriteString(model)
        net.SendToServer()
    end

    local refreshBtn = vgui.Create("DButton", right)
    refreshBtn:SetPos(14, 312)
    refreshBtn:SetSize(right:GetWide() - 28, 38)
    StyleButton(refreshBtn, "default")
    refreshBtn:SetButtonText(L("refresh_button"))
    refreshBtn.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
        RequestRules()
    end

    local hint = vgui.Create("DLabel", right)
    hint:SetFont("gVOX.Small")
    hint:SetTextColor(UI.muted)
    hint:SetText("Tip: select a rule on the left to quickly edit it.")
    hint:SetPos(14, 365)
    hint:SizeToContents()

    function ruleList:OnRowSelected(index, line)
        local model = line:GetValue(1)
        local presetName = line:GetValue(2)

        modelEntry:SetText(model)

        for i, p in ipairs(EIGHTBIT_SKINVOICE.PresetList) do
            if GetPresetName(p.id) == presetName then
                presetCombo:ChooseOptionID(i)
                break
            end
        end
    end

    UpdateMenuList()
    RequestRules()
end

concommand.Add("gvox_skinvoice_menu", OpenMenu)

hook.Add("PopulateToolMenu", "eightbit_skinvoice_populate", function()
    spawnmenu.AddToolMenuOption("Utilities", "gVOX", "eightbit_skinvoice", L("menu_util_label"), "", "", function(panel)
        panel:ClearControls()

        local langCombo = vgui.Create("DComboBox", panel)
        langCombo:SetSortItems(false)

        local currentLang = GetConVarString("gvox_language") or "en"

        for code, name in SortedPairs(EIGHTBIT_SKINVOICE.AvailableLangs) do
            langCombo:AddChoice(name, code)
        end

        for id, data in ipairs(langCombo.Data or {}) do
            if data == currentLang then
                langCombo:ChooseOptionID(id)
                break
            end
        end

        langCombo.OnSelect = function(_, _, _, data)
            RunConsoleCommand("gvox_language", data)
        end

        panel:Help(L("language_label"))
        panel:AddItem(langCombo)
        panel:Help(" ")
        panel:Button(L("menu_util_label"), "gvox_skinvoice_menu")
    end)
end)

cvars.AddChangeCallback("gvox_language", function(_, old, new)
    if old ~= new then
        chat.AddText(Color(100, 200, 255), L("msg_language_changed"))
    end
end)

MsgC(Color(0,255,0), "[gVOX] Client menu loaded.\n")
