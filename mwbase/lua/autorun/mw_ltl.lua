-- Based on Zombie Survival Translation Library
-- https://github.com/JetBoom/zombiesurvival/blob/master/gamemodes/zombiesurvival/gamemode/sh_translate.lua

MWBLTL = {}

local Languages = {}
local Translations = {}
local AddingLanguage

function MWBLTL.GetTranslations(short)
	return Translations[short] || Translations["en"]
end

function MWBLTL.AddLanguage(short, long)
	Languages[short] = long
	Translations[short] = Translations[short] or {}
	AddingLanguage = short
end

function MWBLTL.AddTranslation(id, text)
	if (not AddingLanguage or not Translations[AddingLanguage]) then return end

	Translations[AddingLanguage][id] = text
end

function MWBLTL.Get(id)
	return MWBLTL.GetTranslations(GetConVar("gmod_language"):GetString())[id] or MWBLTL.GetTranslations("en")[id]
end

function MWBLTL.LoadingServerFiles(path)
    if (SERVER) then include(path) end
end

function MWBLTL.LoadingClientFiles(path)
    if (SERVER) then AddCSLuaFile(path) end
    if (CLIENT) then include(path) end
end

function MWBLTL.LoadingSharedFiles(path)
    MWBLTL.LoadingServerFiles(path)
    MWBLTL.LoadingClientFiles(path)
end

local dir = "weapons/mg_base/modules"
for _, name in pairs(file.Find(dir.."/languages/*.lua", "LUA")) do
	MWBLTL.LANGUAGE = {}
	MWBLTL.LoadingSharedFiles(dir.."/languages/"..name)
	for k, v in pairs(MWBLTL.LANGUAGE) do
		MWBLTL.AddTranslation(k, v)
	end
	MWBLTL.LANGUAGE = nil
end