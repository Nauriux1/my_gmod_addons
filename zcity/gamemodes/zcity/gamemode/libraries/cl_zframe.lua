-- Minimal ZFrame panel used by admin/mode menus (missing from Homigrad load path)
if not CLIENT then return end

local PANEL = {}

function PANEL:Init()
	self:SetTitle("")
	self:ShowCloseButton(true)
	self:SetDraggable(true)
	self:SetSizable(false)
end

function PANEL:SetBorder(b)
	-- compatibility no-op
end

function PANEL:Paint(w, h)
	draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 240))
	surface.SetDrawColor(200, 50, 50, 180)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

vgui.Register("ZFrame", PANEL, "DFrame")
