EasyMacros = EasyMacros or {}

local FRAME_WIDTH = 440
local FRAME_HEIGHT = 420
local ICON_SIZE = 48
local LIST_ICON = 36
local LIST_LABEL_WIDTH = LIST_ICON + 8
local LIST_COLS_MAX = 8
local LIST_GAP = 4
local LIST_START_X = 6
local LIST_START_Y = -6
local LIST_ROW_EXTRA = 22
local PREVIEW_HEIGHT = 160
local SIDE_WIDTH = 78
local HINT_TEXT = "Drag A Spell Here From Your Spellbook.\nThen click Create."

local PANEL_BACKDROP = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function ContentTop()
  -- Portrait frames keep the header/portrait in the top ~60px.
  return -60
end

local function ApplyPanelBackdrop(frame, alpha)
  if not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0, 0, 0, alpha or 0.35)
  frame:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
end

local function SetMacroIconTexture(texture, icon)
  if not texture then
    return
  end
  if type(icon) == "number" then
    texture:SetTexture(icon)
  elseif type(icon) == "string" and icon ~= "" then
    if not icon:find("\\") and not icon:find("/") then
      texture:SetTexture("Interface\\Icons\\" .. icon)
    else
      texture:SetTexture(icon)
    end
  else
    texture:SetTexture("Interface\\Icons\\INV_MISC_QUESTIONMARK")
  end
end

-- Same drag path as MacroActionBar (Forever Macro Spellbook): OnDragStart → PickupMacro.
local function CreateMacroIconButton(parent, name, size)
  local button = CreateFrame("Button", name, parent)
  button:SetSize(size, size)
  button:EnableMouse(true)
  button:RegisterForDrag("LeftButton")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(size * 1.64, size * 1.64)
  border:SetPoint("CENTER")
  button.border = border

  button:SetScript("OnEnter", function(self)
    if not self.macroIndex then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("No macro yet")
      GameTooltip:AddLine("Drop a spell, then click Create", 0.8, 0.8, 0.8)
      GameTooltip:Show()
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.macroName or "Macro")
    GameTooltip:AddLine("Drag onto an action bar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStart", function(self)
    if self.macroIndex or self.macroName then
      EasyMacros.PickupManagedMacro(self.macroIndex, self.macroName)
    end
  end)

  function button:SetMacro(info)
    if not info then
      self.macroIndex = nil
      self.macroName = nil
      SetMacroIconTexture(self.icon, nil)
      self:Enable()
      self:SetAlpha(1)
      return
    end
    self.macroIndex = info.index
    self.macroName = info.name
    SetMacroIconTexture(self.icon, info.icon)
    self:Enable()
    self:SetAlpha(1)
  end

  button:SetMacro(nil)
  return button
end

local function SetCreateEnabled(frame, enabled)
  if frame.createButton then
    if enabled then
      frame.createButton:Enable()
    else
      frame.createButton:Disable()
    end
  end
end

local function ShowEmptyState(frame)
  frame.hasPreview = false
  frame.pendingSpell = nil
  frame.currentBody = ""
  frame.hint:Show()
  frame.bodyBox:Hide()
  frame.bodyBox:SetText("")
  frame.activeIcon:SetMacro(nil)
  frame.activeIcon:Show()
  if frame.activeLabel then
    frame.activeLabel:SetText("")
  end
  SetCreateEnabled(frame, false)
end

-- Draft preview only — no CreateMacro until Create Macro is clicked.
local function ShowPendingPreview(frame, spell, preview)
  frame.hasPreview = true
  frame.pendingSpell = spell
  frame.hint:Hide()
  frame.bodyBox:Show()
  frame.bodyBox:SetText(preview.body or "")
  if frame.bodyBox.SetCursorPosition then
    frame.bodyBox:SetCursorPosition(0)
  end
  frame.activeIcon:Show()
  -- Icon only; no macroIndex until create succeeds (cannot drag yet).
  frame.activeIcon:SetMacro({
    name = preview.name,
    icon = EasyMacros.SpellIcon(spell.spellId) or preview.name,
  })
  if frame.activeLabel then
    frame.activeLabel:SetText(preview.name or "")
  end
  SetCreateEnabled(frame, true)
end

local function ShowCreatedPreview(frame, result)
  frame.hasPreview = true
  frame.pendingSpell = nil
  frame.hint:Hide()
  frame.bodyBox:Show()
  frame.bodyBox:SetText(result.body or "")
  if frame.bodyBox.SetCursorPosition then
    frame.bodyBox:SetCursorPosition(0)
  end
  frame.activeIcon:Show()
  frame.activeIcon:SetMacro(result)
  if frame.activeLabel then
    frame.activeLabel:SetText(result.name or "")
  end
  SetCreateEnabled(frame, false)
end

local function ResetPreview(frame)
  ShowEmptyState(frame)
end

local function ListViewportWidth(frame)
  if frame.listScroll and frame.listScroll.GetWidth then
    local width = frame.listScroll:GetWidth()
    if width and width > 1 then
      return width
    end
  end
  -- Scroll inset: panel edges + scrollbar gutter.
  return FRAME_WIDTH - 60
end

local function FitListColumns(availableWidth)
  local stride = LIST_LABEL_WIDTH + LIST_GAP
  local cols = math.floor((availableWidth - LIST_START_X + LIST_GAP) / stride)
  return math.max(1, math.min(LIST_COLS_MAX, cols))
end

local function RefreshManagedList(frame)
  local list = EasyMacros.ListManagedMacros()
  frame.managed = list

  for _, button in ipairs(frame.listButtons) do
    button:Hide()
  end

  local availableWidth = ListViewportWidth(frame)
  local cols = FitListColumns(availableWidth)
  local stride = LIST_LABEL_WIDTH + LIST_GAP
  local rowHeight = LIST_ICON + LIST_ROW_EXTRA
  frame.listChild:SetWidth(availableWidth)

  for index, info in ipairs(list) do
    local button = frame.listButtons[index]
    if not button then
      button = CreateMacroIconButton(frame.listChild, nil, LIST_ICON)
      frame.listButtons[index] = button
      local nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      nameLabel:SetPoint("TOP", button, "BOTTOM", 0, -2)
      nameLabel:SetWidth(LIST_LABEL_WIDTH)
      nameLabel:SetJustifyH("CENTER")
      button.nameLabel = nameLabel
    end
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    -- Center the icon in the label-width cell so names stay inside the viewport.
    local cellX = LIST_START_X + col * stride
    local iconX = cellX + math.floor((LIST_LABEL_WIDTH - LIST_ICON) / 2)
    button:ClearAllPoints()
    button:SetPoint(
      "TOPLEFT",
      frame.listChild,
      "TOPLEFT",
      iconX,
      LIST_START_Y - row * rowHeight
    )
    button:SetMacro(info)
    if button.nameLabel then
      button.nameLabel:SetText(info.name)
    end
    button:Show()
  end

  local rows = math.max(1, math.ceil(math.max(#list, 1) / cols))
  frame.listChild:SetHeight(rows * rowHeight + 16)
  if frame.listHeader then
    frame.listHeader:SetText(string.format("Macros Created by Easy Macros: %d", #list))
  end
end

local function CreatePendingMacro(frame)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before creating macros.") then
    return
  end
  local spell = frame.pendingSpell
  if not spell then
    EasyMacros.Print("Drop a spell first.")
    return
  end
  -- CreateMacro on this click (hardware event), same as Macro Maker / MacroActionBar.
  EasyMacros.MakeMacroFromSpell(spell, function(result)
    if not frame or not frame.IsShown or not frame:IsShown() then
      return
    end
    if result then
      ShowCreatedPreview(frame, result)
    end
    RefreshManagedList(frame)
  end)
end

local function TryAcceptSpellDrop(frame)
  if EasyMacros.CombatBlocked and EasyMacros.CombatBlocked("Leave combat before dropping spells.") then
    return false
  end
  local spell = EasyMacros.CursorSpell and EasyMacros.CursorSpell()
  if not spell then
    return false
  end
  if ClearCursor then
    ClearCursor()
  end

  local spellType = EasyMacros.ClassifySpell(spell.spellId)
  local preview = EasyMacros.PreviewMacro(spell.name, spellType)
  if not preview then
    ShowEmptyState(frame)
    return true
  end
  ShowPendingPreview(frame, spell, preview)
  return true
end

function EasyMacros.CreateDropFrame()
  if EasyMacros.dropFrame then
    return EasyMacros.dropFrame
  end

  local frame = EasyMacros.CreatePortraitWindow("EasyMacrosFrame", "Easy Macros", FRAME_WIDTH, FRAME_HEIGHT)
  EasyMacros.dropFrame = frame

  -- Right column: icon + reset (outside the preview textbox).
  local side = CreateFrame("Frame", nil, frame)
  side:SetWidth(SIDE_WIDTH)
  side:SetPoint("TOPRIGHT", -12, ContentTop())
  side:SetHeight(PREVIEW_HEIGHT)
  frame.side = side

  local activeIcon = CreateMacroIconButton(side, "EasyMacrosActiveIcon", ICON_SIZE)
  activeIcon:SetPoint("TOP", side, "TOP", 0, -8)
  frame.activeIcon = activeIcon

  local activeLabel = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  activeLabel:SetPoint("TOP", activeIcon, "BOTTOM", 0, -4)
  activeLabel:SetWidth(SIDE_WIDTH)
  activeLabel:SetJustifyH("CENTER")
  frame.activeLabel = activeLabel

  local createButton = CreateFrame("Button", "EasyMacrosCreateButton", side, "UIPanelButtonTemplate")
  createButton:SetSize(SIDE_WIDTH - 8, 22)
  createButton:SetPoint("TOP", activeIcon, "BOTTOM", 0, -24)
  createButton:SetText("Create")
  createButton:Disable()
  createButton:SetScript("OnClick", function()
    CreatePendingMacro(frame)
  end)
  frame.createButton = createButton

  local resetButton = CreateFrame("Button", "EasyMacrosResetButton", side, "UIPanelButtonTemplate")
  resetButton:SetSize(SIDE_WIDTH - 8, 22)
  resetButton:SetPoint("TOP", createButton, "BOTTOM", 0, -4)
  resetButton:SetText("Reset")
  resetButton:SetScript("OnClick", function()
    ResetPreview(frame)
  end)
  frame.resetButton = resetButton

  -- Left: its own bordered preview / drop textbox.
  local previewFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  previewFrame:SetPoint("TOPLEFT", 12, ContentTop())
  previewFrame:SetPoint("TOPRIGHT", side, "TOPLEFT", -8, 0)
  previewFrame:SetHeight(PREVIEW_HEIGHT)
  ApplyPanelBackdrop(previewFrame, 0.35)
  frame.previewFrame = previewFrame

  local hint = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", 12, -12)
  hint:SetPoint("BOTTOMRIGHT", -12, 12)
  hint:SetJustifyH("CENTER")
  hint:SetJustifyV("MIDDLE")
  hint:SetText(HINT_TEXT)
  frame.hint = hint

  -- No scroll template: macro bodies are short, so avoid a permanent scrollbar.
  local bodyBox = CreateFrame("EditBox", "EasyMacrosBodyBox", previewFrame)
  bodyBox:SetMultiLine(true)
  bodyBox:SetFontObject(GameFontHighlightSmall)
  bodyBox:SetPoint("TOPLEFT", 10, -10)
  bodyBox:SetPoint("BOTTOMRIGHT", -10, 10)
  bodyBox:SetAutoFocus(false)
  bodyBox:EnableMouse(true)
  bodyBox:Hide()
  bodyBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  bodyBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(frame.currentBody or "")
    end
  end)
  frame.bodyBox = bodyBox

  local originalSetText = bodyBox.SetText
  bodyBox.SetText = function(self, text)
    frame.currentBody = text or ""
    originalSetText(self, frame.currentBody)
  end

  local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listHeader:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", 2, -12)
  listHeader:SetText("Macros Created by Easy Macros: 0")
  frame.listHeader = listHeader

  -- Secure click of Blizzard's micro button (not ShowUIPanel from addon code).
  local spellbookButton = EasyMacros.CreateSecureSpellbookButton
    and EasyMacros.CreateSecureSpellbookButton(frame, "EasyMacrosSpellbookButton")
  if spellbookButton then
    spellbookButton:SetSize(100, 22)
    spellbookButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame.spellbookButton = spellbookButton
  else
    local spellbookHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    spellbookHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    spellbookHint:SetText("Open your spellbook, then drag a spell here.")
    frame.spellbookHint = spellbookHint
  end

  local listPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  listPanel:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", -2, -6)
  listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 36)
  ApplyPanelBackdrop(listPanel, 0.25)
  frame.listPanel = listPanel

  local listScroll = CreateFrame("ScrollFrame", "EasyMacrosListScroll", listPanel, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", 4, -4)
  listScroll:SetPoint("BOTTOMRIGHT", -26, 4)
  frame.listScroll = listScroll

  local listChild = CreateFrame("Frame", nil, listScroll)
  listChild:SetSize(FRAME_WIDTH - 60, 80)
  listScroll:SetScrollChild(listChild)
  frame.listChild = listChild
  frame.listButtons = {}

  local function BindDropTarget(target)
    target:EnableMouse(true)
    target:SetScript("OnReceiveDrag", function()
      TryAcceptSpellDrop(frame)
    end)
    target:SetScript("OnMouseUp", function()
      TryAcceptSpellDrop(frame)
    end)
  end
  BindDropTarget(previewFrame)
  BindDropTarget(bodyBox)

  frame:SetScript("OnShow", function(self)
    RefreshManagedList(self)
    if not self.hasPreview then
      ShowEmptyState(self)
    end
  end)

  ShowEmptyState(frame)
  RefreshManagedList(frame)
  return frame
end

function EasyMacros.ToggleDropFrame(forceShow)
  local frame = EasyMacros.CreateDropFrame()
  if forceShow == true then
    EasyMacros.ShowMainFrame()
    return
  end
  if forceShow == false then
    EasyMacros.HideMainFrame()
    return
  end
  if frame:IsShown() then
    -- Always allow close, including during combat lockdown.
    EasyMacros.HideMainFrame()
  else
    EasyMacros.ShowMainFrame()
  end
end
