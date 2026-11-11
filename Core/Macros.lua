EasyMacros = EasyMacros or {}

-- Forever-compatible create/pickup matches notstraws/MacroActionBar (Macro Spellbook):
--   CreateMacro(name, icon, body, perCharacter)
--   PickupMacro(index)
-- No MacroFrame mediation. Drag from the addon UI onto action bars.

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
  local name, icon, body = GetMacroInfo(index)
  if type(name) ~= "string" or name == "" then
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
  local limit = EasyMacros.CharacterMacroLimit and EasyMacros.CharacterMacroLimit() or (MAX_CHARACTER_MACROS or 18)
  return limit - numCharacter
end

local function TypeNote(preview)
  if preview.spellType == EasyMacros.TEMPLATE_HELP then
    return " (help / mouseover)"
  end
  if preview.spellType == EasyMacros.TEMPLATE_SELF then
    return " (self)"
  end
  if EasyMacros.IsPetClass and EasyMacros.IsPetClass() then
    return " (combat, /petattack)"
  end
  return " (combat)"
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
    EasyMacros.Print("Created \"" .. preview.name .. "\"" .. note .. ". Drag it onto your bar.")
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
  }
end

-- Create or update a character macro (MacroActionBar-style plain API).
-- Returns: index, created (bool), unchanged (bool)
function EasyMacros.CreateOrUpdateCharacterMacro(name, body)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before creating macros.") then
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
    EditMacro(existing.index, name, icon, body)
    return existing.index, false, false
  end

  if CharacterSlotsFree() <= 0 then
    EasyMacros.Print("No free character macro slots.")
    return nil
  end

  -- Forever/Classic: boolean true for character macros (integer 1 is wrong on Forever).
  local result = CreateMacro(name, icon, body, true)

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

-- Call from the Create button OnClick (hardware event).
-- bodyOverride: optional edited macro text from the preview box.
function EasyMacros.MakeMacroFromSpell(spell, onDone, bodyOverride)
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
  if type(bodyOverride) == "string" then
    preview.body = bodyOverride
  end

  local existing = FindCharacterMacro(preview.name)
  if existing and existing.body == preview.body then
    local result = BuildResult(spell, preview, existing.index, false, true)
    if onDone then
      onDone(result)
    end
    return result
  end

  local index, created, unchanged = EasyMacros.CreateOrUpdateCharacterMacro(preview.name, preview.body)
  local result = index and BuildResult(spell, preview, index, created, unchanged) or nil
  -- MacroActionBar picks up on drag; after Create, put it on the cursor so the
  -- next drop can be straight onto an action bar (same PickupMacro API).
  if index and PickupMacro and not (EasyMacros.InCombat and EasyMacros.InCombat()) then
    PickupMacro(index)
  end
  if onDone then
    onDone(result)
  end
  return result
end

-- Save body edits for an existing tracked character macro (hardware event).
function EasyMacros.UpdateManagedMacroBody(name, body, onDone)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before editing macros.") then
    if onDone then
      onDone(nil)
    end
    return nil
  end
  if type(name) ~= "string" or name == "" then
    if onDone then
      onDone(nil)
    end
    return nil
  end
  body = body or ""

  local existing = FindCharacterMacro(name)
  if not existing then
    EasyMacros.Print("Macro \"" .. name .. "\" was not found.")
    EasyMacros.UntrackMacro(name)
    if onDone then
      onDone(nil)
    end
    return nil
  end

  if existing.body == body then
    EasyMacros.Print("No changes to \"" .. name .. "\".")
    local result = {
      index = existing.index,
      name = existing.name,
      body = existing.body,
      icon = existing.icon,
      unchanged = true,
    }
    if onDone then
      onDone(result)
    end
    return result
  end

  EditMacro(existing.index, existing.name, existing.icon, body)
  local tracked = EasyMacros.TrackedMacros()
  for _, entry in ipairs(tracked) do
    if entry.name == name then
      entry.body = body
      break
    end
  end
  EasyMacros.Print("Saved \"" .. name .. "\".")
  local result = {
    index = existing.index,
    name = existing.name,
    body = body,
    icon = existing.icon,
    unchanged = false,
  }
  if onDone then
    onDone(result)
  end
  return result
end

function EasyMacros.MakeCombatMacroFromSpell(spell, onDone)
  return EasyMacros.MakeMacroFromSpell(spell, onDone)
end

-- Rename a tracked character macro (hardware event / popup accept).
function EasyMacros.RenameManagedMacro(oldName, newName, onDone)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before renaming macros.") then
    if onDone then
      onDone(nil)
    end
    return nil
  end
  if type(oldName) ~= "string" or oldName == "" then
    if onDone then
      onDone(nil)
    end
    return nil
  end

  if type(newName) ~= "string" then
    newName = ""
  end
  newName = newName:match("^%s*(.-)%s*$") or ""
  if newName == "" then
    EasyMacros.Print("Enter a macro name.")
    if onDone then
      onDone(nil)
    end
    return nil
  end
  local maxLen = EasyMacros.MACRO_NAME_MAX or 16
  if #newName > maxLen then
    newName = newName:sub(1, maxLen)
  end

  local existing = FindCharacterMacro(oldName)
  if not existing then
    EasyMacros.Print("Macro \"" .. oldName .. "\" was not found.")
    EasyMacros.UntrackMacro(oldName)
    if onDone then
      onDone(nil)
    end
    return nil
  end

  if newName == oldName then
    local result = {
      index = existing.index,
      name = existing.name,
      body = existing.body,
      icon = existing.icon,
      unchanged = true,
    }
    if onDone then
      onDone(result)
    end
    return result
  end

  local conflict = FindCharacterMacro(newName)
  if conflict then
    EasyMacros.Print("A macro named \"" .. newName .. "\" already exists.")
    if onDone then
      onDone(nil)
    end
    return nil
  end

  EditMacro(existing.index, newName, existing.icon, existing.body)
  if EasyMacros.RenameTrackedMacro then
    EasyMacros.RenameTrackedMacro(oldName, newName)
  end
  EasyMacros.Print("Renamed \"" .. oldName .. "\" to \"" .. newName .. "\".")
  local result = {
    index = existing.index,
    name = newName,
    body = existing.body,
    icon = existing.icon,
    oldName = oldName,
    unchanged = false,
  }
  if onDone then
    onDone(result)
  end
  return result
end

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

-- MacroActionBar smb.pickupMacro: PickupMacro(index) from OnDragStart.
function EasyMacros.PickupManagedMacro(macroIndex, macroName)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before dragging macros.") then
    return false
  end
  if not PickupMacro then
    return false
  end

  local index = tonumber(macroIndex)
  if (not index or index <= 0) and type(macroName) == "string" and macroName ~= "" then
    local info = FindCharacterMacro(macroName)
    index = info and info.index
  end
  if not index or index <= 0 then
    return false
  end

  PickupMacro(index)
  return true
end
