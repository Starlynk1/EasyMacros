-- Easy Macros
-- Drop a spellbook spell onto the window to create a class-aware macro.

EasyMacros = EasyMacros or {}

EasyMacros.ADDON_NAME = "EasyMacros"
EasyMacros.VERSION = "1.0.2"
EasyMacros.NO_ICON = "INV_MISC_QUESTIONMARK"
-- Macro names are capped at 16 characters by the client.
EasyMacros.MACRO_NAME_MAX = 16

function EasyMacros.Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffEasy Macros:|r " .. tostring(message))
  end
end

function EasyMacros.EnsureDB()
  if type(EasyMacrosDB) ~= "table" then
    EasyMacrosDB = {}
  end
  return EasyMacrosDB
end

-- Per-character list of macros this addon created.
function EasyMacros.EnsureCharacterDB()
  if type(EasyMacrosCharacter) ~= "table" then
    EasyMacrosCharacter = {}
  end
  if type(EasyMacrosCharacter.macros) ~= "table" then
    EasyMacrosCharacter.macros = {}
  end
  return EasyMacrosCharacter
end

function EasyMacros.TrackedMacros()
  local db = EasyMacros.EnsureCharacterDB()
  return db.macros
end

function EasyMacros.TrackMacro(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" then
    return
  end
  local macros = EasyMacros.TrackedMacros()
  for index, existing in ipairs(macros) do
    if existing.name == entry.name then
      macros[index] = entry
      return
    end
  end
  macros[#macros + 1] = entry
end

function EasyMacros.UntrackMacro(name)
  local macros = EasyMacros.TrackedMacros()
  for index = #macros, 1, -1 do
    if macros[index].name == name then
      table.remove(macros, index)
    end
  end
end
