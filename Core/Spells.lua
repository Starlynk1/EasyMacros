EasyMacros = EasyMacros or {}

-- Classes that keep a combat pet and benefit from /petattack in combat macros.
-- Matches EasyMakro / Macro Spellbook pet-attack options (Hunter, Warlock).
local PET_CLASSES = {
  HUNTER = true,
  WARLOCK = true,
}

function EasyMacros.IsPetClass(classFile)
  if not classFile then
    classFile = select(2, UnitClass("player"))
  end
  return classFile and PET_CLASSES[classFile] and true or false
end

-- Forever docs: C_Spell.IsSpellHelpful / IsSpellHarmful (SpellDocumentation.lua).
-- Classic may still expose IsHelpfulSpell / IsHarmfulSpell.
function EasyMacros.IsSpellHelpful(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.IsSpellHelpful then
    local ok, result = pcall(C_Spell.IsSpellHelpful, spellId)
    if ok then
      return result and true or false
    end
  end
  if IsHelpfulSpell then
    local ok, result = pcall(IsHelpfulSpell, spellId)
    if ok then
      return result and true or false
    end
  end
  return nil
end

function EasyMacros.IsSpellHarmful(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.IsSpellHarmful then
    local ok, result = pcall(C_Spell.IsSpellHarmful, spellId)
    if ok then
      return result and true or false
    end
  end
  if IsHarmfulSpell then
    local ok, result = pcall(IsHarmfulSpell, spellId)
    if ok then
      return result and true or false
    end
  end
  return nil
end

-- Forever: C_Spell.IsSelfBuff — aura applies effects to the player only.
function EasyMacros.IsSpellSelfOnly(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.IsSelfBuff then
    local ok, result = pcall(C_Spell.IsSelfBuff, spellId)
    if ok then
      return result and true or false
    end
  end
  if SpellIsSelfBuff then
    local ok, result = pcall(SpellIsSelfBuff, spellId)
    if ok then
      return result and true or false
    end
  end
  return nil
end

-- Harmful → combat.
-- Helpful + self-only → plain /cast.
-- Helpful for others → mouseover help macro.
function EasyMacros.ClassifySpell(spellId)
  local helpful = EasyMacros.IsSpellHelpful(spellId)
  local harmful = EasyMacros.IsSpellHarmful(spellId)
  local selfOnly = EasyMacros.IsSpellSelfOnly(spellId)

  if helpful == true and harmful ~= true then
    if selfOnly == true then
      return EasyMacros.TEMPLATE_SELF
    end
    return EasyMacros.TEMPLATE_HELP
  end
  if helpful == true and harmful == true then
    -- Dual-purpose (rare). Prefer combat until a dedicated template exists.
    return EasyMacros.TEMPLATE_COMBAT
  end
  if harmful == true then
    return EasyMacros.TEMPLATE_COMBAT
  end
  if helpful == true then
    if selfOnly == true then
      return EasyMacros.TEMPLATE_SELF
    end
    return EasyMacros.TEMPLATE_HELP
  end
  return EasyMacros.TEMPLATE_COMBAT
end

function EasyMacros.SpellIcon(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
    if ok and texture then
      return texture
    end
  end
  if GetSpellTexture then
    local ok, texture = pcall(GetSpellTexture, spellId)
    if ok and texture then
      return texture
    end
  end
  if GetSpellInfo then
    local ok, _, _, icon = pcall(GetSpellInfo, spellId)
    if ok and icon then
      return icon
    end
  end
end

function EasyMacros.SpellName(spellId)
  spellId = tonumber(spellId)
  if not spellId then
    return nil
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
    if type(info) == "string" and info ~= "" then
      return info
    end
  end

  if C_Spell and C_Spell.GetSpellName then
    local name = C_Spell.GetSpellName(spellId)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  if GetSpellInfo then
    local name = GetSpellInfo(spellId)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
end

local function SpellIdFromBook(index, bookType)
  index = tonumber(index)
  if not index or index <= 0 then
    return nil
  end
  bookType = bookType or BOOKTYPE_SPELL or "spell"

  if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bookType)
    if ok and type(info) == "table" then
      local spellId = tonumber(info.spellID) or tonumber(info.spellId)
      if spellId then
        return spellId
      end
    end
  end

  if GetSpellBookItemInfo then
    local ok, kind, spellId = pcall(GetSpellBookItemInfo, index, bookType)
    if ok then
      spellId = tonumber(spellId)
      if spellId then
        return spellId
      end
    end
  end

  if GetSpellInfo then
    local ok, name, _, _, _, _, _, spellId = pcall(GetSpellInfo, index, bookType)
    if ok then
      spellId = tonumber(spellId)
      if spellId then
        return spellId
      end
      if type(name) == "string" and name ~= "" then
        return nil, name
      end
    end
  end
end

local function SpellNameFromBook(index, bookType)
  index = tonumber(index)
  if not index or index <= 0 then
    return nil
  end
  bookType = bookType or BOOKTYPE_SPELL or "spell"

  if GetSpellBookItemName then
    local ok, name = pcall(GetSpellBookItemName, index, bookType)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end

  if C_SpellBook and C_SpellBook.GetSpellBookItemName then
    local ok, name = pcall(C_SpellBook.GetSpellBookItemName, index, bookType)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
end

-- Spellbook drag returns: "spell", spellIndex, bookType, spellID [, baseSpellID]
-- Using spellIndex as a spellID is wrong (that is how Shadow Bolt became Swiftness).
function EasyMacros.CursorSpell()
  if not GetCursorInfo then
    return nil
  end

  local cursorType, spellIndex, bookType, spellId = GetCursorInfo()
  if cursorType ~= "spell" then
    return nil
  end

  spellIndex = tonumber(spellIndex)
  spellId = tonumber(spellId)

  -- Older odd clients may return only ("spell", spellID).
  if not spellId and type(bookType) ~= "string" then
    spellId = spellIndex
    spellIndex = nil
  end

  if not spellId and spellIndex then
    local resolvedId, resolvedName = SpellIdFromBook(spellIndex, bookType)
    spellId = resolvedId
    if not spellId and resolvedName then
      return {
        spellId = nil,
        name = resolvedName,
        bookIndex = spellIndex,
        bookType = bookType,
      }
    end
  end

  local name = spellId and EasyMacros.SpellName(spellId) or nil
  if (not name or name == "") and spellIndex then
    name = SpellNameFromBook(spellIndex, bookType)
  end
  if not name or name == "" then
    return nil
  end

  return {
    spellId = spellId,
    name = name,
    bookIndex = spellIndex,
    bookType = bookType,
  }
end
