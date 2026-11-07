EasyMacros = EasyMacros or {}

local function Trim(text)
  if type(text) ~= "string" then
    return ""
  end
  return (text:match("^%s*(.-)%s*$")) or ""
end

-- Macro names max out at 16 characters.
function EasyMacros.MacroNameForSpell(spellName)
  spellName = Trim(spellName)
  if spellName == "" then
    return "EasyMacro"
  end
  local maxLen = EasyMacros.MACRO_NAME_MAX or 16
  if #spellName <= maxLen then
    return spellName
  end
  return spellName:sub(1, maxLen)
end

function EasyMacros.PreviewMacro(spellName, spellType)
  spellName = Trim(spellName)
  if spellName == "" then
    return nil
  end
  spellType = spellType or EasyMacros.TEMPLATE_COMBAT
  local includePet = spellType == EasyMacros.TEMPLATE_COMBAT and EasyMacros.IsPetClass()
  return {
    name = EasyMacros.MacroNameForSpell(spellName),
    body = EasyMacros.BuildMacroBody(spellName, spellType, { includePet = includePet }),
    spellType = spellType,
    includePet = includePet and true or false,
  }
end

-- Kept for callers that still ask for combat explicitly.
function EasyMacros.PreviewCombatMacro(spellName)
  return EasyMacros.PreviewMacro(spellName, EasyMacros.TEMPLATE_COMBAT)
end
