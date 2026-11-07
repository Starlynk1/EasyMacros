EasyMacros = EasyMacros or {}

local function AccountMacroLimit()
  return MAX_ACCOUNT_MACROS or 120
end

local function MacroCounts()
  local numGlobal, numCharacter = 0, 0
  if GetNumMacros then
    numGlobal, numCharacter = GetNumMacros()
  end
  return numGlobal or 0, numCharacter or 0
end

local function MacroInfoAt(index)
  if not GetMacroInfo then
    return nil
  end
  local ok, name, icon, body = pcall(GetMacroInfo, index)
  if not ok or type(name) ~= "string" or name == "" then
    return nil
  end
  return {
    index = index,
    name = name,
    icon = icon,
    body = body or "",
  }
end

local function FindCharacterMacro(name)
  local _, numCharacter = MacroCounts()
  local first = AccountMacroLimit() + 1
  for offset = 0, numCharacter - 1 do
    local info = MacroInfoAt(first + offset)
    if info and info.name == name then
      return info
    end
  end
end

local function CharacterSlotsFree()
  local _, numCharacter = MacroCounts()
  local limit = MAX_CHARACTER_MACROS or 18
  return limit - numCharacter
end

-- Create or update a character macro. Never creates a second copy of the same name.
-- Returns: index, created (bool), unchanged (bool)
function EasyMacros.CreateOrUpdateCharacterMacro(name, body)
  if InCombatLockdown and InCombatLockdown() then
    EasyMacros.Print("Leave combat before creating macros.")
    return nil
  end
  if MacroFrame and MacroFrame:IsShown() then
    EasyMacros.Print("Close the macro window first.")
    return nil
  end

  name = EasyMacros.MacroNameForSpell(name)
  body = body or ""
  local icon = EasyMacros.NO_ICON or "INV_MISC_QUESTIONMARK"

  local existing = FindCharacterMacro(name)
  if existing then
    if existing.body == body then
      return existing.index, false, true
    end
    local ok, err = pcall(EditMacro, existing.index, name, icon, body)
    if not ok then
      EasyMacros.Print("Could not update macro: " .. tostring(err))
      return nil
    end
    return existing.index, false, false
  end

  if CharacterSlotsFree() <= 0 then
    EasyMacros.Print("No free character macro slots.")
    return nil
  end

  -- Forever/Classic treat integer 1 as false here; must pass boolean true
  -- or the macro is silently created in the General tab.
  local ok, result = pcall(CreateMacro, name, icon, body, true)
  if not ok then
    EasyMacros.Print("Could not create macro: " .. tostring(result))
    return nil
  end

  local index = (type(result) == "number" and result > 0) and result or nil
  if not index then
    local found = FindCharacterMacro(name)
    index = found and found.index or nil
  end
  if not index then
    EasyMacros.Print("Macro was created but not found in character slots.")
    return nil
  end
  if index <= AccountMacroLimit() then
    EasyMacros.Print("Macro landed in General slots instead of character slots.")
    return nil
  end
  return index, true, false
end

local function TypeNote(preview)
  if preview.spellType == EasyMacros.TEMPLATE_HELP then
    return " (help / mouseover)"
  end
  if preview.spellType == EasyMacros.TEMPLATE_SELF then
    return " (self)"
  end
  if preview.includePet then
    return " (combat, with /petattack)"
  end
  return " (combat, no /petattack)"
end

local function BuildResult(spell, preview, index, created, unchanged)
  local icon = EasyMacros.SpellIcon(spell.spellId) or preview.name
  local entry = {
    name = preview.name,
    spellId = spell.spellId,
    spellName = spell.name,
    spellType = preview.spellType,
    body = preview.body,
    icon = icon,
  }
  EasyMacros.TrackMacro(entry)

  local note = TypeNote(preview)
  if unchanged then
    EasyMacros.Print("Already have \"" .. preview.name .. "\"" .. note .. ".")
  elseif created then
    EasyMacros.Print("Created \"" .. preview.name .. "\"" .. note .. ".")
  else
    EasyMacros.Print("Updated \"" .. preview.name .. "\"" .. note .. ".")
  end

  return {
    index = index,
    created = created,
    unchanged = unchanged,
    name = preview.name,
    body = preview.body,
    spellType = preview.spellType,
    spellId = spell.spellId,
    spellName = spell.name,
    icon = icon,
    includePet = preview.includePet,
  }
end

-- CreateMacro/EditMacro taint action bars for the session. Run them off the
-- drag/click stack, and skip writes when the body is already identical.
-- onDone(result) is optional; result is nil on failure.
function EasyMacros.MakeMacroFromSpell(spell, onDone)
  if type(spell) ~= "table" or type(spell.name) ~= "string" or spell.name == "" then
    EasyMacros.Print("Drop a spell from your spellbook.")
    if onDone then
      onDone(nil)
    end
    return nil
  end

  local spellType = EasyMacros.ClassifySpell(spell.spellId)
  local preview = EasyMacros.PreviewMacro(spell.name, spellType)
  if not preview then
    if onDone then
      onDone(nil)
    end
    return nil
  end

  -- Fast path: already exists with the same body — no Create/EditMacro call.
  local existing = FindCharacterMacro(preview.name)
  if existing and existing.body == preview.body then
    local result = BuildResult(spell, preview, existing.index, false, true)
    if onDone then
      onDone(result)
    end
    return result
  end

  local function Finish()
    local index, created, unchanged = EasyMacros.CreateOrUpdateCharacterMacro(preview.name, preview.body)
    local result = index and BuildResult(spell, preview, index, created, unchanged) or nil
    if onDone then
      onDone(result)
    end
  end

  -- Next-frame write so we are not still inside the spell-drop mouse handler
  -- when action bars react to UPDATE_MACROS.
  if EasyMacros.After then
    EasyMacros.After(0, Finish)
    return nil
  end
  Finish()
  return nil
end

function EasyMacros.MakeCombatMacroFromSpell(spell, onDone)
  return EasyMacros.MakeMacroFromSpell(spell, onDone)
end

-- Live character macros that this addon tracks (missing ones are pruned).
function EasyMacros.ListManagedMacros()
  local tracked = EasyMacros.TrackedMacros()
  local live = {}
  for _, entry in ipairs(tracked) do
    local info = FindCharacterMacro(entry.name)
    if info then
      live[#live + 1] = {
        name = entry.name,
        spellId = entry.spellId,
        spellName = entry.spellName or entry.name,
        spellType = entry.spellType,
        body = info.body,
        icon = entry.icon or EasyMacros.SpellIcon(entry.spellId),
        index = info.index,
      }
    else
      EasyMacros.UntrackMacro(entry.name)
    end
  end
  return live
end

function EasyMacros.PickupManagedMacro(macroIndex)
  if InCombatLockdown and InCombatLockdown() then
    EasyMacros.Print("Leave combat before dragging macros.")
    return false
  end
  macroIndex = tonumber(macroIndex)
  if not macroIndex or macroIndex <= 0 or not PickupMacro then
    return false
  end
  local ok, err = pcall(PickupMacro, macroIndex)
  if not ok then
    EasyMacros.Print("Could not pick up macro: " .. tostring(err))
    return false
  end
  return true
end
