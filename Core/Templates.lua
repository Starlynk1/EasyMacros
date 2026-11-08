EasyMacros = EasyMacros or {}

-- Validated against Gethe/wow-ui-source `forever`:
-- Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua
--   /cast → SecureCmdOptionParse(msg) → CastSpellByName(action, target)
-- Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua
--   C_Spell.IsSelfBuff → aura applies to player only (unreliable for some Forever self buffs)
--   C_Spell.IsSpellHelpful → can cast on player or other friendlies
--   Self template also used when helpful + maxRange 0 (Demon Armor/Skin, Inner Fire, etc.)
--
-- Same CreateMacro/PickupMacro pattern as Cobas91/EasyMakro and MacroSpellBook:
-- real character macros with optional /petattack for pet classes.

EasyMacros.TEMPLATE_COMBAT = "combat"
EasyMacros.TEMPLATE_HELP = "help"
EasyMacros.TEMPLATE_SELF = "self"

-- Combat offensive spell.
-- [dead, nohelp] clears a dead enemy; [noexists] then acquires a new one.
-- /petattack only for Hunter / Warlock (same idea as EasyMakro's petAttack opt).
function EasyMacros.BuildCombatMacro(spellName)
  local lines = {
    "#showtooltip",
    "/cleartarget [dead, nohelp]",
    "/targetenemy [noexists]",
    "/startattack",
  }
  if EasyMacros.IsPetClass and EasyMacros.IsPetClass() then
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

function EasyMacros.BuildMacroBody(spellName, spellType)
  spellType = spellType or EasyMacros.TEMPLATE_COMBAT
  if spellType == EasyMacros.TEMPLATE_HELP then
    return EasyMacros.BuildHelpMacro(spellName)
  end
  if spellType == EasyMacros.TEMPLATE_SELF then
    return EasyMacros.BuildSelfMacro(spellName)
  end
  return EasyMacros.BuildCombatMacro(spellName)
end
