EasyMacros = EasyMacros or {}

-- Validated against Gethe/wow-ui-source `forever`:
-- Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua
--   /cast → SecureCmdOptionParse(msg) → CastSpellByName(action, target)
-- Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua
--   C_Spell.IsSelfBuff → aura applies to player only
--   C_Spell.IsSpellHelpful → can cast on player or other friendlies

EasyMacros.TEMPLATE_COMBAT = "combat"
EasyMacros.TEMPLATE_HELP = "help"
EasyMacros.TEMPLATE_SELF = "self"

-- Combat offensive spell. /petattack only for pet classes.
-- [dead, nohelp] clears a dead enemy; [noexists] then acquires a new one.
function EasyMacros.BuildCombatMacro(spellName, options)
  options = options or {}
  local includePet = options.includePet
  if includePet == nil then
    includePet = EasyMacros.IsPetClass()
  end

  local lines = {
    "#showtooltip",
    "/cleartarget [dead, nohelp]",
    "/targetenemy [noexists]",
    "/startattack",
  }
  if includePet then
    lines[#lines + 1] = "/petattack"
  end
  lines[#lines + 1] = "/cast " .. spellName
  return table.concat(lines, "\n")
end

-- Helpful spell that can be cast on others.
-- [@mouseover, help] uses mouseover when that unit is helpable.
-- [] always matches as the fallback (self / current target via default cast rules).
function EasyMacros.BuildHelpMacro(spellName)
  return "#showtooltip\n/cast [@mouseover, help][] " .. spellName
end

-- Personal / self-only helpful spell. No mouseover conditional.
function EasyMacros.BuildSelfMacro(spellName)
  return "#showtooltip\n/cast " .. spellName
end

function EasyMacros.BuildMacroBody(spellName, spellType, options)
  spellType = spellType or EasyMacros.TEMPLATE_COMBAT
  if spellType == EasyMacros.TEMPLATE_HELP then
    return EasyMacros.BuildHelpMacro(spellName)
  end
  if spellType == EasyMacros.TEMPLATE_SELF then
    return EasyMacros.BuildSelfMacro(spellName)
  end
  return EasyMacros.BuildCombatMacro(spellName, options)
end
