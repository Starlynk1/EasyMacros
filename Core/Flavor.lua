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

-- Classic Era / Hardcore / SoD-style era clients: interface 115xx.
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

-- Any Classic progression client: Era, Anniversary (TBC), Wrath, Cata, MoP.
function EasyMacros.IsClassic()
  if EasyMacros.IsForever() or EasyMacros.IsRetail() then
    return false
  end
  local toc = EasyMacros.GetTocVersion()
  if toc >= 11500 and toc < 12000 then
    return true
  end
  -- Anniversary/TBC 205xx, Wrath 304xx, Titan Reforged 380xx, Cata 404xx, MoP 505xx.
  if toc >= 20000 and toc < 60000 then
    return true
  end
  local id = WOW_PROJECT_ID
  if not id or id == WOW_PROJECT_MAINLINE then
    return false
  end
  if WOW_PROJECT_CLASSIC and id == WOW_PROJECT_CLASSIC then
    return true
  end
  if WOW_PROJECT_BURNING_CRUSADE_CLASSIC and id == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
    return true
  end
  if WOW_PROJECT_WRATH_CLASSIC and id == WOW_PROJECT_WRATH_CLASSIC then
    return true
  end
  if WOW_PROJECT_CATACLYSM_CLASSIC and id == WOW_PROJECT_CATACLYSM_CLASSIC then
    return true
  end
  if WOW_PROJECT_MISTS_CLASSIC and id == WOW_PROJECT_MISTS_CLASSIC then
    return true
  end
  return false
end

function EasyMacros.IsRetail()
  return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

function EasyMacros.IsSupported()
  return EasyMacros.IsRetail() or EasyMacros.IsForever() or EasyMacros.IsClassic()
end

-- Classic: 18 character macros. Forever/Retail: 30 (Classic + 12).
-- Some Forever builds still expose MAX_CHARACTER_MACROS as 18.
function EasyMacros.CharacterMacroLimit()
  local reported = tonumber(MAX_CHARACTER_MACROS) or 0
  if EasyMacros.IsForever() or EasyMacros.IsRetail() then
    if reported >= 30 then
      return reported
    end
    return 30
  end
  if reported > 0 then
    return reported
  end
  return 18
end

function EasyMacros.InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

function EasyMacros.CombatBlocked(message)
  if not EasyMacros.InCombat() then
    return false
  end
  EasyMacros.Print(message or "Leave combat before using Easy Macros.")
  return true
end

function EasyMacros.PlayerClassFile()
  if not UnitClass then
    return nil
  end
  local _, classFile = UnitClass("player")
  return classFile
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

-- Open the spellbook by securely clicking Blizzard's micro button.
-- Do NOT call ShowUIPanel / PlayerSpellsUtil / ToggleSpellBook from addon
-- OnClick — that taints PetActionBar:SetShownBase on Forever.
local function ResolveSpellbookMicroButton()
  -- Forever/Retail often expose both; prefer the spells frame button when present.
  return PlayerSpellsMicroButton or SpellbookMicroButton or TalentMicroButton
end

-- Returns a SecureActionButton that clicks the micro button, or nil.
function EasyMacros.CreateSecureSpellbookButton(parent, name)
  local micro = ResolveSpellbookMicroButton()
  if not micro then
    return nil
  end

  local button
  local ok = pcall(function()
    button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
  end)
  if not ok or not button then
    ok = pcall(function()
      button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    end)
  end
  if not ok or not button then
    return nil
  end

  if button.SetText then
    button:SetText("Spellbook")
  end
  -- Retail/Forever want up+down; Classic is fine with both registered.
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("type", "click")
  button:SetAttribute("clickbutton", micro)
  -- Spellbook open may CloseSpecialWindows / reshuffle panels. Re-assert via
  -- ShowUIPanel so we dock in the center slot beside the book (pushable 4).
  button:SetScript("PostClick", function()
    if EasyMacros.ShowMainFrame then
      EasyMacros.ShowMainFrame()
    end
    if EasyMacros.After and EasyMacros.DockBesideSpellbook then
      EasyMacros.After(0, EasyMacros.DockBesideSpellbook)
    elseif EasyMacros.DockBesideSpellbook then
      EasyMacros.DockBesideSpellbook()
    end
  end)
  return button
end

