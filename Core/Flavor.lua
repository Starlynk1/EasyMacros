EasyMacros = EasyMacros or {}

function EasyMacros.GetTocVersion()
  local toc = select(4, GetBuildInfo())
  return tonumber(toc) or 0
end

-- Forever is 1.60.x / interface 16001 (folder _forever_).
function EasyMacros.IsForever()
  local toc = EasyMacros.GetTocVersion()
  if toc >= 16000 and toc < 20000 then
    return true
  end
  local version = GetBuildInfo()
  return type(version) == "string" and version:find("^1%.60") ~= nil
end

-- Classic Era / Anniversary / Hardcore: interface 115xx.
function EasyMacros.IsClassicEra()
  if EasyMacros.IsForever() then
    return false
  end
  local toc = EasyMacros.GetTocVersion()
  if toc >= 11500 and toc < 11600 then
    return true
  end
  if WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    return true
  end
  return false
end

function EasyMacros.IsRetail()
  return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

function EasyMacros.IsSupported()
  return EasyMacros.IsRetail() or EasyMacros.IsForever() or EasyMacros.IsClassicEra()
end

function EasyMacros.PlayerClassFile()
  if not UnitClass then
    return nil
  end
  local _, classFile = UnitClass("player")
  return classFile
end

-- Classes that keep a combat pet and benefit from /petattack.
local PET_CLASSES = {
  HUNTER = true,
  WARLOCK = true,
}

function EasyMacros.IsPetClass(classFile)
  classFile = classFile or EasyMacros.PlayerClassFile()
  return classFile and PET_CLASSES[classFile] == true
end

function EasyMacros.After(delay, callback)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, callback)
    return
  end
  local waiter = CreateFrame("Frame")
  waiter.elapsed = 0
  waiter:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= delay then
      self:SetScript("OnUpdate", nil)
      callback()
    end
  end)
end

local function SpellbookAlreadyOpen()
  if PlayerSpellsFrame and PlayerSpellsFrame.IsShown and PlayerSpellsFrame:IsShown() then
    if PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs and PlayerSpellsFrame.IsFrameTabActive then
      return PlayerSpellsFrame:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
    end
    return true
  end
  if SpellBookFrame and SpellBookFrame.IsShown and SpellBookFrame:IsShown() then
    return true
  end
  return false
end

-- Forever/Retail: PlayerSpellsUtil.OpenToSpellBookTab.
-- Classic Era: ToggleSpellBook / SpellBookFrame.
-- Only opens when hidden so we do not re-enter panel code every time.
function EasyMacros.OpenSpellbook()
  if SpellbookAlreadyOpen() then
    return true
  end
  if PlayerSpellsUtil and PlayerSpellsUtil.OpenToSpellBookTab then
    pcall(PlayerSpellsUtil.OpenToSpellBookTab)
    return true
  end
  if PlayerSpellsFrame then
    if ShowUIPanel then
      pcall(ShowUIPanel, PlayerSpellsFrame)
    else
      PlayerSpellsFrame:Show()
    end
    return true
  end
  if ToggleSpellBook then
    pcall(ToggleSpellBook, BOOKTYPE_SPELL or "spell")
    return true
  end
  if SpellBookFrame then
    if ShowUIPanel then
      pcall(ShowUIPanel, SpellBookFrame)
    else
      SpellBookFrame:Show()
    end
    return true
  end
  return false
end

function EasyMacros.OpenSpellbookDeferred()
  EasyMacros.After(0, function()
    EasyMacros.OpenSpellbook()
  end)
end
