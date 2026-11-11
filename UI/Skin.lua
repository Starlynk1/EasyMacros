EasyMacros = EasyMacros or {}

-- Forever / Retail / Classic each ship their own art for these templates.
-- Prefer PortraitFrameTemplate (round icon + header). Fall back carefully.
local PORTRAIT_ICON = "Interface\\Icons\\INV_Misc_Book_09"
-- Same grey/silver gear the world map uses (not UI-OptionsButton).
local GEAR_TEXTURE = "Interface\\WorldMap\\Gear_64Grey"
local GEAR_ATLAS = "Gear"
local MENU_AUTO_HIDE_SEC = 4

-- Forever may not expose MouseIsOver; prefer region:IsMouseOver().
local function IsMouseOverRegion(region)
  if not region then
    return false
  end
  if region.IsMouseOver then
    local ok, over = pcall(region.IsMouseOver, region)
    if ok then
      return over and true or false
    end
  end
  if MouseIsOver then
    local ok, over = pcall(MouseIsOver, region)
    if ok then
      return over and true or false
    end
  end
  return false
end

local function SetFrameTitle(frame, title)
  if frame.SetTitle then
    pcall(frame.SetTitle, frame, title)
  elseif frame.TitleContainer and frame.TitleContainer.TitleText then
    frame.TitleContainer.TitleText:SetText(title)
  elseif frame.TitleText then
    frame.TitleText:SetText(title)
  else
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -5)
    titleText:SetText(title)
    frame.TitleText = titleText
  end
end

local function SetFramePortrait(frame, path)
  if not frame or not path then
    return
  end
  if frame.SetPortraitToAsset then
    local ok = pcall(frame.SetPortraitToAsset, frame, path)
    if ok then
      return
    end
  end
  if frame.SetPortraitTextureRaw then
    local ok = pcall(frame.SetPortraitTextureRaw, frame, path)
    if ok then
      return
    end
  end
  local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
  if not portrait and frame.GetName then
    portrait = _G[frame:GetName() .. "Portrait"]
  end
  portrait = portrait or frame.portrait
  if portrait and portrait.SetTexture then
    portrait:SetTexture(path)
  end
end

function EasyMacros.ContentRegion(frame)
  return frame.Inset or frame
end

function EasyMacros.IsFrameUnlocked()
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  return db and db.frameUnlocked and true or false
end

function EasyMacros.IsShowSpellTooltip()
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  return db and db.showSpellTooltip and true or false
end

function EasyMacros.SetShowSpellTooltip(enabled)
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  if not db then
    return
  end
  db.showSpellTooltip = enabled and true or false
end

function EasyMacros.UsesBlizzardLayout()
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  if not db then
    return true
  end
  return db.useBlizzardLayout ~= false
end

function EasyMacros.SetUseBlizzardLayout(enabled)
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  if not db then
    return
  end
  db.useBlizzardLayout = enabled and true or false
end

function EasyMacros.AnchorFrameAtCurrentPosition(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end
  local left, bottom = frame:GetLeft(), frame:GetBottom()
  if not left or not bottom then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

-- UIPanel-managed frames cannot be freely dragged until removed from UIPanelWindows.
function EasyMacros.DetachFromUIPanel(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end
  local name = frame.GetName and frame:GetName()
  local left, bottom = frame:GetLeft(), frame:GetBottom()
  local shown = frame:IsShown()
  if name and UIPanelWindows and UIPanelWindows[name] then
    frame._easyMacrosPanelInfo = frame._easyMacrosPanelInfo or CopyTable and CopyTable(UIPanelWindows[name]) or UIPanelWindows[name]
    if shown and HideUIPanel then
      HideUIPanel(frame)
    end
    UIPanelWindows[name] = nil
  end
  if shown then
    frame:ClearAllPoints()
    if left and bottom then
      frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    else
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:Show()
  elseif left and bottom then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  end
  EasyMacros.SetUseBlizzardLayout(false)
end

function EasyMacros.ReattachToUIPanel(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end
  local name = frame.GetName and frame:GetName()
  if name and UIPanelWindows then
    UIPanelWindows[name] = frame._easyMacrosPanelInfo
      or {
        area = "left",
        pushable = 4,
        whileDead = 1,
        width = frame:GetWidth(),
      }
  end
  EasyMacros.SetUseBlizzardLayout(true)
end

function EasyMacros.SetFrameUnlocked(unlocked)
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  if not db then
    return
  end
  unlocked = unlocked and true or false
  db.frameUnlocked = unlocked
  local frame = EasyMacros.dropFrame
  if unlocked then
    -- Must leave UIPanel control or StartMoving does nothing / snaps back.
    EasyMacros.DetachFromUIPanel(frame)
  end
  -- Unchecking Unlock Frame only stops dragging; keep the current placement.
  EasyMacros.ApplyFrameLockState(frame)
end

function EasyMacros.CreatePortraitWindow(name, title, width, height)
  local frame
  local ok = pcall(function()
    frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
  end)
  if not ok or not frame then
    ok = pcall(function()
      frame = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    end)
  end
  if not ok or not frame then
    frame = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
      })
    end
  end

  frame:SetSize(width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  if frame.SetDontSavePosition then
    pcall(frame.SetDontSavePosition, frame, true)
  end

  SetFrameTitle(frame, title)
  SetFramePortrait(frame, PORTRAIT_ICON)

  EasyMacros.RegisterAsUIPanel(frame, width)
  EasyMacros.BindPanelCloseButton(frame)
  EasyMacros.BindFrameSettingsCog(frame)
  EasyMacros.ApplyFrameLockState(frame)

  frame:Hide()
  return frame
end

-- Sit beside Spellbook/Character via Blizzard's panel layout (higher pushable = further right).
function EasyMacros.RegisterAsUIPanel(frame, width)
  local name = frame and frame.GetName and frame:GetName()
  if not name or not UIPanelWindows then
    return
  end

  UIPanelWindows[name] = {
    area = "left",
    pushable = 4,
    whileDead = 1,
    width = width or frame:GetWidth(),
  }

  -- CloseSpecialWindows() wipes UISpecialFrames when Spellbook opens; stay out of that list.
  if UISpecialFrames then
    for index = #UISpecialFrames, 1, -1 do
      if UISpecialFrames[index] == name then
        table.remove(UISpecialFrames, index)
      end
    end
  end
end

function EasyMacros.BindPanelCloseButton(frame)
  if not frame then
    return
  end
  local close = frame.CloseButton or frame.ClosePanelButton
  if not close and frame.GetName then
    close = _G[frame:GetName() .. "CloseButton"]
  end
  if not close then
    return
  end
  frame.closeButton = close
  close:SetScript("OnClick", function()
    EasyMacros.HideMainFrame()
  end)
end

local function ResolveCloseButton(frame)
  return frame.closeButton
    or frame.CloseButton
    or frame.ClosePanelButton
    or (frame.GetName and _G[frame:GetName() .. "CloseButton"])
end

function EasyMacros.HideFrameSettingsMenu(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end
  if frame.settingsMenu then
    frame.settingsMenu:Hide()
  end
  if frame.settingsDismiss then
    frame.settingsDismiss:Hide()
  end
end

function EasyMacros.BindFrameSettingsCog(frame)
  if not frame or frame.settingsCog then
    return
  end

  local close = ResolveCloseButton(frame)
  local parent = (close and close:GetParent()) or frame
  local cog = CreateFrame("Button", "EasyMacrosSettingsCog", parent)
  cog:SetSize(18, 18)
  if close then
    cog:SetPoint("RIGHT", close, "LEFT", -2, 0)
    cog:SetFrameLevel(close:GetFrameLevel() + 5)
  else
    cog:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)
    cog:SetFrameLevel(frame:GetFrameLevel() + 10)
  end
  cog:EnableMouse(true)
  cog:RegisterForClicks("LeftButtonUp")
  cog:Show()

  local icon = cog:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(GEAR_TEXTURE)
  if (not icon.GetTexture or not icon:GetTexture()) and icon.SetAtlas then
    pcall(icon.SetAtlas, icon, GEAR_ATLAS)
  end
  cog.icon = icon

  cog:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  cog:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Frame settings")
    GameTooltip:AddLine("Unlock, tooltips, or reset frame position.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cog:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  cog:SetScript("OnClick", function(self)
    EasyMacros.ToggleFrameSettingsMenu(frame, self)
  end)

  frame.settingsCog = cog
end

local function EnsureSettingsDismiss(frame, menu)
  local dismiss = frame.settingsDismiss
  if not dismiss then
    dismiss = CreateFrame("Button", nil, UIParent)
    dismiss:SetAllPoints(UIParent)
    dismiss:SetFrameStrata("DIALOG")
    dismiss:EnableMouse(true)
    dismiss:RegisterForClicks("AnyUp")
    dismiss:Hide()
    dismiss:SetScript("OnClick", function()
      EasyMacros.HideFrameSettingsMenu(frame)
    end)
    frame.settingsDismiss = dismiss
  end
  dismiss:SetFrameLevel(math.max((menu:GetFrameLevel() or 1) - 1, 1))
  return dismiss
end

local CHECK_SIZE = 26
local CHECK_GAP = 4

local function ApplyVisibleCheckTextures(check)
  -- Forever/Retail UICheckButtonTemplate can end up with empty/tiny textures
  -- when resized; force the classic checkbox art so the box is readable.
  check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  if check.SetDisabledCheckedTexture then
    check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  end
  local function Fit(tex)
    if not tex then
      return
    end
    tex:ClearAllPoints()
    tex:SetAllPoints(check)
    tex:SetAlpha(1)
    tex:Show()
  end
  Fit(check:GetNormalTexture())
  Fit(check:GetPushedTexture())
  Fit(check:GetHighlightTexture())
  Fit(check:GetCheckedTexture())
  if check.GetDisabledCheckedTexture then
    Fit(check:GetDisabledCheckedTexture())
  end
end

local function SizeSettingsMenu(menu)
  local labelPad = 6
  local sidePad = 10
  local maxLabel = 0
  for _, key in ipairs({ "unlockCheck", "tooltipCheck" }) do
    local check = menu[key]
    if check and check.label then
      maxLabel = math.max(maxLabel, check.label:GetStringWidth() or 0)
    end
  end
  if menu.resetButton and menu.resetButton.label then
    maxLabel = math.max(maxLabel, menu.resetButton.label:GetStringWidth() or 0)
  end
  local checkRows = 0
  for _, key in ipairs({ "unlockCheck", "tooltipCheck" }) do
    if menu[key] then
      checkRows = checkRows + 1
    end
  end
  local actionRows = menu.resetButton and 1 or 0
  local width = math.ceil(sidePad + CHECK_SIZE + labelPad + maxLabel + sidePad)
  local height = 8
    + checkRows * CHECK_SIZE
    + math.max(0, checkRows - 1) * CHECK_GAP
    + (actionRows > 0 and (CHECK_GAP + CHECK_SIZE) or 0)
    + 8
  menu:SetWidth(width)
  menu:SetHeight(height)
end

local function EnsureSettingsMenu(frame)
  if frame.settingsMenu then
    return frame.settingsMenu
  end

  local menu = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  menu:SetFrameStrata("DIALOG")
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:Hide()
  if menu.SetBackdrop then
    menu:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 12,
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0, 0, 0, 0.92)
    menu:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
  end

  local function CreateMenuCheck(anchor, text)
    local check = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    if anchor then
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -CHECK_GAP)
    else
      check:SetPoint("TOPLEFT", 10, -8)
    end
    ApplyVisibleCheckTextures(check)

    -- Prefer template text region when present; otherwise own label.
    local label = check.Text or check.text
    if label then
      label:Show()
      label:ClearAllPoints()
      label:SetPoint("LEFT", check, "RIGHT", 6, 0)
      label:SetFontObject(GameFontHighlight)
      label:SetJustifyH("LEFT")
      label:SetText(text)
      label:SetTextColor(0.95, 0.95, 0.95)
    else
      label = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", check, "RIGHT", 6, 0)
      label:SetJustifyH("LEFT")
      label:SetText(text)
      label:SetTextColor(0.95, 0.95, 0.95)
    end
    check.label = label
    -- Clicking the label toggles the box too.
    check:SetHitRectInsets(0, -math.ceil((label:GetStringWidth() or 80) + 10), 0, 0)
    return check
  end

  -- One-shot menu row (not a toggle).
  local function CreateMenuAction(anchor, text)
    local button = CreateFrame("Button", nil, menu)
    button:SetHeight(CHECK_SIZE)
    if anchor then
      button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -CHECK_GAP)
    else
      button:SetPoint("TOPLEFT", 10, -8)
    end
    button:SetPoint("RIGHT", menu, "RIGHT", -10, 0)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", button, "LEFT", CHECK_SIZE + 6, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    label:SetTextColor(0.95, 0.95, 0.95)
    button.label = label
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    return button
  end

  local unlock = CreateMenuCheck(nil, "Unlock Frame")
  unlock:SetScript("OnClick", function(self)
    EasyMacros.BumpFrameSettingsMenuTimer(frame)
    EasyMacros.SetFrameUnlocked(self:GetChecked() and true or false)
  end)
  menu.unlockCheck = unlock

  local tooltip = CreateMenuCheck(unlock, "Show Tooltip")
  tooltip:SetScript("OnClick", function(self)
    EasyMacros.BumpFrameSettingsMenuTimer(frame)
    EasyMacros.SetShowSpellTooltip(self:GetChecked() and true or false)
  end)
  menu.tooltipCheck = tooltip

  local reset = CreateMenuAction(tooltip, "Reset Frame")
  reset:SetScript("OnClick", function()
    EasyMacros.BumpFrameSettingsMenuTimer(frame)
    EasyMacros.ResetFrameToBlizzardLayout()
    if frame.settingsMenu and frame.settingsMenu.unlockCheck then
      frame.settingsMenu.unlockCheck:SetChecked(EasyMacros.IsFrameUnlocked())
    end
  end)
  menu.resetButton = reset

  SizeSettingsMenu(menu)

  menu:SetScript("OnShow", function(self)
    EasyMacros.RefreshFrameSettingsMenu(frame)
    SizeSettingsMenu(self)
    EasyMacros.BumpFrameSettingsMenuTimer(frame)
    self:SetScript("OnUpdate", function(self, elapsed)
      self.hideRemaining = (self.hideRemaining or MENU_AUTO_HIDE_SEC) - elapsed
      if IsMouseOverRegion(self) or IsMouseOverRegion(frame.settingsCog) then
        self.hideRemaining = MENU_AUTO_HIDE_SEC
      end
      if self.hideRemaining <= 0 then
        EasyMacros.HideFrameSettingsMenu(frame)
      end
    end)
  end)
  menu:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
    if frame.settingsDismiss then
      frame.settingsDismiss:Hide()
    end
  end)

  frame.settingsMenu = menu
  return menu
end

function EasyMacros.BumpFrameSettingsMenuTimer(frame)
  frame = frame or EasyMacros.dropFrame
  if frame and frame.settingsMenu then
    frame.settingsMenu.hideRemaining = MENU_AUTO_HIDE_SEC
  end
end

function EasyMacros.RefreshFrameSettingsMenu(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame or not frame.settingsMenu then
    return
  end
  frame.settingsMenu.unlockCheck:SetChecked(EasyMacros.IsFrameUnlocked())
  if frame.settingsMenu.tooltipCheck then
    frame.settingsMenu.tooltipCheck:SetChecked(EasyMacros.IsShowSpellTooltip())
  end
end

function EasyMacros.ToggleFrameSettingsMenu(frame, anchor)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end
  local menu = EnsureSettingsMenu(frame)
  if menu:IsShown() then
    EasyMacros.HideFrameSettingsMenu(frame)
    return
  end
  menu:SetFrameLevel(100)
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor or frame.settingsCog or frame, "BOTTOMRIGHT", 0, -2)
  local dismiss = EnsureSettingsDismiss(frame, menu)
  dismiss:Show()
  EasyMacros.RefreshFrameSettingsMenu(frame)
  menu:Show()
end

local function BindDragHandle(handle, frame, unlocked)
  if not handle then
    return
  end
  if unlocked then
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
      EasyMacros.HideFrameSettingsMenu(frame)
      frame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      EasyMacros.SetUseBlizzardLayout(false)
      EasyMacros.AnchorFrameAtCurrentPosition(frame)
    end)
  else
    handle:RegisterForDrag()
    handle:SetScript("OnDragStart", nil)
    handle:SetScript("OnDragStop", nil)
  end
end

function EasyMacros.ApplyFrameLockState(frame)
  frame = frame or EasyMacros.dropFrame
  if not frame then
    return
  end

  local unlocked = EasyMacros.IsFrameUnlocked()
  frame:SetMovable(unlocked)
  frame:EnableMouse(true)
  -- Portrait title bar eats mouse; bind drag there too.
  BindDragHandle(frame, frame, unlocked)
  BindDragHandle(frame.TitleContainer, frame, unlocked)
  if frame.TitleContainer and frame.TitleContainer.TitleText and frame.TitleContainer.TitleText.EnableMouse then
    -- TitleText is usually a FontString; skip if not a frame.
  end

  if frame.settingsMenu and frame.settingsMenu:IsShown() then
    EasyMacros.RefreshFrameSettingsMenu(frame)
  end
end

function EasyMacros.ResetFrameToBlizzardLayout()
  local db = EasyMacros.EnsureDB and EasyMacros.EnsureDB()
  if db then
    db.frameUnlocked = false
    db.useBlizzardLayout = true
  end

  local frame = EasyMacros.dropFrame
  if not frame then
    return
  end
  EasyMacros.HideFrameSettingsMenu(frame)
  EasyMacros.ReattachToUIPanel(frame)
  EasyMacros.ApplyFrameLockState(frame)

  if frame:IsShown() then
    if HideUIPanel and ShowUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
      frame:Hide()
      ShowUIPanel(frame)
    else
      frame:Hide()
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      frame:Show()
    end
  else
    frame:ClearAllPoints()
  end
  if EasyMacros.LayoutAfterSpellbookToggle then
    EasyMacros.LayoutAfterSpellbookToggle()
  end
end

function EasyMacros.ShowMainFrame()
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before opening Easy Macros.") then
    return
  end
  local frame = EasyMacros.dropFrame or EasyMacros.CreateDropFrame and EasyMacros.CreateDropFrame()
  if not frame then
    return
  end
  EasyMacros.ApplyFrameLockState(frame)
  if not EasyMacros.UsesBlizzardLayout() then
    if not frame:IsShown() then
      if not frame:GetPoint(1) then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      end
      frame:Show()
    end
    return
  end
  if ShowUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
    ShowUIPanel(frame)
  else
    frame:Show()
  end
end

function EasyMacros.HideMainFrame()
  local frame = EasyMacros.dropFrame
  if not frame then
    return
  end
  EasyMacros.HideFrameSettingsMenu(frame)
  if not EasyMacros.UsesBlizzardLayout() then
    frame:Hide()
    return
  end
  if HideUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
    HideUIPanel(frame)
  else
    frame:Hide()
  end
end

local function ResolveSpellbookFrame()
  -- Forever/Retail panel is PlayerSpellsFrame (SpellBookFrame is the tab child).
  -- Classic uses standalone SpellBookFrame.
  if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then
    return PlayerSpellsFrame
  end
  if SpellBookFrame and SpellBookFrame:IsShown() then
    return SpellBookFrame
  end
  return PlayerSpellsFrame or SpellBookFrame
end

-- Keep Easy Macros on the right of the spellbook (book on the left).
function EasyMacros.DockBesideSpellbook()
  if not EasyMacros.UsesBlizzardLayout() then
    return
  end
  local frame = EasyMacros.dropFrame
  local book = ResolveSpellbookFrame()
  if not frame or not frame:IsShown() or not book or not book:IsShown() then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", book, "TOPRIGHT", 12, 0)
end

-- After the secure micro-button toggle: restore us if hidden, prefer book left / us right.
function EasyMacros.LayoutAfterSpellbookToggle()
  local frame = EasyMacros.dropFrame
  if not frame then
    return
  end

  local book = ResolveSpellbookFrame()
  local bookOpen = book and book:IsShown()

  if not EasyMacros.UsesBlizzardLayout() then
    if not frame:IsShown() then
      EasyMacros.ShowMainFrame()
    end
    return
  end

  if bookOpen then
    if frame:IsShown() and HideUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
      HideUIPanel(frame)
    end
    if UpdateUIPanelPositions then
      pcall(UpdateUIPanelPositions, book)
    end
    if ShowUIPanel and UIPanelWindows and UIPanelWindows[frame:GetName()] then
      ShowUIPanel(frame)
    else
      frame:Show()
    end
    EasyMacros.DockBesideSpellbook()
  elseif not frame:IsShown() then
    EasyMacros.ShowMainFrame()
  end
end
